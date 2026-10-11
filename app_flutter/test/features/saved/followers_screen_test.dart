import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/user/user_profile.dart';

import '../../support/saved_world.dart';

Future<SavedWorld> _world({UserRole role = UserRole.photographer}) async {
  final w = SavedWorld(role: role);
  await w.init();
  return w;
}

void main() {
  testWidgets('followers shows "128 người theo dõi · …" and rows with "Theo dõi từ 12/10"', (
    tester,
  ) async {
    final w = await _world(role: UserRole.photographer);
    w.savedFollowRepo.userDirectory['u1'] = (
      displayName: 'Lan Anh',
      avatarUrl: null,
    );
    w.savedFollowRepo.userDirectory['u2'] = (
      displayName: 'Minh Khoa',
      avatarUrl: null,
    );
    w.savedFollowRepo.addFollow(
      'u1',
      w.uid,
      DateTime.utc(2026, 10, 12),
    );
    w.savedFollowRepo.addFollow(
      'u2',
      w.uid,
      DateTime.utc(2026, 10, 11),
    );

    await tester.pumpWidget(w.app('/me/followers'));
    await tester.pumpAndSettle();

    expect(
      find.text('2 người theo dõi · chỉ bạn xem được danh sách này'),
      findsOneWidget,
    );

    expect(find.text('Lan Anh'), findsOneWidget);
    expect(find.text('Theo dõi từ 12/10'), findsOneWidget);
    expect(find.text('Minh Khoa'), findsOneWidget);
    expect(find.text('Theo dõi từ 11/10'), findsOneWidget);
  });

  testWidgets('followers rows are not tappable', (tester) async {
    final w = await _world(role: UserRole.photographer);
    w.savedFollowRepo.userDirectory['u1'] = (
      displayName: 'Lan Anh',
      avatarUrl: null,
    );
    w.savedFollowRepo.addFollow(
      'u1',
      w.uid,
      DateTime.utc(2026, 10, 12),
    );

    await tester.pumpWidget(w.app('/me/followers'));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('follower-row-u1'));
    expect(row, findsOneWidget);
    await tester.tap(row, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Still on followers screen
    expect(find.text('stub /u/u1'), findsNothing);
  });

  testWidgets('a customer opening /me/followers is sent to /profile', (
    tester,
  ) async {
    final w = await _world(role: UserRole.customer);

    await tester.pumpWidget(w.app('/me/followers'));
    await tester.pumpAndSettle();

    expect(find.text('stub /profile'), findsOneWidget);
  });

  testWidgets('empty followers state', (tester) async {
    final w = await _world(role: UserRole.photographer);

    await tester.pumpWidget(w.app('/me/followers'));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có người theo dõi'), findsOneWidget);
    expect(
      find.text('Đăng bài thường xuyên để có thêm người theo dõi.'),
      findsOneWidget,
    );
  });

  testWidgets('followers screen fits 320dp at 1.3x text', (tester) async {
    final w = await _world(role: UserRole.photographer);
    w.savedFollowRepo.userDirectory['u1'] = (
      displayName: 'Lan Anh',
      avatarUrl: null,
    );
    w.savedFollowRepo.addFollow(
      'u1',
      w.uid,
      DateTime.utc(2026, 10, 12),
    );

    tester.view.physicalSize = const Size(320 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      w.app('/me/followers', textScale: 1.3),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
