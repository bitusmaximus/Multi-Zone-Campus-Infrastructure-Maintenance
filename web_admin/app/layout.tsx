import type { Metadata } from 'next';
import Script from 'next/script';
import { ThemeProvider } from '@/app/components/theme-provider';
import './globals.css';

export const metadata: Metadata = {
  title: 'Campus Dispatch | BDU Facilities',
  description: 'Campus infrastructure maintenance dispatch dashboard.',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <Script id="theme-init" strategy="beforeInteractive">
          {`try { const saved = localStorage.getItem('campus-dispatch-theme'); const theme = saved === 'dark' || saved === 'light' ? saved : (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'); document.documentElement.dataset.theme = theme; } catch { document.documentElement.dataset.theme = 'light'; }`}
        </Script>
      </head>
      <body><ThemeProvider>{children}</ThemeProvider></body>
    </html>
  );
}