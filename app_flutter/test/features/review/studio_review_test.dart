import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_providers.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';
import '../../support/fake_review_repository.dart';

const _studio = PhotographerProfile(
  summary: PhotographerSummary(
    id: 'cuc',
    displayName: 'Studio Mây',
    verified: true,
    businessVerified: true,
    providerType: ProviderType.studio,
  ),
  intro: PhotographerIntro(onboardingComplete: true),
);

const _member = PhotographerProfile(
  summary: PhotographerSummary(
    id: 'minh',
    displayName: 'Minh Trí',
    verified: true,
  ),
  intro: PhotographerIntro(onboardingComplete: true),
);

Booking _booking({bool studio = true}) {
  final b = makeTestBooking(
    id: 'b1',
    photographerId: studio ? 'cuc' : 'p1',
    status: BookingStatus.completed,
    day: '2026-10-12',
    start: '15:30',
    end: '19:30',
    serviceSnapshot: const BookingServiceSnapshot(
      name: 'Cưới 4 giờ',
      price: 8000000,
      durationMinutes: 240,
    ),
  );
  if (!studio) return b;
  return b.copyWith(
    studio: StudioBookingInfo(
      assigneeId: 'minh',
      assigneeKind: 'member',
      assignStatus: StudioAssignStatus.assigned,
      assignDeadline: DateTime.utc(2026, 10, 11, 8, 30),
      assignedAt: DateTime.utc(2026, 10, 8, 3),
    ),
  );
}

class _World {
  _World(this.bookings, this.reviews);
  final RecordingBookingRepository bookings;
  final FakeReviewRepository reviews;
}

