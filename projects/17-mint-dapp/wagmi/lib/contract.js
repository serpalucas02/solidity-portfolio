// Configuración del contrato.
// Reemplazá CONTRACT_ADDRESS por la dirección real cuando deployes el token.
export const CONTRACT_ADDRESS = "0x0000000000000000000000000000000000000000";

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
