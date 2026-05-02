import type { Metadata, Viewport } from "next";
import { SITE } from "@/lib/config";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(SITE.url),
  title: {
    default: `${SITE.name} — Free Battle.net launcher for Apple Silicon`,
    template: `%s · ${SITE.name}`,
  },
  description: SITE.description,
  applicationName: SITE.name,
  keywords: [
    "Diablo IV Mac",
    "Diablo 4 macOS",
    "Battle.net Mac",
    "Apple Silicon",
    "GPTK",
    "Wine",
    "D3DMetal",
    "Blizzard Mac",
    "free Battle.net launcher",
    "Whisky alternative",
    "Mythic alternative",
    "CrossOver alternative",
  ],
  authors: [{ name: `${SITE.name} contributors` }],
  alternates: { canonical: "/" },
  openGraph: {
    title: `${SITE.name} — Free Battle.net launcher for Apple Silicon`,
    description: SITE.description,
    url: SITE.url,
    siteName: SITE.name,
    locale: "en_US",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: `${SITE.name} — Free Battle.net launcher for Apple Silicon`,
    description: SITE.shortDescription,
  },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, "max-image-preview": "large" },
  },
  category: "technology",
};

export const viewport: Viewport = {
  themeColor: "#0d1117",
  colorScheme: "dark",
};

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: SITE.name,
  applicationCategory: "GameApplication",
  applicationSubCategory: "Game launcher",
  operatingSystem: "macOS 14+",
  processorRequirements: "Apple Silicon (arm64)",
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
  description: SITE.description,
  url: SITE.url,
  downloadUrl: `${SITE.url}/api/download`,
  installUrl: `${SITE.url}/api/download`,
  screenshot: `${SITE.url}/opengraph-image.png`,
  image: `${SITE.url}/opengraph-image.png`,
  license: "https://opensource.org/licenses/MIT",
  isAccessibleForFree: true,
  softwareVersion: "0.1.0",
  inLanguage: "en",
  publisher: { "@type": "Organization", name: SITE.name, url: SITE.url },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
        {children}
      </body>
    </html>
  );
}
