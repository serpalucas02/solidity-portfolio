import "./globals.css";

export const metadata = {
  title: "Mint dApp — ethers v6",
  description: "Mintear un token llamando mintBAC() con ethers v6 + MetaMask",
};

export default function RootLayout({ children }) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
