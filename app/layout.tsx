import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://theboss.biz"),
  title: {
    default: "The Boss | Fundraise. Save. Engage.",
    template: "%s | The Boss"
  },
  description:
    "The Boss ecosystem helps teams, organizations, families and communities save money, raise money, stay connected and create opportunity.",
  openGraph: {
    title: "The Boss | The Boss Ecosystem",
    description:
      "One ecosystem. More ways to save, fundraise, engage and grow.",
    type: "website"
  },
  robots: { index: false, follow: false }
};

export default function RootLayout({children}:{children:React.ReactNode}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
