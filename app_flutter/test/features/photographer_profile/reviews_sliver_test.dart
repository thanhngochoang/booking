import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_providers.dart';
import 'package:photobooking/data/review/review_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/photographer_profile/widgets/profile_sections.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_review_repository.dart';

class _DelayReviewRepository implements ReviewRepository {
  _DelayReviewRepository(this.completer);
  final Completer<ReviewPage> completer;

  @override
  Future<ReviewPage> forPhotographer(
    String photographerId, {
    Object? after,
    int limit = 10,
  }) =>
      completer.future;

  @override
  Stream<Review?> watchReview(String bookingId) => const Stream.empty();

  @override
  Future<String?> submit({
    required String bookingId,
    required int rating,
    required String text,
    String? postId,
    List<ReviewPhoto> photos = const [],
  }) async =>
      null;
}

class _PagingReviewRepository implements ReviewRepository {
  _PagingReviewRepository({
    required this.firstPage,
    required this.secondPage,
    this.secondPageCompleter,
  });

  final List<Review> firstPage;
  final List<Review> secondPage;
  Completer<void>? secondPageCompleter;
  bool secondPageRequested = false;

  @override
  Future<ReviewPage> forPhotographer(
    String photographerId, {
    Object? after,
    int limit = 10,
  }) async {
    if (after == null) {
      return ReviewPage(
        items: firstPage,
        cursor: 'cursor-1',
        hasMore: true,
      );
    }
    secondPageRequested = true;
    if (secondPageCompleter != null) {
      await secondPageCompleter!.future;
    }
    return ReviewPage(
      items: secondPage,
      cursor: null,
      hasMore: false,
    );
  }

  @override
  Stream<Review?> watchReview(String bookingId) => const Stream.empty();

  @override
  Future<String?> submit({
    required String bookingId,
    required int rating,
    required String text,
    String? postId,
    List<ReviewPhoto> photos = const [],
  }) async =>
      null;
}

class _FlakyPagingRepository extends _PagingReviewRepository {
  _FlakyPagingRepository({required super.firstPage, required super.secondPage});
  int secondPageCalls = 0;
  bool failSecond = true;

  @override
  Future<ReviewPage> forPhotographer(
    String photographerId, {
    Object? after,
    int limit = 10,
  }) async {
    if (after != null) {
      secondPageCalls++;
      if (failSecond) throw Exception('boom');
    }
    return super.forPhotographer(photographerId, after: after, limit: limit);
  }
}

