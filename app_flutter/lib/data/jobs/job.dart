// lib/data/jobs/job.dart
//
// Dart models for jobs/{jobId}.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

export 'package:photobooking/data/content/provider_type.dart';

enum JobStatus {
  draft('draft'),
  open('open'),
  awarded('awarded'),
  expired('expired'),
  closed('closed');

  const JobStatus(this.code);
  final String code;

  /// Safe conversion from string code. Unknown or null maps to [closed].
  static JobStatus fromCode(String? c) {
    for (final s in values) {
      if (s.code == c) return s;
    }
    return closed;
  }
}

enum AllowedProviders {
  all('all'),
  artist('artist'),
  studio('studio');

  const AllowedProviders(this.code);
  final String code;

  static AllowedProviders fromCode(String? c) {
    for (final a in values) {
      if (a.code == c) return a;
    }
    return all;
  }
}

enum ScheduleKind {
  fixed('fixed'),
  flexible('flexible');

  const ScheduleKind(this.code);
  final String code;

  static ScheduleKind fromCode(String? c) {
    for (final k in values) {
      if (k.code == c) return k;
    }
    return fixed;
  }
}

@immutable
class JobSchedule {
  const JobSchedule({
    required this.kind,
    this.day,
    this.start,
    this.end,
    this.from,
    this.to,
    required this.durationMinutes,
  });

  final ScheduleKind kind;
  final String? day;
  final String? start;
  final String? end;
  final String? from;
  final String? to;
  final int durationMinutes;

