import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:photobooking/data/booking/booking_status.dart';

/// `chats.kind`. `collab` (S27 Decision 16) is a studio–collaborator chat:
/// the studio sits in the `customerId` slot, the collaborator in
/// `photographerId`. An unknown kind reads as [inquiry].
enum ChatKind { inquiry, booking, collab }

enum MessageType { text, image, location, system }

enum MessageSendState { sent, sending, failed }

@immutable
class RescheduleProposal {
  const RescheduleProposal({
    required this.day,
    required this.start,
    required this.end,
    required this.byRole,
  });

  final String day;
  final String start;
  final String end;
  final String byRole;

  factory RescheduleProposal.fromMap(Map<String, dynamic> map) {
    return RescheduleProposal(
      day: map['day'] as String? ?? '',
      start: map['start'] as String? ?? '',
      end: map['end'] as String? ?? '',
      byRole: map['byRole'] as String? ?? 'customer',
    );
  }

  Map<String, dynamic> toMap() => {
    'day': day,
    'start': start,
    'end': end,
    'byRole': byRole,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RescheduleProposal &&
          day == other.day &&
          start == other.start &&
          end == other.end &&
          byRole == other.byRole;

  @override
  int get hashCode => Object.hash(day, start, end, byRole);
}

@immutable
class SystemPayload {
  const SystemPayload({
    required this.kind,
    this.status,
    this.proposal,
    this.answer,
    this.answeredBy,
    this.answeredAt,
    this.name,
    this.userId,
  });

  final String kind;

  /// `member_joined` (event group chat): who joined.
  final String? name;
  final String? userId;
  final String? status;
  final RescheduleProposal? proposal;
  final String? answer;
  final String? answeredBy;
  final DateTime? answeredAt;

