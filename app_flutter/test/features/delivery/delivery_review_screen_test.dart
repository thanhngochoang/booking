import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_providers.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/delivery/delivery_review_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_booking_repository.dart';
import '../../support/fake_delivery_repository.dart';

void main() {
  late FakeDeliveryRepository fakeDeliveryRepo;
  late FakeBookingRepository fakeBookingRepo;
  late FakeExternalLauncher fakeLauncher;
  late DateTime currentTime;

  final testSamples = List.generate(
    12,
    (i) => DeliverySampleRef(
      fileId: 'f$i',
      path: 'deliveries/b-rev/f$i.jpg',
      thumbPath: 'deliveries/b-rev/f${i}_t.jpg',
      width: 1600,
      height: 1200,
    ),
  );

  final deliveredRound = DeliveryRound(
    bookingId: 'b-rev',
    round: 1,
    samples: testSamples,
    photoCount: 50,
    linkHost: 'drive.google.com',
    submittedAt: DateTime.utc(2026, 10, 14, 10, 0),
    submittedBy: 'p1',
  );

  final testBooking = makeTestBooking(
    id: 'b-rev',
    status: BookingStatus.delivered,
    photographerId: 'p1',
    customerId: 'c1',
  ).copyWith(
    deliveryRound: 1,
    revisionsIncluded: 2,
    deliveredAt: DateTime.utc(2026, 10, 14, 10, 0),
  );

  final profile = const PhotographerProfile(
    summary: PhotographerSummary(
      id: 'p1',
      displayName: 'Minh Trí',
    ),
  );

  setUp(() {
    fakeDeliveryRepo = FakeDeliveryRepository();
    fakeBookingRepo = FakeBookingRepository();
    fakeLauncher = FakeExternalLauncher();
    currentTime = DateTime.utc(2026, 10, 14, 20, 0); // 10h after submission (left = 2 days 14 hours)
  });

  Widget buildApp(Widget child, {String currentUid = 'c1', GoRouter? router}) {
    return ProviderScope(
      overrides: [
        deliveryRepositoryProvider.overrideWithValue(fakeDeliveryRepo),
        bookingRepositoryProvider.overrideWithValue(fakeBookingRepo),
        bookingProvider('b-rev').overrideWith((ref) => fakeBookingRepo.watchBooking('b-rev')),
        deliveryRoundsProvider('b-rev').overrideWith((ref) => fakeDeliveryRepo.watchRounds('b-rev')),
        deliveryLinkProvider('b-rev').overrideWith((ref) => fakeDeliveryRepo.watchLink('b-rev')),
        photographerProfileProvider('p1').overrideWith((ref) => Future.value(profile)),
        externalLauncherProvider.overrideWithValue(fakeLauncher),
        authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: currentUid))),
        clockProvider.overrideWithValue(() => currentTime),
      ],
      child: router != null
          ? MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('vi'),
            )
          : MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('vi'),
              home: child,
            ),
    );
  }

  testWidgets('delivered: title, sender info, 6 tiles with "+6", masked link, 1/2 free rounds, auto-approve countdown', (tester) async {
    fakeBookingRepo.bookings['b-rev'] = testBooking;
    fakeDeliveryRepo.seedRound('b-rev', deliveredRound);
    fakeDeliveryRepo.seedLink('b-rev', const DeliveryLink(link: 'https://drive.google.com/real-secret', round: 1));

    await tester.pumpWidget(
      buildApp(const DeliveryReviewScreen(bookingId: 'b-rev')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bàn giao · vòng 1'), findsOneWidget);
    expect(find.text('Minh Trí gửi 12 ảnh mẫu · 14/10'), findsOneWidget);
    expect(find.text('+6'), findsOneWidget);
    expect(find.text('drive.google.com/••••••••'), findsOneWidget);
    expect(find.text('Còn 1/2 lượt sửa miễn phí'), findsOneWidget);
    expect(find.text('Tự đồng ý sau 2 ngày 14 giờ nếu bạn không phản hồi'), findsOneWidget);

    // Assert customer NEVER subscribes to the link before approved
    expect(fakeDeliveryRepo.watchLinkCalls, isEmpty);
  });

  testWidgets('"Đồng ý ảnh" opens confirm sheet and approve is called only after confirming', (tester) async {
    fakeBookingRepo.bookings['b-rev'] = testBooking;
    fakeDeliveryRepo.seedRound('b-rev', deliveredRound);

    await tester.pumpWidget(
      buildApp(const DeliveryReviewScreen(bookingId: 'b-rev')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Đồng ý ảnh'));
    await tester.pumpAndSettle();

    // Confirm sheet opened
    expect(find.text('Đồng ý ảnh?'), findsOneWidget);
    expect(find.text('Đồng ý thì link ảnh gốc mở ra; bạn có 48 giờ để kiểm tra.'), findsOneWidget);

    expect(fakeDeliveryRepo.approveCalls, isEmpty);

    // Confirm inside sheet
    final confirmButtons = find.widgetWithText(AppButton, 'Đồng ý ảnh');
    await tester.tap(confirmButtons.last);
    await tester.pumpAndSettle();

    expect(fakeDeliveryRepo.approveCalls, ['b-rev']);
  });

  testWidgets('no rounds left shows "Hết lượt sửa miễn phí (2/2)" and "Xin thêm 1 vòng"', (tester) async {
    final exhaustedBooking = testBooking.copyWith(deliveryRound: 2);
    final round2 = DeliveryRound(
      bookingId: 'b-rev',
      round: 2,
      samples: testSamples,
      photoCount: 50,
      linkHost: 'drive.google.com',
      submittedAt: DateTime.utc(2026, 10, 15, 10, 0),
      submittedBy: 'p1',
    );
    fakeBookingRepo.bookings['b-rev'] = exhaustedBooking;
    fakeDeliveryRepo.seedRound('b-rev', deliveredRound);
    fakeDeliveryRepo.seedRound('b-rev', round2);

    await tester.pumpWidget(
      buildApp(const DeliveryReviewScreen(bookingId: 'b-rev')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hết lượt sửa miễn phí (2/2)'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Xin thêm 1 vòng'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Yêu cầu chỉnh sửa'), findsNothing);
  });

  testWidgets('a pending extra round shows "Đã xin thêm 1 vòng · chờ Minh Trí trả lời" and hides outline', (tester) async {
    final pendingBooking = testBooking.copyWith(
      deliveryRound: 2,
      extraRound: ExtraRound(status: 'pending', at: DateTime.utc(2026, 10, 15)),
    );
    fakeBookingRepo.bookings['b-rev'] = pendingBooking;
    fakeDeliveryRepo.seedRound('b-rev', deliveredRound);

    await tester.pumpWidget(
      buildApp(const DeliveryReviewScreen(bookingId: 'b-rev')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đã xin thêm 1 vòng · chờ Minh Trí trả lời'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Xin thêm 1 vòng'), findsNothing);
    expect(find.widgetWithText(AppButton, 'Yêu cầu chỉnh sửa'), findsNothing);
  });

  testWidgets('approved: "Mở bộ ảnh gốc" launches link, check card shows "còn 47 giờ" with bar, "Báo vấn đề với ảnh gốc" opens S18.01 through /b/:id/dispute?from=delivery', (tester) async {
    final approvedTime = DateTime.utc(2026, 10, 15, 10, 0);
    final checkUntilTime = approvedTime.add(const Duration(hours: 48));
    currentTime = approvedTime.add(const Duration(hours: 1)); // 47 hours left

    final approvedBooking = testBooking.copyWith(
      status: BookingStatus.approved,
      approvedAt: approvedTime,
      checkUntil: checkUntilTime,
    );
    fakeBookingRepo.bookings['b-rev'] = approvedBooking;
    fakeDeliveryRepo.seedRound('b-rev', deliveredRound);
    fakeDeliveryRepo.seedLink('b-rev', const DeliveryLink(link: 'https://drive.google.com/real-photos', round: 1));

    final router = GoRouter(
      initialLocation: '/b/b-rev/delivery',
      routes: [
        GoRoute(
          path: '/b/:id/delivery',
          builder: (_, s) => DeliveryReviewScreen(bookingId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/b/:id/dispute',
          builder: (_, s) => Scaffold(body: Text('stub ${s.uri}')),
        ),
      ],
    );
    await tester.pumpWidget(buildApp(const SizedBox.shrink(), router: router));
    await tester.pumpAndSettle();

    expect(find.text('Bàn giao · đã đồng ý'), findsOneWidget);
    expect(find.text('https://drive.google.com/real-photos'), findsOneWidget);
    expect(find.text('còn 47 giờ'), findsOneWidget);

    // Open link
    final openButtonFinder = find.widgetWithText(AppButton, 'Mở bộ ảnh gốc');
    await tester.scrollUntilVisible(openButtonFinder, 200);
    await tester.tap(openButtonFinder);
    await tester.pumpAndSettle();
    expect(fakeLauncher.opened, [Uri.parse('https://drive.google.com/real-photos')]);

    // Report: S18.01 over S05.02 with the delivery reasons (Decision 13).
    final reportFinder = find.text('Báo vấn đề với ảnh gốc');
    await tester.scrollUntilVisible(reportFinder, 200);
    await tester.tap(reportFinder);
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/b/b-rev/dispute?from=delivery');
  });

  Future<void> pumpApproved(
    WidgetTester tester, {
    String? disputeId,
    EscrowStatus escrow = EscrowStatus.held,
  }) async {
    final approvedTime = DateTime.utc(2026, 10, 15, 10, 0);
    currentTime = approvedTime.add(const Duration(hours: 1));
    fakeBookingRepo.bookings['b-rev'] = testBooking.copyWith(
      status: BookingStatus.approved,
      approvedAt: approvedTime,
      checkUntil: approvedTime.add(const Duration(hours: 48)),
      disputeId: disputeId,
      escrowStatus: escrow,
    );
    fakeDeliveryRepo.seedRound('b-rev', deliveredRound);

    await tester.pumpWidget(
      buildApp(const DeliveryReviewScreen(bookingId: 'b-rev')),
    );
    await tester.pumpAndSettle();
    expect(find.text('còn 47 giờ'), findsOneWidget);
  }

  testWidgets('a booking with an open dispute has no report button on the check card', (tester) async {
    await pumpApproved(tester, disputeId: 'dK7Q2', escrow: EscrowStatus.disputed);
    expect(find.text('Báo vấn đề với ảnh gốc'), findsNothing);
  });

  testWidgets('after a resolved shoot dispute the delivery can still be reported', (tester) async {
    await pumpApproved(tester, disputeId: 'dK7Q2');
    expect(find.text('Báo vấn đề với ảnh gốc'), findsOneWidget);
  });

  testWidgets('"Báo vấn đề với ảnh gốc" is hidden when escrow no longer holds money', (tester) async {
    await pumpApproved(tester, escrow: EscrowStatus.released);
    expect(find.text('Báo vấn đề với ảnh gốc'), findsNothing);
  });

  testWidgets('approved: "Đánh giá buổi chụp" navigates to review, reviewed shows "Xem đánh giá"', (tester) async {
    final approvedBooking = testBooking.copyWith(
      status: BookingStatus.approved,
      approvedAt: DateTime.utc(2026, 10, 15, 10, 0),
      checkUntil: DateTime.utc(2026, 10, 17, 10, 0),
    );
    fakeBookingRepo.bookings['b-rev'] = approvedBooking;
    fakeDeliveryRepo.seedRound('b-rev', deliveredRound);

    await tester.pumpWidget(
      buildApp(const DeliveryReviewScreen(bookingId: 'b-rev')),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppButton, 'Đánh giá buổi chụp'), findsOneWidget);

    // Mark as reviewed
    final reviewedBooking = approvedBooking.copyWith(reviewedAt: DateTime.utc(2026, 10, 16, 10, 0));
    fakeBookingRepo.seedBooking(reviewedBooking);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppButton, 'Xem đánh giá'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Đánh giá buổi chụp'), findsNothing);
  });

  testWidgets('after checkUntil shows "Đã hết thời gian kiểm tra" and no report button', (tester) async {
    final approvedTime = DateTime.utc(2026, 10, 15, 10, 0);
    final checkUntilTime = approvedTime.add(const Duration(hours: 48));
    currentTime = checkUntilTime.add(const Duration(hours: 1)); // Expired

    final approvedBooking = testBooking.copyWith(
      status: BookingStatus.approved,
      approvedAt: approvedTime,
      checkUntil: checkUntilTime,
    );
    fakeBookingRepo.bookings['b-rev'] = approvedBooking;
    fakeDeliveryRepo.seedRound('b-rev', deliveredRound);

    await tester.pumpWidget(
      buildApp(const DeliveryReviewScreen(bookingId: 'b-rev')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đã hết thời gian kiểm tra'), findsOneWidget);
    expect(find.text('Báo vấn đề với ảnh gốc'), findsNothing);
  });

  testWidgets('purged samples show "Ảnh mẫu đã xoá sau 90 ngày"', (tester) async {
    final completedBooking = testBooking.copyWith(
      status: BookingStatus.completed,
    );
    final emptyRound = DeliveryRound(
      bookingId: 'b-rev',
      round: 1,
      samples: const [], // Purged
      photoCount: 50,
      linkHost: 'drive.google.com',
      submittedAt: DateTime.utc(2026, 6, 1, 10, 0),
      submittedBy: 'p1',
    );
    fakeBookingRepo.bookings['b-rev'] = completedBooking;
    fakeDeliveryRepo.seedRound('b-rev', emptyRound);

    await tester.pumpWidget(
      buildApp(const DeliveryReviewScreen(bookingId: 'b-rev')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ảnh mẫu đã xoá sau 90 ngày'), findsOneWidget);
  });

  testWidgets('a stranger opening the customer route sees the not-found state', (tester) async {
    fakeBookingRepo.bookings['b-rev'] = testBooking;
    fakeDeliveryRepo.seedRound('b-rev', deliveredRound);

    await tester.pumpWidget(
      buildApp(const DeliveryReviewScreen(bookingId: 'b-rev'), currentUid: 'stranger-999'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không tìm thấy bàn giao'), findsOneWidget);
  });

  testWidgets('ScreenCode is S05.06 and fits 320 dp at 1.3x text', (tester) async {
    tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    fakeBookingRepo.bookings['b-rev'] = testBooking;
    fakeDeliveryRepo.seedRound('b-rev', deliveredRound);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.3),
        ),
        child: buildApp(const DeliveryReviewScreen(bookingId: 'b-rev')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is ScreenCode && w.code == ScreenCodes.deliveryReview,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
