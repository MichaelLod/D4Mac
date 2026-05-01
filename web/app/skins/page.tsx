import Link from "next/link";

type SkinCard = {
  sku: string;
  name: string;
  price: string;
  blurb: string;
  colors: [string, string];
};

const SKINS: SkinCard[] = [
  {
    sku: "skin-tristram",
    name: "Tristram",
    price: "$2.99",
    blurb: "Diablo II parchment + blood red.",
    colors: ["#F0E0B0", "#B83030"],
  },
  {
    sku: "skin-westmarch",
    name: "Westmarch",
    price: "$2.99",
    blurb: "Templar gold and ivory.",
    colors: ["#E5C772", "#8B5A2B"],
  },
  {
    sku: "skin-zakarum",
    name: "Zakarum",
    price: "$2.99",
    blurb: "Light-touched Khanduran white.",
    colors: ["#F4F4F8", "#A6B5C9"],
  },
  {
    sku: "bundle-act1",
    name: "Act 1 Bundle",
    price: "$7.99",
    blurb: "Tristram + Westmarch + Zakarum. Save $1.",
    colors: ["#F0E0B0", "#A6B5C9"],
  },
  {
    sku: "lifetime-all",
    name: "Lifetime Pass",
    price: "$14.99",
    blurb: "Every skin we ever make. One purchase, forever.",
    colors: ["#00AEFF", "#B83030"],
  },
];

export const metadata = {
  title: "Skins · D4Mac",
  description:
    "Cosmetic themes for the D4Mac launcher. One-time purchase, lifetime access on all your Macs.",
};

export default function SkinsPage() {
  return (
    <main style={{ minHeight: "100vh", padding: "64px 24px" }}>
      <div style={{ maxWidth: 880, margin: "0 auto" }}>
        <Link
          href="/"
          style={{
            color: "var(--text-dim)",
            textDecoration: "none",
            fontSize: 14,
          }}
        >
          ← Back
        </Link>
        <h1
          style={{
            fontSize: "clamp(40px, 7vw, 64px)",
            fontWeight: 800,
            letterSpacing: "-0.03em",
            margin: "20px 0 8px",
            background:
              "linear-gradient(180deg, #ffffff 0%, var(--accent-2) 100%)",
            WebkitBackgroundClip: "text",
            backgroundClip: "text",
            WebkitTextFillColor: "transparent",
          }}
        >
          D4Mac Skins
        </h1>
        <p
          style={{
            fontSize: 18,
            color: "var(--text-dim)",
            maxWidth: 560,
            marginBottom: 48,
          }}
        >
          Cosmetic themes for the launcher. One-time purchase, lifetime access
          on all your Macs.
        </p>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
            gap: 16,
          }}
        >
          {SKINS.map((skin) => (
            <a
              key={skin.sku}
              href={`/api/checkout?sku=${skin.sku}`}
              style={{
                display: "block",
                padding: 20,
                background: "var(--surface)",
                border: "1px solid var(--border)",
                borderRadius: 14,
                textDecoration: "none",
                color: "inherit",
                transition: "border-color 150ms ease, transform 150ms ease",
              }}
            >
              <div
                style={{
                  width: "100%",
                  aspectRatio: "16 / 9",
                  background: `linear-gradient(135deg, ${skin.colors[0]}, ${skin.colors[1]})`,
                  borderRadius: 8,
                  marginBottom: 14,
                }}
              />
              <h3
                style={{
                  fontSize: 18,
                  fontWeight: 700,
                  marginBottom: 6,
                }}
              >
                {skin.name}
              </h3>
              <p
                style={{
                  fontSize: 14,
                  color: "var(--text-dim)",
                  marginBottom: 14,
                }}
              >
                {skin.blurb}
              </p>
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                }}
              >
                <span
                  style={{
                    fontSize: 18,
                    fontWeight: 700,
                    color: "var(--accent-2)",
                  }}
                >
                  {skin.price}
                </span>
                <span style={{ fontSize: 13, color: "var(--text-dim)" }}>
                  Buy →
                </span>
              </div>
            </a>
          ))}
        </div>
      </div>
    </main>
  );
}