void main() {
  group('ReviewsSliver', () {
    late FakeReviewRepository fakeReviews;
    late FakeUserRepository fakeUsers;
    late FakePostRepository fakePosts;
    late FakePublicProfileRepository fakeProfiles;

    setUp(() {
      fakeReviews = FakeReviewRepository();
      fakeUsers = FakeUserRepository();
      fakePosts = FakePostRepository();
      fakeProfiles = FakePublicProfileRepository([
        const PhotographerProfile(
          summary: PhotographerSummary(
            id: 'p1',
            displayName: 'Minh Trí',
            ratingAvg: 4.8,
            reviewCount: 2,
          ),
        ),
      ]);
    });

    Widget buildApp({
      required Widget sliver,
      List<Override> overrides = const [],
      GoRouter? router,
      double textScale = 1.0,
      Size size = const Size(390, 844),
    }) {
      final child = MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: router != null
            ? MaterialApp.router(
                routerConfig: router,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              )
            : MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: CustomScrollView(
                    slivers: [sliver],
                  ),
                ),
              ),
      );

      final overrideOrigins =
          overrides.map((o) => (o as dynamic).origin).toSet();

      return ProviderScope(
        overrides: [
          if (!overrideOrigins.contains(reviewRepositoryProvider))
            reviewRepositoryProvider.overrideWithValue(fakeReviews),
          if (!overrideOrigins.contains(userRepositoryProvider))
            userRepositoryProvider.overrideWithValue(fakeUsers),
          if (!overrideOrigins.contains(postRepositoryProvider))
            postRepositoryProvider.overrideWithValue(fakePosts),
          if (!overrideOrigins.contains(publicProfileRepositoryProvider))
            publicProfileRepositoryProvider.overrideWithValue(fakeProfiles),
          ...overrides,
        ],
        child: child,
      );
    }

    testWidgets('first load shows ReviewTile.skeleton three times', (
      tester,
    ) async {
      final completer = Completer<ReviewPage>();
      final delayRepo = _DelayReviewRepository(completer);

      await tester.pumpWidget(
        buildApp(
          sliver: const ReviewsSliver(photographerId: 'p1'),
          overrides: [
            reviewRepositoryProvider.overrideWithValue(delayRepo),
          ],
        ),
      );

      // Wait 200ms to clear anti-flash threshold in AsyncView
      await tester.pump(const Duration(milliseconds: 200));

      final skeletonFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_ReviewTileSkeleton',
      );
      expect(skeletonFinder, findsNWidgets(3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'ReviewTile.skeleton has the same size as a ReviewTile with a 4-line text at 390 and 320 dp',
      (tester) async {
        final review = Review(
          bookingId: 'b1',
          customerId: 'c1',
          photographerId: 'p1',
          serviceId: 's1',
          rating: 5,
          text: 'Line 1\nLine 2\nLine 3\nLine 4',
          createdAt: DateTime(2026, 10, 2),
        );

        for (final width in [390.0, 320.0]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildDarkTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  width: width,
                  child: ReviewTile(
                    review: review,
                    name: 'Nguyễn Văn A',
                    thumbs: const [],
                  ),
                ),
              ),
            ),
          );

          final realSize = tester.getSize(find.byType(ReviewTile));

          await tester.pumpWidget(
            MaterialApp(
              theme: buildDarkTheme(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  width: width,
                  child: AppSkeletonScope(
                    child: ReviewTile.skeleton(),
                  ),
                ),
              ),
            ),
          );

          final skeletonFinder = find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_ReviewTileSkeleton',
          );
          final skeletonSize = tester.getSize(skeletonFinder);

          expect(skeletonSize.width, realSize.width);
          expect(skeletonSize.height, realSize.height);
        }
      },
    );

    testWidgets('loading more shows the inline SignatureLoader', (
      tester,
    ) async {
      final reviews1 = List.generate(
        10,
        (i) => Review(
          bookingId: 'b$i',
          customerId: 'c$i',
          photographerId: 'p1',
          serviceId: 's1',
          rating: 5,
          text: 'Đánh giá số $i rất tuyệt vời!',
          createdAt: DateTime(2026, 10, 1, 10, i),
        ),
      );

      final secondCompleter = Completer<void>();
      final pagingRepo = _PagingReviewRepository(
        firstPage: reviews1,
        secondPage: [
          Review(
            bookingId: 'b10',
            customerId: 'c10',
            photographerId: 'p1',
            serviceId: 's1',
            rating: 4,
            text: 'Đánh giá trang 2',
            createdAt: DateTime(2026, 10, 1, 9),
          ),
        ],
        secondPageCompleter: secondCompleter,
      );

      await tester.pumpWidget(
        buildApp(
          sliver: const ReviewsSliver(photographerId: 'p1'),
          overrides: [
            reviewRepositoryProvider.overrideWithValue(pagingRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Initial page is loaded, 10 items present
      expect(find.text('Đánh giá số 0 rất tuyệt vời!'), findsOneWidget);

      // Trigger load more by scrolling or direct call
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();

      // SignatureLoader with LoaderSize.inline is shown
      final loaderFinder = find.byWidgetPredicate(
        (w) => w is SignatureLoader && w.size == LoaderSize.inline,
      );
      expect(loaderFinder, findsOneWidget);

      // Complete the second page
      secondCompleter.complete();
      await tester.pumpAndSettle();

      expect(find.text('Đánh giá trang 2'), findsOneWidget);
      expect(find.byType(SignatureLoader), findsNothing);
    });

    testWidgets('shows the newest reviews with name, stars, date and text', (
      tester,
    ) async {
      await fakeUsers.ensureProfile(
        const AuthUser(
          uid: 'c1',
          displayName: 'Thanh Ngô',
        ),
      );

      fakeReviews.seedReview(
        Review(
          bookingId: 'b1',
          customerId: 'c1',
          photographerId: 'p1',
          serviceId: 's1',
          rating: 5,
          text: 'Buổi chụp diễn ra hoàn hảo!',
          createdAt: DateTime(2026, 10, 2),
        ),
      );

      await tester.pumpWidget(
        buildApp(sliver: const ReviewsSliver(photographerId: 'p1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('4.8 · 2 đánh giá'), findsOneWidget);
      expect(find.text('Thanh Ngô'), findsOneWidget);
      expect(find.text('02/10/2026'), findsOneWidget);
      expect(find.text('Buổi chụp diễn ra hoàn hảo!'), findsOneWidget);
    });

    testWidgets('Xem thêm expands a long review', (tester) async {
      final longReview = Review(
        bookingId: 'b1',
        customerId: 'c1',
        photographerId: 'p1',
        serviceId: 's1',
        rating: 5,
        text: 'Dòng 1: Quá tuyệt vời\n'
            'Dòng 2: Rất hài lòng\n'
            'Dòng 3: Thợ chụp có tâm\n'
            'Dòng 4: Giá cả hợp lý\n'
            'Dòng 5: Sẽ quay lại ủng hộ lần sau!',
        createdAt: DateTime(2026, 10, 2),
      );

      fakeReviews.seedReview(longReview);

      await tester.pumpWidget(
        buildApp(sliver: const ReviewsSliver(photographerId: 'p1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xem thêm'), findsOneWidget);

      await tester.tap(find.text('Xem thêm'));
      await tester.pumpAndSettle();

      expect(find.text('Xem thêm'), findsNothing);
      expect(find.text(longReview.text), findsOneWidget);
    });

    testWidgets('a failing next page shows retry instead of auto-retrying', (
      tester,
    ) async {
      final repo = _FlakyPagingRepository(
        firstPage: [
          for (var i = 0; i < 10; i++)
            Review(
              bookingId: 'b$i',
              customerId: 'c$i',
              photographerId: 'p1',
              serviceId: 's1',
              rating: 5,
              text: 'Đánh giá $i',
              createdAt: DateTime(2026, 10, 1, 10, i),
            ),
        ],
        secondPage: [
          Review(
            bookingId: 'b10',
            customerId: 'c10',
            photographerId: 'p1',
            serviceId: 's1',
            rating: 5,
            text: 'Trang hai',
            createdAt: DateTime(2026, 10, 1, 9),
          ),
        ],
      );
      await tester.pumpWidget(
        buildApp(
          sliver: const ReviewsSliver(photographerId: 'p1'),
          overrides: [reviewRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(repo.secondPageCalls, 1);
      expect(find.text('Thử lại'), findsOneWidget);

      repo.failSecond = false;
      await tester.ensureVisible(find.text('Thử lại'));
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsNothing);
      expect(repo.secondPageCalls, 2);
      expect(find.text('Trang hai'), findsOneWidget);
    });

    testWidgets('a review that overflows only at 1.3x text shows Xem thêm', (
      tester,
    ) async {
      fakeReviews.seedReview(
        Review(
          bookingId: 'b1',
          customerId: 'c1',
          photographerId: 'p1',
          serviceId: 's1',
          rating: 5,
          text: List.filled(40, 'chụp').join(' '),
          createdAt: DateTime(2026, 10, 2),
        ),
      );
      await tester.pumpWidget(
        buildApp(sliver: const ReviewsSliver(photographerId: 'p1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Xem thêm'), findsNothing);

      await tester.pumpWidget(
        buildApp(
          sliver: const ReviewsSliver(photographerId: 'p1'),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Xem thêm'), findsOneWidget);
    });

    testWidgets('an unknown customer shows the localized fallback name', (
      tester,
    ) async {
      fakeReviews.seedReview(
        Review(
          bookingId: 'b1',
          customerId: 'ghost',
          photographerId: 'p1',
          serviceId: 's1',
          rating: 5,
          text: 'Tốt',
          createdAt: DateTime(2026, 10, 2),
        ),
      );
      await tester.pumpWidget(
        buildApp(sliver: const ReviewsSliver(photographerId: 'p1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Khách hàng'), findsOneWidget);
    });

    testWidgets('photo thumbnails open the real-shoot post', (tester) async {
      fakePosts.add(
        PostSummary(
          id: 'post_123',
          kind: PostKind.realShoot,
          authorId: 'c1',
          photographerId: 'p1',
          serviceId: 's1',
          images: const [
            PostImage(url: 'https://example.com/p1.jpg'),
            PostImage(url: 'https://example.com/p2.jpg'),
          ],
          createdAt: DateTime(2026, 10, 2),
        ),
      );

      fakeReviews.seedReview(
        Review(
          bookingId: 'b1',
          customerId: 'c1',
          photographerId: 'p1',
          serviceId: 's1',
          rating: 5,
          text: 'Ảnh chia sẻ thật tuyệt vời',
          photoPostId: 'post_123',
          createdAt: DateTime(2026, 10, 2),
        ),
      );

      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/u/p1',
        routes: [
          GoRoute(
            path: '/u/:uid',
            builder: (_, _) => const Scaffold(
              body: CustomScrollView(
                slivers: [
                  ReviewsSliver(photographerId: 'p1'),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/p/:id',
            builder: (_, s) {
              pushedRoute = s.uri.toString();
              return Text('Post ${s.pathParameters['id']}');
            },
          ),
        ],
      );

      await tester.pumpWidget(
        buildApp(
          sliver: const ReviewsSliver(photographerId: 'p1'),
          router: router,
        ),
      );
      await tester.pumpAndSettle();

      final thumb = find.byKey(const Key('review-thumb-https://example.com/p1.jpg'));
      expect(thumb, findsOneWidget);

      await tester.tap(thumb);
      await tester.pumpAndSettle();

      expect(pushedRoute, '/p/post_123');
      expect(find.text('Post post_123'), findsOneWidget);
    });

    testWidgets('scrolling to the end loads the next page', (tester) async {
      final reviews1 = List.generate(
        10,
        (i) => Review(
          bookingId: 'b$i',
          customerId: 'c$i',
          photographerId: 'p1',
          serviceId: 's1',
          rating: 5,
          text: 'Đánh giá $i',
          createdAt: DateTime(2026, 10, 1, 10, i),
        ),
      );
      final reviews2 = [
        Review(
          bookingId: 'b10',
          customerId: 'c10',
          photographerId: 'p1',
          serviceId: 's1',
          rating: 5,
          text: 'Đánh giá trang tiếp theo 10',
          createdAt: DateTime(2026, 10, 1, 9),
        ),
      ];

      final pagingRepo = _PagingReviewRepository(
        firstPage: reviews1,
        secondPage: reviews2,
      );

      await tester.pumpWidget(
        buildApp(
          sliver: const ReviewsSliver(photographerId: 'p1'),
          overrides: [
            reviewRepositoryProvider.overrideWithValue(pagingRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đánh giá 0'), findsOneWidget);
      expect(find.text('Đánh giá trang tiếp theo 10'), findsNothing);

      // Scroll to the end
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(pagingRepo.secondPageRequested, isTrue);
      expect(find.text('Đánh giá trang tiếp theo 10'), findsOneWidget);
    });

    testWidgets('no reviews keeps the empty state', (tester) async {
      await tester.pumpWidget(
        buildApp(sliver: const ReviewsSliver(photographerId: 'p1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chưa có đánh giá'), findsOneWidget);
      expect(
        find.text('Đánh giá hiện ở đây sau những buổi chụp đầu tiên.'),
        findsOneWidget,
      );
      expect(find.byType(ReviewTile), findsNothing);
    });

    testWidgets('320 dp, 1.3×: no overflow', (tester) async {
      fakeReviews.seedReview(
        Review(
          bookingId: 'b1',
          customerId: 'c1',
          photographerId: 'p1',
          serviceId: 's1',
          rating: 5,
          text: 'Đánh giá rất tốt trên màn hình nhỏ và cỡ chữ to',
          createdAt: DateTime(2026, 10, 2),
        ),
      );

      await tester.pumpWidget(
        buildApp(
          sliver: const ReviewsSliver(photographerId: 'p1'),
          size: const Size(320, 600),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
