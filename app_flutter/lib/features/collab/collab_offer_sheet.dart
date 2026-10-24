import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/collab/collab_providers.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/features/collab/collab_controller.dart';
import 'package:photobooking/features/studio/studio_common.dart';

/// Opens S27.07 "Nhận việc cộng tác" for [job] (from "Việc chờ nhận" or
/// `/collab?offer=…`).
Future<void> showCollabOfferSheet(BuildContext context, CollabJob job) =>
    showAppSheet<void>(
      context,
      builder: (_) =>
          ScreenCode(ScreenCodes.collabOffer, child: _OfferSheet(job: job)),
    );

/// S27.07 (mock `#S27.07`): the shoot and its area, the studio (who answers
/// to the customer), the fee (paid by the studio outside the app) and the
/// time left to answer, the calendar note, then outline "Từ chối" and the
/// primary "Nhận việc". Never the customer's name, number or channels (R8:
/// contact opens only after acceptance). Past the expiry: "Việc này đã hết
/// hạn trả lời" and no answer.
class _OfferSheet extends ConsumerStatefulWidget {
  const _OfferSheet({required this.job});

  final CollabJob job;

  @override
  ConsumerState<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends ConsumerState<_OfferSheet> {
  bool? _sending;
  String? _error;
  bool _expired = false;

  Future<void> _answer({required bool accept}) async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _sending = accept;
      _error = null;
    });
    try {
      final status = await ref
          .read(collabRepositoryProvider)
          .respondOffer(widget.job.bookingId, accept: accept);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              status == OfferStatus.accepted
                  ? l.collabOfferAcceptedToast
                  : l.collabOfferDeclinedToast,
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = null;
        _error = collabErrorText(e, l);
      });
    }
  }

  /// "13:40 hôm nay" on the same Vietnam day, else "13:40 T7 24/10".
  String _deadlineTime(DateTime at, DateTime now) {
    final l = context.l10n;
    final vn = toVn(at);
    final hm =
        '${vn.hour.toString().padLeft(2, '0')}:'
        '${vn.minute.toString().padLeft(2, '0')}';
    return vnDateKey(at) == vnDateKey(now)
        ? l.collabOfferTimeToday(hm)
        : studioDeadlineText(at);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final clock = ref.watch(clockProvider);
    final now = clock();
    final j = widget.job;
    final expired =
        _expired ||
        j.offerStatus != OfferStatus.pending ||
        !now.isBefore(j.offerExpiresAt);
    final sending = _sending != null;
    final place = j.placeName.trim();

    Widget fact({
      required IconData icon,
      required Widget title,
      required String note,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: AppIcon(icon, size: AppIconSize.sm, color: secondary),
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  child: title,
                ),
                Text(
                  note,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: Column(
        key: const Key('collab-offer-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.collabOfferTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: l.studioSheetClose,
                icon: const AppIcon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            place.isEmpty
                ? collabShootText(j)
                : '${collabShootText(j)} · $place',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          fact(
            icon: AppIcons.store,
            title: Text(j.studioName),
            note: l.collabOfferStudioNote,
          ),
          fact(
            icon: AppIcons.payment,
            title: Text(
              formatMoney(j.agreedFee),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            note: l.collabOfferFeeNote,
          ),
          if (!expired)
            fact(
              icon: AppIcons.schedule,
              title: CountdownText(
                deadline: j.offerExpiresAt,
                now: clock,
                onExpired: () {
                  if (mounted) setState(() => _expired = true);
                },
                builder: (context, left) => Text(
                  l.collabOfferDeadline(
                    _deadlineTime(j.offerExpiresAt, now),
                    collabLeftText(left, l),
                  ),
                ),
              ),
              note: l.collabOfferDeadlineNote,
            ),
          StudioNote(l.collabOfferLockNote),
          if (expired)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s2),
              child: Text(
                l.collabOfferExpired,
                key: const Key('collab-offer-expired'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            )
          else ...[
            if (_error case final e?)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s2),
                child: Text(
                  e,
                  key: const Key('collab-offer-error'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.s2),
            Row(
              children: [
                Expanded(
                  child: AppButton.outline(
                    l.collabOfferDecline,
                    key: const Key('collab-offer-decline'),
                    loading: _sending == false,
                    onPressed: sending ? null : () => _answer(accept: false),
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: AppButton.primary(
                    l.collabOfferAccept,
                    key: const Key('collab-offer-accept'),
                    loading: _sending == true,
                    onPressed: sending ? null : () => _answer(accept: true),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
