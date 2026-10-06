import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';
import '../../support/fake_review_repository.dart';

/// Plan 4e: a completed booking is reviewed with photos on S05.05, S05.02
/// shows it as reviewed, and the review appears on the photographer's S03.01.
void main() {
  testWidgets(
    'completed booking → review with 2 photos → S05.02 reviewed → S03.01 lists it',
    (tester) async {
      final fakeReviews = FakeReviewRepository(currentUserId: 'c1');
      final repo = RecordingBookingRepository()
        ..seedBooking(
          makeTestBooking(
            id: 'b1',
            status: BookingStatus.completed,
            customerId: 'c1',
            photographerId: 'p1',
            serviceId: 's1',
            day: '2026-10-02',
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
          ),
        );

      final handles = await pumpBookingRoute(
        tester,
        path: '/b/b1',
        bookings: repo,
        reviews: fakeReviews,
        signedInUid: 'c1',
        extraOverrides: [
          mediaUploaderProvider.overrideWithValue(FakeMediaUploader()),
          imagePickerProvider.overrideWithValue(
            FakeImagePicker([
              const [
                PickedImage(path: '/tmp/1.jpg', name: '1.jpg'),
                PickedImage(path: '/tmp/2.jpg', name: '2.jpg'),
              ],
            ]),
          ),
        ],
      );
      await tester.pumpAndSettle();

      // S05.02: completed → "Đánh giá", step 7 not done yet.
      final timeline = tester.widget<StatusTimeline>(
        find.byType(StatusTimeline),
      );
      expect(timeline.steps.last.state, TimelineStepState.upcoming);
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Đánh giá'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Đánh giá'));
      await tester.pumpAndSettle();
      expect(handles.location, '/b/b1/review');

      // S05.05: 5 stars, text, 2 photos, share.
      await tester.tap(find.byKey(const Key('star_5')));
      await tester.enterText(
        find.byKey(const Key('review_text_field')),
        'Buổi chụp rất đẹp và chuyên nghiệp',
      );
      await tester.tap(find.byKey(const Key('add_photo_tile')));
      await tester.pumpAndSettle();
      expect(find.text('Gửi & chia sẻ 2 ảnh'), findsOneWidget);
      await tester.tap(find.byKey(const Key('submit_share_button')));
      await tester.pumpAndSettle();

      // Back on S05.02 as reviewed, timeline step 7 done.
      expect(handles.location, '/b/b1');
      expect(find.text('Cảm ơn bạn đã đánh giá!'), findsOneWidget);
      final after = tester.widget<StatusTimeline>(find.byType(StatusTimeline));
      expect(after.steps.last.state, TimelineStepState.done);
      expect(find.widgetWithText(AppButton, 'Xem đánh giá'), findsOneWidget);

      // S03.01 "Đánh giá" lists the review.
      handles.router.go('/u/p1?tab=reviews');
      await tester.pumpAndSettle();
      expect(find.text('Buổi chụp rất đẹp và chuyên nghiệp'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
