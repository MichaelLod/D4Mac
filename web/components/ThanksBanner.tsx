"use client";

import { useEffect, useState } from "react";

export function ThanksBanner() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get("status") !== "thanks") return;

    setVisible(true);
    window.history.replaceState({}, "", window.location.pathname);
    const t = setTimeout(() => setVisible(false), 6000);
    return () => clearTimeout(t);
  }, []);

  if (!visible) return null;
  return <div className="thanks-banner">Thanks for the coffee. Truly.</div>;
}
