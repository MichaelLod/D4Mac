# D4Mac (private)

Free Battle.net launcher for Apple Silicon Macs. Closed source. Free download.
Monetised via paid skin DLC sold from `d4mac.app`.

The compiled `.app` is **free to distribute** — Apple's GPTK
non-commercial-redistribution clause permits free downloads. Selling the
binary itself or bundling it into a paid product is not allowed.
Revenue path: paid cosmetic skins sold via Stripe; `d4mac://activate?token=…`
deep links carry Ed25519-signed JWTs that unlock skin entitlements at runtime.

## Layout

| Path | Purpose |
|---|---|
| `Sources/D4Mac/` | SwiftUI launcher — bottle manager, BNet launcher, theme system, license verifier |
| `web/` | Landing page + Stripe checkout + activate page (Vercel) |
| `keys/` | Ed25519 signing keys (gitignored) |
| `Prereqs/` | Microsoft VC++ redistributable fetcher |
| `Resources/` | `Info.plist`, app icon, GPTK license PDF |
| `THIRD_PARTY_LICENSES.md` | Per-component licence breakdown for everything bundled in `.app` |

## Build the app

```bash
./build.sh                        # debug
./build.sh --release              # optimised
./build.sh --release --notarize   # signed + notarised via stored Developer ID
```

Requires `../wine-cx26.1/` already staged with the Wine 11.0 + GPTK runtime.
See "Wine runtime" below.

## Run the storefront locally

```bash
cd web
npm install
npm run dev          # http://localhost:3000
```

`web/.env.local` should contain:

- `STRIPE_SECRET_KEY` — test key from dashboard.stripe.com/test/apikeys
- `LICENSE_PRIVATE_KEY_PEM` — full contents of `keys/license-priv.pem`

For production deploy, set the same vars on Vercel.

## How activation works

1. User clicks a locked skin in the .app → opens `d4mac.app/api/checkout?sku=…`
2. Server creates a Stripe Checkout Session, 303s the browser to it
3. User pays with card; Stripe redirects to `/activate?session_id=…`
4. Activate page reads session, merges entitlements into the Stripe Customer's
   `metadata.entitlements` (CSV), signs an Ed25519 JWT, redirects to
   `d4mac://activate?token=…`
5. macOS Launch Services hands the URL to D4Mac; `.onOpenURL` decodes,
   `LicenseVerifier` validates the signature, JWT is stored in Keychain,
   `EntitlementStore` exposes the unlocked skin set to the UI

No webhook, no email, no DB. Stripe's Customer.metadata is the only
persistent store; the JWT is the offline credential.

## Wine runtime

D4Mac depends on a Wine 11.0 build with CrossOver's LGPL patches. Build it
once from `crossover-sources-26.1.0.tar.gz` (CodeWeavers LGPL release) using
GPTK's clang toolchain (`brew install game-porting-toolkit-compiler`),
stage Apple GPTK 3.0 binaries inside `lib/external/`, and place the result
at `../wine-cx26.1/` next to this repo. `THIRD_PARTY_LICENSES.md` enumerates
every component, its source URL, and its licence.

## Stripe

Test-mode SKUs already exist in account `delsys.business`:

| SKU | Price ID (test) | Price |
|---|---|---|
| skin-tristram | `price_1TSBjTDVxaFW5IPCmEV704Y5` | $2.99 |
| skin-westmarch | `price_1TSBjVDVxaFW5IPCkTouWlsa` | $2.99 |
| skin-zakarum | `price_1TSBjXDVxaFW5IPCGClyYwMw` | $2.99 |
| bundle-act1 | `price_1TSBjZDVxaFW5IPCLZ93w8Mr` | $7.99 |
| lifetime-all | `price_1TSBjbDVxaFW5IPCdFyltYzX` | $14.99 |

For live mode, recreate the same Products/Prices via dashboard or CLI and
update `web/lib/skus.ts`.
