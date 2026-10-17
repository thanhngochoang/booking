import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/data/safety/safety_providers.dart';
import 'package:photobooking/features/safety/report_sheet.dart';

import '../../support/fake_safety_repository.dart';
import '../../support/screen_host.dart';

void main() {
  late FakeSafetyRepository repo;

  setUp(() {
    repo = FakeSafetyRepository();
  });

  Future<void> pumpHost(
    WidgetTester tester,
    Widget child, {
    String myUid = 'u_me',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      screenApp(
        overrides: [
          safetyRepositoryProvider.overrideWithValue(repo),
          blockIndexProvider.overrideWith((ref) => repo.watchIndex()),
          authStateProvider.overrideWith(
            (ref) => Stream.value(AuthUser(uid: myUid)),
          ),
        ],
        home: Scaffold(body: child),
      ),
    );
  }

  group('ReportSheet', () {
    testWidgets('shows correct titles per target: user, post, message, event', (
      tester,
    ) async {
      await pumpHost(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showReportSheet(
              ctx,
              target: ReportTarget.user(uid: 'u_target', name: 'Minh Trí'),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo Minh Trí'), findsOneWidget);
      expect(
        find.text('Người bị báo cáo không biết ai đã báo cáo.'),
        findsOneWidget,
      );
    });

    testWidgets('post target title', (tester) async {
      await pumpHost(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showReportSheet(
              ctx,
              target: ReportTarget.post(
                postId: 'p1',
                authorId: 'u2',
                authorName: 'Minh Trí',
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo bài viết'), findsOneWidget);
    });

    testWidgets('message target title and quotes sender and text', (
      tester,
    ) async {
      await pumpHost(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showReportSheet(
              ctx,
              target: ReportTarget.message(
                chatId: 'c1',
                messageId: 'm1',
                senderId: 'u2',
                senderName: 'Minh Trí',
                text: 'Xin chào bạn',
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo tin nhắn'), findsOneWidget);
      expect(find.text('Minh Trí'), findsWidgets);
      expect(find.text('Xin chào bạn'), findsOneWidget);
    });

    testWidgets('event target title and hides block checkbox', (tester) async {
      await pumpHost(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showReportSheet(
              ctx,
              target: ReportTarget.event(
                eventId: 'e1',
                title: 'Workshop Nhiếp ảnh',
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo sự kiện'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets(
      'the seven reasons appear in order; submit disabled until one is picked',
      (tester) async {
        await pumpHost(
          tester,
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showReportSheet(
                ctx,
                target: ReportTarget.user(uid: 'u_target', name: 'Minh Trí'),
              ),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final submitBtn = find.byKey(const Key('report-submit'));
        expect(submitBtn, findsOneWidget);
        // Initially disabled
        final btnWidget = tester.widget<AppButton>(submitBtn);
        expect(btnWidget.onPressed, isNull);

        // Seven reasons in order
        expect(find.text('Spam hoặc quảng cáo'), findsOneWidget);
        expect(find.text('Lừa đảo, đòi chuyển tiền ngoài ứng dụng'), findsOneWidget);
        expect(find.text('Quấy rối hoặc xúc phạm'), findsOneWidget);
        expect(find.text('Nội dung nhạy cảm, không phù hợp'), findsOneWidget);
        expect(find.text('Ảnh lấy cắp, vi phạm bản quyền'), findsOneWidget);
        expect(find.text('Giả mạo người khác'), findsOneWidget);
        expect(find.text('Lý do khác'), findsOneWidget);

        // Pick spam
        await tester.tap(find.text('Spam hoặc quảng cáo'));
        await tester.pumpAndSettle();

        final enabledBtn = tester.widget<AppButton>(submitBtn);
        expect(enabledBtn.onPressed, isNotNull);
      },
    );

    testWidgets('"Lý do khác" needs 10 characters', (tester) async {
      await pumpHost(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showReportSheet(
              ctx,
              target: ReportTarget.user(uid: 'u_target', name: 'Minh Trí'),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lý do khác'));
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const Key('report-submit'));
      expect(tester.widget<AppButton>(submitBtn).onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, '123456789');
      await tester.pumpAndSettle();
      expect(tester.widget<AppButton>(submitBtn).onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, '1234567890');
      await tester.pumpAndSettle();
      expect(tester.widget<AppButton>(submitBtn).onPressed, isNotNull);
    });

    testWidgets('submit sends block when checked and shows feedback snackbar', (
      tester,
    ) async {
      await pumpHost(
        tester,
        Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showReportSheet(
              ctx,
              target: ReportTarget.user(uid: 'u_target', name: 'Minh Trí'),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spam hoặc quảng cáo'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('report-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-submit')));
      await tester.pumpAndSettle();

      expect(repo.reportCalls.length, 1);
      expect(repo.reportCalls.first.block, isTrue);
      expect(find.text('Đã gửi báo cáo và chặn Minh Trí.'), findsOneWidget);
    });
  });
}
