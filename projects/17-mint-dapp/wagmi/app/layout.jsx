import "./globals.css";
import { Providers } from "./providers";

export const metadata = {
  title: "Mint dApp — wagmi + viem",
  description: "Mintear un token llamando mintBAC() con wagmi + viem",
};

export default function RootLayout({ children }) {
  return (
    <html lang="es">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
