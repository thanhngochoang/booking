import 'package:flutter/material.dart';
import 'package:photobooking/core/widgets/chat_bubble.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/l10n/app_localizations.dart';

BubbleSendState sendStateOf(MessageSendState s) => switch (s) {
      MessageSendState.sending => BubbleSendState.sending,
      MessageSendState.failed => BubbleSendState.failed,
      MessageSendState.sent => BubbleSendState.sent,
    };

/// The system sentence for a booking [status] (also the S07.02 row preview
/// when the last message is a status message); null for the states that post
/// no message (draft, upcoming, reviewed).
String? bookingStatusSentence(BookingStatus status, AppLocalizations l) =>
    switch (status) {
      BookingStatus.requested => l.chatSysRequested,
      BookingStatus.accepted => l.chatSysAccepted,
      BookingStatus.declined => l.chatSysDeclined,
      BookingStatus.expired => l.chatSysExpired,
      BookingStatus.cancelled => l.chatSysCancelled,
      BookingStatus.completed => l.chatSysCompleted,
      BookingStatus.draft ||
      BookingStatus.upcoming ||
      BookingStatus.shot ||
      BookingStatus.delivered ||
      BookingStatus.revisionRequested ||
      BookingStatus.approved ||
      BookingStatus.reviewed => null,
    };

ChatBubbleContent bubbleContentOf(
  ChatMessage m, {
  String? imageUrl,
  String? localPath,
  required AppLocalizations l,
  required String senderName,
  List<Widget> systemActions = const [],
}) {
  if (m.deletedAt != null) {
    return TextContent(l.chatMessageRemoved);
  }
  return switch (m.type) {
    MessageType.text => TextContent(m.body ?? ''),
    MessageType.image => ImageContent(imageUrl ?? '', localPath: localPath),
    MessageType.location => LocationContent(
        label: l.chatLocationOf(senderName),
        mapUrl: m.point != null
            ? 'https://www.google.com/maps?q=${m.point!.lat},${m.point!.lng}'
            : '',
      ),
    MessageType.system => _systemContentOf(
        m,
        l: l,
        systemActions: systemActions,
      ),
  };
}

SystemContent _systemContentOf(
  ChatMessage m, {
  required AppLocalizations l,
  List<Widget> systemActions = const [],
}) {
  final sys = m.system;
  if (sys == null) {
    return SystemContent(m.body ?? '', actions: systemActions);
  }

  if (sys.kind == 'reschedule_proposal' && sys.proposal != null) {
    final prop = sys.proposal!;
    final answer = sys.answer;
    final text = switch (answer) {
      'accepted' => l.chatRescheduleAccepted,
      'declined' => l.chatRescheduleDeclined,
      'expired' => l.chatRescheduleExpired,
      _ => l.chatRescheduleProposal(prop.day, prop.start, prop.end),
    };
    return SystemContent(
      text,
      actions: answer == null ? systemActions : const [],
    );
  }

  final status = sys.status;
  if (status != null) {
    final known = bookingStatusFromCode(status);
    final text =
        (known == null ? null : bookingStatusSentence(known, l)) ??
        m.body ??
        status;
    return SystemContent(text, actions: systemActions);
  }

  return SystemContent(m.body ?? '', actions: systemActions);
}
