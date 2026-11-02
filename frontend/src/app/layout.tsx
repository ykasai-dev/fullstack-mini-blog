import type { Metadata } from "next";
import "./globals.css";
import Link from "next/link";
import AuthButton from "@/components/AuthButton";

export const metadata: Metadata = {
  title: "Mini Blog",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="ja">
      <body>
        <header>
          <nav>
            <Link href="/">Home</Link>
            <AuthButton />
          </nav>
        </header>
        {children}
      </body>
    </html>
  );
}
