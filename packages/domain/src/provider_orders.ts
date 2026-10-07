/**
 * Whether a provider can receive orders ("Nhận đơn" vs "Chưa nhận đơn",
 * identity-verification-design.md §3): staff-verified and profile complete.
 */

export interface OrderEligibilityFields {
  readonly verified?: unknown;
  readonly onboardingComplete?: unknown;
}

/** True only when both are literally `true`; any other value (missing, string, null) is false. */
export function acceptsOrders(fields: OrderEligibilityFields | null | undefined): boolean {
  return fields?.verified === true && fields?.onboardingComplete === true;
}

/** The patch the trigger writes, or null when the stored flag already matches (or the doc is gone). */
export function acceptingOrdersPatch(
  after: (OrderEligibilityFields & { readonly acceptingOrders?: unknown }) | null | undefined,
): { acceptingOrders: boolean } | null {
  if (!after) return null;
  const next = acceptsOrders(after);
  return after.acceptingOrders === next ? null : { acceptingOrders: next };
}
