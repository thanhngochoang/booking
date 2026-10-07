import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/badges/badge.dart';
import 'package:photobooking/features/badges/badges_view.dart';

import '../../support/badges_world.dart';

final _day = DateTime.utc(2026, 9, 1);

BadgesView _build({
  List<String> held = const [],
  Map<String, BadgeProgressEntry>? progress,
  bool own = true,
  bool photographer = true,
  DateTime? seenAt,
  Map<String, DateTime> at = const {},
}) => buildBadgesView(
  catalog: badgeCatalogue(),
  earned: [for (final id in held) earnedOn(id, at[id] ?? _day)],
  progress: progress,
  own: own,
  photographer: photographer,
  seenAt: seenAt,
);

List<String> _names(List<BadgeTileVm> l) => [for (final t in l) t.badge.name];

void main() {
  test('own photographer sees 12 minus hidden new_member', () {
    final v = _build(progress: const {});
    expect(v.shown, 11);
    expect(v.fromReviews.length + v.fromSystem.length, 11);
    expect(_names(v.fromSystem), isNot(contains('Thành viên mới')));
    final held = _build(held: ['new_member'], progress: const {});
    expect(held.shown, 12);
    expect(held.earned, 1);
  });

  test('customers see customer and both badges only', () {
    final v = _build(
      photographer: false,
      held: ['new_member'],
      progress: const {},
    );
    expect(_names(v.fromReviews), ['Nhận xét chi tiết']);
    expect(_names(v.fromSystem), [
      'Thành viên mới',
      'Khách thân thiết',
      'Người chia sẻ',
    ]);
  });

  test('others see earned only, no progress, no nearest', () {
    final v = _build(
      own: false,
      held: ['top_rated', 'fast_reply'],
      progress: const {'top_rated': BadgeProgressEntry(current: 1, target: 2)},
    );
    expect(_names(v.fromReviews), ['Được đánh giá cao']);
    expect(_names(v.fromSystem), ['Phản hồi nhanh']);
    expect(
      [
        ...v.fromReviews,
        ...v.fromSystem,
      ].every((t) => t.progress == null && !t.isNew && t.badge.earned),
      isTrue,
    );
    expect(v.nearest, isNull);
  });

  test('earned first by order within each section', () {
    final v = _build(held: ['shoots_100', 'fast_reply'], progress: const {});
    expect(_names(v.fromSystem).take(3), [
      'Phản hồi nhanh',
      '100+ buổi chụp',
      'Hồ sơ đầy đủ',
    ]);
    expect(v.fromSystem.take(2).every((t) => t.badge.earned), isTrue);
    expect(v.fromSystem.skip(2).every((t) => !t.badge.earned), isTrue);
  });

  test('isNew only for awards after seenAt and only on the own view', () {
    final seen = DateTime.utc(2026, 9, 10);
    final at = {
      'top_rated': DateTime.utc(2026, 9, 1),
      'fast_reply': DateTime.utc(2026, 9, 11),
    };
    final own = _build(
      held: ['top_rated', 'fast_reply'],
      progress: const {},
      seenAt: seen,
      at: at,
    );
    bool isNew(BadgesView v, String name) => [
      ...v.fromReviews,
      ...v.fromSystem,
    ].firstWhere((t) => t.badge.name == name).isNew;
    expect(isNew(own, 'Được đánh giá cao'), isFalse);
    expect(isNew(own, 'Phản hồi nhanh'), isTrue);
    final other = _build(
      own: false,
      held: ['top_rated', 'fast_reply'],
      seenAt: seen,
      at: at,
    );
    expect(isNew(other, 'Phản hồi nhanh'), isFalse);
    // First visit: everything earned is new.
    final first = _build(held: ['top_rated'], progress: const {});
    expect(isNew(first, 'Được đánh giá cao'), isTrue);
  });

  test('nearest picks the highest current/target when nothing is earned', () {
    final v = _build(
      progress: const {
        'top_rated': BadgeProgressEntry(current: 12, target: 20),
        'complete_profile': BadgeProgressEntry(current: 5, target: 6),
        'event_host': BadgeProgressEntry(current: 0, target: 1),
      },
    );
    expect(v.nearest?.badge.name, 'Hồ sơ đầy đủ');
    expect(v.nearest?.progress?.current, 5);
    final withEarned = _build(
      held: ['fast_reply'],
      progress: const {
        'complete_profile': BadgeProgressEntry(current: 5, target: 6),
      },
    );
    expect(withEarned.nearest, isNull);
  });

  test('earned tile shows the snapshot text, locked the description', () {
    final v = buildBadgesView(
      catalog: badgeCatalogue(),
      earned: [earnedOn('top_rated', _day, '4,9 sao từ 58 đánh giá')],
      progress: const {},
      own: true,
      photographer: true,
    );
    expect(v.fromReviews.first.badge.condition, '4,9 sao từ 58 đánh giá');
    expect(
      v.fromReviews.first.description,
      'Từ 4,8 sao với ít nhất 20 đánh giá',
    );
    expect(v.fromReviews.last.badge.condition, 'Viết 5 nhận xét dài');
  });
}
