import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/support/support_providers.dart';
import 'package:photobooking/data/support/support_thread.dart';
import 'package:photobooking/features/disputes/dispute_detail_screen.dart';

import '../../support/dispute_world.dart';
import '../../support/fake_support_repository.dart';
import '../../support/screen_host.dart';

const _id = '01JDZ8Y3VQK7Q2';

DisputeOutcome _outcome(
  DisputeOutcomeKind kind, {
  int percent = 0,
  int refund = 0,
  int release = 1500000,
  String note = 'Thợ ảnh đã giao bù đủ 40 ảnh nhưng trễ 3 ngày.',
}) => DisputeOutcome(
  kind: kind,
  refundPercent: percent,
  refundAmount: refund,
  releaseAmount: release,
  note: note,
  decidedAt: DateTime.utc(2026, 10, 15, 9, 40), // 16:40 15/10 in Vietnam
);

Dispute _resolved(DisputeOutcome outcome, {String providerId = 'p1'}) =>
    fixtureDispute(
      _id,
      providerId: providerId,
      providerName: providerId == 'platform' ? null : 'Minh Trí',
      subjectType: providerId == 'platform'
          ? DisputeSubjectType.ticket
          : DisputeSubjectType.booking,
      eventId: providerId == 'platform' ? 'e1' : null,
      status: DisputeStatus.resolved,
      outcome: outcome,
      resolvedAt: outcome.decidedAt,
    );

SupportMessage _msg(
  String id,
  SupportSenderRole role,
  String? senderId,
  String name,
  String body,
  int minute,
) => SupportMessage(
  id: id,
  threadId: 'dispute_$_id',
  senderId: senderId,
  senderRole: role,
  senderName: name,
  body: body,
  createdAt: DateTime.utc(2026, 10, 14, 3, minute),
);

final _thread = [
  _msg(
    'm0',
    SupportSenderRole.system,
    null,
    'Hệ thống',
    'Khiếu nại đã được gửi. Tiền được giữ tới khi có kết quả.',
    12,
  ),
  _msg(
    'm1',
    SupportSenderRole.customer,
    'c1',
    'Lan',
    'Gói 40 ảnh nhưng mình chỉ nhận được 28 ảnh.',
    12,
  ),
  _msg(
    'm2',
    SupportSenderRole.staff,
    'staff1',
    'Nhân Viên',
    'Chào chị, em đã nhận khiếu nại.',
    20,
  ),
  _msg(
    'm3',
    SupportSenderRole.provider,
    'p1',
    'Minh Trí',
    'Em đã gửi bù 12 ảnh còn thiếu.',
    30,
  ),
];

class _Harness {
  _Harness(this.world, this.support);
  final DisputeWorld world;
  final FakeSupportRepository support;
}

