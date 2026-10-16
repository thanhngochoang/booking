import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:photobooking/data/chat/chat.dart';

enum SupportThreadKind { help, dispute }

enum SupportSenderRole { customer, provider, user, staff, system }

@immutable
class SupportThread {
  const SupportThread({
    required this.id,
    required this.kind,
    this.ownerId,
    this.disputeId,
    required this.participants,
    required this.status,
    required this.awaitingStaff,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastSenderRole,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final SupportThreadKind kind;
  final String? ownerId;
  final String? disputeId;
  final List<String> participants;
  final String status; // 'open' | 'closed'
  final bool awaitingStaff;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final SupportSenderRole? lastSenderRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SupportThread.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SupportThread.fromMap(doc.id, data);
  }

  factory SupportThread.fromMap(String id, Map<String, dynamic> data) {
    final kindStr = data['kind'] as String?;
    final kind = switch (kindStr) {
      'dispute' => SupportThreadKind.dispute,
      _ => SupportThreadKind.help,
    };

    final roleStr = data['lastSenderRole'] as String?;
    final lastSenderRole = roleStr != null ? _parseRole(roleStr) : null;

    final rawParticipants = data['participants'];
    final participants = rawParticipants is List
        ? rawParticipants.map((e) => e.toString()).toList()
        : <String>[];

    return SupportThread(
      id: id,
      kind: kind,
      ownerId: data['ownerId'] as String?,
      disputeId: data['disputeId'] as String?,
      participants: participants,
      status: (data['status'] as String?) ?? 'open',
      awaitingStaff: (data['awaitingStaff'] as bool?) ?? false,
      lastMessageAt: _parseDateTime(data['lastMessageAt']),
      lastMessagePreview: data['lastMessagePreview'] as String?,
      lastSenderRole: lastSenderRole,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kind': kind.name,
      'ownerId': ownerId,
      'disputeId': disputeId,
      'participants': participants,
      'status': status,
      'awaitingStaff': awaitingStaff,
      'lastMessageAt': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'lastMessagePreview': lastMessagePreview,
      'lastSenderRole': lastSenderRole?.name,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

@immutable
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.threadId,
    this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.sendState = MessageSendState.sent,
  });

  final String id;
  final String threadId;
  final String? senderId;
  final SupportSenderRole senderRole;
  final String senderName;
  final String body;
  final DateTime createdAt;
  final MessageSendState sendState;

  SupportMessage copyWith({
    String? id,
    String? threadId,
    String? senderId,
    SupportSenderRole? senderRole,
    String? senderName,
    String? body,
    DateTime? createdAt,
    MessageSendState? sendState,
  }) {
    return SupportMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      senderName: senderName ?? this.senderName,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      sendState: sendState ?? this.sendState,
    );
  }

  factory SupportMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SupportMessage.fromMap(doc.id, data);
  }

  factory SupportMessage.fromMap(String id, Map<String, dynamic> data) {
    return SupportMessage(
      id: id,
      threadId: (data['threadId'] as String?) ?? '',
      senderId: data['senderId'] as String?,
      senderRole: _parseRole((data['senderRole'] as String?) ?? 'user'),
      senderName: (data['senderName'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      sendState: MessageSendState.sent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'threadId': threadId,
      'senderId': senderId,
      'senderRole': senderRole.name,
      'senderName': senderName,
      'body': body,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

SupportSenderRole _parseRole(String role) => switch (role) {
      'customer' => SupportSenderRole.customer,
      'provider' => SupportSenderRole.provider,
      'staff' => SupportSenderRole.staff,
      'system' => SupportSenderRole.system,
      _ => SupportSenderRole.user,
    };

DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}
