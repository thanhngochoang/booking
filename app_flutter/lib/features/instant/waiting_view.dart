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
import 'package:photobooking/l10n/app_localizations.dart';

/// "0:42": minutes and seconds left on an invite.
String waitingClock(Duration left) {
  final s = left.isNegative ? 0 : left.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// The latest `expiresAt` of the pending invites; null when nobody is still
/// looking.
DateTime? latestPendingExpiry(InstantRequest r) {
  DateTime? latest;
  for (final o in r.offers) {
    final at = o.expiresAt;
    if (o.outcome != OfferOutcome.pending || at == null) continue;
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return latest;
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
      return _BoldPart(
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
                          _InviteeRow(row: o),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.s3),
              Text(
                l.waitingNote,
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
/// khác") and the status chip.
class _InviteeRow extends StatelessWidget {
  const _InviteeRow({required this.row});

  final InstantOfferRow row;

  List<MetaPart> _meta(AppLocalizations l, _RowState state) =>
      state == _RowState.notCounted
      ? [MetaPart.text(l.chooseUnavailable(row.name))]
      : [
          if (row.reviewCount >= kTomatoPctMinReviews)
            MetaPart.tomato(row.tomatoPct),
          MetaPart.text(l.waitingRowEta(row.etaMinutes)),
        ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = _stateOf(row.outcome);
    final meta = _meta(l, state);
    final chip = switch (state) {
      _RowState.viewing => l.waitingViewing,
      _RowState.declined => l.waitingDeclined,
      _RowState.expired => l.waitingExpired,
      _RowState.notCounted => l.waitingNotCounted,
    };
    return Semantics(
      key: ValueKey('waiting-row-${row.photographerId}'),
      container: true,
      liveRegion: state != _RowState.viewing,
      label: state == _RowState.viewing
          ? l.waitingRowSemantics(row.name)
          : '${row.name}, ${metaPartsSemantics(meta, l)}, $chip',
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
          vertical: 3,
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

/// [text] with [part] bold in tabular figures (mock `<b class="tn">`).
class _BoldPart extends StatelessWidget {
  const _BoldPart(this.text, {required this.part, this.style, this.textAlign});

  final String text;
  final String part;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final at = text.indexOf(part);
    if (at < 0) return Text(text, style: style, textAlign: textAlign);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: part,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(text: text.substring(at + part.length)),
        ],
      ),
      style: style,
      textAlign: textAlign,
    );
  }
}
