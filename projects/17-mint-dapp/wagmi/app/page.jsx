"use client";

import { useEffect } from "react";
import {
  useAccount,
  useConnect,
  useDisconnect,
  useSwitchChain,
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { arbitrum } from "wagmi/chains";
import { CONTRACT_ADDRESS, CONTRACT_ABI } from "../lib/contract";

export default function Home() {
  // Estado de la cuenta y de la red, todo via hooks (wagmi maneja los listeners).
  const { address, isConnected, chainId } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain } = useSwitchChain();

  const onArbitrum = chainId === arbitrum.id;

  // Lectura on-chain (balanceOf). Se cachea y se puede refetchear.
  const { data: balance, refetch } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: CONTRACT_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: isConnected && onArbitrum },
  });

  // Escritura on-chain (mintBAC). writeContract dispara la tx; hash la identifica.
  const { writeContract, data: hash, isPending } = useWriteContract();

  // Espera a que la transacción se mine.
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  // Cuando el mint se confirma, refrescamos el balance.
  useEffect(() => {
    if (isSuccess) refetch();
  }, [isSuccess, refetch]);

  function mint() {
    writeContract({
      address: CONTRACT_ADDRESS,
      abi: CONTRACT_ABI,
      functionName: "mintBAC",
    });
  }

  const isMinting = isPending || isConfirming;

  return (
    <div className="container">
      <h1>Mint dApp</h1>
      <p className="subtitle">wagmi + viem · Arbitrum One</p>

      {!isConnected ? (
        // injected() = MetaMask y wallets inyectadas en el browser
        <button onClick={() => connect({ connector: connectors[0] })}>
          Conectar wallet
        </button>
      ) : !onArbitrum ? (
        <button onClick={() => switchChain({ chainId: arbitrum.id })}>
          Cambiar a Arbitrum
        </button>
      ) : (
        <div>
          <div className="account">
            {address.slice(0, 6)}…{address.slice(-4)}
          </div>

          {balance !== undefined && (
            <p className="balance">Balance: {balance.toString()} BAC</p>
          )}

          <button onClick={mint} disabled={isMinting}>
            {isMinting ? "Minteando…" : "Mint Token"}
          </button>

          <button
            onClick={() => disconnect()}
            style={{
              background: "transparent",
              color: "#8b949e",
              marginTop: "0.75rem",
            }}
          >
            Desconectar
          </button>
        </div>
      )}
    </div>
  );
}
