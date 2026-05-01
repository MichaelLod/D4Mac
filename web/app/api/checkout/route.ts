import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";
import { SKU_TO_PRICE, isSkuId, type SkuId } from "@/lib/skus";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

type CheckoutBody = { type?: "tip" | "skin"; sku?: string };

function originFor(req: NextRequest): string {
  const proto = req.headers.get("x-forwarded-proto") ?? "https";
  const host = req.headers.get("x-forwarded-host") ?? req.headers.get("host");
  return `${proto}://${host}`;
}

async function createSkinSession(sku: SkuId, origin: string) {
  return await stripe.checkout.sessions.create({
    mode: "payment",
    payment_method_types: ["card"],
    line_items: [{ price: SKU_TO_PRICE[sku], quantity: 1 }],
    customer_creation: "always",
    automatic_tax: { enabled: true },
    success_url: `${origin}/activate?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${origin}/?status=cancelled`,
  });
}

/** GET /api/checkout?sku=<sku> — creates a session and 303s to Stripe. */
export async function GET(req: NextRequest) {
  const url = new URL(req.url);
  const sku = url.searchParams.get("sku");
  if (!isSkuId(sku)) {
    return NextResponse.json({ error: "Unknown sku" }, { status: 400 });
  }
  try {
    const session = await createSkinSession(sku, originFor(req));
    if (!session.url) {
      return NextResponse.json({ error: "No checkout URL" }, { status: 500 });
    }
    return NextResponse.redirect(session.url, 303);
  } catch (err) {
    console.error("stripe checkout error", err);
    return NextResponse.json({ error: "Checkout session failed" }, { status: 500 });
  }
}

/** POST /api/checkout — JSON body `{type:"skin",sku:"…"}` or empty for tip. */
export async function POST(req: NextRequest) {
  let body: CheckoutBody = {};
  try {
    body = (await req.json()) as CheckoutBody;
  } catch {
    // empty body is fine — defaults to tip flow for the BMC button
  }

  const origin = originFor(req);

  try {
    if (body.type === "skin") {
      if (!isSkuId(body.sku)) {
        return NextResponse.json({ error: "Unknown sku" }, { status: 400 });
      }
      const session = await createSkinSession(body.sku, origin);
      return NextResponse.json({ url: session.url });
    }

    // Default: coffee tip (the BMC button on the landing page)
    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      submit_type: "donate",
      payment_method_types: ["card"],
      line_items: [
        {
          price_data: {
            currency: "usd",
            product_data: {
              name: "Coffee for D4Mac",
              description: "Thanks for supporting open-source Mac gaming.",
            },
            unit_amount: 500,
          },
          quantity: 1,
          adjustable_quantity: { enabled: true, minimum: 1, maximum: 50 },
        },
      ],
      success_url: `${origin}/?status=thanks`,
      cancel_url: `${origin}/?status=cancelled`,
    });
    return NextResponse.json({ url: session.url });
  } catch (err) {
    console.error("stripe checkout error", err);
    return NextResponse.json({ error: "Checkout session failed" }, { status: 500 });
  }
}
