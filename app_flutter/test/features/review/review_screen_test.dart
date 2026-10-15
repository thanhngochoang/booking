import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_providers.dart';
import 'package:photobooking/data/review/review_repository.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';
import '../../support/fake_review_repository.dart';

Booking _booking({BookingStatus status = BookingStatus.completed}) {
  return makeTestBooking(
    id: 'b1',
    status: status,
    customerId: 'c1',
    photographerId: 'p1',
    serviceId: 's1',
    day: '2026-10-12',
    start: '15:30',
    end: '17:30',
    deposit: 450000,
    remaining: 1050000,
    serviceSnapshot: const BookingServiceSnapshot(
      name: 'Chân dung 2 giờ',
      price: 1500000,
      durationMinutes: 120,
    ),
    place: const BookingPlace(name: 'Bến Bạch Đằng'),
  );
}

void main() {
  group('ReviewScreen', () {
    late FakeReviewRepository fakeReviews;
    late FakeMediaUploader fakeUploader;
    late FakeImagePicker fakePicker;

    setUp(() {
      fakeReviews = FakeReviewRepository(currentUserId: 'c1');
      fakeUploader = FakeMediaUploader();
      fakePicker = FakeImagePicker();
    });

    testWidgets('first load shows BookingCard.skeleton(compact)', (
      tester,
    ) async {
      final pending = Completer<Booking?>();

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: RecordingBookingRepository(),
        signedInUid: 'c1',
        extraOverrides: [
          bookingProvider('b1').overrideWith((_) => pending.future.asStream()),
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey('booking_card_skeleton')), findsOne);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'shows the compact card, the pad, the comment field with a counter, and the share section',
      (tester) async {
        final repo = RecordingBookingRepository()..seedBooking(_booking());

        await pumpBookingRoute(
          tester,
          path: '/b/b1/review',
          bookings: repo,
          signedInUid: 'c1',
          extraOverrides: [
            reviewRepositoryProvider.overrideWithValue(fakeReviews),
            mediaUploaderProvider.overrideWithValue(fakeUploader),
            imagePickerProvider.overrideWithValue(fakePicker),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.byType(BookingCard), findsOneWidget);
        expect(find.byType(VerdictPad), findsOneWidget);
        expect(find.byKey(const Key('review_text_field')), findsOneWidget);
        expect(find.text('Chia sẻ ảnh bạn thích'), findsOneWidget);
      },
    );

    testWidgets('0 photos: one primary Gửi đánh giá', (tester) async {
      final repo = RecordingBookingRepository()..seedBooking(_booking());

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('submit_review_button')), findsOneWidget);
      expect(find.byKey(const Key('review_only_button')), findsNothing);
      expect(find.byKey(const Key('submit_share_button')), findsNothing);

      // Disabled before input
      final btn = tester.widget<AppButton>(
        find.byKey(const Key('submit_review_button')),
      );
      expect(btn.onPressed, isNull);

      // Pick tomato
      await tester.tap(find.byKey(const Key('verdict-tomato')));
      await tester.pump();

      // Enter text
      await tester.enterText(
        find.byKey(const Key('review_text_field')),
        'Buổi chụp rất đẹp và vui vẻ',
      );
      await tester.pump();

      // Now enabled
      final enabledBtn = tester.widget<AppButton>(
        find.byKey(const Key('submit_review_button')),
      );
      expect(enabledBtn.onPressed, isNotNull);
    });

    testWidgets('with photos: Chỉ đánh giá and Gửi & chia sẻ 2 ảnh', (
      tester,
    ) async {
      fakePicker = FakeImagePicker([
        const [
          PickedImage(path: '/tmp/1.jpg', name: '1.jpg'),
          PickedImage(path: '/tmp/2.jpg', name: '2.jpg'),
        ],
      ]);

      final repo = RecordingBookingRepository()..seedBooking(_booking());

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('verdict-tomato')));
      await tester.enterText(
        find.byKey(const Key('review_text_field')),
        'Buổi chụp tuyệt vời và chuyên nghiệp',
      );
      await tester.pump();

      // Pick photos
      await tester.tap(find.byKey(const Key('add_photo_tile')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_only_button')), findsOneWidget);
      expect(find.byKey(const Key('submit_share_button')), findsOneWidget);
      expect(find.text('Gửi & chia sẻ 2 ảnh'), findsOneWidget);
    });

    testWidgets(
      'submitting sends verdict, trimmed text, postId and the uploaded photos, then opens S05.02 with the thanks message',
      (tester) async {
        fakePicker = FakeImagePicker([
          const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
        ]);

        final repo = RecordingBookingRepository()..seedBooking(_booking());

        final handles = await pumpBookingRoute(
          tester,
          path: '/b/b1/review',
          bookings: repo,
          signedInUid: 'c1',
          extraOverrides: [
            reviewRepositoryProvider.overrideWithValue(fakeReviews),
            mediaUploaderProvider.overrideWithValue(fakeUploader),
            imagePickerProvider.overrideWithValue(fakePicker),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('verdict-tomato')));
        await tester.enterText(
          find.byKey(const Key('review_text_field')),
          '  Buổi chụp rất đẹp và chuyên nghiệp  ',
        );
        await tester.tap(find.byKey(const Key('add_photo_tile')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('submit_share_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(fakeReviews.submitCalls, hasLength(1));
        final call = fakeReviews.submitCalls.first;
        expect(call['verdict'], Verdict.tomato);
        expect(call['hits'], 1);
        expect(call['reasons'], isEmpty);
        expect(call['text'], 'Buổi chụp rất đẹp và chuyên nghiệp');
        expect(call['postId'], isNotNull);
        expect(call['photos'], hasLength(1));

        // Check thanks message and navigation
        expect(find.text('Cảm ơn bạn đã đánh giá!'), findsOneWidget);
        expect(handles.location, '/b/b1');
      },
    );

    testWidgets('a conflict after a lost response shows the review as sent', (
      tester,
    ) async {
      final repo = RecordingBookingRepository()..seedBooking(_booking());

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('verdict-tomato')));
      await tester.enterText(
        find.byKey(const Key('review_text_field')),
        'Đã gửi đánh giá từ trước',
      );
      await tester.pump();

      // Simulate conflict from server and seed the review that exists on server
      fakeReviews.nextError = ReviewErrorCode.conflict;
      fakeReviews.seedReview(
        Review(
          bookingId: 'b1',
          customerId: 'c1',
          photographerId: 'p1',
          serviceId: 's1',
          verdict: Verdict.tomato,
          text: 'Đã gửi đánh giá từ trước',
          createdAt: DateTime.now(),
        ),
      );

      await tester.tap(find.byKey(const Key('submit_review_button')));
      await tester.pumpAndSettle();

      // Read-only view is shown instead of navigating away or staying with inputs
      expect(find.text('Đã gửi đánh giá từ trước'), findsOneWidget);
      expect(find.byKey(const Key('review_text_field')), findsNothing);
    });

    testWidgets('while the review loads the form is not shown', (tester) async {
      final repo = RecordingBookingRepository()..seedBooking(_booking());
      final pending = StreamController<Review?>();
      addTearDown(pending.close);

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          bookingReviewProvider('b1').overrideWith((_) => pending.stream),
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byKey(const Key('review_text_field')), findsNothing);
      expect(find.byKey(const ValueKey('booking_card_skeleton')), findsOne);

      pending.add(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review_text_field')), findsOneWidget);
    });

    testWidgets('a review load error shows retry', (tester) async {
      final repo = RecordingBookingRepository()..seedBooking(_booking());
      var calls = 0;

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          bookingReviewProvider('b1').overrideWith((_) {
            calls++;
            return calls == 1
                ? Stream<Review?>.error(StateError('boom'))
                : Stream<Review?>.value(null);
          }),
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_text_field')), findsNothing);
      expect(find.text('Thử lại'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review_text_field')), findsOneWidget);
    });

    testWidgets('a reviewed booking without a review doc shows Đã đánh giá', (
      tester,
    ) async {
      final repo = RecordingBookingRepository()
        ..seedBooking(_booking(status: BookingStatus.reviewed));

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review_already_done')), findsOneWidget);
      expect(find.byKey(const Key('review_text_field')), findsNothing);
      expect(find.byKey(const Key('submit_review_button')), findsNothing);
    });

    testWidgets(
      'a failed submit shows a localized message, not the raw error',
      (tester) async {
        final repo = RecordingBookingRepository()..seedBooking(_booking());

        await pumpBookingRoute(
          tester,
          path: '/b/b1/review',
          bookings: repo,
          signedInUid: 'c1',
          extraOverrides: [
            reviewRepositoryProvider.overrideWithValue(fakeReviews),
            mediaUploaderProvider.overrideWithValue(fakeUploader),
            imagePickerProvider.overrideWithValue(fakePicker),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('verdict-tomato')));
        await tester.enterText(
          find.byKey(const Key('review_text_field')),
          'Buổi chụp rất đẹp và chuyên nghiệp',
        );
        await tester.pump();
        fakeReviews.nextError = ReviewErrorCode.unknown;
        await tester.tap(find.byKey(const Key('submit_review_button')));
        await tester.pumpAndSettle();

        expect(find.text('Không gửi được. Thử lại nhé.'), findsOneWidget);
        expect(find.textContaining('ReviewException'), findsNothing);
      },
    );

    testWidgets('a booking that is not completed shows chưa đánh giá được', (
      tester,
    ) async {
      final repo = RecordingBookingRepository()
        ..seedBooking(_booking(status: BookingStatus.requested));

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Buổi chụp chưa hoàn thành nên chưa đánh giá được.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('review_text_field')), findsNothing);
    });

    Future<void> pumpForm(WidgetTester tester, {Booking? booking}) async {
      final repo = RecordingBookingRepository()
        ..seedBooking(booking ?? _booking());
      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the pad, level and hint after the first tap', (
      tester,
    ) async {
      await pumpForm(tester);
      expect(find.byType(VerdictPad), findsOneWidget);
      expect(find.text('Hài lòng'), findsOneWidget);
      expect(find.byType(VerdictLevel), findsNothing);

      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byKey(const Key('verdict-tomato')));
        await tester.pump();
      }
      expect(find.text('Rất hài lòng'), findsOneWidget);
      expect(find.text('Làm lại'), findsOneWidget);
      expect(find.text('Chạm tiếp để tăng mức độ, tối đa 10'), findsOneWidget);
      expect(find.text('Điều gì chưa ổn?'), findsNothing);

      await tester.tap(find.text('Làm lại'));
      await tester.pump();
      expect(find.byType(VerdictLevel), findsNothing);
    });

    testWidgets('brick shows the reasons title and six chips', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.byKey(const Key('verdict-brick')));
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('verdict-brick')));
        await tester.pump();
      }

      expect(find.text('Chưa ưng'), findsOneWidget); // level 3
      expect(find.text('Điều gì chưa ổn?'), findsOneWidget);
      expect(find.text('Chọn ít nhất 1'), findsOneWidget);
      final chips = find.descendant(
        of: find.byKey(const Key('review_reasons')),
        matching: find.byType(AppChip),
      );
      expect(chips, findsNWidgets(6));
      final labels = tester
          .widgetList<AppChip>(chips)
          .map((c) => c.label)
          .toList();
      expect(labels, [
        'Đến trễ',
        'Ảnh không như mẫu',
        'Giao ảnh chậm',
        'Thái độ',
        'Đổi giá',
        'Khác',
      ]);
      // The brick frame of the mock has no tap hint.
      expect(find.text('Chạm tiếp để tăng mức độ, tối đa 10'), findsNothing);
    });

    testWidgets('submit is disabled with "Chọn cà chua hoặc gạch" under it '
        'before a side is picked', (tester) async {
      await pumpForm(tester);
      expect(find.text('Chọn cà chua hoặc gạch'), findsOneWidget);
      final btn = tester.widget<AppButton>(
        find.byKey(const Key('submit_review_button')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('brick without a reason shows "Chọn ít nhất một lý do"', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.tap(find.byKey(const Key('verdict-brick')));
      await tester.enterText(
        find.byKey(const Key('review_text_field')),
        'Đến trễ và giao ảnh quá chậm',
      );
      await tester.pump();
      expect(find.text('Chọn ít nhất một lý do'), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.byKey(const Key('submit_review_button')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Đến trễ'));
      await tester.pump();
      expect(find.text('Chọn ít nhất một lý do'), findsNothing);
      expect(
        tester
            .widget<AppButton>(find.byKey(const Key('submit_review_button')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('short text shows "Viết ít nhất 10 ký tự"', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.byKey(const Key('verdict-tomato')));
      await tester.enterText(find.byKey(const Key('review_text_field')), 'Đẹp');
      await tester.pump();
      expect(find.text('Viết ít nhất 10 ký tự'), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.byKey(const Key('submit_review_button')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('the text hint follows the side', (tester) async {
      await pumpForm(tester);
      expect(find.text('Điều bạn thích nhất ở buổi chụp'), findsOneWidget);
      await tester.tap(find.byKey(const Key('verdict-brick')));
      await tester.pump();
      expect(find.text('Kể rõ điều chưa ổn để thợ cải thiện'), findsOneWidget);
    });

    testWidgets('a brick review sends hits and the ticked reasons', (
      tester,
    ) async {
      await pumpForm(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('verdict-brick')));
        await tester.pump();
      }
      await tester.tap(find.text('Giao ảnh chậm'));
      await tester.tap(find.text('Đến trễ'));
      await tester.enterText(
        find.byKey(const Key('review_text_field')),
        'Đến trễ 30 phút, ảnh giao chậm',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('submit_review_button')));
      await tester.pumpAndSettle();

      final call = fakeReviews.submitCalls.single;
      expect(call['verdict'], Verdict.brick);
      expect(call['hits'], 3);
      expect(call['reasons'], [ReviewReason.late, ReviewReason.slowDelivery]);
    });

    testWidgets('a send error keeps side, hits, reasons and text and shows '
        'the network message', (tester) async {
      await pumpForm(tester);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('verdict-brick')));
        await tester.pump();
      }
      await tester.tap(find.text('Thái độ'));
      await tester.enterText(
        find.byKey(const Key('review_text_field')),
        'Thái độ chưa tốt với khách',
      );
      await tester.pump();

      fakeReviews.nextError = ReviewErrorCode.network;
      await tester.tap(find.byKey(const Key('submit_review_button')));
      await tester.pumpAndSettle();

      expect(find.text('Không gửi được. Thử lại nhé.'), findsOneWidget);
      expect(find.text('Rất hài lòng'), findsNothing);
      expect(find.text('Chưa ưng'), findsOneWidget); // still 4 hits
      expect(find.text('×4'), findsOneWidget);
      expect(
        tester
            .widgetList<AppChip>(
              find.descendant(
                of: find.byKey(const Key('review_reasons')),
                matching: find.byType(AppChip),
              ),
            )
            .where((c) => c.selected)
            .map((c) => c.label),
        ['Thái độ'],
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('review_text_field')))
            .controller!
            .text,
        'Thái độ chưa tốt với khách',
      );
    });

    testWidgets('read-only view shows VerdictBadge ×n, reason chips and the '
        'text', (tester) async {
      fakeReviews.seedReview(
        Review(
          bookingId: 'b1',
          customerId: 'c1',
          photographerId: 'p1',
          serviceId: 's1',
          verdict: Verdict.brick,
          hits: 3,
          reasons: const [ReviewReason.late, ReviewReason.slowDelivery],
          text: 'Đến trễ 30 phút, ảnh giao chậm',
          createdAt: DateTime.now(),
        ),
      );
      await pumpForm(tester, booking: _booking(status: BookingStatus.reviewed));

      final badge = tester.widget<VerdictBadge>(find.byType(VerdictBadge));
      expect(badge.kind, VerdictKind.brick);
      expect(badge.hits, 3);
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('Chưa hài lòng'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('review_reasons_readonly')),
          matching: find.byType(AppChip),
        ),
        findsNWidgets(2),
      );
      expect(find.text('Đến trễ'), findsOneWidget);
      expect(find.text('Giao ảnh chậm'), findsOneWidget);
      expect(find.text('Đến trễ 30 phút, ảnh giao chậm'), findsOneWidget);
      expect(find.byType(VerdictPad), findsNothing);
    });

    testWidgets('a completed booking with reviewedAt opens the read-only '
        'view', (tester) async {
      await pumpForm(
        tester,
        booking: _booking().copyWith(reviewedAt: DateTime.utc(2026, 10, 13)),
      );
      expect(find.byKey(const Key('review_already_done')), findsOneWidget);
      expect(find.byType(VerdictPad), findsNothing);
    });

    testWidgets('the screen carries ScreenCode S05.05', (tester) async {
      await pumpForm(tester);
      final code = tester.widget<ScreenCode>(find.byType(ScreenCode).first);
      expect(code.code, 'S05.05');
      expect(ScreenCodes.reviewAndShare, 'S05.05');
    });

    testWidgets('brick form with reasons and photos fits 320 dp at 1.3× text', (
      tester,
    ) async {
      final repo = RecordingBookingRepository()..seedBooking(_booking());
      final picker = FakeImagePicker([
        const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
      ]);
      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        viewSize: const Size(320, 600),
        textScale: 1.3,
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(picker),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verdict-brick')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('add_photo_tile')));
      await tester.tap(find.byKey(const Key('add_photo_tile')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('submit_share_button')), findsOneWidget);
    });

    testWidgets('an existing review shows the read-only view', (tester) async {
      fakeReviews.seedReview(
        Review(
          bookingId: 'b1',
          customerId: 'c1',
          photographerId: 'p1',
          serviceId: 's1',
          verdict: Verdict.tomato,
          text: 'Rất ưng ý với chất lượng ảnh',
          photoPostId: 'p_123',
          createdAt: DateTime.now(),
        ),
      );

      final repo = RecordingBookingRepository()
        ..seedBooking(_booking(status: BookingStatus.reviewed));

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Rất ưng ý với chất lượng ảnh'), findsOneWidget);
      expect(find.text('Hài lòng'), findsOneWidget);
      expect(find.text('Xem ảnh đã chia sẻ'), findsOneWidget);
      expect(find.byKey(const Key('review_text_field')), findsNothing);
      expect(find.byKey(const Key('submit_review_button')), findsNothing);
    });

    testWidgets(
      'S05.02 Đánh giá opens this screen (S05.01 Đánh giá is covered in my_bookings_screen_test)',
      (tester) async {
        final repo = RecordingBookingRepository()
          ..seedBooking(_booking(status: BookingStatus.completed));

        final handles = await pumpBookingRoute(
          tester,
          path: '/b/b1',
          bookings: repo,
          signedInUid: 'c1',
          extraOverrides: [
            reviewRepositoryProvider.overrideWithValue(fakeReviews),
            mediaUploaderProvider.overrideWithValue(fakeUploader),
            imagePickerProvider.overrideWithValue(fakePicker),
          ],
        );
        await tester.pumpAndSettle();

        // S05.02 completed shows "Đánh giá" button
        final reviewButton = find.text('Đánh giá');
        expect(reviewButton, findsOneWidget);
        await tester.tap(reviewButton);
        await tester.pumpAndSettle();

        expect(handles.location, '/b/b1/review');
      },
    );

    testWidgets(
      '320 dp and 1.3× text, light and dark: no overflow; the bottom bar stays visible above the keyboard',
      (tester) async {
        final repo = RecordingBookingRepository()..seedBooking(_booking());

        for (final brightness in [Brightness.light, Brightness.dark]) {
          await pumpBookingRoute(
            tester,
            path: '/b/b1/review',
            bookings: repo,
            signedInUid: 'c1',
            viewSize: const Size(320, 600),
            textScale: 1.3,
            brightness: brightness,
            extraOverrides: [
              reviewRepositoryProvider.overrideWithValue(fakeReviews),
              mediaUploaderProvider.overrideWithValue(fakeUploader),
              imagePickerProvider.overrideWithValue(fakePicker),
            ],
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('submit_review_button')), findsOneWidget);

          // The keyboard is up: the bar moves above it instead of hiding.
          await pumpBookingRoute(
            tester,
            path: '/b/b1/review',
            bookings: repo,
            signedInUid: 'c1',
            viewSize: const Size(320, 600),
            textScale: 1.3,
            brightness: brightness,
            keyboardInset: 300,
            extraOverrides: [
              reviewRepositoryProvider.overrideWithValue(fakeReviews),
              mediaUploaderProvider.overrideWithValue(fakeUploader),
              imagePickerProvider.overrideWithValue(fakePicker),
            ],
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final bar = tester.getRect(
            find.byKey(const Key('submit_review_button')),
          );
          expect(bar.bottom, lessThanOrEqualTo(300));
        }
      },
    );

    testWidgets('10 photos at 320 dp and 1.3× text: no overflow, both buttons '
        'reachable', (tester) async {
      final repo = RecordingBookingRepository()..seedBooking(_booking());
      final picker = FakeImagePicker([
        [
          for (var i = 0; i < 10; i++)
            PickedImage(path: '/tmp/$i.jpg', name: '$i.jpg'),
        ],
      ]);

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        viewSize: const Size(320, 600),
        textScale: 1.3,
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(picker),
        ],
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('add_photo_tile')));
      await tester.tap(find.byKey(const Key('add_photo_tile')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('photo_tile_9')), findsOneWidget);
      expect(find.byKey(const Key('add_photo_tile')), findsNothing);
      expect(find.byKey(const Key('review_only_button')), findsOneWidget);
      expect(find.byKey(const Key('submit_share_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the hint sits above the grid; Tuỳ chọn is plain accent text; '
        'the remove button has a tooltip and a 48 dp target', (tester) async {
      final repo = RecordingBookingRepository()..seedBooking(_booking());
      final picker = FakeImagePicker([
        const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
      ]);

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(picker),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_photo_tile')));
      await tester.pumpAndSettle();

      final hint = find.textContaining('Buổi chụp thật');
      expect(hint, findsOneWidget);
      expect(
        tester.getTopLeft(hint).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('photo_tile_0'))).dy),
      );

      final optional = find.text('Tuỳ chọn');
      expect(
        find.ancestor(of: optional, matching: find.byType(DecoratedBox)),
        findsNothing,
      );

      final remove = find.byKey(const Key('remove_photo_0'));
      expect(find.byTooltip('Gỡ ảnh'), findsOneWidget);
      final size = tester.getSize(remove);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('an uploading tile announces its progress', (tester) async {
      final repo = RecordingBookingRepository()..seedBooking(_booking());
      final manual = _HangingUploader();
      final picker = FakeImagePicker([
        const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
      ]);

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(manual),
          imagePickerProvider.overrideWithValue(picker),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_photo_tile')));
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsLabel('Ảnh 1 đang tải lên, 30%'), findsOneWidget);
    });

    testWidgets('submit failures: not eligible, forbidden and network '
        'each get their own message', (tester) async {
      final repo = RecordingBookingRepository()..seedBooking(_booking());

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('verdict-tomato')));
      await tester.enterText(
        find.byKey(const Key('review_text_field')),
        'Buổi chụp rất đẹp và chuyên nghiệp',
      );
      await tester.pump();

      const cases = {
        ReviewErrorCode.notEligible:
            'Buổi chụp chưa hoàn thành nên chưa đánh giá được.',
        ReviewErrorCode.permissionDenied:
            'Bạn không thể đánh giá buổi chụp này.',
        ReviewErrorCode.notFound: 'Bạn không thể đánh giá buổi chụp này.',
        ReviewErrorCode.network: 'Không gửi được. Thử lại nhé.',
      };
      for (final entry in cases.entries) {
        fakeReviews.nextError = entry.key;
        await tester.tap(find.byKey(const Key('submit_review_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
        ScaffoldMessenger.of(
          tester.element(find.byKey(const Key('review_text_field'))),
        ).clearSnackBars();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('someone else’s booking shows an empty state, not the form', (
      tester,
    ) async {
      final repo = RecordingBookingRepository()..seedBooking(_booking());

      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: repo,
        signedInUid: 'someone-else',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Bạn không thể đánh giá buổi chụp này.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('review_text_field')), findsNothing);
    });

    testWidgets('a missing booking says it was not found', (tester) async {
      await pumpBookingRoute(
        tester,
        path: '/b/b1/review',
        bookings: RecordingBookingRepository(),
        signedInUid: 'c1',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy buổi chụp'), findsOneWidget);
      expect(
        find.text('Buổi chụp chưa hoàn thành nên chưa đánh giá được.'),
        findsNothing,
      );
    });

    testWidgets('S05.02 Xem đánh giá opens the read-only view of the review', (
      tester,
    ) async {
      fakeReviews.seedReview(
        Review(
          bookingId: 'b1',
          customerId: 'c1',
          photographerId: 'p1',
          serviceId: 's1',
          verdict: Verdict.tomato,
          text: 'Rất ưng ý với chất lượng ảnh',
          createdAt: DateTime.now(),
        ),
      );
      final repo = RecordingBookingRepository()
        ..seedBooking(_booking(status: BookingStatus.reviewed));

      final handles = await pumpBookingRoute(
        tester,
        path: '/b/b1',
        bookings: repo,
        signedInUid: 'c1',
        extraOverrides: [
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(fakePicker),
        ],
      );
      await tester.pumpAndSettle();

      final view = find.widgetWithText(AppButton, 'Xem đánh giá');
      await tester.ensureVisible(view);
      await tester.pumpAndSettle();
      await tester.tap(view);
      await tester.pumpAndSettle();

      expect(handles.location, '/b/b1/review');
      expect(find.text('Rất ưng ý với chất lượng ảnh'), findsOneWidget);
      expect(find.byKey(const Key('review_text_field')), findsNothing);
      expect(find.byKey(const Key('submit_review_button')), findsNothing);
    });
  });
}

/// An uploader that reports 30 % and then never finishes.
class _HangingUploader implements MediaUploader {
  final _controllers = <StreamController<UploadEvent>>[];

  @override
  Stream<UploadEvent> upload(PickedImage image, {
    required String storagePath,
    required ImagePurpose purpose,
  }) {
    final c = StreamController<UploadEvent>()
      ..add(const UploadEvent.progress(0.3));
    _controllers.add(c);
    return c.stream;
  }

  @override
  Future<void> delete(String storagePath) async {}
}
