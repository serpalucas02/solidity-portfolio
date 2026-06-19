"use client";

import { useState } from "react";
import { ethers } from "ethers";
import {
  CONTRACT_ADDRESS,
  CONTRACT_ABI,
  ARBITRUM_CHAIN_ID_HEX,
  ARBITRUM_PARAMS,
} from "../lib/contract";

export default function Home() {
  const [account, setAccount] = useState("");
  const [balance, setBalance] = useState(null);
  const [isMinting, setIsMinting] = useState(false);
  const [error, setError] = useState("");

  const isConnected = account !== "";

  // 1. Conectar MetaMask y asegurarse de estar en Arbitrum
  async function connectWallet() {
    setError("");
    if (!window.ethereum) {
      setError("Instalá MetaMask para continuar.");
      return;
    }

    try {
      const [addr] = await window.ethereum.request({
        method: "eth_requestAccounts",
      });

      // Si no estamos en Arbitrum, pedimos el cambio (o agregar la red).
      const chainId = await window.ethereum.request({ method: "eth_chainId" });
      if (chainId !== ARBITRUM_CHAIN_ID_HEX) {
        try {
          await window.ethereum.request({
            method: "wallet_switchEthereumChain",
            params: [{ chainId: ARBITRUM_CHAIN_ID_HEX }],
          });
        } catch (switchError) {
          // 4902 = la red no está agregada en la wallet -> la agregamos
          if (switchError.code === 4902) {
            await window.ethereum.request({
              method: "wallet_addEthereumChain",
              params: [ARBITRUM_PARAMS],
            });
          } else {
            throw switchError;
          }
        }
      }

      setAccount(addr);
      await refreshBalance(addr);
    } catch (err) {
      console.error(err);
      setError("No se pudo conectar la wallet.");
    }
  }

  // 2. Leer el balance del token (función view, no cuesta gas)
  async function refreshBalance(addr) {
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const contract = new ethers.Contract(
        CONTRACT_ADDRESS,
        CONTRACT_ABI,
        provider
      );
      const bal = await contract.balanceOf(addr);
      setBalance(bal.toString());
    } catch {
      // Si el contrato no está deployado todavía, no rompemos la UI.
      setBalance(null);
    }
  }

  // 3. Mintear: manda una transacción que ejecuta mintBAC()
  async function mintToken() {
    setError("");
    setIsMinting(true);
    try {
      // El signer representa a la cuenta conectada: es quien firma y paga el gas.
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const contract = new ethers.Contract(
        CONTRACT_ADDRESS,
        CONTRACT_ABI,
        signer
      );

      const tx = await contract.mintBAC(); // dispara la transacción
      await tx.wait(); // espera a que se mine

      await refreshBalance(account);
    } catch (err) {
      console.error(err);
      setError("Falló el minteo (¿contrato deployado? ¿tenés ETH para gas?).");
    } finally {
      setIsMinting(false);
    }
  }

  return (
    <div className="container">
      <h1>Mint dApp</h1>
      <p className="subtitle">ethers v6 + MetaMask · Arbitrum One</p>

      {!isConnected ? (
        <button onClick={connectWallet}>Conectar MetaMask</button>
      ) : (
        <div>
          <div className="account">
            {account.slice(0, 6)}…{account.slice(-4)}
          </div>

          {balance !== null && (
            <p className="balance">Balance: {balance} BAC</p>
          )}

          <button onClick={mintToken} disabled={isMinting}>
            {isMinting ? "Minteando…" : "Mint Token"}
          </button>
        </div>
      )}

      {error && <p className="error">{error}</p>}
    </div>
  );
}
