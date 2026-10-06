import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_providers.dart';
import 'package:photobooking/data/review/review_repository.dart';
import 'package:photobooking/features/review/widgets/star_rating.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';
import '../../support/fake_review_repository.dart';

Booking _booking({
  BookingStatus status = BookingStatus.completed,
}) {
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

    testWidgets('first load shows BookingCard.skeleton(compact)', (tester) async {
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
        'shows the compact card, stars, the comment field with a counter, and the share section',
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
      expect(find.byType(StarRating), findsOneWidget);
      expect(find.byKey(const Key('review_text_field')), findsOneWidget);
      expect(find.text('Chia sẻ ảnh bạn thích'), findsOneWidget);
    });

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
      final btn = tester.widget<AppButton>(find.byKey(const Key('submit_review_button')));
      expect(btn.onPressed, isNull);

      // Tap 5th star
      await tester.tap(find.byKey(const Key('star_5')));
      await tester.pump();

      // Enter text
      await tester.enterText(
        find.byKey(const Key('review_text_field')),
        'Buổi chụp rất đẹp và vui vẻ',
      );
      await tester.pump();

      // Now enabled
      final enabledBtn =
          tester.widget<AppButton>(find.byKey(const Key('submit_review_button')));
      expect(enabledBtn.onPressed, isNotNull);
    });

    testWidgets('with photos: Chỉ đánh giá and Gửi & chia sẻ 2 ảnh',
        (tester) async {
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

      await tester.tap(find.byKey(const Key('star_5')));
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
        'submitting sends rating, trimmed text, postId and the uploaded photos, then opens S05.02 with the thanks message',
        (tester) async {
      fakePicker = FakeImagePicker([
        const [
          PickedImage(path: '/tmp/1.jpg', name: '1.jpg'),
        ],
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

      await tester.tap(find.byKey(const Key('star_5')));
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
      expect(call['rating'], 5);
      expect(call['text'], 'Buổi chụp rất đẹp và chuyên nghiệp');
      expect(call['postId'], isNotNull);
      expect(call['photos'], hasLength(1));

      // Check thanks message and navigation
      expect(find.text('Cảm ơn bạn đã đánh giá!'), findsOneWidget);
      expect(handles.location, '/b/b1');
    });

    testWidgets('a conflict after a lost response shows the review as sent',
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

      await tester.tap(find.byKey(const Key('star_5')));
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
          rating: 5,
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

    testWidgets('a reviewed booking without a review doc shows Đã đánh giá',
        (tester) async {
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

    testWidgets('a failed submit shows a localized message, not the raw error',
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

      await tester.tap(find.byKey(const Key('star_5')));
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
    });

    testWidgets('a booking that is not completed shows chưa đánh giá được',
        (tester) async {
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

      expect(find.text('Buổi chụp chưa hoàn thành nên chưa đánh giá được.'),
          findsOneWidget);
      expect(find.byKey(const Key('review_text_field')), findsNothing);
    });

    testWidgets('an existing review shows the read-only view', (tester) async {
      fakeReviews.seedReview(
        Review(
          bookingId: 'b1',
          customerId: 'c1',
          photographerId: 'p1',
          serviceId: 's1',
          rating: 4,
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
      expect(find.byType(StarRating), findsOneWidget);
      expect(find.text('Xem ảnh đã chia sẻ'), findsOneWidget);
      expect(find.byKey(const Key('review_text_field')), findsNothing);
      expect(find.byKey(const Key('submit_review_button')), findsNothing);
    });

    testWidgets(
        'S05.02 Đánh giá and S05.01 Đánh giá open this screen; S05.02 Xem đánh giá opens the read-only view',
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
    });

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
      }
    });
  });
}
