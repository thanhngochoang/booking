// test/features/jobs/invite_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/features/jobs/invite_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/fake_job_repository.dart';

class _FakeRecommender implements RecommendationRepository {
  _FakeRecommender(this.photographers);
  final List<PhotographerSummary> photographers;

  @override
  Future<RecommendationPage> recommendPhotographers(RecommendationQuery query) async {
    return RecommendationPage(
      items: photographers
          .map((p) => RecommendedPhotographer(photographer: p, rank: 1, score: 0.9))
          .toList(),
      requestId: 'req_1',
      algorithm: 'test',
      algorithmVersion: '1.0',
    );
  }

  @override
  Future<RecommendationPage> similar(String photographerId, {int limit = 8}) async =>
      recommendPhotographers(const RecommendationQuery());

  @override
  Future<PostRecommendationPage> recommendPosts(PostRecommendationQuery query) async =>
      const PostRecommendationPage(
        items: [],
        requestId: 'req_1',
        algorithm: 'test',
        algorithmVersion: '1.0',
      );

  @override
  Future<void> sendFeedback(List<RecommendationSignal> signals) async {}
}

void main() {
  testWidgets('invite_sheet lists photographers and sends invites', (tester) async {
    final now = DateTime.utc(2026, 10, 20);
    final repo = FakeJobRepository(currentUid: 'u1');

    final photographers = [
      const PhotographerSummary(
        id: 'p1',
        displayName: 'Photographer One',
        acceptingOrders: true,
        providerType: ProviderType.individual,
      ),
      const PhotographerSummary(
        id: 'p2',
        displayName: 'Photographer Two',
        acceptingOrders: true,
        providerType: ProviderType.individual,
      ),
      const PhotographerSummary(
        id: 'p3_closed',
        displayName: 'Closed Photographer',
        acceptingOrders: false,
        providerType: ProviderType.individual,
      ),
    ];

    final job = Job(
      id: 'j1',
      customerId: 'u1',
      customer: const JobCustomer(name: 'User 1'),
      specialtyId: 'portrait',
      title: 'Chụp ảnh tốt nghiệp',
      description: 'Mô tả',
      schedule: const JobSchedule(kind: ScheduleKind.fixed, day: '2026-10-25', durationMinutes: 60),
      dayFrom: '2026-10-25',
      dayTo: '2026-10-25',
      area: const JobArea(
        areaId: 'a1',
        name: 'Hoàn Kiếm, Hà Nội',
        city: 'Hà Nội',
        cityKey: 'ha-noi',
        lat: 21.0,
        lng: 105.8, geohash5: 'w4gxx',
      ),
      wants: const JobWants(),
      allowedProviders: AllowedProviders.all,
      quoteDeadline: now.add(const Duration(days: 3)),
      status: JobStatus.open,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobRepositoryProvider.overrideWithValue(repo),
          recommendationRepositoryProvider.overrideWithValue(_FakeRecommender(photographers)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InviteSheet(
              job: job,
              alreadyInvitedIds: const ['p2'],
              quotedPhotographerIds: const [],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // p1 and p2 show up; p3_closed does not
    expect(find.text('Photographer One'), findsOneWidget);
    expect(find.text('Photographer Two'), findsOneWidget);
    expect(find.text('Closed Photographer'), findsNothing);

    // p2 is already invited, so it has tag "Đã mời"
    expect(find.text('Đã mời'), findsOneWidget);

    // Tap on p1 checkbox to select
    await tester.tap(find.text('Photographer One'));
    await tester.pumpAndSettle();

    // Verify send button is enabled with "Gửi lời mời (1)"
    expect(find.text('Gửi lời mời (1)'), findsOneWidget);
    await tester.tap(find.text('Gửi lời mời (1)'));
    await tester.pumpAndSettle();

    expect(repo.inviteCalls, hasLength(1));
    expect(repo.inviteCalls.first.jobId, 'j1');
    expect(repo.inviteCalls.first.photographerIds, ['p1']);
  });
}
