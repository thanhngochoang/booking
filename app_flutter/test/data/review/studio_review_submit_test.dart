import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/review/firestore_review_repository.dart';
import 'package:photobooking/data/review/review.dart';

import '../../support/fake_review_repository.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock
    implements HttpsCallableResult<Map<String, dynamic>> {}

void main() {
  test('submit with a studio draft sends both blocks', () async {
    final functions = _MockFunctions();
    final callable = _MockCallable();
    final result = _MockResult();
    when(() => functions.httpsCallable(any())).thenReturn(callable);
    when(() => result.data).thenReturn({'postId': null});
    Map<String, dynamic>? sent;
    when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((
      inv,
    ) async {
      sent = Map<String, dynamic>.from(inv.positionalArguments.first as Map);
      return result;
    });
    final repo = FirestoreReviewRepository(
      firestore: FakeFirebaseFirestore(),
      functions: functions,
    );

    await repo.submit(
      bookingId: 'b1',
      verdict: Verdict.tomato,
      hits: 8,
      reasons: const [],
      text: 'Thợ An chụp rất có tâm',
      studio: const StudioReviewDraft(
        verdict: Verdict.brick,
        hits: 3,
        reasons: [
          StudioReviewReason.lateAssignment,
          StudioReviewReason.slowResponse,
        ],
        text: 'Studio báo thợ quá trễ',
      ),
    );

    expect(sent, {
      'bookingId': 'b1',
      'verdict': 'tomato',
      'hits': 8,
      'reasons': <String>[],
      'text': 'Thợ An chụp rất có tâm',
      'postId': null,
      'photos': <Object?>[],
      'studio': {
        'verdict': 'brick',
        'hits': 3,
        'reasons': ['late_assignment', 'slow_response'],
        'text': 'Studio báo thợ quá trễ',
      },
    });
  });

  test('studio reason codes match the server list', () {
    expect(StudioReviewReason.values.map((r) => r.code), [
      'late_assignment',
      'slow_response',
      'price_changed',
      'poor_assignment',
      'other',
    ]);
    expect(
      StudioReviewReason.fromCode('poor_assignment'),
      StudioReviewReason.poorAssignment,
    );
    expect(StudioReviewReason.fromCode('late'), isNull);
  });

  group('Review.fromFirestore studio fields', () {
    late FakeFirebaseFirestore db;
    setUp(() => db = FakeFirebaseFirestore());

    test('a studio review maps subjectType, viaStudioName, assigneeName', () async {
      await db.doc('reviews/b1_studio').set({
        'bookingId': 'b1',
        'subjectType': 'studio',
        'subjectId': 'cuc',
        'photographerId': 'cuc',
        'assigneeId': 'an',
        'assigneeName': 'An',
        'verdict': 'brick',
        'hits': 3,
        'reasons': ['late_assignment', 'price_changed', 'late', 'other'],
        'text': 'Studio báo thợ quá trễ',
        'createdAt': '2026-10-21T03:00:00.000Z',
      });
      final studio = Review.fromFirestore(await db.doc('reviews/b1_studio').get());
      expect(studio.bookingId, 'b1');
      expect(studio.subjectType, 'studio');
      expect(studio.isStudioReview, isTrue);
      expect(studio.assigneeId, 'an');
      expect(studio.assigneeName, 'An');
      expect(studio.viaStudioName, isNull);
      expect(studio.studioReasons, [
        StudioReviewReason.lateAssignment,
        StudioReviewReason.priceChanged,
        StudioReviewReason.other,
      ]);
      expect(studio.reasons, isEmpty);

      await db.doc('reviews/b1').set({
        'bookingId': 'b1',
        'subjectType': 'photographer',
        'subjectId': 'an',
        'photographerId': 'an',
        'viaStudioId': 'cuc',
        'viaStudioName': 'Studio Cúc',
        'verdict': 'tomato',
        'hits': 8,
        'text': 'Thợ An chụp rất có tâm',
      });
      final member = Review.fromFirestore(await db.doc('reviews/b1').get());
      expect(member.subjectType, 'photographer');
      expect(member.isStudioReview, isFalse);
      expect(member.viaStudioId, 'cuc');
      expect(member.viaStudioName, 'Studio Cúc');
      expect(member.assigneeName, isNull);
      expect(member.studioReasons, isEmpty);
    });

    test("an empty snapshot name ('') reads as no name", () async {
      await db.doc('reviews/b2').set({
        'subjectType': 'photographer',
        'viaStudioId': 'cuc',
        'viaStudioName': '',
        'verdict': 'tomato',
        'text': 'x',
      });
      await db.doc('reviews/b2_studio').set({
        'bookingId': 'b2',
        'subjectType': 'studio',
        'assigneeId': 'an',
        'assigneeName': '',
        'verdict': 'tomato',
        'text': 'x',
      });
      expect(
        Review.fromFirestore(await db.doc('reviews/b2').get()).viaStudioName,
        isNull,
      );
      expect(
        Review.fromFirestore(await db.doc('reviews/b2_studio').get())
            .assigneeName,
        isNull,
      );
    });
  });

  test('the fake stores both documents of a studio submit', () async {
    final fake = FakeReviewRepository()
      ..bookingPhotographerIds['b1'] = 'cuc';
    await fake.submit(
      bookingId: 'b1',
      verdict: Verdict.tomato,
      hits: 5,
      reasons: const [],
      text: 'Thợ An chụp rất có tâm',
      studio: const StudioReviewDraft(
        verdict: Verdict.tomato,
        hits: 2,
        reasons: [],
        text: 'Studio trả lời nhanh',
      ),
    );
    expect(fake.submitCalls.single['studio'], isA<StudioReviewDraft>());
    expect(fake.reviews.keys, containsAll(['b1', 'b1_studio']));
    expect(fake.reviews['b1_studio']!.subjectType, 'studio');
    expect(fake.reviews['b1_studio']!.photographerId, 'cuc');
  });
}
