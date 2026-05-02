import { CoffeeButton } from "@/components/CoffeeButton";
import { CoffeeTagline } from "@/components/CoffeeTagline";
import { DownloadButton } from "@/components/DownloadModal";
import { ThanksBanner } from "@/components/ThanksBanner";
import { getDownloadCount } from "@/lib/downloads";

export const revalidate = 60;

export default async function Page() {
  const count = await getDownloadCount();

  const downloadMeta =
    count !== null && count > 0
      ? `${count.toLocaleString()} downloads · macOS 14+ · Apple Silicon`
      : "macOS 14+ · Apple Silicon · ~400 MB";

  return (
    <>
      <ThanksBanner />
      <main>
        <section className="hero">
          <div className="container">
            <div className="badge">Free · Diablo IV verified · macOS 14+</div>
            <h1>
              Diablo IV
              <br />
              on your Mac.
            </h1>
            <p className="lede">
              A free Battle.net launcher for Apple Silicon. No CrossOver
              licence. No monthly fee. Drag, drop, play.
            </p>

            <DownloadButton>
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                <polyline points="7 10 12 15 17 10" />
                <line x1="12" y1="15" x2="12" y2="3" />
              </svg>
              <span>Download for Mac</span>
            </DownloadButton>
            <p className="fineprint">{downloadMeta}</p>
          </div>
        </section>

        <section className="coffee" id="coffee">
          <div className="container">
            <CoffeeTagline />
            <p className="coffee-lede">
              D4Mac is free forever. If it saved you the $74 CrossOver licence,
              a coffee helps keep it that way.
            </p>
            <CoffeeButton />
            <p className="fineprint">
              Secure checkout via Stripe. $5 each, buy as many as you like.
            </p>
          </div>
        </section>

        <section className="features">
          <div className="container">
            <h2>What&apos;s in the box</h2>
            <ul className="feature-grid">
              <li>
                <h3>Self-contained .app</h3>
                <p>
                  Wine 11.0 + Apple GPTK 3.0 in a single drag-to-Applications
                  bundle.
                </p>
              </li>
              <li>
                <h3>Diablo IV verified</h3>
                <p>
                  Launches past <code>Sync interval</code>, the wall that
                  blocked self-built Wine + D3DMetal until now.
                </p>
              </li>
              <li>
                <h3>No licence keys</h3>
                <p>
                  Uses Apple&apos;s free non-commercial GPTK redistribution
                  clause. Zero subscriptions.
                </p>
              </li>
              <li>
                <h3>Clean reset</h3>
                <p>
                  Settings → Reset bottle if Battle.net gets weird. The app
                  itself stays untouched.
                </p>
              </li>
            </ul>
          </div>
        </section>
      </main>

      <footer>
        <div className="container">
          <p>
            Wine 11.0 is LGPL 2.1. Apple GPTK is © Apple, used under the public
            non-commercial redistribution clause.
          </p>
          <p>Not affiliated with Blizzard, Apple, or CodeWeavers.</p>
        </div>
      </footer>
    </>
  );
}
