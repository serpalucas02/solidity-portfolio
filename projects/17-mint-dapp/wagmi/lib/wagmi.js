import { http, createConfig } from "wagmi";
import { arbitrum } from "wagmi/chains";
import { injected } from "wagmi/connectors";

// Config de wagmi: qué redes soporta la app, con qué wallet se conecta
// (injected = MetaMask y similares) y por qué RPC habla con la cadena.
export const config = createConfig({
  chains: [arbitrum],
  connectors: [injected()],
  transports: {
    [arbitrum.id]: http(),
  },
});
