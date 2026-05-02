import Stripe from "stripe";
import { notFound } from "next/navigation";
import { getDownloadCount } from "@/lib/downloads";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export const dynamic = "force-dynamic";
export const metadata = { title: "Dashboard · D4Mac", robots: "noindex,nofollow" };

const REFETCH_LIMIT = 100;

function fmtMoney(cents: number, currency = "usd"): string {
  const sym = currency === "usd" ? "$" : currency.toUpperCase() + " ";
  return sym + (cents / 100).toFixed(2);
}

function fmtDate(unix: number): string {
  return new Date(unix * 1000).toLocaleString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

async function fetchData() {
  const [sessions, downloadCount] = await Promise.all([
    stripe.checkout.sessions.list({
      limit: REFETCH_LIMIT,
      expand: ["data.line_items"],
    }),
    getDownloadCount(),
  ]);
  const paid = sessions.data.filter((s) => s.payment_status === "paid");

  const totalRevenue = paid.reduce((sum, s) => sum + (s.amount_total ?? 0), 0);
  const totalCoffees = paid.reduce((sum, s) => {
    const qty = (s.line_items?.data ?? []).reduce(
      (q, li) => q + (li.quantity ?? 1),
      0,
    );
    return sum + qty;
  }, 0);
  const totalSessions = paid.length;
  const conversionPct =
    downloadCount && downloadCount > 0
      ? ((totalSessions / downloadCount) * 100).toFixed(1) + "%"
      : null;

  return {
    totalRevenue,
    totalCoffees,
    totalSessions,
    downloadCount,
    conversionPct,
    recent: paid
      .slice()
      .sort((a, b) => b.created - a.created)
      .slice(0, 25),
    fetchedAt: Date.now(),
    isTestMode: !sessions.data[0]?.livemode,
  };
}

export default async function DashboardPage({
  searchParams,
}: {
  searchParams: Promise<{ token?: string }>;
}) {
  const { token } = await searchParams;
  const expected = process.env.DASHBOARD_TOKEN;
  if (!expected || token !== expected) {
    notFound();
  }

  const data = await fetchData();

  return (
    <main
      style={{
        padding: "40px 24px",
        maxWidth: 1080,
        margin: "0 auto",
        color: "var(--text)",
      }}
    >
      <header style={{ marginBottom: 28 }}>
        <h1 style={{ fontSize: 32, fontWeight: 700, letterSpacing: "-0.02em" }}>
          D4Mac dashboard
        </h1>
        <div style={{ display: "flex", gap: 12, alignItems: "center", marginTop: 8 }}>
          <span
            style={{
              fontSize: 11,
              padding: "3px 10px",
              borderRadius: 999,
              background: data.isTestMode ? "rgba(255,180,0,0.15)" : "rgba(0,200,80,0.15)",
              color: data.isTestMode ? "#ffb400" : "#00c850",
              border: data.isTestMode
                ? "1px solid rgba(255,180,0,0.3)"
                : "1px solid rgba(0,200,80,0.3)",
              fontWeight: 600,
              letterSpacing: "0.06em",
              textTransform: "uppercase",
            }}
          >
            {data.isTestMode ? "TEST mode" : "LIVE mode"}
          </span>
          <span style={{ fontSize: 13, color: "var(--text-dim)" }}>
            Fetched {new Date(data.fetchedAt).toLocaleTimeString()} · last {REFETCH_LIMIT} sessions
          </span>
        </div>
      </header>

      <section
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
          gap: 14,
          marginBottom: 32,
        }}
      >
        <Stat label="Tips received" value={fmtMoney(data.totalRevenue)} accent />
        <Stat label="Coffees" value={data.totalCoffees.toString()} />
        <Stat
          label="Downloads"
          value={
            data.downloadCount === null
              ? "—"
              : data.downloadCount.toLocaleString()
          }
          hint={data.downloadCount === null ? "DATABASE_URL not set" : undefined}
        />
        <Stat
          label="Conversion"
          value={data.conversionPct ?? "—"}
          hint={data.conversionPct ? "tippers ÷ downloads" : undefined}
        />
        <Stat
          label="Avg tip"
          value={
            data.totalSessions > 0
              ? fmtMoney(Math.round(data.totalRevenue / data.totalSessions))
              : "–"
          }
        />
      </section>

      <Card title="Recent tips">
        {data.recent.length === 0 ? (
          <Empty>No paid sessions yet.</Empty>
        ) : (
          <Table
            columns={["Date", "Email", "Amount"]}
            align={["left", "left", "right"]}
            rows={data.recent.map((s) => [
              <span key="d" style={{ color: "var(--text-dim)" }}>
                {fmtDate(s.created)}
              </span>,
              <span key="e" style={{ fontFamily: "ui-monospace, monospace", fontSize: 13 }}>
                {s.customer_details?.email ?? "—"}
              </span>,
              fmtMoney(s.amount_total ?? 0, s.currency ?? "usd"),
            ])}
          />
        )}
      </Card>

      <footer style={{ marginTop: 40, fontSize: 12, color: "var(--text-dim)" }}>
        Token-gated. Bookmark this URL — anyone with the token sees this page.
      </footer>
    </main>
  );
}

