import 'dart:async';

import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    this.currentUserId = 'cust1',
  });

  String currentUserId;
  bool online = true;
  ChatErrorCode? failNext;

  final Map<String, ChatThread> threads = {};
  final Map<String, List<ChatMessage>> messages = {};
  final Map<String, int> unreadCounts = {}; // chatId -> count for currentUserId

  final Map<String, StreamController<ChatThread?>> _threadControllers = {};
  final Map<String, StreamController<List<ChatMessage>>> _messageControllers = {};
  final StreamController<List<ChatListItem>> _myChatsController =
      StreamController<List<ChatListItem>>.broadcast();
  final StreamController<int> _totalUnreadController =
      StreamController<int>.broadcast();

  void _checkPreconditions() {
    if (!online) {
      throw const ChatException(
        ChatErrorCode.network,
        'No network connection',
      );
    }
    if (failNext != null) {
      final code = failNext!;
      failNext = null;
      throw ChatException(code, 'Simulated failure: $code');
    }
  }

  void seedThread(ChatThread thread) {
    threads[thread.id] = thread;
    _notifyThread(thread.id);
    _notifyChats();
  }

  void seedMessages(String chatId, List<ChatMessage> msgs) {
    messages[chatId] = List.from(msgs);
    _notifyMessages(chatId);
    _notifyChats();
  }

  void seedUnread(String chatId, int count) {
    unreadCounts[chatId] = count;
    _notifyChats();
    _notifyTotalUnread();
  }

  void _notifyThread(String chatId) {
    if (_threadControllers.containsKey(chatId)) {
      _threadControllers[chatId]!.add(threads[chatId]);
    }
  }

  void _notifyMessages(String chatId) {
    if (_messageControllers.containsKey(chatId)) {
      _messageControllers[chatId]!.add(List.unmodifiable(messages[chatId] ?? []));
    }
  }

  void _notifyChats() {
    final items = threads.values.map((t) {
      final unread = unreadCounts[t.id] ?? 0;
      return ChatListItem(thread: t, unreadCount: unread);
    }).toList();
    items.sort((a, b) {
      final aTime = a.thread.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.thread.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    _myChatsController.add(items);
  }

  void _notifyTotalUnread() {
    final total = unreadCounts.values.fold<int>(0, (sum, count) => sum + count);
    _totalUnreadController.add(total);
  }

  @override
  Stream<ChatThread?> watchThread(String chatId) {
    _threadControllers.putIfAbsent(
      chatId,
      () => StreamController<ChatThread?>.broadcast(
        onListen: () {
          _threadControllers[chatId]?.add(threads[chatId]);
        },
      ),
    );
    return _threadControllers[chatId]!.stream;
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId, {int limit = 50}) {
    _messageControllers.putIfAbsent(
      chatId,
      () => StreamController<List<ChatMessage>>.broadcast(
        onListen: () {
          final list = messages[chatId] ?? [];
          final slice = list.length > limit ? list.sublist(list.length - limit) : list;
          _messageControllers[chatId]?.add(List.unmodifiable(slice));
        },
      ),
    );
    return _messageControllers[chatId]!.stream;
  }

  @override
  Future<List<ChatMessage>> olderMessages(
    String chatId, {
    required DateTime before,
    int limit = 50,
  }) async {
    _checkPreconditions();
    final list = messages[chatId] ?? [];
    final older = list.where((m) => m.createdAt.isBefore(before)).toList();
    if (older.length > limit) {
      return older.sublist(older.length - limit);
    }
    return older;
  }

  @override
  Stream<List<ChatListItem>> watchMyChats({int limit = 50}) {
    _notifyChats();
    return _myChatsController.stream;
  }

  @override
  Stream<int> watchTotalUnread() {
    _notifyTotalUnread();
    return _totalUnreadController.stream;
  }

  @override
  Future<String> openInquiry(String photographerId) async {
    _checkPreconditions();
    final chatId = '${currentUserId}_$photographerId';
    if (!threads.containsKey(chatId)) {
      final now = DateTime.now();
      final thread = ChatThread(
        id: chatId,
        kind: ChatKind.inquiry,
        customerId: currentUserId,
        photographerId: photographerId,
        createdAt: now,
        updatedAt: now,
      );
      seedThread(thread);
      unreadCounts[chatId] = 0;
    }
    return chatId;
  }

  Future<void> _addMessage(String chatId, ChatMessage message) async {
    final thread = threads[chatId];
    if (thread == null) {
      throw const ChatException(ChatErrorCode.notFound, 'Thread not found');
    }

    // Check read-only
    if (thread.readOnlyAt != null && DateTime.now().isAfter(thread.readOnlyAt!)) {
      throw const ChatException(ChatErrorCode.notEligible, 'Chat is read-only');
    }

    // Check inquiry cap for customer
    if (thread.kind == ChatKind.inquiry &&
        currentUserId == thread.customerId &&
        thread.photographerRepliedAt == null &&
        thread.customerMessagesBeforeReply >= 3) {
      throw const ChatException(
        ChatErrorCode.limitExceeded,
        'Inquiry limit reached (max 3 messages before photographer replies)',
      );
    }

    // Check retry by clientId
    final existing = messages[chatId] ?? [];
    if (existing.any((m) => m.id == message.id)) {
      return; // Idempotent
    }

    final updatedMessages = List<ChatMessage>.from(existing)..add(message);
    messages[chatId] = updatedMessages;

    // Update thread
    int customerMessagesBeforeReply = thread.customerMessagesBeforeReply;
    DateTime? photographerRepliedAt = thread.photographerRepliedAt;

    if (thread.kind == ChatKind.inquiry) {
      if (currentUserId == thread.photographerId && photographerRepliedAt == null) {
        photographerRepliedAt = message.createdAt;
      } else if (currentUserId == thread.customerId && photographerRepliedAt == null) {
        customerMessagesBeforeReply++;
      }
    }

    String preview = '';
    switch (message.type) {
      case MessageType.text:
        preview = message.body ?? '';
      case MessageType.image:
        preview = 'Ảnh';
      case MessageType.location:
        preview = 'Vị trí';
      case MessageType.system:
        preview = message.system?.kind == 'reschedule_proposal'
            ? 'Đề nghị đổi lịch'
            : '';
    }

    final updatedThread = ChatThread(
      id: thread.id,
      kind: thread.kind,
      customerId: thread.customerId,
      photographerId: thread.photographerId,
      bookingId: thread.bookingId,
      photographerRepliedAt: photographerRepliedAt,
      customerMessagesBeforeReply: customerMessagesBeforeReply,
      lastMessageAt: message.createdAt,
      lastMessagePreview: preview,
      lastSenderId: currentUserId,
      readOnlyAt: thread.readOnlyAt,
      rescheduleUsed: thread.rescheduleUsed,
      createdAt: thread.createdAt,
      updatedAt: message.createdAt,
    );

    threads[chatId] = updatedThread;
    _notifyThread(chatId);
    _notifyMessages(chatId);
    _notifyChats();
  }

  @override
  Future<void> sendText(
    String chatId,
    String text, {
    required String clientId,
  }) async {
    _checkPreconditions();
    final msg = ChatMessage(
      id: clientId,
      senderId: currentUserId,
      type: MessageType.text,
      body: text,
      createdAt: DateTime.now(),
    );
    await _addMessage(chatId, msg);
  }

  @override
  Future<void> sendImage(
    String chatId,
    PickedImage image, {
    required String clientId,
  }) async {
    _checkPreconditions();
    final storagePath = 'chats/$chatId/$currentUserId/$clientId.webp';
    final msg = ChatMessage(
      id: clientId,
      senderId: currentUserId,
      type: MessageType.image,
      imagePath: storagePath,
      createdAt: DateTime.now(),
    );
    await _addMessage(chatId, msg);
  }

  @override
  Future<void> sendLocation(
    String chatId,
    ({double lat, double lng}) point, {
    required String clientId,
  }) async {
    _checkPreconditions();
    final msg = ChatMessage(
      id: clientId,
      senderId: currentUserId,
      type: MessageType.location,
      point: point,
      createdAt: DateTime.now(),
    );
    await _addMessage(chatId, msg);
  }

  @override
  Future<void> markRead(String chatId) async {
    unreadCounts[chatId] = 0;
    _notifyChats();
    _notifyTotalUnread();
  }

  @override
  Future<void> proposeReschedule(
    String bookingId, {
    required String day,
    required String start,
    required String clientId,
  }) async {
    _checkPreconditions();
    final thread = threads.values.firstWhere(
      (t) => t.bookingId == bookingId,
      orElse: () => throw const ChatException(
        ChatErrorCode.notFound,
        'Booking chat not found',
      ),
    );

    if (thread.rescheduleUsed) {
      throw const ChatException(
        ChatErrorCode.limitExceeded,
        'Reschedule already used',
      );
    }

    final msg = ChatMessage(
      id: clientId,
      senderId: null,
      type: MessageType.system,
      system: SystemPayload(
        kind: 'reschedule_proposal',
        proposal: RescheduleProposal(
          day: day,
          start: start,
          end: '11:00',
          byRole: currentUserId == thread.customerId ? 'customer' : 'photographer',
        ),
      ),
      createdAt: DateTime.now(),
    );
    await _addMessage(thread.id, msg);
  }

  @override
  Future<void> answerReschedule(
    String chatId,
    String messageId, {
    required bool accept,
  }) async {
    _checkPreconditions();
    final msgs = messages[chatId] ?? [];
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx == -1) {
      throw const ChatException(ChatErrorCode.notFound, 'Proposal message not found');
    }
    final existing = msgs[idx];
    final sys = existing.system;
    if (sys == null || sys.kind != 'reschedule_proposal') {
      throw const ChatException(ChatErrorCode.invalidArgument, 'Not a proposal message');
    }

    final answer = accept ? 'accepted' : 'declined';
    msgs[idx] = ChatMessage(
      id: existing.id,
      senderId: existing.senderId,
      type: existing.type,
      body: existing.body,
      imagePath: existing.imagePath,
      point: existing.point,
      system: SystemPayload(
        kind: sys.kind,
        status: sys.status,
        proposal: sys.proposal,
        answer: answer,
        answeredBy: currentUserId,
        answeredAt: DateTime.now(),
      ),
      createdAt: existing.createdAt,
    );

    if (accept) {
      final thread = threads[chatId];
      if (thread != null) {
        threads[chatId] = ChatThread(
          id: thread.id,
          kind: thread.kind,
          customerId: thread.customerId,
          photographerId: thread.photographerId,
          bookingId: thread.bookingId,
          photographerRepliedAt: thread.photographerRepliedAt,
          customerMessagesBeforeReply: thread.customerMessagesBeforeReply,
          lastMessageAt: thread.lastMessageAt,
          lastMessagePreview: thread.lastMessagePreview,
          lastSenderId: thread.lastSenderId,
          readOnlyAt: thread.readOnlyAt,
          rescheduleUsed: true,
          createdAt: thread.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    }

    _notifyMessages(chatId);
    _notifyThread(chatId);
  }
}