Future<_World> _pump(
  WidgetTester tester, {
  bool studio = true,
  void Function(FakeReviewRepository reviews)? seed,
  Size viewSize = const Size(390, 1600),
  double textScale = 1.0,
}) async {
  final bookings = RecordingBookingRepository()
    ..seedBooking(_booking(studio: studio));
  final reviews = FakeReviewRepository(currentUserId: 'c1')
    ..bookingRepository = bookings;
  seed?.call(reviews);
  await pumpBookingRoute(
    tester,
    path: '/b/b1/review',
    bookings: bookings,
    signedInUid: 'c1',
    viewSize: viewSize,
    textScale: textScale,
    extraOverrides: [
      reviewRepositoryProvider.overrideWithValue(reviews),
      mediaUploaderProvider.overrideWithValue(FakeMediaUploader()),
      imagePickerProvider.overrideWithValue(FakeImagePicker()),
      photographerProfileProvider('cuc')
          .overrideWithValue(const AsyncData(_studio)),
      photographerProfileProvider('minh')
          .overrideWithValue(const AsyncData(_member)),
    ],
  );
  await _settle(tester);
  return _World(bookings, reviews);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _in(String block, Finder f) =>
    find.descendant(of: find.byKey(Key('review-block-$block')), matching: f);

AppButton _submit(WidgetTester tester) =>
    tester.widget<AppButton>(find.byKey(const Key('submit_review_button')));

String? _missing(WidgetTester tester) {
  final f = find.byKey(const Key('review_missing_hint'));
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
}

Future<void> _fill(
  WidgetTester tester,
  String block, {
  String side = 'tomato',
  String text = 'Chụp khéo, hai bên gia đình đều ưng.',
}) async {
  await tester.tap(_in(block, find.byKey(Key('verdict-$side'))));
  await tester.pump();
  await tester.enterText(_in(block, find.byType(TextField)), text);
  await tester.pump();
}

void main() {
  testWidgets('a studio booking shows two blocks with their notes', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Studio Mây · Cưới 4 giờ'), findsOneWidget);
    expect(find.text('T2 12/10 · thợ Minh Trí'), findsOneWidget);
    expect(find.text('Thợ Minh Trí'), findsOneWidget);
    expect(find.text('Tính cho hồ sơ thợ'), findsOneWidget);
    expect(find.text('Studio Mây'), findsOneWidget);
    expect(find.text('Tính cho studio'), findsOneWidget);
    expect(find.byType(VerdictPad), findsNWidgets(2));
    for (final pad in tester.widgetList<VerdictPad>(find.byType(VerdictPad))) {
      expect(pad.compact, isTrue);
    }
    expect(_in('assignee', find.text('Nhận xét cho thợ')), findsOneWidget);
    expect(_in('studio', find.text('Nhận xét cho studio')), findsOneWidget);
    expect(_submit(tester).label, 'Gửi 2 đánh giá');
  });

  testWidgets('the pads say whom they rate', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel('Ném cà chua cho thợ, 0 trên 10'), findsOne);
    expect(find.bySemanticsLabel('Ném gạch cho studio, 0 trên 10'), findsOne);
    handle.dispose();
  });

  testWidgets('Gửi 2 đánh giá stays disabled until both blocks have a '
      'verdict and 10+ characters, and the line names the missing block', (
    tester,
  ) async {
    await _pump(tester);
    expect(_submit(tester).onPressed, isNull);
    expect(_missing(tester), 'Còn thiếu đánh giá cho thợ');

    await _fill(tester, 'assignee');
    expect(_submit(tester).onPressed, isNull);
    expect(_missing(tester), 'Còn thiếu đánh giá cho studio');

    await _fill(tester, 'studio', text: 'Ngắn');
    expect(_submit(tester).onPressed, isNull);
    expect(_missing(tester), 'Còn thiếu đánh giá cho studio');

    await _fill(
      tester,
      'studio',
      side: 'brick',
      text: 'Báo thợ trễ, phải nhắn hỏi.',
    );
    await tester.tap(_in('studio', find.text('Báo thợ trễ')));
    await tester.pump();
    expect(_submit(tester).onPressed, isNotNull);
    expect(_missing(tester), isNull);
  });

  testWidgets('a studio brick needs one of the five studio reasons', (
    tester,
  ) async {
    await _pump(tester);
    await _fill(tester, 'assignee');
    await _fill(
      tester,
      'studio',
      side: 'brick',
      text: 'Báo thợ trễ, phải nhắn hỏi nhiều lần.',
    );

    for (final label in [
      'Báo thợ trễ',
      'Tư vấn chậm',
      'Đổi giá',
      'Giao thợ không hợp',
      'Khác',
    ]) {
      expect(_in('studio', find.text(label)), findsOneWidget, reason: label);
    }
    // The member's own reasons are not offered to the studio.
    expect(_in('studio', find.text('Đến trễ')), findsNothing);
    expect(_submit(tester).onPressed, isNull);
    expect(_missing(tester), 'Còn thiếu đánh giá cho studio');

    await tester.tap(_in('studio', find.text('Tư vấn chậm')));
    await tester.pump();
    expect(_submit(tester).onPressed, isNotNull);
  });

  testWidgets('submitting sends both blocks', (tester) async {
    final w = await _pump(tester);
    await _fill(tester, 'assignee');
    await tester.tap(_in('assignee', find.byKey(const Key('verdict-tomato'))));
    await tester.pump();
    await _fill(
      tester,
      'studio',
      side: 'brick',
      text: '  Báo thợ trễ, phải nhắn hỏi nhiều lần.  ',
    );
    await tester.tap(_in('studio', find.text('Đổi giá')));
    await tester.tap(_in('studio', find.text('Báo thợ trễ')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('submit_review_button')));
    await _settle(tester);

    final call = w.reviews.submitCalls.single;
    expect(call['bookingId'], 'b1');
    expect(call['verdict'], Verdict.tomato);
    expect(call['hits'], 2);
    expect(call['text'], 'Chụp khéo, hai bên gia đình đều ưng.');
    expect(
      call['studio'],
      const StudioReviewDraft(
        verdict: Verdict.brick,
        hits: 1,
        // Catalogue order, not tap order.
        reasons: [
          StudioReviewReason.lateAssignment,
          StudioReviewReason.priceChanged,
        ],
        text: 'Báo thợ trễ, phải nhắn hỏi nhiều lần.',
      ),
    );
    expect(w.reviews.reviews.keys, containsAll(['b1', 'b1_studio']));
  });

  testWidgets('after submitting, review mode shows both blocks read-only', (
    tester,
  ) async {
    await _pump(
      tester,
      seed: (reviews) => reviews
        ..seedReview(
          Review(
            bookingId: 'b1',
            customerId: 'c1',
            photographerId: 'minh',
            serviceId: 's1',
            verdict: Verdict.tomato,
            hits: 8,
            text: 'Chụp khéo, hai bên gia đình đều ưng.',
            createdAt: DateTime.utc(2026, 10, 14),
            viaStudioId: 'cuc',
          ),
        )
        ..seedReview(
          Review(
            bookingId: 'b1',
            subjectType: 'studio',
            customerId: 'c1',
            photographerId: 'cuc',
            serviceId: 's1',
            verdict: Verdict.brick,
            hits: 2,
            studioReasons: const [StudioReviewReason.lateAssignment],
            text: 'Báo thợ trễ, phải nhắn hỏi nhiều lần.',
            createdAt: DateTime.utc(2026, 10, 14),
            assigneeId: 'minh',
          ),
        ),
    );

    expect(find.byType(VerdictPad), findsNothing);
    expect(find.byKey(const Key('submit_review_button')), findsNothing);
    final member = find.byKey(const Key('review-readonly-assignee'));
    final studio = find.byKey(const Key('review-readonly-studio'));
    expect(
      find.descendant(of: member, matching: find.text('Thợ Minh Trí')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: member,
        matching: find.text('Chụp khéo, hai bên gia đình đều ưng.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: studio, matching: find.text('Báo thợ trễ')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: studio,
        matching: find.text('Báo thợ trễ, phải nhắn hỏi nhiều lần.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an individual booking keeps the single block', (tester) async {
    await _pump(tester, studio: false);

    expect(find.byType(VerdictPad), findsOneWidget);
    expect(find.byKey(const Key('review-block-studio')), findsNothing);
    expect(find.text('Tính cho studio'), findsNothing);
    expect(_submit(tester).label, 'Gửi đánh giá');
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _pump(tester, viewSize: const Size(320, 700), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