function Stat({
  label,
  value,
  accent = false,
  hint,
}: {
  label: string;
  value: string;
  accent?: boolean;
  hint?: string;
}) {
  return (
    <div
      style={{
        background: "var(--surface)",
        border: "1px solid var(--border)",
        borderRadius: 12,
        padding: "16px 18px",
      }}
    >
      <div
        style={{
          fontSize: 12,
          color: "var(--text-dim)",
          textTransform: "uppercase",
          letterSpacing: "0.08em",
        }}
      >
        {label}
      </div>
      <div
        style={{
          fontSize: 28,
          fontWeight: 700,
          marginTop: 6,
          letterSpacing: "-0.02em",
          color: accent ? "var(--accent-2)" : "var(--text)",
        }}
      >
        {value}
      </div>
      {hint && (
        <div style={{ fontSize: 11, color: "var(--text-dim)", marginTop: 4 }}>
          {hint}
        </div>
      )}
    </div>
  );
}

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 24 }}>
      <h2
        style={{
          fontSize: 14,
          fontWeight: 600,
          textTransform: "uppercase",
          letterSpacing: "0.08em",
          color: "var(--text-dim)",
          marginBottom: 10,
        }}
      >
        {title}
      </h2>
      <div
        style={{
          background: "var(--surface)",
          border: "1px solid var(--border)",
          borderRadius: 12,
          overflow: "hidden",
        }}
      >
        {children}
      </div>
    </section>
  );
}

function Empty({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ padding: 24, color: "var(--text-dim)", fontSize: 14, textAlign: "center" }}>
      {children}
    </div>
  );
}

function Table({
  columns,
  rows,
  align,
}: {
  columns: string[];
  rows: React.ReactNode[][];
  align: ("left" | "right")[];
}) {
  return (
    <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14 }}>
      <thead>
        <tr style={{ background: "rgba(255,255,255,0.02)" }}>
          {columns.map((c, i) => (
            <th
              key={c}
              style={{
                padding: "10px 16px",
                textAlign: align[i],
                fontWeight: 600,
                fontSize: 12,
                color: "var(--text-dim)",
                textTransform: "uppercase",
                letterSpacing: "0.06em",
                borderBottom: "1px solid var(--border)",
              }}
            >
              {c}
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {rows.map((row, idx) => (
          <tr
            key={idx}
            style={{ borderTop: idx === 0 ? "none" : "1px solid var(--border)" }}
          >
            {row.map((cell, i) => (
              <td
                key={i}
                style={{
                  padding: "10px 16px",
                  textAlign: align[i],
                }}
              >
                {cell}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
