import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';

import '../../support/content_fixtures.dart';

void main() {
  test('a query has sensible defaults and no coordinates', () {
    const q = RecommendationQuery();
    expect(q.sort, RecommendationSort.best);
    expect(q.limit, 20);
    expect(q.excludeIds, isEmpty);
    expect(q.geohash6, isNull);
  });

  test('copyWith changes only what is given; equality is by value', () {
    final a = RecommendationQuery(
      specialtyId: 'portrait',
      date: DateTime.utc(2026, 10, 12),
      geohash6: 'w3gvk1',
      budgetMax: 2000000,
      excludeIds: const ['p1'],
    );
    final b = a.copyWith(limit: 5);
    expect(b.limit, 5);
    expect(b.specialtyId, 'portrait');
    expect(b.excludeIds, ['p1']);
    expect(a, a.copyWith());
    expect(a, isNot(b));
    expect(a.hashCode, a.copyWith().hashCode);
  });

  test('copyWith can clear the cursor to restart a search', () {
    final a = const RecommendationQuery().copyWith(cursor: '20');
    expect(a.cursor, '20');
    expect(a.copyWith(clearCursor: true).cursor, isNull);
  });

  test('markFallback flags a page and keeps everything else', () {
    final page = RecommendationPage(
      items: [
        RecommendedPhotographer(
          photographer: fixturePhotographer('p1'),
          rank: 1,
          score: 0.9,
        ),
      ],
      requestId: 'r1',
      algorithm: 'rules-v1',
      algorithmVersion: '1.0.0',
      nextCursor: '1',
    );
    expect(page.usedFallback, isFalse);
    final flagged = page.markFallback();
    expect(flagged.usedFallback, isTrue);
    expect(flagged.requestId, 'r1');
    expect(flagged.nextCursor, '1');
    expect(flagged.items, hasLength(1));
  });

  test('signal types match the API enum', () {
    expect(SignalType.values.map((t) => t.name), [
      'impression',
      'click',
      'inquiry',
      'booking',
    ]);
  });
}
