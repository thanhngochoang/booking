import 'package:flutter/material.dart';
import 'package:photobooking/core/widgets/chat_bubble.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/l10n/app_localizations.dart';

BubbleSendState sendStateOf(MessageSendState s) => switch (s) {
      MessageSendState.sending => BubbleSendState.sending,
      MessageSendState.failed => BubbleSendState.failed,
      MessageSendState.sent => BubbleSendState.sent,
    };

ChatBubbleContent bubbleContentOf(
  ChatMessage m, {
  String? imageUrl,
  required AppLocalizations l,
  required String senderName,
  List<Widget> systemActions = const [],
}) {
  return switch (m.type) {
    MessageType.text => TextContent(m.body ?? ''),
    MessageType.image => ImageContent(imageUrl ?? m.imagePath ?? ''),
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
    final text = switch (status) {
      'requested' => l.chatSysRequested,
      'accepted' => l.chatSysAccepted,
      'declined' => l.chatSysDeclined,
      'expired' => l.chatSysExpired,
      'cancelled' => l.chatSysCancelled,
      'completed' => l.chatSysCompleted,
      _ => m.body ?? status,
    };
    return SystemContent(text, actions: systemActions);
  }

  return SystemContent(m.body ?? '', actions: systemActions);
}
