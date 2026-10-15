// test/features/explore/search/explore_search_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/discovery/explore_catalog.dart';
import 'package:photobooking/data/discovery/explore_catalog_providers.dart';
import 'package:photobooking/data/discovery/fake_explore_catalog_repository.dart';
import 'package:photobooking/features/explore/search/explore_search_screen.dart';

import '../../../support/screen_host.dart';

void main() {
  group('ExploreSearchScreen', () {
    late FakePhotographerRepository photographers;
    late FakeExploreCatalogRepository catalog;

    setUp(() {
      photographers = FakePhotographerRepository([
        const PhotographerSummary(
          id: 'p1',
          displayName: 'Chánh Tâm',
          areaLabel: 'Quận 7',
          reviewCount: 3,
          verified: true,
          acceptingOrders: true,
        ),
        const PhotographerSummary(
          id: 'p2',
          displayName: 'Ngọc Châu',
          areaLabel: 'Quận 3',
          reviewCount: 24,
          tomatoCount: 22,
          tomatoPct: 92,
          acceptingOrders: true,
        ),
      ]);
      catalog = FakeExploreCatalogRepository(
        const ExploreCatalog({
          'portrait': ExploreCategoryStat(serviceCount: 128),
        }),
      );
    });

    Widget createScreen({GoRouter? router, double textScale = 1.0}) {
      final overrides = [
        photographerRepositoryProvider.overrideWithValue(photographers),
        exploreCatalogRepositoryProvider.overrideWithValue(catalog),
      ];

      if (router != null) {
        return screenRouterApp(
          router: router,
          overrides: overrides,
          textScale: textScale,
        );
      }

      return screenApp(
        home: const ExploreSearchScreen(),
        overrides: overrides,
        textScale: textScale,
      );
    }

    testWidgets('ScreenCode S02.07 is present', (tester) async {
      await tester.pumpWidget(createScreen());
      expect(
        find.byWidgetPredicate(
          (w) => w is ScreenCode && w.code == ScreenCodes.exploreSearch,
        ),
        findsOneWidget,
      );
    });

    testWidgets('idle shows "Gõ tên dịch vụ, khu vực hoặc tên thợ ảnh."', (
      tester,
    ) async {
      await tester.pumpWidget(createScreen());
      expect(
        find.text('Gõ tên dịch vụ, khu vực hoặc tên thợ ảnh.'),
        findsOneWidget,
      );
    });

    testWidgets('typing "chan" shows Dịch vụ and Thợ ảnh sections', (
      tester,
    ) async {
      await tester.pumpWidget(createScreen());
      await tester.enterText(find.byType(TextField), 'chan');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Dịch vụ'), findsOneWidget);
      expect(find.text('Chân dung'), findsOneWidget);
      expect(find.text('128 gói'), findsOneWidget);

      expect(find.text('Thợ ảnh'), findsOneWidget);
      expect(
        find.textContaining('Chánh Tâm', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a service row opens /action?specialty=portrait', (tester) async {
      String? routedTo;
      final router = GoRouter(
        initialLocation: '/explore/search',
        routes: [
          GoRoute(
            path: '/explore/search',
            builder: (_, _) => const ExploreSearchScreen(),
          ),
          GoRoute(
            path: '/action',
            builder: (_, state) {
              routedTo = state.uri.toString();
              return const Scaffold(body: Text('Action Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(createScreen(router: router));
      await tester.enterText(find.byType(TextField), 'chan dung');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chân dung'));
      await tester.pumpAndSettle();

      expect(routedTo, '/action?specialty=portrait');
    });

    testWidgets('an area row opens /action?area=...', (tester) async {
      String? routedTo;
      final router = GoRouter(
        initialLocation: '/explore/search',
        routes: [
          GoRoute(
            path: '/explore/search',
            builder: (_, _) => const ExploreSearchScreen(),
          ),
          GoRoute(
            path: '/action',
            builder: (_, state) {
              routedTo = state.uri.toString();
              return const Scaffold(body: Text('Action Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(createScreen(router: router));
      await tester.enterText(find.byType(TextField), 'quan 1');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Địa điểm'), findsOneWidget);
      await tester.tap(find.text('Quận 1, TP.HCM'));
      await tester.pumpAndSettle();

      expect(routedTo, '/action?area=hcm-q1');
    });

    testWidgets('a photographer row opens /u/:uid', (tester) async {
      String? routedTo;
      final router = GoRouter(
        initialLocation: '/explore/search',
        routes: [
          GoRoute(
            path: '/explore/search',
            builder: (_, _) => const ExploreSearchScreen(),
          ),
          GoRoute(
            path: '/u/:uid',
            builder: (_, state) {
              routedTo = state.uri.toString();
              return const Scaffold(body: Text('Profile Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(createScreen(router: router));
      await tester.enterText(find.byType(TextField), 'chan');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Chánh Tâm', findRichText: true));
      await tester.pumpAndSettle();

      expect(routedTo, '/u/p1');
    });

    testWidgets(
      'no results shows empty state and "Xem tất cả thợ ảnh" opens /action',
      (tester) async {
        String? routedTo;
        final router = GoRouter(
          initialLocation: '/explore/search',
          routes: [
            GoRoute(
              path: '/explore/search',
              builder: (_, _) => const ExploreSearchScreen(),
            ),
            GoRoute(
              path: '/action',
              builder: (_, state) {
                routedTo = state.uri.toString();
                return const Scaffold(body: Text('Action Screen'));
              },
            ),
          ],
        );

        await tester.pumpWidget(createScreen(router: router));
        await tester.enterText(find.byType(TextField), 'xyz123');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('Không tìm thấy “xyz123”'), findsOneWidget);
        expect(find.text('Xem tất cả thợ ảnh'), findsOneWidget);

        await tester.tap(find.text('Xem tất cả thợ ảnh'));
        await tester.pumpAndSettle();

        expect(routedTo, '/action');
      },
    );

    testWidgets('clear button empties the field and shows idle state', (
      tester,
    ) async {
      await tester.pumpWidget(createScreen());
      await tester.enterText(find.byType(TextField), 'chan');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Chân dung'), findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.close));
      await tester.pumpAndSettle();

      expect(find.text('Gõ tên dịch vụ, khu vực hoặc tên thợ ảnh.'), findsOneWidget);
      expect(find.text('Chân dung'), findsNothing);
    });

    testWidgets('debounce: three fast keystrokes search once', (tester) async {
      await tester.pumpWidget(createScreen());
      await tester.enterText(find.byType(TextField), 'c');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'ch');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(find.byType(TextField), 'cha');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Chánh Tâm', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('fits 320dp at 1.3x text', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createScreen(textScale: 1.3));
      await tester.enterText(find.byType(TextField), 'chan');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
