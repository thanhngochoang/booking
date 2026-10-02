# SDD ledger — plan: docs/superpowers/plans/2026-10-02-mock-parity-1.md
Spec: docs/design/ui-mock.html (layout authority) + specs (behaviour). Audit: audit.md in this workspace.
## Preflight
| Pair/Task | Shared | Finding |
|---|---|---|
| T1 → T4,T8,T9,T10 | AppButtonSize | consumed by name |
| T3 AppChip ↔ T7 S34, T9 S35 | chip kinds | T3 sets S35 chip kinds; T7 uses context chips |
| T5 PhoneField ↔ T6 S33, T7 S34, T8 S42 | two boxes | T5 before T6–T8 |
| T10 AppOptionTile | new widget | reused later by S06/S47 |
| T11 mock edit | docs only | controller republishes artifact |
Ruling: commit trailer per environment, not reviewed. 2c paused after Task 6 (complete 620b768); resume at Task 7 after this plan.
Task 1: first commit (sizes) done
Ruling: controlHeight 52→48 (mock .btn); add tokens radius xl16/card20/sheet28/control14, text xs2 11 — exact mock parity — many visual tests updated
Task 1: fix round 1 dispatched
Task 1: complete c54eaae (controller-checked stat + tokens regenerated)
Ruling: batch Tasks 2+3 (small visual widget fixes)
Tasks 2+3: 4646a91, 68f7809 — review needs fixes (glass fill, free-ink, tag border, pill offset, middle tab label)
Tasks 2+3: fix round 1 dispatched
Tasks 2+3: fix a648b6b — 5 items reported; complete
Carry to Task 11: glass fill candidates photographer_card:96, event_tile:40, role_screen:129, reason_chips:36, segmented_tabs:39 (check vs mock); contact_dial_test.dart:671 tap() hit-test warning
Ruling: batch Tasks 4+5
Tasks 4+5: 3691bea, 9970c13 — review needs fixes (48dp layout box inflates card row)
Ruling: AppButton tapAlignment; compact buttons absorb adjacent padding into the 48dp tap box so layout equals the mock
Tasks 4+5: fix round 1 dispatched (+ contact_dial_test warning)
Tasks 4+5: fix d66dc1a — complete (841 tests, no warnings)
Carry to Task 11: stacked card buttons gap 18 → drop SizedBox (10)
NOTE: another session edits l10n/core.dart/splash/aperture_loader in the working tree — implementers stage only their own hunks
USER 2026-10-02: battery/perf moved to final plan (947dd10); no device rebuild per plan — only in the final plan
USER: every screen shows its code — codes default ON in debug, placeholders tagged (1d7b8dc); splash/session error have no code per spec §2 — ask user
