// S05.02-askshot "Buổi chụp có diễn ra không?": the end + 24 h question of
// a booking nobody scanned (Decision 10). "Có, đã chụp" → `shot`; "Không
// diễn ra" → the booking stays held and S18.01 opens with the reason set.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';

/// Whether the customer is asked about [b] at [now]: the question is open,
/// nobody answered and the booking is still `upcoming` (not scanned).
bool asksShootHappened(Booking b, DateTime now) {
  final until = b.shootQuestionUntil;
  return b.status == BookingStatus.upcoming &&
      b.shootQuestionAt != null &&
      b.shootDeniedAt == null &&
      (until == null || now.isBefore(until));
}

/// Opens the sheet; returns the answer the server took (true: it happened),
/// or null when closed without sending.
Future<bool?> showAskShotSheet(
  BuildContext context, {
  required Booking booking,
  required String photographerName,
}) => showAppSheet<bool>(
  context,
  builder: (_) => ScreenCode(
    ScreenCodes.bookingDetail,
    label: 'askshot',
    child: AskShotSheet(booking: booking, photographerName: photographerName),
  ),
);

class AskShotSheet extends ConsumerStatefulWidget {
  const AskShotSheet({
    super.key,
    required this.booking,
    required this.photographerName,
  });

  final Booking booking;
  final String photographerName;

  @override
  ConsumerState<AskShotSheet> createState() => _AskShotSheetState();
}

class _AskShotSheetState extends ConsumerState<AskShotSheet> {
  bool _happened = true;
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(bookingRepositoryProvider)
          .answerShootHappened(widget.booking.id, happened: _happened);
      if (mounted) Navigator.of(context).pop(_happened);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = context.l10n.s30_error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final day = parseDayKey(widget.booking.day);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget option(bool value, String title, String sub) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: AppOptionTile(
        key: Key('ask-shot-${value ? 'yes' : 'no'}'),
        label: title,
        description: sub,
        selected: _happened == value,
        enabled: !_sending,
        onTap: () => setState(() => _happened = value),
      ),
    );
    return Padding(
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
            child: Text(l.s0502_askTitle, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            l.s0502_askBody(
              widget.photographerName,
              day == null ? widget.booking.day : formatDay(day),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: AppSpace.s2),
          const SizedBox(height: AppSpace.s1),
          option(true, l.s0502_askYes, l.s0502_askYesSub),
          option(false, l.s0502_askNo, l.s0502_askNoSub),
          Text(
            l.s0502_askTimeout,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.s2),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s3),
          AppButton.primary(
            l.s0502_askSend,
            key: const Key('ask-shot-send'),
            loading: _sending,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
