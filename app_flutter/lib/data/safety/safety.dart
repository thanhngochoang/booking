import 'package:flutter/foundation.dart';

@immutable
class BlockIndex {
  const BlockIndex({
    this.blockedIds = const {},
    this.blockedByIds = const {},
  });

  final Set<String> blockedIds;
  final Set<String> blockedByIds;

  /// Every user hidden from this account in feeds, shelves, search, etc.
  /// (the union of people I blocked and people who blocked me).
  Set<String> get hidden => {...blockedIds, ...blockedByIds};

  bool blockedByMe(String id) => blockedIds.contains(id);
  bool blockedMe(String id) => blockedByIds.contains(id);
  bool hides(String? id) => id != null && hidden.contains(id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockIndex &&
          setEquals(blockedIds, other.blockedIds) &&
          setEquals(blockedByIds, other.blockedByIds);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(blockedIds),
        Object.hashAll(blockedByIds),
      );
}

@immutable
class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.blockedAt,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final DateTime blockedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockedUser &&
          userId == other.userId &&
          displayName == other.displayName &&
          avatarUrl == other.avatarUrl &&
          blockedAt == other.blockedAt;

  @override
  int get hashCode => Object.hash(userId, displayName, avatarUrl, blockedAt);
}

enum ReportTargetType { user, post, message, event }

enum ReportReason {
  spam('spam'),
  scam('scam'),
  harassment('harassment'),
  inappropriate('inappropriate'),
  stolenPhotos('stolen_photos'),
  impersonation('impersonation'),
  other('other');

  const ReportReason(this.code);
  final String code;

  static ReportReason? fromCode(String? code) {
    if (code == null) return null;
    for (final r in ReportReason.values) {
      if (r.code == code) return r;
    }
    return null;
  }
}

@immutable
class ReportTarget {
  const ReportTarget({
    required this.type,
    required this.id,
    this.chatId,
    this.ownerId,
    this.ownerName,
    this.excerpt,
    this.thumbUrl,
  });

  final ReportTargetType type;
  final String id;
  final String? chatId;
  final String? ownerId;
  final String? ownerName;
  final String? excerpt;
  final String? thumbUrl;

  factory ReportTarget.user({
    required String uid,
    required String name,
    String? avatarUrl,
  }) {
    return ReportTarget(
      type: ReportTargetType.user,
      id: uid,
      ownerId: uid,
      ownerName: name,
      thumbUrl: avatarUrl,
    );
  }

  factory ReportTarget.post({
    required String postId,
    required String authorId,
    String? authorName,
    String? excerpt,
    String? thumbUrl,
  }) {
    return ReportTarget(
      type: ReportTargetType.post,
      id: postId,
      ownerId: authorId,
      ownerName: authorName,
      excerpt: excerpt,
      thumbUrl: thumbUrl,
    );
  }

  factory ReportTarget.message({
    required String chatId,
    required String messageId,
    required String senderId,
    String? senderName,
    String? text,
  }) {
    return ReportTarget(
      type: ReportTargetType.message,
      id: messageId,
      chatId: chatId,
      ownerId: senderId,
      ownerName: senderName,
      excerpt: text,
    );
  }

  factory ReportTarget.event({
    required String eventId,
    required String title,
    String? hostId,
    String? hostName,
    String? coverUrl,
  }) {
    return ReportTarget(
      type: ReportTargetType.event,
      id: eventId,
      ownerId: hostId,
      ownerName: hostName,
      excerpt: title,
      thumbUrl: coverUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportTarget &&
          type == other.type &&
          id == other.id &&
          chatId == other.chatId &&
          ownerId == other.ownerId &&
          ownerName == other.ownerName &&
          excerpt == other.excerpt &&
          thumbUrl == other.thumbUrl;

  @override
  int get hashCode =>
      Object.hash(type, id, chatId, ownerId, ownerName, excerpt, thumbUrl);
}

@immutable
class ReportDraft {
  const ReportDraft({
    required this.target,
    required this.reason,
    this.text,
    this.block = false,
  });

  final ReportTarget target;
  final ReportReason reason;
  final String? text;
  final bool block;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportDraft &&
          target == other.target &&
          reason == other.reason &&
          text == other.text &&
          block == other.block;

  @override
  int get hashCode => Object.hash(target, reason, text, block);
}

@immutable
class ReportResult {
  const ReportResult({
    required this.reportId,
    this.duplicate = false,
    this.blocked = false,
  });

  final String reportId;
  final bool duplicate;
  final bool blocked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportResult &&
          reportId == other.reportId &&
          duplicate == other.duplicate &&
          blocked == other.blocked;

  @override
  int get hashCode => Object.hash(reportId, duplicate, blocked);
}

class SafetyError implements Exception {
  const SafetyError(this.code, [this.message]);
  final String code;
  final String? message;

  @override
  String toString() => 'SafetyError($code, $message)';
}
