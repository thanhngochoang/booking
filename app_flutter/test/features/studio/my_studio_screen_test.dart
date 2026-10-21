import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/studio/studio_repository.dart';

import '../../support/meta_finders.dart';
import '../../support/studio_world.dart';

Finder _key(String k) => find.byKey(Key(k));

void _usePhone(WidgetTester tester, {double width = 390, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// An's membership of Studio Mây since 02/2026.
final _active = makeRelation(
  id: 'act',
  studioId: 'may',
  studioName: 'Studio Mây',
  createdAt: DateTime.utc(2026, 2, 3, 3),
);

/// Studio Nắng's invite, sent 2 days ago (5 days left).
final _invite = makeRelation(
  id: 'inv_nang',
  studioId: 'nang',
  studioName: 'Studio Nắng',
  status: RelationStatus.invited,
);

/// An's own request to Studio Mây, sent 2 hours ago.
final _request = makeRelation(
  id: 'req_may',
  studioId: 'may',
  studioName: 'Studio Mây',
  status: RelationStatus.requested,
  initiatedBy: RelationInitiator.member,
  createdAt: studioNow.subtract(const Duration(hours: 2)),
);

Future<StudioWorld> _open(
  WidgetTester tester, {
  void Function(StudioWorld w)? seed,
  double width = 390,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
}) async {
  _usePhone(tester, width: width);
  final w = StudioWorld(uid: 'an');
  w.intro = const PhotographerIntro(
    onboardingComplete: true,
    verified: true,
    studioId: 'may',
  );
  w.photographers.add(
    const PhotographerSummary(
      id: 'may',
      displayName: 'Studio Mây',
      verified: true,
      businessVerified: true,
      providerType: ProviderType.studio,
    ),
  );
  seed?.call(w);
  await tester.pumpWidget(
    w.app(location: '/me/studio', textScale: textScale, brightness: brightness),
  );
  await _settle(tester);
  return w;
}

void _member(StudioWorld w, {int jobs = 2}) {
  w.studios
    ..seedRelation(_active)
    ..seedRelation(_invite);
  w.bookings.emitAssigned([
    for (var i = 0; i < jobs; i++)
      makeStudioBooking(
        id: 'job$i',
        photographerId: 'may',
        assigneeId: 'an',
        status: BookingStatus.upcoming,
      ),
    // Another studio's or a closed job is not listed.
    makeStudioBooking(
      id: 'done',
      photographerId: 'may',
      assigneeId: 'an',
      status: BookingStatus.completed,
    ),
  ]);
}

AppButton _button(WidgetTester tester, String key) =>
    tester.widget<AppButton>(_key(key));

/// The last studio call was [name] with [payload].
void _expectLast(StudioWorld w, String name, Map<String, Object?> payload) {
  final c = w.studios.calls.last;
  expect([c.$1, c.$2], [name, payload]);
}

void main() {
  testWidgets('a member sees the studio card, jobs and Rời studio', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester, seed: _member);
    expect(find.text('Studio của tôi'), findsOneWidget);
    expect(find.text('Studio Mây'), findsWidgets);
    expect(
      find.bySemanticsLabel(RegExp('^Studio Mây, Studio đã xác minh')),
      findsOne,
    );
    expect(
      findMeta('Thành viên từ 02/2026 · 2 việc được giao'),
      findsOneWidget,
    );
    expect(find.text('Việc studio giao'), findsOneWidget);
    expect(find.text('ĐÃ GIAO'), findsNWidgets(2));
    expect(find.text('T7 24/10 · 15:00–17:00'), findsNWidgets(2));
    expect(find.text('Rời studio'), findsOneWidget);
    expect(find.byType(CtaSurface), findsNothing);
    expect(
      find.text(
        'Rời hoặc bị bỏ khỏi studio thì 7 ngày sau mới vào được studio khác.',
      ),
      findsOneWidget,
    );
    await tester.tap(_key('my-studio-view'));
    await _settle(tester);
    expect(find.text('stub /u/may'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a job opens its booking', (tester) async {
    await _open(tester, seed: _member);
    await tester.tap(_key('my-studio-job-job0'));
    await _settle(tester);
    expect(find.text('stub /b/job0'), findsOneWidget);
  });

  testWidgets('Rời studio confirms in a red sheet and leaves', (tester) async {
    final w = await _open(tester, seed: (w) => _member(w, jobs: 0));
    await tester.tap(_key('my-studio-leave'));
    await _settle(tester);
    expect(find.text('Rời Studio Mây?'), findsOneWidget);
    expect(
      find.text('7 ngày sau bạn mới vào được studio khác, kể cả Studio Mây.'),
      findsOneWidget,
    );
    expect(find.text('Ở lại'), findsOneWidget);
    final confirm = find.descendant(
      of: find.byKey(const Key('app-sheet')),
      matching: find.byWidgetPredicate(
        (w) => w is AppButton && w.label == 'Rời studio',
      ),
    );
    final filled = tester.widget<FilledButton>(
      find.descendant(of: confirm, matching: find.byType(FilledButton)),
    );
    expect(filled.style?.backgroundColor?.resolve({}), AppColors.error);
    await tester.tap(confirm);
    await _settle(tester);
    _expectLast(w, 'leaveStudio', <String, Object?>{});
    expect(find.text('Bạn chưa ở studio nào'), findsOneWidget);
  });

  testWidgets(
    'leaving with open jobs shows the busy body and no leave button',
    (tester) async {
      final w = await _open(tester, seed: _member);
      await tester.tap(_key('my-studio-leave'));
      await _settle(tester);
      expect(find.text('Còn 2 buổi chụp được giao'), findsOneWidget);
      expect(
        find.text('Chụp xong hoặc nhờ studio giao người khác rồi rời.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('app-sheet')),
          matching: find.text('Rời studio'),
        ),
        findsNothing,
      );
      expect(w.studios.calls, isEmpty);
    },
  );

  testWidgets('invites while in a studio are dimmed with Bạn đang ở {studio}', (
    tester,
  ) async {
    await _open(tester, seed: _member);
    expect(find.text('Lời mời'), findsOneWidget);
    expect(findMeta('Bạn đang ở Studio Mây'), findsOneWidget);
    final row = tester.widget<MemberRow>(
      find.ancestor(
        of: find.text('Studio Nắng'),
        matching: find.byType(MemberRow),
      ),
    );
    expect(row.enabled, isFalse);
    expect(_button(tester, 'my-studio-accept-inv_nang').onPressed, isNull);
    expect(_button(tester, 'my-studio-decline-inv_nang').onPressed, isNull);
  });

  testWidgets('Nhận accepts, Từ chối declines', (tester) async {
    final w = await _open(
      tester,
      seed: (w) {
        w.intro = const PhotographerIntro(onboardingComplete: true);
        w.studios
          ..seedRelation(_invite)
          ..seedRelation(
            makeRelation(
              id: 'inv_hoa',
              studioId: 'hoa',
              studioName: 'Studio Hoa',
              status: RelationStatus.invited,
            ),
          );
      },
    );
    expect(findMeta('Hết hạn sau 5 ngày'), findsNWidgets(2));
    await tester.tap(_key('my-studio-decline-inv_hoa'));
    await _settle(tester);
    _expectLast(w, 'respondInvite', {'relationId': 'inv_hoa', 'accept': false});
    expect(find.text('Studio Hoa'), findsNothing);
    await tester.tap(_key('my-studio-accept-inv_nang'));
    await _settle(tester);
    _expectLast(w, 'respondInvite', {'relationId': 'inv_nang', 'accept': true});
    expect(find.text('Rời studio'), findsOneWidget);
  });

  testWidgets('not in a studio shows the empty state and a pending own '
      'request with Huỷ', (tester) async {
    final w = await _open(
      tester,
      seed: (w) {
        w.intro = const PhotographerIntro(onboardingComplete: true);
        w.studios
          ..seedRelation(_request)
          ..seedRelation(_invite);
      },
    );
    expect(find.text('Bạn chưa ở studio nào'), findsOneWidget);
    expect(
      find.text('Studio mời bạn, hoặc bạn xin gia nhập từ hồ sơ studio.'),
      findsOneWidget,
    );
    expect(find.text('Đã xin gia nhập Studio Mây · chờ duyệt'), findsOneWidget);
    expect(findMeta('Gửi 2 giờ trước · hết hạn sau 7 ngày'), findsOneWidget);
    expect(find.text('Rời studio'), findsNothing);
    expect(_button(tester, 'my-studio-accept-inv_nang').onPressed, isNotNull);
    await tester.tap(_key('my-studio-cancel-req_may'));
    await _settle(tester);
    _expectLast(w, 'cancelJoinRequest', {'relationId': 'req_may'});
    expect(find.text('Đã xin gia nhập Studio Mây · chờ duyệt'), findsNothing);
  });

  testWidgets('a refusal shows studioErrorText', (tester) async {
    final w = await _open(
      tester,
      seed: (w) {
        w.intro = const PhotographerIntro(onboardingComplete: true);
        w.studios.seedRelation(_invite);
      },
    );
    w.studios.nextError = 'cooldown';
    await tester.tap(_key('my-studio-accept-inv_nang'));
    await _settle(tester);
    expect(find.text('Chưa đủ 7 ngày kể từ lần rời studio.'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text ($brightness)', (tester) async {
      await _open(
        tester,
        seed: _member,
        width: 320,
        textScale: 1.3,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      expect(_key('my-studio-leave'), findsOneWidget);
      expect(_key('my-studio-accept-inv_nang'), findsOneWidget);
    });
  }
}
