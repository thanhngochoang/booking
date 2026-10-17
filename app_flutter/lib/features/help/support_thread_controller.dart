import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/support/support_providers.dart';
import 'package:photobooking/data/support/support_repository.dart';
import 'package:photobooking/data/support/support_thread.dart';

@immutable
class SupportThreadState {
  const SupportThreadState({
    this.pending = const [],
    this.errorCode,
    this.errorSeq = 0,
  });

  final List<SupportMessage> pending;
  final String? errorCode;
  final int errorSeq;

  SupportThreadState copyWith({
    List<SupportMessage>? pending,
    String? errorCode,
  }) {
    return SupportThreadState(
      pending: pending ?? this.pending,
      errorCode: errorCode ?? this.errorCode,
      errorSeq: errorCode == null ? errorSeq : errorSeq + 1,
    );
  }
}

class SupportThreadController extends Notifier<SupportThreadState> {
  SupportThreadController(this._threadId);

  final String? _threadId;
  String? get _uid => ref.read(authStateProvider).value?.uid;

  @override
  SupportThreadState build() => const SupportThreadState();

  void syncWithStream(List<SupportMessage> stream) {
    if (state.pending.isEmpty) return;
    final ids = {for (final m in stream) m.id};
    final rest = [
      for (final m in state.pending)
        if (!ids.contains(m.id)) m,
    ];
    if (rest.length != state.pending.length) {
      Future.microtask(() {
        if (ref.mounted) {
          state = state.copyWith(pending: rest);
        }
      });
    }
  }

  Future<void> sendText(String text) async {
    final clientId = newUlid();
    final pendingMsg = SupportMessage(
      id: clientId,
      threadId: _threadId ?? '',
      senderId: _uid,
      senderRole: SupportSenderRole.user,
      senderName: '',
      body: text,
      createdAt: DateTime.now(),
      sendState: MessageSendState.sending,
    );

    state = state.copyWith(
      pending: [...state.pending, pendingMsg],
      errorCode: null,
    );

    await _performSend(clientId, text);
  }

  Future<void> retry(String clientId) async {
    final msg = state.pending.cast<SupportMessage?>().firstWhere(
      (m) => m?.id == clientId,
      orElse: () => null,
    );
    if (msg == null) return;

    _updatePendingState(clientId, MessageSendState.sending);
    await _performSend(clientId, msg.body);
  }

  Future<void> _performSend(String clientId, String text) async {
    final repo = ref.read(supportRepositoryProvider);
    final uid = _uid;
    // The user's own help thread is sent without an id: the callable creates
    // it on the first message and refuses an id that does not exist yet.
    final threadId = uid != null && _threadId == repo.helpThreadIdFor(uid)
        ? null
        : _threadId;
    try {
      await repo.send(threadId: threadId, text: text, clientId: clientId);
      // Wait for stream sync to drop it, or update to sent
      _updatePendingState(clientId, MessageSendState.sent);
    } catch (e) {
      final code = e is SupportError ? e.code : 'generic';
      _updatePendingState(clientId, MessageSendState.failed);
      state = state.copyWith(errorCode: code);
    }
  }

  void _updatePendingState(String clientId, MessageSendState sendState) {
    if (!ref.mounted) return;
    final updated = state.pending.map((m) {
      if (m.id == clientId) {
        return m.copyWith(sendState: sendState);
      }
      return m;
    }).toList();
    state = state.copyWith(pending: updated);
  }
}

final supportThreadControllerProvider = NotifierProvider.autoDispose
    .family<SupportThreadController, SupportThreadState, String?>(
      SupportThreadController.new,
    );
