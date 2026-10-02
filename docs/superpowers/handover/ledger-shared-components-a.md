# Handover ledger — Shared Components A (2026-10-02-shared-components-a.md)

## Lane 2 Step 2 (8a2/2-L2): Decision & Chat Widgets

Branch: `plan/8a2-2-L2-decision-chat-widgets`
Target: `develop`

### Scope Completed
1. **Baseline Fix** (commit `6682f6b`):
   - Fixed pre-existing compile errors on develop where `AppSkeleton.box/line` static methods were incorrectly called with `const` in `booking_card.dart`, `escrow_notice.dart`, `money_breakdown.dart`, `policy_table.dart`, and `status_timeline.dart`.
2. **Task 6 (Steps 1–5): Decision Widgets** (commit `0d21039`):
   - `PaymentProviderCode` enum (`momo`, `vnpay`, `zalopay`, `bank_transfer`) in `lib/core/payments.dart`.
   - `ProviderPicker`: Selection card with radio indicators and provider logos/labels.
   - `ReasonPicker`: Chip & radio selection modes with custom input for "Lý do khác" (character count, validation).
   - `AppButton.danger`: Solid red theme button for destructive confirmation.
   - `showAppSheet`: Added `isDismissible`, `enableDrag`, and `canDismiss` predicate hook.
   - `showConfirmSheet`: Modal sheet locked during async confirmation, double-tap protection, PopScope handling, SnackBar on failure.
   - Tests: 13 unit & widget tests in `test/core/widgets/`.
3. **Task 9: Chat Widgets** (commit `7028ad6`):
   - `ChatBubble`: Supports `ChatBubbleContent` hierarchy (`TextContent`, `ImageContent`, `LocationContent`, `SystemContent`), states (`sending`, `sent`, `delivered`, `seen`, `failed`), and `ChatBubble.skeleton()`.
   - `ChatComposer`: Single-line/multiline text input, camera picker action, inline `SignatureLoader` when sending, clearing input on send, `disabledReason` banner.
   - `ConversationRow`: Avatar, participant preview, timestamp, unread counter badge with `"{n} tin chưa đọc"` accessibility semantics, `ConversationRow.skeleton()`.
   - Tests: 14 widget tests in `test/core/widgets/`.

### Verification
- `flutter analyze`: 0 issues found.
- `flutter test --no-pub`: 1492 passed (2 skipped).

### Gate Status
- Reaches Gate G2 for Lane 2.
- Unblocks Lane 1 Step 3 (Task 6 Step 6: migrating feature confirmation sheets to `showConfirmSheet`).
