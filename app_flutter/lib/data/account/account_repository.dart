import 'dart:async';

enum BlockerKind {
  openBooking,
  openJob,
  openJobPost,
  openQuote,
  activeInstant,
  studioMembership,
  openCollab,
  liveTicket,
  hostedEvent,
  openDispute,
  heldPayment,
  refundInProgress,
  unpaidEarnings;

  static BlockerKind? fromWire(String raw) => switch (raw) {
    'open_booking' => openBooking,
    'open_job' => openJob,
    'open_job_post' => openJobPost,
    'open_quote' => openQuote,
    'active_instant' => activeInstant,
    'studio_membership' => studioMembership,
    'open_collab' => openCollab,
    'live_ticket' => liveTicket,
    'hosted_event' => hostedEvent,
    'open_dispute' => openDispute,
    'held_payment' => heldPayment,
    'refund_in_progress' => refundInProgress,
    'unpaid_earnings' => unpaidEarnings,
    _ => null,
  };
}

class DeletionBlocker {
  const DeletionBlocker({
    required this.kind,
    required this.count,
    this.amount,
    this.first,
  });

  final BlockerKind kind;
  final int count;
  final int? amount;
  final ({String id, String title, String? day, String? eventId})? first;

  static DeletionBlocker? fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'] as String?;
    if (rawKind == null) return null;
    final kind = BlockerKind.fromWire(rawKind);
    if (kind == null) return null;

    final count = (json['count'] as num?)?.toInt() ?? 0;
    final amount = (json['amount'] as num?)?.toInt();

    ({String id, String title, String? day, String? eventId})? first;
    final rawFirst = json['first'] as Map<String, dynamic>?;
    if (rawFirst != null && rawFirst['id'] is String) {
      first = (
        id: rawFirst['id'] as String,
        title: (rawFirst['title'] as String?) ?? '',
        day: rawFirst['day'] as String?,
        eventId: rawFirst['eventId'] as String?,
      );
    }

    return DeletionBlocker(
      kind: kind,
      count: count,
      amount: amount,
      first: first,
    );
  }
}

class DataExport {
  const DataExport({
    required this.path,
    required this.sizeBytes,
    required this.createdAt,
    required this.expiresAt,
  });

  final String path;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool usableAt(DateTime now) => now.isBefore(expiresAt);

  static DataExport? fromJson(Map<String, dynamic> json) {
    final path = json['path'] as String? ?? json['lastPath'] as String?;
    final size = (json['sizeBytes'] as num?)?.toInt() ?? (json['lastSizeBytes'] as num?)?.toInt();
    if (path == null || size == null) return null;

    DateTime? parseDate(dynamic v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final createdAt = parseDate(json['createdAt']) ?? DateTime.now();
    final expiresAt = parseDate(json['expiresAt']);
    if (expiresAt == null) return null;

    return DataExport(
      path: path,
      sizeBytes: size,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}

class AccountException implements Exception {
  const AccountException(this.code);
  final String code;

  @override
  String toString() => 'AccountException: $code';
}

class AccountLock {
  const AccountLock(this.restoreUntil);
  final DateTime restoreUntil;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountLock &&
          runtimeType == other.runtimeType &&
          restoreUntil == other.restoreUntil;

  @override
  int get hashCode => restoreUntil.hashCode;
}

abstract class AccountRepository {
  Future<List<DeletionBlocker>> deletionBlockers();
  Future<DateTime> requestDeletion();
  Future<void> restore();
  Stream<AccountLock?> watchLock(String uid);
  Future<DataExport> requestExport();
  Stream<DataExport?> watchExport(String uid);
  Future<Uri> exportDownloadUrl(String path);
  Future<void> setHiddenFromDiscovery(String uid, bool hidden);
}
