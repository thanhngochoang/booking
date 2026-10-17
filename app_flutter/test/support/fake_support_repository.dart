import 'dart:async';

import 'package:photobooking/data/support/support_repository.dart';
import 'package:photobooking/data/support/support_thread.dart';

class FakeSupportRepository implements SupportRepository {
  FakeSupportRepository({
    this.sendError,
    this.initialThread,
    List<SupportMessage>? initialMessages,
  }) {
    if (initialThread != null) {
      _threads[initialThread!.id] = initialThread;
    }
    if (initialMessages != null && initialThread != null) {
      _messages[initialThread!.id] = List.from(initialMessages);
    }
  }

  final SupportThread? initialThread;
  final Map<String, SupportThread?> _threads = {};
  final Map<String, List<SupportMessage>> _messages = {};
  final Map<String, StreamController<SupportThread?>> _threadControllers = {};
  final Map<String, StreamController<List<SupportMessage>>>
  _messageControllers = {};

  Object? sendError;
  final List<({String? threadId, String text, String clientId})> sentCalls = [];

  /// The text of every [send] call, in order.
  List<String> get sentBodies => [for (final c in sentCalls) c.text];

  @override
  String helpThreadIdFor(String uid) => 'help_$uid';

  @override
  Stream<SupportThread?> watchThread(String threadId) {
    final controller = _threadControllers.putIfAbsent(
      threadId,
      () => StreamController<SupportThread?>.broadcast(
        onListen: () {
          _threadControllers[threadId]?.add(_threads[threadId]);
        },
      ),
    );
    return controller.stream;
  }

  @override
  Stream<List<SupportMessage>> watchMessages(
    String threadId, {
    int limit = 30,
  }) {
    final controller = _messageControllers.putIfAbsent(
      threadId,
      () => StreamController<List<SupportMessage>>.broadcast(
        onListen: () {
          _messageControllers[threadId]?.add(_messages[threadId] ?? []);
        },
      ),
    );
    return controller.stream;
  }

  @override
  Future<String> send({
    String? threadId,
    required String text,
    required String clientId,
  }) async {
    sentCalls.add((threadId: threadId, text: text, clientId: clientId));
    if (sendError != null) {
      throw sendError!;
    }

    final targetThreadId = threadId ?? 'help_test_user';
    final existingThread =
        _threads[targetThreadId] ??
        SupportThread(
          id: targetThreadId,
          kind: SupportThreadKind.help,
          ownerId: 'test_user',
          participants: const ['test_user'],
          status: 'open',
          awaitingStaff: true,
          lastMessageAt: DateTime.now(),
          lastMessagePreview: text,
        );
    setThread(existingThread);

    final msg = SupportMessage(
      id: 'msg_$clientId',
      threadId: targetThreadId,
      senderId: 'test_user',
      senderRole: SupportSenderRole.user,
      senderName: 'Test User',
      body: text,
      createdAt: DateTime.now(),
    );
    final msgs = _messages.putIfAbsent(targetThreadId, () => []);
    msgs.add(msg);
    _messageControllers[targetThreadId]?.add(List.unmodifiable(msgs));

    return targetThreadId;
  }

  void setThread(SupportThread? thread) {
    if (thread != null) {
      _threads[thread.id] = thread;
      _threadControllers[thread.id]?.add(thread);
    }
  }

  void setMessages(String threadId, List<SupportMessage> msgs) {
    _messages[threadId] = List.from(msgs);
    _messageControllers[threadId]?.add(List.unmodifiable(msgs));
  }

  void dispose() {
    for (final c in _threadControllers.values) {
      c.close();
    }
    for (final c in _messageControllers.values) {
      c.close();
    }
  }
}
