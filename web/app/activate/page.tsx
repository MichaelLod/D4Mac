import Stripe from "stripe";
import { signLicense } from "@/lib/license";
import { SKU_TO_ENTITLEMENTS, isSkuId } from "@/lib/skus";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export const dynamic = "force-dynamic";

export default async function ActivatePage({
  searchParams,
}: {
  searchParams: Promise<{ session_id?: string }>;
}) {
  const { session_id } = await searchParams;
  if (!session_id) {
    return <Status title="Missing session id" body="Open this link from the Stripe success redirect." />;
  }

  let session: Stripe.Checkout.Session;
  try {
    session = await stripe.checkout.sessions.retrieve(session_id, {
      expand: ["line_items.data.price", "customer"],
    });
  } catch {
    return <Status title="Session not found" body="That checkout session doesn't exist or has expired." />;
  }

  if (session.payment_status !== "paid") {
    return <Status title="Payment not complete" body={`Stripe says: ${session.payment_status}.`} />;
  }

  const customerId =
    typeof session.customer === "string" ? session.customer : session.customer?.id;
  if (!customerId) {
    return <Status title="No customer on session" body="Your Checkout config must enable customer creation." />;
  }

  const customer = await stripe.customers.retrieve(customerId);
  if (customer.deleted) {
    return <Status title="Customer deleted" body="Contact support — your Stripe customer record was removed." />;
  }

  const existingCSV = (customer.metadata?.entitlements ?? "").trim();
  const existing = existingCSV ? existingCSV.split(",").filter(Boolean) : [];

  const newEntitlements = (session.line_items?.data ?? []).flatMap((li) => {
    const sku = li.price?.metadata?.sku;
    return isSkuId(sku) ? SKU_TO_ENTITLEMENTS[sku] : [];
  });

  const merged = Array.from(new Set([...existing, ...newEntitlements]));

  await stripe.customers.update(customerId, {
    metadata: { entitlements: merged.join(",") },
  });

  const jwt = await signLicense({
    customerId,
    sessionId: session_id,
    entitlements: merged,
  });

  const deepLink = `d4mac://activate?token=${encodeURIComponent(jwt)}`;

  return <ActivateView deepLink={deepLink} entitlementCount={merged.length} />;
}

function ActivateView({
  deepLink,
  entitlementCount,
}: {
  deepLink: string;
  entitlementCount: number;
}) {
  return (
    <main
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        padding: 24,
      }}
    >
      <script
        dangerouslySetInnerHTML={{
          __html: `setTimeout(function () { window.location.href = ${JSON.stringify(deepLink)}; }, 250);`,
        }}
      />
      <div
        style={{
          maxWidth: 480,
          textAlign: "center",
          padding: "48px 36px",
          background: "var(--surface)",
          border: "1px solid var(--border)",
          borderRadius: 16,
        }}
      >
        <h1 style={{ fontSize: 32, fontWeight: 700, marginBottom: 12 }}>
          Opening D4Mac…
        </h1>
        <p style={{ color: "var(--text-dim)", marginBottom: 28 }}>
          {entitlementCount === 1
            ? "Your skin is being delivered to the app."
            : `${entitlementCount} skins are being delivered to the app.`}
        </p>
        <a className="btn-primary" href={deepLink} style={{ fontSize: 18, padding: "16px 32px" }}>
          Open D4Mac
        </a>
        <p style={{ marginTop: 24, fontSize: 13, color: "var(--text-dim)" }}>
          Your browser may ask for permission to open D4Mac. Allow it.
        </p>
      </div>
    </main>
  );
}

function Status({ title, body }: { title: string; body: string }) {
  return (
    <main style={{ minHeight: "100vh", display: "grid", placeItems: "center", padding: 24 }}>
      <div
        style={{
          maxWidth: 480,
          textAlign: "center",
          padding: "48px 36px",
          background: "var(--surface)",
          border: "1px solid var(--border)",
          borderRadius: 16,
        }}
      >
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 12 }}>{title}</h1>
        <p style={{ color: "var(--text-dim)" }}>{body}</p>
      </div>
    </main>
  );
}
