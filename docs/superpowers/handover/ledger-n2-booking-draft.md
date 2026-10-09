# Handover Ledger: N2 Booking Nháp Dùng Chung (#199)

## Overview & Scope
- **Issue:** #199 (`Nền · Booking nháp dùng chung (buildBookingDraft, milestoneAmounts)`)
- **Plan:** `docs/superpowers/plans/2026-10-08-n2-booking-draft.md`
- **Branch:** `plan/199-booking-nhap` (branched from `origin/develop`)
- **Scope executed:**
  - `packages/domain`: `milestones.ts` (`milestoneAmounts`, `DEFAULT_MILESTONE_PERCENTS`, `MILESTONE_KINDS`), `booking_policy.ts` (`clampRevisions`, `DEFAULT_REVISIONS`, `REVISIONS_MAX`), `booking_ports.ts` (`ServiceRecord.revisions`), `booking.ts` (`Booking.revisionsIncluded`), `create_booking.ts` (`BookingDraftCore`, `BookingDraftInput`, `draftTotal`, `buildBookingDraft`, and refactored `createBookingDraft`).
  - `app_flutter/firebase/functions`: `booking_firestore.ts` (`bookingToFirestore` writes `revisionsIncluded: b.revisionsIncluded ?? null`, `bookingFromFirestore` parses number), `booking_readers.ts` (`serviceRecordOf` parses `deliverables.revisions`), unit tests in `booking_readers.test.ts` and `booking_firestore.test.ts`.

## Decisions & Rulings (Decisions 1–8)
1. **Decision 1 (Builder lives in domain):** `buildBookingDraft` is a pure function in `packages/domain/src/create_booking.ts`, not Firestore- or Functions-specific.
2. **Decision 2 (One shared input, slot comments):** `BookingDraftInput` extends `BookingDraftCore` with extension slots reserved for upcoming units (#139, #136, #190).
3. **Decision 3 (Slots layout):** Slot markers placed verbatim in `create_booking.ts` (imports block, `BookingDraftInput`, `draftTotal`, `buildBookingDraft`). Each slot helper returns `{}` when input is absent to avoid writing `undefined` or stray keys.
4. **Decision 4 (Milestone split module):** `packages/domain/src/milestones.ts` contains `milestoneAmounts(net, percents = DEFAULT_MILESTONE_PERCENTS)`.
5. **Decision 5 (Rounding remainder):** Remainder `net % 100` is distributed such that `delivery = net - shoot`, guaranteeing `shoot + delivery === net` exact for all integers up to `MAX_SAFE_INTEGER`.
6. **Decision 6 (Free revision rounds):** Clamped with `clampRevisions` between 0 and 5 (`REVISIONS_MAX = 5`), defaulting to 1 (`DEFAULT_REVISIONS = 1`). Stored on `Booking` as `revisionsIncluded` and on `ServiceRecord` as `revisions`.
7. **Decision 7 (Split validation):** Input `net` must be non-negative safe integer; percents must be safe integers in [0, 100] summing to 100, throwing `invalid_argument` otherwise.
8. **Decision 8 (Backward compatibility):** Absence of `revisionsIncluded` or non-number in Firestore restores as `undefined` (never coerced to 0). Absence of `deliverables.revisions` in package docs restores without `revisions` key.

## Slot Markers as Merged
In `packages/domain/src/create_booking.ts`:
```ts
// ── Draft slots: imports (one block per unit; edit only your own) ──
// slot #139 (quotes)

// slot #136 (studio)

// slot #190 (add-ons)

// ── end draft slot imports ──

// eslint-disable-next-line @typescript-eslint/no-empty-object-type
export interface BookingDraftInput extends BookingDraftCore {
  // slot #139 (quotes): readonly quote?: { jobId: string; quoteId: string; terms: BookingTerms };

  // slot #136 (studio): readonly providerType?: ProviderType | null;

  // slot #190 (add-ons): readonly addons?: readonly AddonLine[]; readonly pickup?: BookingPickup;
}

export function draftTotal(i: BookingDraftInput): number {
  return i.service.price; // slot #190 (add-ons): bookingTotal(i.service, i.addons ?? [])
}

export function buildBookingDraft(i: BookingDraftInput): Booking {
  const core = coreDraft(i);
  return {
    ...core,
    // slot #139 (quotes): ...quoteDraftFields(i),

    // slot #136 (studio): ...studioDraftFields(i, core),

    // slot #190 (add-ons): ...addonDraftFields(i),
  };
}
```

## Consumer Instructions
- **#139 (Quotes):** Fill slot "quotes" (`quote?`, `quoteDraftFields(i)` returning `{ quote: ... }`).
- **#136 (Studio):** Fill slot "studio" (`providerType?: ProviderType | null`, `studioDraftFields(i, core)`).
- **#190 (Add-ons):** Fill slot "add-ons" (`addons?`, `pickup?`, `addonDraftFields(i)`, and `draftTotal` calling `bookingTotal(i.service, i.addons ?? [])`).
- **#152 (Milestones & S05.06/07):** Add milestone state models to `milestones.ts` and read `b.revisionsIncluded ?? DEFAULT_REVISIONS`.

## Order Gate Integration Status
- #198 was merged into `develop` prior to this branch (`deps.gate.acceptsOrders` check is in place and preserved in `createBookingDraft`).

## Verification & Test Results
- `packages/domain`: 1005 passing tests, 0 failing, clean lint.
- `app_flutter/firebase/functions`: 364 passing tests, 0 failing, clean lint, build passes.
- Skipped test suites: none.
