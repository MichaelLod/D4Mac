"use client";

import { useState } from "react";

export function CoffeeButton() {
  const [loading, setLoading] = useState(false);

  async function handleClick() {
    setLoading(true);
    try {
      const res = await fetch("/api/checkout", { method: "POST" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const { url } = (await res.json()) as { url?: string };
      if (!url) throw new Error("No checkout URL returned");
      window.location.href = url;
    } catch (err) {
      console.error("checkout failed", err);
      setLoading(false);
      alert("Could not start checkout. Please try again in a moment.");
    }
  }

  return (
    <button
      className="btn-primary"
      type="button"
      onClick={handleClick}
      disabled={loading}
    >
      <svg
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
      >
        <path d="M17 8h1a4 4 0 0 1 0 8h-1" />
        <path d="M3 8h14v9a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4V8z" />
        <line x1="6" y1="2" x2="6" y2="4" />
        <line x1="10" y1="2" x2="10" y2="4" />
        <line x1="14" y1="2" x2="14" y2="4" />
      </svg>
      <span>{loading ? "Opening checkout…" : "Buy me a coffee"}</span>
    </button>
  );
}