  factory SystemPayload.fromMap(Map<String, dynamic> map) {
    DateTime? toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final propMap = map['proposal'];
    return SystemPayload(
      kind: map['kind'] as String? ?? 'booking_status',
      status: map['status'] as String?,
      proposal: propMap is Map<String, dynamic>
          ? RescheduleProposal.fromMap(propMap)
          : null,
      answer: map['answer'] as String?,
      answeredBy: map['answeredBy'] as String?,
      answeredAt: toDate(map['answeredAt']),
      name: map['name'] as String?,
      userId: map['userId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'kind': kind,
    if (name != null) 'name': name,
    if (userId != null) 'userId': userId,
    if (status != null) 'status': status,
    if (proposal != null) 'proposal': proposal!.toMap(),
    if (answer != null) 'answer': answer,
    if (answeredBy != null) 'answeredBy': answeredBy,
    if (answeredAt != null) 'answeredAt': answeredAt!.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemPayload &&
          kind == other.kind &&
          status == other.status &&
          proposal == other.proposal &&
          answer == other.answer &&
          answeredBy == other.answeredBy &&
          answeredAt == other.answeredAt &&
          name == other.name &&
          userId == other.userId;

  @override
  int get hashCode => Object.hash(
    kind,
    status,
    proposal,
    answer,
    answeredBy,
    answeredAt,
    name,
    userId,
  );
}

@immutable
class ChatThread {
  const ChatThread({
    required this.id,
    required this.kind,
    required this.customerId,
    required this.photographerId,
    this.bookingId,
    this.photographerRepliedAt,
    this.customerMessagesBeforeReply = 0,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastSenderId,
    this.readOnlyAt,
    this.rescheduleUsed = false,
    this.blockedAt,
    this.createdAt,
    this.updatedAt,
    this.bookingStatus,
    this.assigneeId,
    this.jobId,
  });

  final String id;
  final ChatKind kind;
  final String customerId;
  final String photographerId;
  final String? bookingId;
  final String? jobId;
  final DateTime? photographerRepliedAt;
  final int customerMessagesBeforeReply;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastSenderId;
  final DateTime? readOnlyAt;
  final bool rescheduleUsed;

  /// Time when one of the participants blocked the other, making the chat
  /// permanently read-only and disabling the composer.
  final DateTime? blockedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// `BookingStatus` code of [bookingId], mirrored by the server on every
  /// status change; null for inquiries and chats written before it existed.
  final String? bookingStatus;

  /// Studio booking chat: the member who shoots, a third member speaking for
  /// the studio side (#136 Decision 16); null otherwise.
  final String? assigneeId;

  /// The other party [uid] talks to: the customer for the studio side
  /// (studio or assignee), the studio or photographer for the customer.
  String counterpartIdOf(String uid) =>
      uid == customerId ? photographerId : customerId;

  /// Whether [uid] speaks for the provider (the photographer or studio, or
  /// the studio's assignee), as the server's `roleInChat`.
  bool isProviderSide(String uid) =>
      uid.isNotEmpty && (uid == photographerId || uid == assigneeId);

  factory ChatThread.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime? toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final kindStr = data['kind'] as String? ?? 'inquiry';
    return ChatThread(
      id: doc.id,
      kind: switch (kindStr) {
        'booking' => ChatKind.booking,
        'collab' => ChatKind.collab,
        _ => ChatKind.inquiry,
      },
      customerId: data['customerId'] as String? ?? '',
      photographerId: data['photographerId'] as String? ?? '',
      bookingId: data['bookingId'] as String?,
      photographerRepliedAt: toDate(data['photographerRepliedAt']),
      customerMessagesBeforeReply:
          (data['customerMessagesBeforeReply'] as num?)?.toInt() ?? 0,
      lastMessageAt: toDate(data['lastMessageAt']),
      lastMessagePreview: data['lastMessagePreview'] as String?,
      lastSenderId: data['lastSenderId'] as String?,
      readOnlyAt: toDate(data['readOnlyAt']),
      rescheduleUsed: data['rescheduleUsed'] as bool? ?? false,
      blockedAt: toDate(data['blockedAt']),
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updatedAt']),
      bookingStatus: data['bookingStatus'] is String
          ? data['bookingStatus'] as String
          : null,
      assigneeId:
          data['assigneeId'] is String && (data['assigneeId'] as String) != ''
          ? data['assigneeId'] as String
          : null,
      jobId: data['jobId'] as String?,
    );
  }

  ChatThread copyWith({
    String? id,
    ChatKind? kind,
    String? customerId,
    String? photographerId,
    String? bookingId,
    DateTime? photographerRepliedAt,
    int? customerMessagesBeforeReply,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
    String? lastSenderId,
    DateTime? readOnlyAt,
    bool? rescheduleUsed,
    DateTime? blockedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? bookingStatus,
    String? assigneeId,
    String? jobId,
  }) {
    return ChatThread(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      customerId: customerId ?? this.customerId,
      photographerId: photographerId ?? this.photographerId,
      bookingId: bookingId ?? this.bookingId,
      jobId: jobId ?? this.jobId,
      photographerRepliedAt:
          photographerRepliedAt ?? this.photographerRepliedAt,
      customerMessagesBeforeReply:
          customerMessagesBeforeReply ?? this.customerMessagesBeforeReply,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      readOnlyAt: readOnlyAt ?? this.readOnlyAt,
      rescheduleUsed: rescheduleUsed ?? this.rescheduleUsed,
      blockedAt: blockedAt ?? this.blockedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      assigneeId: assigneeId ?? this.assigneeId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatThread &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          kind == other.kind &&
          customerId == other.customerId &&
          photographerId == other.photographerId &&
          bookingId == other.bookingId &&
          photographerRepliedAt == other.photographerRepliedAt &&
          customerMessagesBeforeReply == other.customerMessagesBeforeReply &&
          lastMessageAt == other.lastMessageAt &&
          lastMessagePreview == other.lastMessagePreview &&
          lastSenderId == other.lastSenderId &&
          readOnlyAt == other.readOnlyAt &&
          rescheduleUsed == other.rescheduleUsed &&
          blockedAt == other.blockedAt &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          bookingStatus == other.bookingStatus &&
          assigneeId == other.assigneeId &&
          jobId == other.jobId;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    customerId,
    photographerId,
    bookingId,
    photographerRepliedAt,
    customerMessagesBeforeReply,
    lastMessageAt,
    lastMessagePreview,
    lastSenderId,
    readOnlyAt,
    rescheduleUsed,
    blockedAt,
    createdAt,
    updatedAt,
    bookingStatus,
    assigneeId,
    jobId,
  );
}

/// Days of silence after which an inquiry is closed (domain
/// `INQUIRY_CLOSE_DAYS`). Closed is derived, never stored: any message reopens it.
const inquiryCloseDays = 14;

extension ChatThreadRules on ChatThread {
  /// Same rule as the domain's `isInquiryClosed`: an inquiry is closed when
  /// [now] is at or past `(lastMessageAt ?? createdAt) + inquiryCloseDays`;
  /// a booking chat never is.
  bool isClosedInquiryAt(DateTime now) {
    if (kind != ChatKind.inquiry) return false;
    final since = lastMessageAt ?? createdAt;
    if (since == null) return false;
    return !now.isBefore(since.add(const Duration(days: inquiryCloseDays)));
  }

  /// [bookingStatus] parsed; null when absent or unknown.
  BookingStatus? get bookingStatusValue => bookingStatusFromCode(bookingStatus);
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    this.senderId,
    required this.type,
    this.body,
    this.imagePath,
    this.point,
    this.system,
    required this.createdAt,
    this.sendState = MessageSendState.sent,
    this.senderName,
    this.deletedAt,
  });

  final String id;
  final String? senderId;

  /// The sender's display name, stored on group chat messages (never a phone).
  final String? senderName;

  /// A moderator deleted the message: it stays as a tombstone.
  final DateTime? deletedAt;
  final MessageType type;
  final String? body;
  final String? imagePath;
  final ({double lat, double lng})? point;
  final SystemPayload? system;
  final DateTime createdAt;
  final MessageSendState sendState;

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    DateTime toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    final typeStr = data['type'] as String? ?? 'text';
    final type = switch (typeStr) {
      'image' => MessageType.image,
      'location' => MessageType.location,
      'system' => MessageType.system,
      _ => MessageType.text,
    };

    ({double lat, double lng})? point;
    final rawPoint = data['point'];
    if (rawPoint is GeoPoint) {
      point = (lat: rawPoint.latitude, lng: rawPoint.longitude);
    } else if (rawPoint is Map<String, dynamic>) {
      final lat = (rawPoint['lat'] ?? rawPoint['latitude'] as num?)?.toDouble();
      final lng = (rawPoint['lng'] ?? rawPoint['longitude'] as num?)
          ?.toDouble();
      if (lat != null && lng != null) {
        point = (lat: lat, lng: lng);
      }
    }

    final sysMap = data['system'];
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String?,
      type: type,
      body: data['body'] as String?,
      imagePath: data['imagePath'] as String?,
      point: point,
      system: sysMap is Map<String, dynamic>
          ? SystemPayload.fromMap(sysMap)
          : null,
      createdAt: toDate(data['createdAt']),
      sendState: MessageSendState.sent,
      senderName: data['senderName'] as String?,
      deletedAt: data['deletedAt'] is Timestamp
          ? (data['deletedAt'] as Timestamp).toDate()
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          id == other.id &&
          senderId == other.senderId &&
          type == other.type &&
          body == other.body &&
          imagePath == other.imagePath &&
          point == other.point &&
          system == other.system &&
          createdAt == other.createdAt &&
          sendState == other.sendState &&
          senderName == other.senderName &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    senderId,
    type,
    body,
    imagePath,
    point,
    system,
    createdAt,
    sendState,
    senderName,
    deletedAt,
  );
}

@immutable
class ChatListItem {
  const ChatListItem({required this.thread, required this.unreadCount});

  final ChatThread thread;
  final int unreadCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatListItem &&
          thread == other.thread &&
          unreadCount == other.unreadCount;

  @override
  int get hashCode => Object.hash(thread, unreadCount);
}
