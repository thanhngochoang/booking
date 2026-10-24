// test/support/recruit_world.dart
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/collab/collab_providers.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';

/// Tuesday 21/10/2026 10:00 in Vietnam (S27 fixtures).
final recruitNow = DateTime.utc(2026, 10, 21, 3);

/// An open collaborator post of Studio Cúc (TP.HCM Q1 + Q3, cưới + gia đình,
/// 800.000₫/buổi) posted a day before [recruitNow].
RecruitPost makeRecruitPost({
  String id = 'p1',
  String studioId = 'cuc',
  String studioName = 'Studio Cúc',
  bool businessVerified = false,
  RecruitKind kind = RecruitKind.collaborator,
  String title = 'Tuyển CTV chụp cưới cuối tuần',
  List<String> specialties = const ['wedding', 'family'],
  List<String> areas = const ['hcm-q1', 'hcm-q3'],
  RecruitFrequency frequency = RecruitFrequency.weekly,
  FeeHint fee = const PerShootFee(800000),
  String requirements = '',
  RecruitPostStatus status = RecruitPostStatus.open,
  bool renewed = false,
  int applicationCount = 0,
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  final created = createdAt ?? recruitNow.subtract(const Duration(days: 1));
  return RecruitPost(
    id: id,
    studioId: studioId,
    studioName: studioName,
    studioAvatarUrl: null,
    studioBusinessVerified: businessVerified,
    kind: kind,
    title: title,
    specialties: specialties,
    areas: areas,
    frequency: frequency,
    fee: fee,
    requirements: requirements,
    status: status,
    renewed: renewed,
    applicationCount: applicationCount,
    matchKeys: [
      for (final a in areas)
        for (final s in specialties) 'a=$a|s=$s',
    ],
    createdAt: created,
    expiresAt: expiresAt ?? created.add(const Duration(days: 30)),
  );
}

/// Hòa's application to post [postId] of Studio Cúc, sent an hour ago.
RecruitApplication makeRecruitApplication({
  String postId = 'p1',
  String studioId = 'cuc',
  String applicantId = 'hoa',
  String applicantName = 'Hòa',
  RecruitKind kind = RecruitKind.collaborator,
  ApplicationStatus status = ApplicationStatus.applied,
  String message = 'Em chụp cưới 2 năm, rảnh cuối tuần.',
  List<String> samplePostIds = const [],
  DateTime? createdAt,
}) {
  final created = createdAt ?? recruitNow.subtract(const Duration(hours: 1));
  return RecruitApplication(
    id: '${postId}_$applicantId',
    postId: postId,
    studioId: studioId,
    applicantId: applicantId,
    kind: kind,
    postTitle: 'Tuyển CTV chụp cưới cuối tuần',
    applicantName: applicantName,
    applicantAvatarUrl: null,
    status: status,
    message: message,
    samplePostIds: samplePostIds,
    createdAt: created,
    expiresAt: created.add(const Duration(days: 7)),
    respondedAt: null,
  );
}

/// The collaboration Studio Cúc – [collaboratorId], active for 10 days with a
/// suggested fee of 600.000₫.
Collaboration makeCollaboration({
  String studioId = 'cuc',
  String collaboratorId = 'dung',
  String studioName = 'Studio Cúc',
  String collaboratorName = 'Dũng',
  CollabStatus status = CollabStatus.active,
  int? defaultFee = 600000,
  DateTime? activeAt,
}) {
  final active = activeAt ?? recruitNow.subtract(const Duration(days: 10));
  return Collaboration(
    id: '${studioId}_$collaboratorId',
    studioId: studioId,
    collaboratorId: collaboratorId,
    studioName: studioName,
    studioAvatarUrl: null,
    collaboratorName: collaboratorName,
    collaboratorAvatarUrl: null,
    status: status,
    defaultFee: defaultFee,
    activeAt: status == CollabStatus.active ? active : null,
    expiresAt: active.add(const Duration(days: 7)),
    endedAt: null,
  );
}

/// A job of Studio Cúc's booking [bookingId] offered to [collaboratorId]
/// (24/10 15:00–17:00, "Gói gia đình", 600.000₫).
CollabJob makeCollabJob({
  String bookingId = 'b1',
  String studioId = 'cuc',
  String collaboratorId = 'dung',
  String studioName = 'Studio Cúc',
  String collaboratorName = 'Dũng',
  String day = '2026-10-24',
  String start = '15:00',
  String end = '17:00',
  String serviceName = 'Gói gia đình',
  String placeName = 'Công viên Tao Đàn',
  int agreedFee = 600000,
  OfferStatus offerStatus = OfferStatus.accepted,
  DateTime? offerExpiresAt,
  DateTime? acceptedAt,
  PayStatus payStatus = PayStatus.none,
  DateTime? payDueAt,
  String? paidOn,
  CollabPayMethod? payMethod,
  DateTime? reportedAt,
  DateTime? updatedAt,
}) => CollabJob(
  id: '${bookingId}_$collaboratorId',
  bookingId: bookingId,
  studioId: studioId,
  collaboratorId: collaboratorId,
  studioName: studioName,
  collaboratorName: collaboratorName,
  day: day,
  start: start,
  end: end,
  serviceName: serviceName,
  placeName: placeName,
  agreedFee: agreedFee,
  offerStatus: offerStatus,
  offerExpiresAt: offerExpiresAt ?? recruitNow.add(const Duration(hours: 6)),
  acceptedAt:
      acceptedAt ?? (offerStatus == OfferStatus.accepted ? recruitNow : null),
  payStatus: payStatus,
  payDueAt: payDueAt,
  paidOn: paidOn,
  payMethod: payMethod,
  reportedAt: reportedAt,
  updatedAt: updatedAt ?? recruitNow,
);

/// The signed-in provider's facts: a verified individual by default.
ProviderFacts makeProviderFacts({
  String role = 'photographer',
  ProviderType providerType = ProviderType.individual,
  bool acceptingOrders = true,
  bool businessVerified = false,
  List<String> recruitMatchKeys = const [],
}) => ProviderFacts(
  role: role,
  providerType: providerType,
  acceptingOrders: acceptingOrders,
  businessVerified: businessVerified,
  recruitMatchKeys: recruitMatchKeys,
);

/// In-memory recruit and collaboration repositories, signed in as [uid] at
/// [now]. Features add their own routes on top of [overrides].
class RecruitWorld {
  RecruitWorld({this.uid = 'hoa', DateTime? now})
    : now = now ?? recruitNow,
      recruits = FakeRecruitRepository(
        uid: uid,
        clock: () => now ?? recruitNow,
      ),
      collabs = FakeCollabRepository(uid: uid, clock: () => now ?? recruitNow);

  final String uid;
  final DateTime now;
  final FakeRecruitRepository recruits;
  final FakeCollabRepository collabs;

  List<Override> get overrides => [
    authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid))),
    clockProvider.overrideWithValue(() => now),
    recruitRepositoryProvider.overrideWithValue(recruits),
    collabRepositoryProvider.overrideWithValue(collabs),
  ];
}
