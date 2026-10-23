// S13.03 (`#S13.03`): the invites are out. One row per person of the round
// with what they did (looking, declined, expired, or busy when the invite
// went out), the time left on the latest invite, and the waiting loader while
// someone is still looking. Who accepts first moves the request to S13.04;
// nobody → the server ends the round (S13.02). "Huỷ yêu cầu" opens S13.08.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/customer_cancel_sheet.dart';
import 'package:photobooking/features/instant/instant_bold_part.dart';
import 'package:photobooking/features/instant/instant_meta.dart';
import 'package:photobooking/features/instant/instant_ticks.dart';

/// "0:42": minutes and seconds left on an invite.
String waitingClock(Duration left) {
  final s = left.isNegative ? 0 : left.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

enum _RowState { viewing, declined, expired, notCounted }

_RowState _stateOf(OfferOutcome o) => switch (o) {
  // `accepted` lasts only until the request is assigned (S13.04).
  OfferOutcome.pending || OfferOutcome.accepted => _RowState.viewing,
  OfferOutcome.declined => _RowState.declined,
  OfferOutcome.expired || OfferOutcome.withdrawn => _RowState.expired,
  OfferOutcome.unavailable => _RowState.notCounted,
};

class WaitingView extends ConsumerWidget {
  const WaitingView({super.key, required this.request});

  final InstantRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final rows = request.offers;
    final invited = rows
        .where((o) => o.outcome != OfferOutcome.unavailable)
        .length;
    final latest = latestPendingExpiry(request);
    final bodyStyle = theme.textTheme.bodySmall?.copyWith(
      color: dark
          ? AppColorsDark.foregroundSecondary
          : AppColors.foregroundSecondary,
    );
    Widget body(Duration left) {
      final time = waitingClock(left);
      return InstantBoldPart(
        l.waitingBody(time),
        part: time,
        style: bodyStyle,
        textAlign: TextAlign.center,
      );
    }

    return ScreenCode(
      ScreenCodes.instantSearching,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Text(l.waitingTitle),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s1,
              AppSpace.s4,
              AppSpace.s6,
            ),
            children: [
              Center(
                child: SignatureLoader(
                  wave: LoaderWave.vibration,
                  // Waiting on someone only while an invite is still open.
                  active: latest != null,
                  semanticsLabel: l.waitingTitle,
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              Text(
                l.waitingSent(invited),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: AppText.md,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpace.s1),
              if (latest == null)
                body(Duration.zero)
              else
                CountdownText(
                  deadline: latest,
                  now: ref.read(clockProvider),
                  builder: (context, left) => body(left),
                ),
              const SizedBox(height: AppSpace.s4),
              if (rows.isNotEmpty)
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s3,
                      vertical: AppSpace.s1,
                    ),
                    child: Column(
                      children: [
                        for (final (i, o) in rows.indexed) ...[
                          if (i > 0) const Divider(height: 1),
                          _InviteeRow(
                            key: ValueKey(
                              'waiting-invitee-${o.photographerId}',
                            ),
                            row: o,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.s3),
              Text(
                // Nothing held before payment (#140): no money sentence.
                request.paid ? l.waitingNote : l.waitingNoteUnpaid,
                textAlign: TextAlign.center,
                style: bodyStyle,
              ),
            ],
          ),
          bottomNavigationBar: AppFooterBar(
            child: AppButton.text(
              l.waitingCancel,
              key: const Key('waiting-cancel'),
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(
                  dark ? AppColorsDark.destructive : AppColors.destructive,
                ),
              ),
              onPressed: () =>
                  showCustomerCancelSheet(context, ref, request: request),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mock `.irow2`: avatar, name, meta (tomato and ETA, or "vừa nhận việc
/// khác") and the status chip. A row whose state changes while the screen is
/// open is announced (live region); the rows as first shown are not.
class _InviteeRow extends StatefulWidget {
  const _InviteeRow({super.key, required this.row});

  final InstantOfferRow row;

  @override
  State<_InviteeRow> createState() => _InviteeRowState();
}

class _InviteeRowState extends State<_InviteeRow> {
  bool _changed = false;

  @override
  void didUpdateWidget(_InviteeRow old) {
    super.didUpdateWidget(old);
    if (_stateOf(old.row.outcome) != _stateOf(widget.row.outcome)) {
      _changed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final row = widget.row;
    final state = _stateOf(row.outcome);
    final meta = state == _RowState.notCounted
        ? [MetaPart.text(l.waitingRowUnavailable)]
        : [
            // Below five reviews only the ETA (no "Mới" on a waiting row).
            ...instantReviewMeta(
              l,
              tomatoPct: row.tomatoPct,
              reviewCount: row.reviewCount,
              newLabel: false,
            ),
            MetaPart.text(l.waitingRowEta(row.etaMinutes)),
          ];
    final chip = switch (state) {
      _RowState.viewing => l.waitingViewing,
      _RowState.declined => l.waitingDeclined,
      _RowState.expired => l.waitingExpired,
      _RowState.notCounted => l.waitingNotCounted,
    };
    return Semantics(
      key: ValueKey('waiting-row-${row.photographerId}'),
      container: true,
      liveRegion: _changed,
      label: switch (state) {
        _RowState.viewing => l.waitingRowSemantics(row.name),
        // "Quốc Bảo vừa nhận việc khác, Không tính": the name once.
        _RowState.notCounted => '${l.chooseUnavailable(row.name)}, $chip',
        _ => '${row.name}, ${metaPartsSemantics(meta, l)}, $chip',
      },
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
        child: Row(
          children: [
            AppAvatar(
              url: row.avatarUrl,
              name: row.name,
              size: AppAvatarSize.sm,
              decorative: true,
            ),
            const SizedBox(width: AppSpace.s2h),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  MetaLine(meta),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            _StateChip(label: chip, state: state),
          ],
        ),
      ),
    );
  }
}

/// Mock `.st` (`.live` for someone looking, `.no` for "Không tính").
class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.state});

  final String label;
  final _RowState state;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (state) {
      _RowState.viewing =>
        dark ? AppColorsDark.foreground : AppColors.foreground,
      _RowState.notCounted =>
        dark ? AppColorsDark.destructive : AppColors.destructive,
      _ =>
        dark
            ? AppColorsDark.foregroundSecondary
            : AppColors.foregroundSecondary,
    };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: AppText.xs2,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
