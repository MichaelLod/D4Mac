"use client";

import { useEffect, useState } from "react";

const TAGLINES = [
  "Inarius would tip. Be unlike Lilith.",
  "Coffee: the only legendary drop with a 100% rate.",
  "Helped you slay D4? Help me slay these bugs.",
  "Caffeine is the cheapest reagent on this table.",
  "One coffee = one less curse on the codebase.",
  "Tip jar's open. Mephisto's not watching.",
  "$5 buys two more hours of bug-hunting in Hell.",
  "Patch notes powered by espresso.",
  "Tyrael blesses generous tippers. Probably.",
  "Demons live on souls. I live on cold brew.",
  "This launcher cost a weekend. Pay it forward in beans.",
  "Even Deckard Cain says: stay awhile, and tip.",
  "Battle-tested. Caffeine-powered.",
  "Buy a coffee, unlock zero achievements. Worth it anyway.",
  "Free as in beer. Tip as in coffee.",
  "Saved you 74 dollars. Asks for five. Math checks out.",
  "Andariel's Visage doesn't have a tip option. This does.",
  "Tipping the dev: +5 to Karma, untyped, doesn't stack.",
  "Sanctuary's saved. Tip the night-shift sysadmin.",
  "Loot dropped: 1× peace of mind. Take a coffee.",
  "Espresso costs less than a Helltide reagent.",
  "If this worked first try, that was the coffee.",
  "No DRM. No telemetry. Just vibes — and a coffee fund.",
  "The codebase has 0 microtransactions. This is the only one.",
  "Lilith would never. You would.",
  "Caffeine: the unofficial 6th class.",
  "Click the button. The Lord of Terror commands it.",
  "Worship the bean. The bean keeps the lights on.",
  "If this saved you a Bootcamp reboot, throw a coffee.",
  "Five bucks. One coffee. Zero demons summoned.",
  "Patches don't write themselves. Beans help.",
  "Open-source vibes, closed-source coffee budget.",
];

const ROTATION_MS = 60_000;

export function CoffeeTagline({
  className = "coffee-tagline",
}: {
  className?: string;
} = {}) {
  const [index, setIndex] = useState(0);

  useEffect(() => {
    // Randomise initial pick on mount so two visitors at the same minute
    // don't see the same nudge.
    setIndex(Math.floor(Math.random() * TAGLINES.length));

    const id = setInterval(() => {
      setIndex((prev) => (prev + 1) % TAGLINES.length);
    }, ROTATION_MS);

    return () => clearInterval(id);
  }, []);

  return (
    <h2 key={index} className={className}>
      {TAGLINES[index]}
    </h2>
  );
}