Future<_Harness> _open(
  WidgetTester tester, {
  String uid = 'c1',
  Iterable<Dispute> disputes = const [],
  String id = _id,
  List<SupportMessage>? messages,
  double width = 390,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width * 2, 800 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final world = DisputeWorld(uid: uid, disputes: disputes);
  final support = FakeSupportRepository(
    initialThread: SupportThread(
      id: 'dispute_$id',
      kind: SupportThreadKind.dispute,
      disputeId: id,
      participants: const ['c1', 'p1'],
      status: 'open',
      awaitingStaff: false,
    ),
    initialMessages: messages ?? _thread,
  );
  final router = GoRouter(
    initialLocation: '/disputes/$id',
    routes: [
      GoRoute(
        path: '/disputes/:id',
        builder: (_, s) =>
            DisputeDetailScreen(disputeId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/help/chat',
        builder: (_, _) => const Scaffold(body: Text('help-chat-page')),
      ),
    ],
  );
  await tester.pumpWidget(
    screenRouterApp(
      router: router,
      textScale: textScale,
      overrides: [
        ...world.overrides,
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(initialUser: AuthUser(uid: uid)),
        ),
        supportRepositoryProvider.overrideWithValue(support),
      ],
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return _Harness(world, support);
}

Finder get _scrollable => find
    .descendant(
      of: find.byKey(const Key('dispute-detail-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: _scrollable);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('customer view of an open dispute: "Khiếu nại #K7Q2", '
      '"Đang xem xét", "Tiền đang giữ 1.500.000₫", three steps with '
      '"Hỗ trợ đang xem xét" current', (tester) async {
    await _open(
      tester,
      disputes: [
        fixtureDispute(
          _id,
          evidencePaths: const [
            'disputeEvidence/c1/d/f1.jpg',
            'disputeEvidence/c1/d/f2.jpg',
          ],
        ),
      ],
    );
    expect(find.text('Khiếu nại #K7Q2'), findsOneWidget);
    // The badge is upper case like every status badge (mock `.badge`).
    expect(find.text('ĐANG XEM XÉT'), findsOneWidget);
    expect(find.text('Minh Trí · Chân dung'), findsOneWidget);
    expect(find.text('Tiền đang giữ'), findsOneWidget);
    expect(find.text('1.500.000₫'), findsOneWidget);
    expect(find.text('Tạm dừng chuyển cho tới khi có kết quả'), findsOneWidget);
    expect(find.text('Gửi lúc'), findsOneWidget);
    // Opened 07:00 UTC on 20/10 = 14:00 in Vietnam.
    expect(find.text('14:00 20/10'), findsOneWidget);

    final timeline = tester.widget<StatusTimeline>(find.byType(StatusTimeline));
    expect(
      [for (final s in timeline.steps) (s.title, s.state)],
      [
        ('Đã gửi khiếu nại', TimelineStepState.done),
        ('Hỗ trợ đang xem xét', TimelineStepState.current),
        ('Kết quả', TimelineStepState.upcoming),
      ],
    );
    expect(timeline.steps.first.subtitle, 'Mô tả và 2 ảnh bằng chứng');
    // The composer sits in the footer, outside the scroll view.
    expect(find.byKey(const Key('support-composer')), findsOneWidget);
    expect(find.text('Nhắn cho hỗ trợ…'), findsOneWidget);
  });

  testWidgets('provider view of a split outcome reads "Hoàn cho khách '
      '600.000₫" and "Chuyển cho bạn 900.000₫"', (tester) async {
    await _open(
      tester,
      uid: 'p1',
      disputes: [
        _resolved(
          _outcome(
            DisputeOutcomeKind.split,
            percent: 40,
            refund: 600000,
            release: 900000,
          ),
        ),
      ],
    );
    expect(find.text('ĐÃ XỬ LÝ'), findsOneWidget);
    expect(find.text('Chia: hoàn 40%'), findsOneWidget);
    expect(find.text('Hoàn cho khách'), findsOneWidget);
    expect(find.text('600.000₫'), findsOneWidget);
    expect(find.text('Chuyển cho bạn'), findsOneWidget);
    expect(find.text('900.000₫'), findsOneWidget);
    expect(find.text('Hoàn cho bạn'), findsNothing);
  });

  testWidgets('customer view of split reads "Hoàn cho bạn" and "Chuyển cho '
      'Minh Trí"', (tester) async {
    await _open(
      tester,
      disputes: [
        _resolved(
          _outcome(
            DisputeOutcomeKind.split,
            percent: 40,
            refund: 600000,
            release: 900000,
          ),
        ),
      ],
    );
    expect(find.text('Đã có kết quả · 16:40 15/10'), findsOneWidget);
    expect(find.text('Hoàn cho bạn'), findsOneWidget);
    expect(find.text('Về tài khoản hoặc ví đã thanh toán'), findsOneWidget);
    expect(find.text('Chuyển cho Minh Trí'), findsOneWidget);
    expect(find.text('Hoàn cho khách'), findsNothing);
  });

  testWidgets('release outcome reads "Chuyển tiền cho {name}"; refund reads '
      '"Hoàn 100%"', (tester) async {
    await _open(
      tester,
      disputes: [_resolved(_outcome(DisputeOutcomeKind.release))],
    );
    expect(find.text('Chuyển tiền cho Minh Trí'), findsOneWidget);
    expect(find.text('Chuyển cho Minh Trí'), findsOneWidget);
    // Nothing refunded: no refund row.
    expect(find.text('Hoàn cho bạn'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await _open(
      tester,
      disputes: [
        _resolved(
          _outcome(
            DisputeOutcomeKind.refund,
            percent: 100,
            refund: 1500000,
            release: 0,
          ),
        ),
      ],
    );
    expect(find.text('Hoàn 100%'), findsOneWidget);
    expect(find.text('Hoàn cho bạn'), findsOneWidget);
    expect(find.text('1.500.000₫'), findsOneWidget);
    expect(find.textContaining('Chuyển cho'), findsNothing);
  });

  testWidgets('platform event release names "ứng dụng"', (tester) async {
    await _open(
      tester,
      disputes: [
        _resolved(_outcome(DisputeOutcomeKind.release), providerId: 'platform'),
      ],
    );
    expect(find.text('Chuyển tiền cho ứng dụng'), findsOneWidget);
    expect(find.text('Chuyển cho ứng dụng'), findsOneWidget);
  });

  testWidgets('the staff note shows "Ghi chú của hỗ trợ: …"', (tester) async {
    await _open(
      tester,
      disputes: [
        _resolved(_outcome(DisputeOutcomeKind.release, note: 'Đã đủ ảnh.')),
      ],
    );
    expect(find.text('Ghi chú của hỗ trợ: Đã đủ ảnh.'), findsOneWidget);
  });

  testWidgets('messages are labelled Hỗ trợ / "{name} · nhiếp ảnh gia" / mine '
      'unlabelled', (tester) async {
    await _open(tester, disputes: [fixtureDispute(_id)]);
    await _scrollTo(tester, find.byKey(const Key('bubble-m3')));

    ChatBubble bubble(String id) =>
        tester.widget<ChatBubble>(find.byKey(Key('bubble-$id')));
    expect(bubble('m0').content, isA<SystemContent>());
    expect(bubble('m1').mine, isTrue);
    expect(bubble('m1').senderName, isNull);
    expect(bubble('m2').mine, isFalse);
    expect(bubble('m2').senderName, 'Hỗ trợ');
    expect(bubble('m3').senderName, 'Minh Trí · nhiếp ảnh gia');
    expect(find.text('Trao đổi'), findsOneWidget);
  });

  testWidgets('the provider sees the customer labelled "{name} · khách"; a '
      'ticket host is "{name} · chủ sự kiện"', (tester) async {
    await _open(tester, uid: 'p1', disputes: [fixtureDispute(_id)]);
    await _scrollTo(tester, find.byKey(const Key('bubble-m3')));
    ChatBubble bubble(String id) =>
        tester.widget<ChatBubble>(find.byKey(Key('bubble-$id')));
    expect(bubble('m1').senderName, 'Lan · khách');
    expect(bubble('m3').mine, isTrue);
    expect(bubble('m3').senderName, isNull);

    await tester.pumpWidget(const SizedBox());
    await _open(
      tester,
      disputes: [
        fixtureDispute(
          _id,
          subjectType: DisputeSubjectType.ticket,
          eventId: 'e1',
          providerName: 'Hà Host',
        ),
      ],
      messages: [
        _msg('h1', SupportSenderRole.provider, 'p1', 'Hà Host', 'Có ạ', 40),
      ],
    );
    await _scrollTo(tester, find.byKey(const Key('bubble-h1')));
    expect(bubble('h1').senderName, 'Hà Host · chủ sự kiện');
  });

  testWidgets('sending from the composer posts to the dispute thread', (
    tester,
  ) async {
    final h = await _open(tester, disputes: [fixtureDispute(_id)]);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('support-composer')),
        matching: find.byType(TextField),
      ),
      'Mình gửi thêm ảnh chụp màn hình',
    );
    await tester.pump();
    await tester.tap(find.byIcon(AppIcons.forward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.support.sentCalls.single.threadId, 'dispute_$_id');
    expect(h.support.sentBodies.single, 'Mình gửi thêm ảnh chụp màn hình');
  });

  testWidgets('resolved: no composer, the closed text and "Liên hệ hỗ trợ" '
      'pushes /help/chat', (tester) async {
    await _open(
      tester,
      disputes: [_resolved(_outcome(DisputeOutcomeKind.release))],
    );
    expect(find.byKey(const Key('support-composer')), findsNothing);
    await _scrollTo(
      tester,
      find.text('Khiếu nại đã đóng. Cần thêm hỗ trợ? Liên hệ ở mục Trợ giúp.'),
    );
    // Read-only: the messages are still there.
    await _scrollTo(tester, find.byKey(const Key('bubble-m3')));
    // No timeline once there is an outcome (mock S18.02-resolved).
    expect(find.byType(StatusTimeline), findsNothing);

    await tester.tap(find.text('Liên hệ hỗ trợ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('help-chat-page'), findsOneWidget);
  });

  testWidgets('an unknown or forbidden id shows "Không tìm thấy khiếu nại"', (
    tester,
  ) async {
    await _open(tester, id: 'missing');
    expect(find.text('Không tìm thấy khiếu nại'), findsOneWidget);
    expect(
      find.text('Khiếu nại này không tồn tại hoặc bạn không có quyền xem.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('support-composer')), findsNothing);
  });

  testWidgets('tapping an evidence photo opens it full screen', (tester) async {
    await _open(
      tester,
      disputes: [
        fixtureDispute(
          _id,
          evidencePaths: const [
            'disputeEvidence/c1/d/f1.jpg',
            'disputeEvidence/c1/d/f2.jpg',
          ],
        ),
      ],
    );
    final photo = find.byKey(const Key('dispute-evidence-1'));
    await _scrollTo(tester, photo);
    expect(find.text('Mô tả & ảnh'), findsOneWidget);
    expect(find.text('Thiếu 20 ảnh so với gói đã chọn'), findsWidgets);
    await tester.tap(photo);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('dispute-evidence-viewer')), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey(
          'photo:https://storage.test/disputeEvidence/c1/d/f2.jpg',
        ),
      ),
      findsWidgets,
    );
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _open(
      tester,
      width: 320,
      textScale: 1.3,
      disputes: [
        fixtureDispute(
          _id,
          evidencePaths: const ['disputeEvidence/c1/d/f1.jpg'],
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    await _scrollTo(tester, find.byKey(const Key('bubble-m3')));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await _open(
      tester,
      width: 320,
      textScale: 1.3,
      disputes: [
        _resolved(
          _outcome(
            DisputeOutcomeKind.split,
            percent: 40,
            refund: 600000,
            release: 900000,
          ),
        ),
      ],
    );
    expect(tester.takeException(), isNull);
  });
}
