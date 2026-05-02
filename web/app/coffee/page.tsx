import Link from "next/link";
import { CoffeeButton } from "@/components/CoffeeButton";
import { CoffeeTagline } from "@/components/CoffeeTagline";

export const metadata = {
  title: "Buy me a coffee · D4Mac",
  description:
    "D4Mac is free forever. If it saved you the $74 CrossOver licence, a coffee helps keep it that way.",
};

export default function CoffeePage() {
  return (
    <main className="coffee-page">
      <Link href="/" className="coffee-page__back">
        ← Back to D4Mac
      </Link>

      <div className="coffee-page__inner">
        <CoffeeTagline className="coffee-tagline coffee-tagline--lg" />

        <div className="coffee-cup-wrap">
          <CoffeeCupArt />
        </div>

        <div className="coffee-page__cta">
          <CoffeeButton />
          <p className="coffee-page__fineprint">
            $5 each. Pick your quantity at Stripe checkout.
          </p>
        </div>

        <section className="coffee-page__why">
          <h2 className="coffee-page__why-title">What tips fund</h2>
          <ul className="coffee-page__why-list">
            <li>
              <strong>Bug fixes</strong>
              <span>
                Every Diablo patch breaks something. Tips keep me chasing them
                instead of giving up.
              </span>
            </li>
            <li>
              <strong>More games</strong>
              <span>
                Overwatch, WoW, StarCraft on the wishlist. Each one needs a
                bottle, testing, and a few sleepless nights.
              </span>
            </li>
            <li>
              <strong>Actual coffee</strong>
              <span>
                The launcher was built on espresso. Help me keep the engine
                running.
              </span>
            </li>
          </ul>
        </section>

        <p className="coffee-page__footer">
          Secure checkout via Stripe · No subscription · No data sold
        </p>
      </div>
    </main>
  );
}

function CoffeeCupArt() {
  return (
    <svg
      className="coffee-cup-illustration"
      viewBox="0 0 240 240"
      role="img"
      aria-label="A steaming coffee cup"
    >
      <defs>
        <linearGradient id="cupGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#e8eaf0" />
          <stop offset="1" stopColor="#a8acba" />
        </linearGradient>
        <linearGradient id="coffeeGrad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#3a2615" />
          <stop offset="1" stopColor="#1c0f06" />
        </linearGradient>
        <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
          <stop offset="0" stopColor="rgba(255, 180, 80, 0.45)" />
          <stop offset="1" stopColor="rgba(255, 180, 80, 0)" />
        </radialGradient>
      </defs>

      {/* warm under-glow */}
      <ellipse cx="120" cy="195" rx="85" ry="14" fill="url(#glow)" />

      {/* steam wisps — animated via CSS */}
      <g className="cup-steam-group">
        <path
          className="cup-steam"
          d="M 96 70 q -8 -14 0 -28 q 8 -14 0 -28"
        />
        <path
          className="cup-steam"
          d="M 120 70 q -8 -14 0 -28 q 8 -14 0 -28"
        />
        <path
          className="cup-steam"
          d="M 144 70 q -8 -14 0 -28 q 8 -14 0 -28"
        />
      </g>

      {/* cup body */}
      <path
        className="cup-body"
        d="M 60 90 L 60 145 a 60 30 0 0 0 120 0 L 180 90 Z"
        fill="url(#cupGrad)"
        stroke="#000"
        strokeOpacity="0.25"
        strokeWidth="1.5"
      />

      {/* coffee surface */}
      <ellipse
        cx="120"
        cy="92"
        rx="60"
        ry="11"
        fill="url(#coffeeGrad)"
      />
      <ellipse
        cx="120"
        cy="91"
        rx="56"
        ry="9"
        fill="none"
        stroke="rgba(255,255,255,0.06)"
        strokeWidth="1"
      />

      {/* handle */}
      <path
        className="cup-handle"
        d="M 180 102 q 30 4 30 28 q 0 24 -30 28"
        fill="none"
        stroke="#a8acba"
        strokeWidth="6"
        strokeLinecap="round"
      />

      {/* saucer */}
      <ellipse
        cx="120"
        cy="190"
        rx="80"
        ry="10"
        fill="url(#cupGrad)"
        stroke="#000"
        strokeOpacity="0.25"
        strokeWidth="1.5"
      />
      <ellipse cx="120" cy="190" rx="64" ry="6" fill="rgba(0,0,0,0.18)" />
    </svg>
  );
}
