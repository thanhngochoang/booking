// test/features/explore/search/explore_search_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/discovery/explore_catalog.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/explore/search/explore_search.dart';

void main() {
  group('searchExplore', () {
    final specialties = [
      for (final s in kSpecialties) (id: s.id, label: s.labelVi),
    ];
    final styles = [
      for (final s in kStyles) (id: s.id, label: s.labelVi),
    ];
    final areas = builtInAreas;
    final photographers = [
      const PhotographerSummary(
        id: 'p1',
        displayName: 'Chánh Tâm',
        areaLabel: 'Quận 7',
        reviewCount: 3,
      ),
      const PhotographerSummary(
        id: 'p2',
        displayName: 'Ngọc Châu',
        areaLabel: 'Quận 3',
        reviewCount: 24,
      ),
      const PhotographerSummary(
        id: 'p3',
        displayName: 'Anh Tuấn',
        areaLabel: 'Quận 1',
      ),
    ];
    final catalog = const ExploreCatalog({
      'portrait': ExploreCategoryStat(serviceCount: 128),
      'wedding': ExploreCategoryStat(serviceCount: 64),
    });

    test('an empty query has no hits', () {
      final res = searchExplore(
        '',
        specialties: specialties,
        styles: styles,
        areas: areas,
        photographers: photographers,
        catalog: catalog,
      );
      expect(res.isEmpty, isTrue);
      expect(res.services, isEmpty);
      expect(res.styles, isEmpty);
      expect(res.places, isEmpty);
      expect(res.photographers, isEmpty);
    });

    test('"chan dung" finds "Chân dung"', () {
      final res = searchExplore(
        'chan dung',
        specialties: specialties,
        styles: styles,
        areas: areas,
        photographers: photographers,
        catalog: catalog,
      );
      expect(res.services, isNotEmpty);
      expect(res.services.first.id, 'portrait');
      expect(res.services.first.label, 'Chân dung');
    });

    test('"quan 1" finds the area "Quận 1"', () {
      final res = searchExplore(
        'quan 1',
        specialties: specialties,
        styles: styles,
        areas: areas,
        photographers: photographers,
        catalog: catalog,
      );
      expect(res.places, isNotEmpty);
      expect(res.places.first.label, contains('Quận 1'));
    });

    test('a one-letter query does not search names', () {
      final res = searchExplore(
        'c',
        specialties: specialties,
        styles: styles,
        areas: areas,
        photographers: photographers,
        catalog: catalog,
      );
      expect(res.photographers, isEmpty);
    });

    test('names match anywhere but prefix matches come first', () {
      final res = searchExplore(
        'chan',
        specialties: specialties,
        styles: styles,
        areas: areas,
        photographers: photographers,
        catalog: catalog,
      );
      // 'Chánh Tâm' (starts with chan) vs 'Ngọc Châu' (contains chau/chan?)
      expect(res.photographers, isNotEmpty);
      expect(res.photographers.first.label, 'Chánh Tâm');
    });

    test('service hits carry the catalog count', () {
      final res = searchExplore(
        'chan dung',
        specialties: specialties,
        styles: styles,
        areas: areas,
        photographers: photographers,
        catalog: catalog,
      );
      expect(res.services.first.serviceCount, 128);
    });

    test('limits are 5/5/5/10', () {
      // Create large lists
      final manySpecialties = [
        for (var i = 0; i < 20; i++) (id: 's$i', label: 'Dịch vụ $i'),
      ];
      final manyStyles = [
        for (var i = 0; i < 20; i++) (id: 'st$i', label: 'Phong cách $i'),
      ];
      final manyAreas = [
        for (var i = 0; i < 20; i++)
          AreaOption(
            id: 'a$i',
            name: 'Khu vực $i',
            lat: 10.0,
            lng: 106.0,
          ),
      ];
      final manyPhotographers = [
        for (var i = 0; i < 20; i++)
          PhotographerSummary(id: 'p$i', displayName: 'Thợ $i'),
      ];

      final res = searchExplore(
        'c', // 1 char will search specialties, styles, areas (photographers requires >= 2 chars)
        specialties: manySpecialties,
        styles: manyStyles,
        areas: manyAreas,
        photographers: manyPhotographers,
        catalog: ExploreCatalog.empty,
      );
      expect(res.services.length, lessThanOrEqualTo(5));
      expect(res.styles.length, lessThanOrEqualTo(5));
      expect(res.places.length, lessThanOrEqualTo(5));

      final res2 = searchExplore(
        'tho',
        specialties: manySpecialties,
        styles: manyStyles,
        areas: manyAreas,
        photographers: manyPhotographers,
        catalog: ExploreCatalog.empty,
      );
      expect(res2.photographers.length, lessThanOrEqualTo(10));
    });
  });
}
