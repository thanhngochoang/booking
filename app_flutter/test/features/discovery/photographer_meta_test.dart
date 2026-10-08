// test/features/discovery/photographer_meta_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/features/discovery/photographer_meta.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import '../../support/content_fixtures.dart';

void main() {
  final l = AppLocalizationsVi();

  String meta(PhotographerSummary p) => metaPartsText(areaRatingMeta(p, l));

  test('area, % cà chua with count and sessions, joined by dots', () {
    final parts = areaRatingMeta(
      fixturePhotographer(
        'p1',
        areaLabel: 'Quận 3',
        tomatoCount: 56,
        brickCount: 2,
      ),
      l,
    );
    expect(metaPartsText(parts), 'Quận 3 · 97% (58) · 112 buổi');
    expect(parts[1], isA<MetaPart>());
  });

  test('under 5 reviews the review part reads "Mới · n đánh giá"', () {
    expect(
      meta(fixturePhotographer('p', areaLabel: 'Quận 3', tomatoCount: 3)),
      'Quận 3 · Mới · 3 đánh giá · 112 buổi',
    );
    expect(
      meta(fixturePhotographer('p', areaLabel: 'Quận 3', tomatoCount: 4)),
      'Quận 3 · Mới · 4 đánh giá · 112 buổi',
    );
    expect(
      meta(fixturePhotographer('p', areaLabel: 'Quận 3', tomatoCount: 5)),
      'Quận 3 · 100% (5) · 112 buổi',
    );
  });

  test('missing parts are left out', () {
    const bare = PhotographerSummary(id: 'x', displayName: 'Mới');
    expect(meta(bare), '');
    expect(meta(fixturePhotographer('p', areaLabel: null, completed: 0)), '');
    expect(
      meta(fixturePhotographer('p', areaLabel: 'Quận 1', completed: 5)),
      'Quận 1 · 5 buổi',
    );
  });

  group('freeThisWeekLabel (today is Thursday 1 Oct 2026, Vietnam time)', () {
    String? label(String? day) => freeThisWeekLabel(
      fixturePhotographer('p', nextFreeDate: day),
      fixtureNow,
      l,
    );

    test('free within the next 7 days names the weekday', () {
      expect(label('2026-10-03'), 'Rảnh T7 này');
      expect(label('2026-10-04'), 'Rảnh CN này');
      expect(label('2026-10-01'), 'Rảnh T5 này', reason: 'today counts');
    });

    test('later, past or unknown days give no pill', () {
      expect(label('2026-10-08'), isNull);
      expect(label('2026-09-30'), isNull);
      expect(label(null), isNull);
      expect(label('not-a-day'), isNull);
    });
  });
}
