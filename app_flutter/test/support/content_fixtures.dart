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
  createdAt: fixtureNow.subtract(age),
);

PhotographerSummary fixturePhotographer(
  String id, {
  String name = 'Minh Trí',
  bool verified = false,
  List<String> specialties = const ['portrait'],
  List<String> styles = const [],
  double rating = 4.9,
  int reviews = 58,
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
}) => PhotographerSummary(
  id: id,
  displayName: name,
  avatarUrl: avatarUrl ?? 'https://img.test/avatar-$id.jpg',
  coverUrl: coverUrl,
  verified: verified,
  specialtyIds: specialties,
  styleIds: styles,
  areaLabel: areaLabel,
  lat: lat,
  lng: lng,
  ratingAvg: rating,
  reviewCount: reviews,
  completedCount: completed,
  responseMinutes: responseMinutes,
  startingPriceVnd: startingPrice,
  nextFreeDate: nextFreeDate,
  createdAt: fixtureNow.subtract(createdAgo),
  providerType: providerType,
  approvedAwardCount: approvedAwards,
  studioDistrict: studioDistrict,
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
