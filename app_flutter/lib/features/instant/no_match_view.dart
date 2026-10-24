// S13.07 (`#S13.07`): nobody accepted in the search window. Not an end
// (spec §2.1.9, §3.1): money paid stays held and is never refunded by itself.
// "Chọn thêm người" opens a new round (S13.02, nothing more to pay); "Đặt
// lịch thường với người bạn chọn" goes to Tìm thợ ảnh while the request stays
// open (Decision 13); the red cancel opens S13.08. An unpaid request (every
// #140 one) has no money line.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/choose_controller.dart';
import 'package:photobooking/features/instant/closed_view.dart';
import 'package:photobooking/features/instant/customer_cancel_sheet.dart';
import 'package:photobooking/features/instant/instant_icon_disc.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';

/// "Đặt lịch thường" (Decision 13): Tìm thợ ảnh; the request stays open.
const _bookNormally = '/action';

class NoMatchView extends ConsumerWidget {
  const NoMatchView({super.key, required this.request});

  final InstantRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // "Chọn thêm người" is S13.02's "Xem 5 người khác": the same call.
    final provider = chooseControllerProvider(request.id);
    final fetching = ref.watch(provider.select((s) => s.fetching));
    ref.listen(provider.select((s) => s.error), (_, error) {
      if (error == null) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(instantErrorText(l, error))));
    });
    final paid = request.paid;
    final amount = formatMoney(request.amountVnd);
    return ScreenCode(
      ScreenCodes.instantNoMatch,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              tooltip: l.back,
              icon: const AppIcon(AppIcons.back),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            title: Text(l.instantTitle),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s4,
              AppSpace.s4,
              AppSpace.s6,
            ),
            children: [
              const Center(child: InstantIconDisc(AppIcons.personSearch)),
              const SizedBox(height: AppSpace.s4),
              Text(
                l.noMatchTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.s2),
              Text(
                l.noMatchBody(request.invitedTotal, request.roundsWithInvites),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.s4),
              if (paid) ...[
                EscrowNotice(
                  text: l.noMatchHeld(
                    amount,
                    instantRefundToText(l, request.payMethod),
                  ),
                  maxLines: null,
                ),
                const SizedBox(height: AppSpace.s3),
              ],
              AppButton.outline(
                l.noMatchBookNormally,
                key: const Key('no-match-book-normally'),
                onPressed: () => context.go(_bookNormally),
              ),
              const SizedBox(height: AppSpace.s1),
              AppButton.text(
                paid ? l.noMatchCancel(amount) : l.waitingCancel,
                key: const Key('no-match-cancel'),
                style: ButtonStyle(
                  foregroundColor: WidgetStatePropertyAll(
                    dark ? AppColorsDark.destructive : AppColors.destructive,
                  ),
                ),
                onPressed: () =>
                    showCustomerCancelSheet(context, ref, request: request),
              ),
            ],
          ),
          bottomNavigationBar: AppFooterBar(
            child: AppButton.primary(
              l.noMatchMore,
              key: const Key('no-match-more'),
              loading: fetching,
              onPressed: fetching ? null : ref.read(provider.notifier).more,
            ),
          ),
        ),
      ),
    );
  }
}
