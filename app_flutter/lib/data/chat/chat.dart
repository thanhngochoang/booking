import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ChatKind { inquiry, booking }

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
  });

  final String kind;
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
    );
  }

  Map<String, dynamic> toMap() => {
    'kind': kind,
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
          answeredAt == other.answeredAt;

  @override
  int get hashCode =>
      Object.hash(kind, status, proposal, answer, answeredBy, answeredAt);
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
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final ChatKind kind;
  final String customerId;
  final String photographerId;
  final String? bookingId;
  final DateTime? photographerRepliedAt;
  final int customerMessagesBeforeReply;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastSenderId;
  final DateTime? readOnlyAt;
  final bool rescheduleUsed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
      kind: kindStr == 'booking' ? ChatKind.booking : ChatKind.inquiry,
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
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updatedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatThread &&
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
          rescheduleUsed == other.rescheduleUsed;

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
  );
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
  });

  final String id;
  final String? senderId;
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
      final lng = (rawPoint['lng'] ?? rawPoint['longitude'] as num?)?.toDouble();
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
          sendState == other.sendState;

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
  );
}

@immutable
class ChatListItem {
  const ChatListItem({
    required this.thread,
    required this.unreadCount,
  });

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
