export type SkuId =
  | "skin-tristram"
  | "skin-westmarch"
  | "skin-zakarum"
  | "bundle-act1"
  | "lifetime-all";

/**
 * Stripe Price IDs. Create these in the Stripe Dashboard
 * (Products → Add product → Add price), then paste the IDs here.
 * Each Stripe Price should also have its `metadata.sku` set to the
 * matching key below so the activate page can map back.
 */
export const SKU_TO_PRICE: Record<SkuId, string> = {
  "skin-tristram":  "price_1TSBjTDVxaFW5IPCmEV704Y5",
  "skin-westmarch": "price_1TSBjVDVxaFW5IPCkTouWlsa",
  "skin-zakarum":   "price_1TSBjXDVxaFW5IPCGClyYwMw",
  "bundle-act1":    "price_1TSBjZDVxaFW5IPCLZ93w8Mr",
  "lifetime-all":   "price_1TSBjbDVxaFW5IPCdFyltYzX",
};

/**
 * What each SKU unlocks. Bundles expand to multiple skin ids.
 * The wildcard "skin-*" represents lifetime/all-skins access; the Swift
 * `EntitlementStore.owns(_:)` honours it.
 */
export const SKU_TO_ENTITLEMENTS: Record<SkuId, string[]> = {
  "skin-tristram":  ["skin-tristram"],
  "skin-westmarch": ["skin-westmarch"],
  "skin-zakarum":   ["skin-zakarum"],
  "bundle-act1":    ["skin-tristram", "skin-westmarch", "skin-zakarum"],
  "lifetime-all":   ["skin-*"],
};

export function isSkuId(value: unknown): value is SkuId {
  return typeof value === "string" && value in SKU_TO_PRICE;
}
