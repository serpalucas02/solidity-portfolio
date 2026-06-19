// Configuración del contrato.
// Reemplazá CONTRACT_ADDRESS por la dirección real cuando deployes el token.
export const CONTRACT_ADDRESS = "0x0000000000000000000000000000000000000000";

// Arbitrum One
export const ARBITRUM_CHAIN_ID = 42161;
export const ARBITRUM_CHAIN_ID_HEX = "0xa4b1"; // 42161 en hex (lo que pide MetaMask)

export const ARBITRUM_PARAMS = {
  chainId: ARBITRUM_CHAIN_ID_HEX,
  chainName: "Arbitrum One",
  nativeCurrency: { name: "ETH", symbol: "ETH", decimals: 18 },
  rpcUrls: ["https://arb1.arbitrum.io/rpc"],
  blockExplorerUrls: ["https://arbiscan.io"],
};

// ABI mínimo: solo las funciones que usa el front.
export const CONTRACT_ABI = [
  {
    type: "function",
    name: "mintBAC",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
];
