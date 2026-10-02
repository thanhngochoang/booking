// test/features/discovery/photographer_meta_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/features/discovery/photographer_meta.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import '../../support/content_fixtures.dart';

void main() {
  final l = AppLocalizationsVi();

  test('area, rating with count and sessions, joined by dots', () {
    expect(
      areaRatingMeta(fixturePhotographer('p1', areaLabel: 'Quận 3'), l),
      'Quận 3 · ★ 4,9 (58) · 112 buổi',
    );
  });

  test('missing parts are left out', () {
    const bare = PhotographerSummary(id: 'x', displayName: 'Mới');
    expect(areaRatingMeta(bare, l), '');
    expect(
      areaRatingMeta(
        fixturePhotographer('p', areaLabel: null, reviews: 0, completed: 0),
        l,
      ),
      '',
    );
    expect(
      areaRatingMeta(
        fixturePhotographer('p', areaLabel: 'Quận 1', reviews: 0, completed: 5),
        l,
      ),
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
