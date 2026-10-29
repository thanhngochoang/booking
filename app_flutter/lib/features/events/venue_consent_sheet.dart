// lib/features/events/venue_consent_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/features/events/event_links.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// "{n} ngày" / "{n} giờ" left until [until] (at least one hour).
String venueTimeLeft(AppLocalizations l, DateTime until, DateTime now) {
  final left = until.difference(now);
  if (left.inDays >= 1) {
    return l.assignLeftDays(left.inDays);
  }
  final hours = left.inHours < 1 ? 1 : left.inHours;
  return l.assignLeftHours(hours);
}

/// Opens S11.02-venue-consent for [event] at [spotName]. Returns true once
/// the spot manager answered (accepted or declined).
Future<bool> showVenueConsentSheet(
  BuildContext context, {
  required EventDetail event,
  required String spotName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final answer = await showAppSheet<bool>(
    context,
    builder: (_) => ScreenCode(
      ScreenCodes.eventDetail,
      child: VenueConsentSheet(event: event, spotName: spotName),
    ),
  );
  if (answer == null) {
    return false;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          answer ? l.s1102_consentAccepted : l.s1102_consentDeclinedDone,
        ),
      ),
    );
  return true;
}

/// S11.02-venue-consent (mock `#S11.02-venue-consent`, Decision 16): the
/// manager of the event's spot sees the host, day, hours, capacity and
/// price, sets "Phí quản lý mỗi khách" (0 allowed; locked at 0 without a
/// business or on a free event; below the price otherwise) and answers:
/// "Từ chối" (red text → red ConfirmSheet) or "Đồng ý" (the one primary).
/// Pops true for accepted, false for declined.
class VenueConsentSheet extends ConsumerStatefulWidget {
  const VenueConsentSheet({
    super.key,
    required this.event,
    required this.spotName,
  });

  final EventDetail event;
  final String spotName;

  @override
  ConsumerState<VenueConsentSheet> createState() => _VenueConsentSheetState();
}

class _VenueConsentSheetState extends ConsumerState<VenueConsentSheet> {
  final _fee = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  int get _price =>
      widget.event.summary.isFree ? 0 : widget.event.summary.priceVnd;

  String _errorText(AppLocalizations l, Object e) =>
      switch (eventErrorCodeOf(e)) {
        'deadline_passed' => l.s1102_consentExpired,
        'business_required' => l.s1102_consentFeeLocked,
        'invalid_argument' => l.s1102_consentFeeTooHigh(formatMoney(_price)),
        'network' => l.s30_network,
        _ => l.s30_error,
      };

  Future<bool> _send({required bool accept, int? fee}) async {
    final l = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(eventRepositoryProvider)
          .respondVenueConsent(
            widget.event.id,
            accept: accept,
            venueFeePerGuest: accept ? fee : null,
          );
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _error = _errorText(l, e));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _accept(bool feeOpen) async {
    final l = context.l10n;
    final fee = feeOpen ? (parseVnd(_fee.text) ?? 0) : 0;
    if (fee > 0 && fee >= _price) {
      setState(() => _error = l.s1102_consentFeeTooHigh(formatMoney(_price)));
      return;
    }
    final ok = await _send(accept: true, fee: fee);
    if (ok && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _decline() async {
    final l = context.l10n;
    var ok = false;
    final yes = await showConfirmSheet(
      context,
      title: l.s1102_consentDeclineTitle,
      body: l.s1102_consentDeclineBody,
      confirmLabel: l.s1102_consentDecline,
      keepLabel: l.s30_keep,
      onConfirm: () async {
        ok = await _send(accept: false);
      },
    );
    if (yes && ok && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final e = widget.event;
    final s = e.summary;
    final now = ref.watch(clockProvider)();
    final org = ref.watch(myOrganizerProvider).value;
    final free = _price == 0;
    final business = org?.canSell ?? false;
    final feeOpen = !free && business;
    final until = e.venueConsentExpiresAt;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.mutedForeground,
    );
    final meta = l.s1102_consentMeta(
      s.hostName,
      eventWhenLabel(l, s.startsAt, e.endsAt),
      s.capacity,
      free ? l.freeTag : l.s1102_pricePerTicket(formatMoney(_price)),
    );
    final note = [
      l.s1102_consentBody,
      if (until != null && until.isAfter(now))
        l.s1102_consentLeft(venueTimeLeft(l, until, now)),
    ].join(' ');

    return PopScope(
      canPop: !_busy,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s4,
          AppSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l.s1102_consentTitle(widget.spotName),
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpace.s1),
            Text(
              meta,
              key: const Key('venue-consent-meta'),
              style: muted?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            TextField(
              key: const Key('venue-consent-fee'),
              controller: _fee,
              enabled: feeOpen && !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: const [VndInputFormatter()],
              decoration: InputDecoration(
                labelText: l.s1102_consentFee,
                hintText: feeOpen ? '0' : null,
                helperText: free
                    ? l.s1102_consentFeeFree
                    : business
                    ? null
                    : l.s1102_consentFeeLocked,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            Text(note, style: muted),
            if (_error case final err?) ...[
              const SizedBox(height: AppSpace.s2),
              Semantics(
                liveRegion: true,
                child: Text(
                  err,
                  key: const Key('venue-consent-error'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.s4),
            Row(
              children: [
                Expanded(
                  flex: 40,
                  child: AppButton.outline(
                    l.s1102_consentDecline,
                    key: const Key('venue-consent-decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: _busy ? null : _decline,
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  flex: 60,
                  child: AppButton.primary(
                    l.s1102_consentAccept,
                    key: const Key('venue-consent-accept'),
                    loading: _busy,
                    onPressed: _busy ? null : () => _accept(feeOpen),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
