# Handover ledger — plan A1 (provider types), unit 9a/2-L1

Plan: `docs/superpowers/plans/2026-10-05-a1-provider-types.md`, Tasks 6–7 (lane 1). Tasks 1–5 in 9a/1-L2 (`ledger-a1-provider-types-9a-1-L2.md`).
Shipped in the batch branch `plan/9abc-L1-provider-portfolio-awards` together with C1–C3 and 9c/2-L1 (one PR; single session, user's instruction 2026-10-06).

## Built
- Task 6: `ProviderName` + `providerMarkOf` on the profile header, home ("Rảnh tuần này" card overlay) and photo detail; `ProviderTag` under the profile name; studio meta line shows `studioDistrict`. No `VerifiedName(` left in features.
- Task 7: S08.01 "Bạn nhận việc với tư cách" (Cá nhân / Studio, "Tên studio"), S08.05 "Địa chỉ cơ sở" block for studios, S09.02 "Hình thức nhận việc" row + `ProviderTypeSheet` (red confirm when an artist switches to Studio).

## Rulings
- The stored provider type is nullable (unknown ≠ individual): `storedProviderTypeProvider` is the single source; S08.01 loads it through `AsyncView`, "Tiếp tục" is disabled until known, and `setType` runs only when the stored type is known and differs. Prevents a studio being switched back to individual when the read fails or arrives late.
- S08.05 shows ErrorState + retry when any prefill read fails (it used to open an empty form).
- After a switch to Studio, Settings pushes the full `/setup/4` (S08.05) form; there is no address-only screen.
- Home "Rảnh tuần này" card keeps `PhotoCard` and passes name + mark through `overlay` with an explicit semantics label; `ProviderName.maxLines` added (ellipsis).
- Core additions (backwards-compatible): `AppOptionTile.description`, `ProviderName.maxLines`.

## Deferred
- The mark label switch in `home_screen.dart` duplicates `ProviderMark`'s semantics labels; move to a core helper when touched.
- No test for the mark on the home hero-card author row, nor for "individual non-verified shows no tag".

## Final review (whole branch)
- Settings "Hình thức nhận việc" row, `ProviderTypeSheet` and the S09.01 award nudge read `liveProviderTypeProvider` (the live `myTierProvider` type when known, else the profile read; a missing profile reads as Cá nhân), so an artist promoted mid-session is asked before switching to Studio.
- S08.01 asks the same red confirm when an artist picks Studio.
- From Settings, S08.05 opens as `/setup/4?from=settings` and pops back on save; onboarding still lands on Đặt lịch.
