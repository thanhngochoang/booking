// test/support/earnings_world.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/earnings_providers.dart';
import 'package:photobooking/data/earnings/earnings_repository.dart';
import 'package:photobooking/features/earnings/earnings_analytics.dart';
import 'package:photobooking/features/earnings/earnings_screen.dart';

import 'screen_host.dart';

/// 08/10/2026 09:00 in Vietnam.
final earningsNow = DateTime.utc(2026, 10, 8, 2);

/// A signed-in photographer with in-memory earnings, a recording analytics
/// hook and S06.05 mounted at `/work/earnings`; other routes are stubs.
class EarningsWorld {
  EarningsWorld({DateTime? now}) : now = now ?? earningsNow;

  /// The clock of the repository and of `clockProvider`; tests may move it.
  DateTime now;

  /// The signed-in user's password (email accounts).
  static const password = 'password1';

  late String uid;
  final auth = FakeAuthRepository();
  late final repo = FakeEarningsRepository(clock: () => now);

  /// Registers the signed-in photographer; call before [app].
  Future<void> init() async {
    final u = await auth.registerWithEmail('tri@b.vn', password, 'Minh Trí');
    uid = u.uid;
  }

  /// `(name, params)` of every analytics call.
  final events = <(String, Map<String, Object>)>[];
  late GoRouter router;

  EarningItem item(
    String id, {
    String day = '2026-10-12',
    int amount = 450000,
    EarningState state = EarningState.held,
    String name = 'Lan Anh',
    String label = 'Chân dung 2h',
    String? holdReason,
    DateTime? paidOutAt,
    String subjectType = 'booking',
    String? subjectId,
    int fee = 0,
    int tax = 0,
    int? net,
    int feeRateBp = 0,
    int taxRateBp = 0,
    bool estimated = true,
    int? milestonesDone,
    int? milestonesTotal,
    List<String> milestonesRefunded = const <String>[],
  }) => EarningItem(
    id: id,
    subjectType: subjectType,
    subjectId: subjectId ?? 'b-$id',
    counterpartName: name,
    subjectLabel: label,
    day: day,
    amountVnd: amount,
    state: state,
    holdReason: holdReason,
    paidOutAt: paidOutAt,
    feeVnd: fee,
    taxVnd: tax,
    netVnd: net,
    feeRateBp: feeRateBp,
    taxRateBp: taxRateBp,
    estimated: estimated,
    milestonesDone: milestonesDone,
    milestonesTotal: milestonesTotal,
    milestonesRefunded: milestonesRefunded,
  );

  PayoutAccountView account({
    String bank = 'VCB',
    String last4 = '3456',
    String holder = 'NGUYEN MINH TRI',
    DateTime? updatedAt,
    DateTime? activeFrom,
    PayoutNameStatus nameStatus = PayoutNameStatus.matched,
  }) => PayoutAccountView(
    accountId: 'acc-0',
    bankCode: bank,
    accountLast4: last4,
    holderName: holder,
    updatedAt: updatedAt ?? now,
    activeFrom: activeFrom ?? updatedAt ?? now,
    nameStatus: nameStatus,
  );

  List<Override> get overrides => [
    authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid))),
    authRepositoryProvider.overrideWithValue(auth),
    earningsRepositoryProvider.overrideWithValue(repo),
    clockProvider.overrideWithValue(() => now),
    earningsAnalyticsProvider.overrideWithValue(
      (name, params) => events.add((name, params)),
    ),
  ];

  Widget app({
    String location = '/work/earnings',
    double textScale = 1.0,
    Widget Function()? account,
  }) {
    Widget stub(BuildContext _, GoRouterState s) =>
        Scaffold(body: Text('stub ${s.uri}'));
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/work/earnings',
          builder: (_, _) => const EarningsScreen(),
          routes: [
            GoRoute(
              path: 'account',
              builder: account == null ? stub : (_, _) => account(),
            ),
          ],
        ),
        GoRoute(path: '/b/:id', builder: stub),
        GoRoute(path: '/bookings', builder: stub),
      ],
    );
    return screenRouterApp(
      router: router,
      overrides: overrides,
      textScale: textScale,
    );
  }
}

void usePhone(WidgetTester tester, {double width = 390, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
