import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

/// Thursday 1 Oct 2026, 12:00 in Vietnam.
final fixtureNow = DateTime.utc(2026, 10, 1, 5);

PostSummary fixturePost(
  String id, {
  PostKind kind = PostKind.work,
  String photographerId = 'p1',
  String? authorId,
  String serviceId = 's1',
  String caption = 'Chiều muộn ở bến Bạch Đằng #chandung',
  Duration age = const Duration(hours: 1),
  String? specialtyId,
  String? styleId,
  String? locationName = 'Bến Bạch Đằng',
  int likes = 0,
  int saves = 0,
  int images = 1,
  bool inPortfolio = true,
  List<String> hashtags = const ['chandung'],
  String? albumId,
  int? albumPosition,
  String? eventId,
}) => PostSummary(
  id: id,
  kind: kind,
  authorId: authorId ?? photographerId,
  photographerId: photographerId,
  serviceId: serviceId,
  images: [
    for (var i = 0; i < images; i++)
      PostImage(
        url: 'https://img.test/$id-$i.jpg',
        blurHash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        width: 1200,
        height: 1600,
      ),
  ],
  caption: caption,
  locationName: locationName,
  styleId: styleId,
  specialtyId: specialtyId,
  hashtags: hashtags,
  inPortfolio: inPortfolio,
  albumId: albumId,
  albumPosition: albumPosition,
  likeCount: likes,
  saveCount: saves,
  eventId: eventId,
  createdAt: fixtureNow.subtract(age),
);

PhotographerSummary fixturePhotographer(
  String id, {
  String name = 'Minh Trí',
  bool verified = false,
  bool businessVerified = false,
  List<String> specialties = const ['portrait'],
  List<String> styles = const [],
  int tomatoCount = 0,
  int brickCount = 0,
  double? score,
  int completed = 112,
  int? startingPrice = 1500000,
  String? nextFreeDate,
  double? lat = 10.7769,
  double? lng = 106.7009,
  int? responseMinutes = 60,
  Duration createdAgo = const Duration(days: 200),
  String? areaLabel = 'Quận 1',
  String? avatarUrl,
  String? coverUrl,
  ProviderType providerType = ProviderType.individual,
  int approvedAwards = 0,
  String? studioDistrict,
  bool acceptingOrders = true,
  bool hiddenFromDiscovery = false,
  bool deletionPending = false,
  String? studioId,
  int memberCount = 0,
}) => PhotographerSummary(
  id: id,
  displayName: name,
  avatarUrl: avatarUrl ?? 'https://img.test/avatar-$id.jpg',
  coverUrl: coverUrl,
  verified: verified,
  businessVerified: businessVerified,
  acceptingOrders: acceptingOrders,
  hiddenFromDiscovery: hiddenFromDiscovery,
  deletionPending: deletionPending,
  specialtyIds: specialties,
  styleIds: styles,
  areaLabel: areaLabel,
  lat: lat,
  lng: lng,
  reviewCount: tomatoCount + brickCount,
  tomatoCount: tomatoCount,
  brickCount: brickCount,
  tomatoPct: tomatoCount + brickCount == 0
      ? 0
      : (100 * tomatoCount / (tomatoCount + brickCount)).round(),
  // Like the server with every verdict at full intensity, unless a test
  // pins the score.
  score:
      score ??
      (tomatoCount + brickCount == 0
          ? 0
          : ((tomatoCount - brickCount) / (tomatoCount + brickCount) * 1000)
                    .round() /
                1000),
  completedCount: completed,
  responseMinutes: responseMinutes,
  startingPriceVnd: startingPrice,
  nextFreeDate: nextFreeDate,
  createdAt: fixtureNow.subtract(createdAgo),
  providerType: providerType,
  approvedAwardCount: approvedAwards,
  studioDistrict: studioDistrict,
  studioId: studioId,
  memberCount: memberCount,
);

ServiceSummary fixtureService(
  String id, {
  String photographerId = 'p1',
  String name = 'Chân dung 2 giờ',
  int price = 1500000,
  String? specialtyId = 'portrait',
  int durationMinutes = 120,
  bool active = true,
}) => ServiceSummary(
  id: id,
  photographerId: photographerId,
  name: name,
  specialtyId: specialtyId,
  priceVnd: price,
  durationMinutes: durationMinutes,
  photoCount: 40,
  editedCount: 40,
  deliveryDays: 5,
  active: active,
);

AlbumSummary fixtureAlbum(
  String id, {
  String photographerId = 'p1',
  String title = 'Album',
  String description = '',
  int position = 1,
  int postCount = 1,
  int mediaCount = 1,
  bool visible = true,
  String? coverPostId,
  int? coverImageIndex,
  String? coverUrl,
}) => AlbumSummary(
  id: id,
  photographerId: photographerId,
  title: title,
  description: description,
  position: position,
  postCount: postCount,
  mediaCount: mediaCount,
  visible: visible,
  coverPostId: coverPostId,
  coverImageIndex: coverImageIndex,
  coverUrl: coverUrl,
);

Award fixtureAward(
  String id, {
  String photographerId = 'p1',
  String competition = 'Sony World Photography Awards',
  int year = 2025,
  String? category,
  AwardResult result = AwardResult.gold,
  String? workPostId,
  AwardStatus status = AwardStatus.approved,
  String? reviewNote,
  DateTime? createdAt,
}) => Award(
  id: id,
  photographerId: photographerId,
  competition: competition,
  year: year,
  category: category,
  result: result,
  workPostId: workPostId,
  status: status,
  reviewNote: reviewNote,
  createdAt: createdAt ?? fixtureNow,
);