  factory JobSchedule.fromJson(Map<String, dynamic> json) {
    return JobSchedule(
      kind: ScheduleKind.fromCode(json['kind'] as String?),
      day: json['day'] as String?,
      start: json['start'] as String?,
      end: json['end'] as String?,
      from: json['from'] as String?,
      to: json['to'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.code,
    if (day != null) 'day': day,
    if (start != null) 'start': start,
    if (end != null) 'end': end,
    if (from != null) 'from': from,
    if (to != null) 'to': to,
    'durationMinutes': durationMinutes,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobSchedule &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          day == other.day &&
          start == other.start &&
          end == other.end &&
          from == other.from &&
          to == other.to &&
          durationMinutes == other.durationMinutes;

  @override
  int get hashCode => Object.hash(kind, day, start, end, from, to, durationMinutes);
}

@immutable
class JobArea {
  const JobArea({
    required this.areaId,
    required this.name,
    required this.city,
    required this.cityKey,
    required this.lat,
    required this.lng,
    required this.geohash5,
  });

  final String areaId;
  final String name;
  final String city;
  final String cityKey;
  final double lat;
  final double lng;
  final String geohash5;

  factory JobArea.fromJson(Map<String, dynamic> json) {
    return JobArea(
      areaId: json['areaId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      cityKey: json['cityKey'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      geohash5: json['geohash5'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'areaId': areaId,
    'name': name,
    'city': city,
    'cityKey': cityKey,
    'lat': lat,
    'lng': lng,
    'geohash5': geohash5,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobArea &&
          runtimeType == other.runtimeType &&
          areaId == other.areaId &&
          name == other.name &&
          city == other.city &&
          cityKey == other.cityKey &&
          lat == other.lat &&
          lng == other.lng &&
          geohash5 == other.geohash5;

  @override
  int get hashCode => Object.hash(areaId, name, city, cityKey, lat, lng, geohash5);
}

@immutable
class JobReference {
  const JobReference({required this.url, required this.path});

  final String url;
  final String path;

  factory JobReference.fromJson(Map<String, dynamic> json) {
    return JobReference(
      url: json['url'] as String? ?? '',
      path: json['path'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'path': path};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobReference &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          path == other.path;

  @override
  int get hashCode => Object.hash(url, path);
}

@immutable
class JobCustomer {
  const JobCustomer({
    required this.name,
    this.avatarUrl,
    this.hireCount = 0,
    this.phoneVerified = false,
  });

  final String name;
  final String? avatarUrl;
  final int hireCount;
  final bool phoneVerified;

  factory JobCustomer.fromJson(Map<String, dynamic> json) {
    return JobCustomer(
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      hireCount: (json['hireCount'] as num?)?.toInt() ?? 0,
      phoneVerified: json['phoneVerified'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'hireCount': hireCount,
    'phoneVerified': phoneVerified,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobCustomer &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          avatarUrl == other.avatarUrl &&
          hireCount == other.hireCount &&
          phoneVerified == other.phoneVerified;

  @override
  int get hashCode => Object.hash(name, avatarUrl, hireCount, phoneVerified);
}

@immutable
class JobBudget {
  const JobBudget({required this.min, required this.max});

  final int min;
  final int max;

  factory JobBudget.fromJson(Map<String, dynamic> json) {
    return JobBudget(
      min: (json['min'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobBudget &&
          runtimeType == other.runtimeType &&
          min == other.min &&
          max == other.max;

  @override
  int get hashCode => Object.hash(min, max);
}

@immutable
class JobWants {
  const JobWants({this.editedCount, this.deliveryDays});

  final int? editedCount;
  final int? deliveryDays;

  factory JobWants.fromJson(Map<String, dynamic> json) {
    return JobWants(
      editedCount: (json['editedCount'] as num?)?.toInt(),
      deliveryDays: (json['deliveryDays'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (editedCount != null) 'editedCount': editedCount,
    if (deliveryDays != null) 'deliveryDays': deliveryDays,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobWants &&
          runtimeType == other.runtimeType &&
          editedCount == other.editedCount &&
          deliveryDays == other.deliveryDays;

  @override
  int get hashCode => Object.hash(editedCount, deliveryDays);
}

@immutable
class JobCheckout {
  const JobCheckout({
    required this.quoteId,
    required this.bookingId,
    required this.expiresAt,
  });

  final String quoteId;
  final String bookingId;
  final DateTime expiresAt;

  factory JobCheckout.fromJson(Map<String, dynamic> json) {
    return JobCheckout(
      quoteId: json['quoteId'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      expiresAt: _parseDateTime(json['expiresAt']) ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'quoteId': quoteId,
    'bookingId': bookingId,
    'expiresAt': expiresAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobCheckout &&
          runtimeType == other.runtimeType &&
          quoteId == other.quoteId &&
          bookingId == other.bookingId &&
          expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(quoteId, bookingId, expiresAt);
}

@immutable
class RecentQuoter {
  const RecentQuoter({required this.photographerId, this.avatarUrl});

  final String photographerId;
  final String? avatarUrl;

  factory RecentQuoter.fromJson(Map<String, dynamic> json) {
    return RecentQuoter(
      photographerId: json['photographerId'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'photographerId': photographerId,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentQuoter &&
          runtimeType == other.runtimeType &&
          photographerId == other.photographerId &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode => Object.hash(photographerId, avatarUrl);
}

@immutable
class AwardedTo {
  const AwardedTo({
    required this.photographerId,
    required this.name,
    required this.price,
  });

  final String photographerId;
  final String name;
  final int price;

  factory AwardedTo.fromJson(Map<String, dynamic> json) {
    return AwardedTo(
      photographerId: json['photographerId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'photographerId': photographerId,
    'name': name,
    'price': price,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AwardedTo &&
          runtimeType == other.runtimeType &&
          photographerId == other.photographerId &&
          name == other.name &&
          price == other.price;

  @override
  int get hashCode => Object.hash(photographerId, name, price);
}

DateTime? _parseDateTime(Object? val) {
  if (val is Timestamp) return val.toDate().toUtc();
  if (val is DateTime) return val.toUtc();
  if (val is String) return DateTime.tryParse(val)?.toUtc();
  return null;
}

@immutable
class Job {
  const Job({
    required this.id,
    required this.customerId,
    required this.customer,
    required this.specialtyId,
    required this.title,
    required this.description,
    this.references = const [],
    required this.schedule,
    required this.dayFrom,
    required this.dayTo,
    required this.area,
    this.budget,
    required this.wants,
    required this.allowedProviders,
    required this.quoteDeadline,
    this.extended = false,
    required this.status,
    this.quoteCount = 0,
    this.newQuoteCount = 0,
    this.viewCount = 0,
    this.inviteCount = 0,
    this.matchCount = 0,
    this.recentQuoters = const [],
    this.awardedQuoteId,
    this.bookingId,
    this.awardedTo,
    this.checkout,
    this.expiringNotifiedAt,
    this.closedAt,
    this.referencesPurgeAfter,
    this.quotesSeenAt,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String customerId;
  final JobCustomer customer;
  final String specialtyId;
  final String title;
  final String description;
  final List<JobReference> references;
  final JobSchedule schedule;
  final String dayFrom;
  final String dayTo;
  final JobArea area;
  final JobBudget? budget;
  final JobWants wants;
  final AllowedProviders allowedProviders;
  final DateTime quoteDeadline;
  final bool extended;
  final JobStatus status;
  final int quoteCount;
  final int newQuoteCount;
  final int viewCount;
  final int inviteCount;
  final int matchCount;
  final List<RecentQuoter> recentQuoters;
  final String? awardedQuoteId;
  final String? bookingId;
  final AwardedTo? awardedTo;
  final JobCheckout? checkout;
  final DateTime? expiringNotifiedAt;
  final DateTime? closedAt;
  final DateTime? referencesPurgeAfter;
  final DateTime? quotesSeenAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Safe deserialization from Firestore data.
  static Job? fromFirestore(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    try {
      final customerRaw = data['customer'];
      final customer = customerRaw is Map<String, dynamic>
          ? JobCustomer.fromJson(customerRaw)
          : const JobCustomer(name: '');

      final scheduleRaw = data['schedule'];
      final schedule = scheduleRaw is Map<String, dynamic>
          ? JobSchedule.fromJson(scheduleRaw)
          : const JobSchedule(kind: ScheduleKind.fixed, durationMinutes: 60);

      final areaRaw = data['area'];
      final area = areaRaw is Map<String, dynamic>
          ? JobArea.fromJson(areaRaw)
          : const JobArea(
              areaId: '',
              name: '',
              city: '',
              cityKey: '',
              lat: 0.0,
              lng: 0.0,
              geohash5: '',
            );

      final budgetRaw = data['budget'];
      final budget = budgetRaw is Map<String, dynamic>
          ? JobBudget.fromJson(budgetRaw)
          : null;

      final wantsRaw = data['wants'];
      final wants = wantsRaw is Map<String, dynamic>
          ? JobWants.fromJson(wantsRaw)
          : const JobWants();

      final referencesRaw = data['references'];
      final references = <JobReference>[];
      if (referencesRaw is List) {
        for (final r in referencesRaw) {
          if (r is Map<String, dynamic>) {
            references.add(JobReference.fromJson(r));
          }
        }
      }

      final recentRaw = data['recentQuoters'];
      final recentQuoters = <RecentQuoter>[];
      if (recentRaw is List) {
        for (final r in recentRaw) {
          if (r is Map<String, dynamic>) {
            recentQuoters.add(RecentQuoter.fromJson(r));
          }
        }
      }

      final checkoutRaw = data['checkout'];
      final checkout = checkoutRaw is Map<String, dynamic>
          ? JobCheckout.fromJson(checkoutRaw)
          : null;

      final awardedToRaw = data['awardedTo'];
      final awardedTo = awardedToRaw is Map<String, dynamic>
          ? AwardedTo.fromJson(awardedToRaw)
          : null;

      final quoteDeadline =
          _parseDateTime(data['quoteDeadline']) ?? DateTime.now().toUtc();
      final createdAt =
          _parseDateTime(data['createdAt']) ?? DateTime.now().toUtc();
      final updatedAt = _parseDateTime(data['updatedAt']) ?? createdAt;

      return Job(
        id: id,
        customerId: data['customerId'] as String? ?? '',
        customer: customer,
        specialtyId: data['specialtyId'] as String? ?? '',
        title: data['title'] as String? ?? '',
        description: data['description'] as String? ?? '',
        references: references,
        schedule: schedule,
        dayFrom: data['dayFrom'] as String? ?? '',
        dayTo: data['dayTo'] as String? ?? '',
        area: area,
        budget: budget,
        wants: wants,
        allowedProviders: AllowedProviders.fromCode(data['allowedProviders'] as String?),
        quoteDeadline: quoteDeadline,
        extended: data['extended'] == true,
        status: JobStatus.fromCode(data['status'] as String?),
        quoteCount: (data['quoteCount'] as num?)?.toInt() ?? 0,
        newQuoteCount: (data['newQuoteCount'] as num?)?.toInt() ?? 0,
        viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
        inviteCount: (data['inviteCount'] as num?)?.toInt() ?? 0,
        matchCount: (data['matchCount'] as num?)?.toInt() ?? 0,
        recentQuoters: recentQuoters,
        awardedQuoteId: data['awardedQuoteId'] as String?,
        bookingId: data['bookingId'] as String?,
        awardedTo: awardedTo,
        checkout: checkout,
        expiringNotifiedAt: _parseDateTime(data['expiringNotifiedAt']),
        closedAt: _parseDateTime(data['closedAt']),
        referencesPurgeAfter: _parseDateTime(data['referencesPurgeAfter']),
        quotesSeenAt: _parseDateTime(data['quotesSeenAt']),
        version: (data['version'] as num?)?.toInt() ?? 1,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toFirestore() => {
    'customerId': customerId,
    'customer': customer.toJson(),
    'specialtyId': specialtyId,
    'title': title,
    'description': description,
    'references': references.map((r) => r.toJson()).toList(),
    'schedule': schedule.toJson(),
    'dayFrom': dayFrom,
    'dayTo': dayTo,
    'area': area.toJson(),
    if (budget != null) 'budget': budget!.toJson() else 'budget': null,
    'wants': wants.toJson(),
    'allowedProviders': allowedProviders.code,
    'quoteDeadline': Timestamp.fromDate(quoteDeadline),
    'extended': extended,
    'status': status.code,
    'quoteCount': quoteCount,
    'newQuoteCount': newQuoteCount,
    'viewCount': viewCount,
    'inviteCount': inviteCount,
    'matchCount': matchCount,
    'recentQuoters': recentQuoters.map((r) => r.toJson()).toList(),
    'awardedQuoteId': awardedQuoteId,
    'bookingId': bookingId,
    if (awardedTo != null) 'awardedTo': awardedTo!.toJson() else 'awardedTo': null,
    if (checkout != null) 'checkout': {
      'quoteId': checkout!.quoteId,
      'bookingId': checkout!.bookingId,
      'expiresAt': Timestamp.fromDate(checkout!.expiresAt),
    } else 'checkout': null,
    'expiringNotifiedAt': expiringNotifiedAt != null ? Timestamp.fromDate(expiringNotifiedAt!) : null,
    'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
    'referencesPurgeAfter': referencesPurgeAfter != null ? Timestamp.fromDate(referencesPurgeAfter!) : null,
    'quotesSeenAt': quotesSeenAt != null ? Timestamp.fromDate(quotesSeenAt!) : null,
    'version': version,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
