import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

function originFor(req: NextRequest): string {
  const proto = req.headers.get("x-forwarded-proto") ?? "https";
  const host = req.headers.get("x-forwarded-host") ?? req.headers.get("host");
  return `${proto}://${host}`;
}

/** POST /api/checkout — creates a $5 coffee tip checkout session, adjustable 1–50. */
export async function POST(req: NextRequest) {
  const origin = originFor(req);
  try {
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
      payment_intent_data: {
        description: "Coffee for D4Mac",
        statement_descriptor_suffix: "D4MAC TIP",
      },
      success_url: `${origin}/?status=thanks`,
      cancel_url: `${origin}/?status=cancelled`,
    });
    return NextResponse.json({ url: session.url });
  } catch (err) {
    console.error("stripe checkout error", err);
    return NextResponse.json({ error: "Checkout session failed" }, { status: 500 });
  }
}
