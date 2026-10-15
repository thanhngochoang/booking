// test/core/widgets/confirm_sheet_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/confirm_sheet.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

import 'widget_host.dart';

void main() {
  testWidgets('keep pops false without calling onConfirm', (tester) async {
    bool? result;
    var onConfirmCalled = false;

    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await showConfirmSheet(
                  context,
                  title: 'Huỷ buổi chụp?',
                  confirmLabel: 'Huỷ lịch',
                  keepLabel: 'Giữ lịch',
                  onConfirm: () async => onConfirmCalled = true,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Huỷ buổi chụp?'), findsOneWidget);
    expect(find.text('Giữ lịch'), findsOneWidget);
    expect(find.text('Huỷ lịch'), findsOneWidget);

    // Tap keep
    await tester.tap(find.text('Giữ lịch'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(onConfirmCalled, isFalse);
    expect(find.text('Huỷ buổi chụp?'), findsNothing);
  });

  testWidgets('double tap runs onConfirm once; sheet locked while running', (
    tester,
  ) async {
    bool? result;
    var callCount = 0;
    final completer = Completer<void>();

    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await showConfirmSheet(
                  context,
                  title: 'Xác nhận xoá?',
                  confirmLabel: 'Xoá',
                  keepLabel: 'Huỷ',
                  onConfirm: () async {
                    callCount++;
                    await completer.future;
                  },
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap confirm first time
    await tester.tap(find.text('Xoá'));
    await tester.pump(); // Start onConfirm

    expect(callCount, 1);

    // Tap confirm second time while running
    await tester.tap(find.text('Xoá'), warnIfMissed: false);
    await tester.pump();

    // Call count still 1
    expect(callCount, 1);

    // Try tapping Keep while running -> ignored
    await tester.tap(find.text('Huỷ'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Xác nhận xoá?'), findsOneWidget);

    // PopScope canPop is false while running
    final popScopeFinder = find.byWidgetPredicate(
      (w) => w is PopScope && w.canPop == false,
    );
    expect(popScopeFinder, findsOneWidget);

    // Complete onConfirm
    completer.complete();
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.text('Xác nhận xoá?'), findsNothing);
  });

  testWidgets('error keeps the sheet open with a SnackBar', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showConfirmSheet(
                  context,
                  title: 'Lỗi thử nghiệm',
                  confirmLabel: 'Thử',
                  keepLabel: 'Đóng',
                  onConfirm: () async => throw Exception('Lỗi mạng giả lập'),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thử'));
    await tester.pumpAndSettle();

    // Sheet is still open
    expect(find.text('Lỗi thử nghiệm'), findsOneWidget);
    // SnackBar is shown
    expect(find.text('Exception: Lỗi mạng giả lập'), findsOneWidget);
  });

  testWidgets('danger uses the red button, never the gradient', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showConfirmSheet(
                  context,
                  title: 'Nguy hiểm',
                  confirmLabel: 'Xác nhận xoá',
                  keepLabel: 'Quay lại',
                  danger: true,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Confirm button should be danger (red background) and have NO CtaSurface (gradient)
    expect(find.byType(CtaSurface), findsNothing);

    final filledBtn = tester.widget<FilledButton>(
      find.descendant(
        of: find.widgetWithText(AppButton, 'Xác nhận xoá'),
        matching: find.byType(FilledButton),
      ),
    );

    final bg = filledBtn.style?.backgroundColor?.resolve(const {});
    expect(bg, AppColors.error);
  });

  testWidgets(
    'confirmEnabled false disables confirm and updates when it flips',
    (tester) async {
      final enabledNotifier = ValueNotifier<bool>(false);
      var confirmed = false;

      await tester.pumpWidget(
        hostWidget(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showConfirmSheet(
                    context,
                    title: 'Có điều kiện',
                    confirmLabel: 'Đồng ý',
                    keepLabel: 'Đóng',
                    confirmEnabled: enabledNotifier,
                    onConfirm: () async => confirmed = true,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Confirm button is disabled initially
      final confirmBtnFinder = find.widgetWithText(AppButton, 'Đồng ý');
      final btnWidget = tester.widget<AppButton>(confirmBtnFinder);
      expect(btnWidget.onPressed, isNull);

      // Tap confirm -> nothing happens
      await tester.tap(find.text('Đồng ý'), warnIfMissed: false);
      await tester.pump();
      expect(confirmed, isFalse);

      // Flip enabled to true
      enabledNotifier.value = true;
      await tester.pumpAndSettle();

      final btnWidgetEnabled = tester.widget<AppButton>(confirmBtnFinder);
      expect(btnWidgetEnabled.onPressed, isNotNull);

      // Tap confirm -> triggers
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    },
  );

  testWidgets('renders cleanly at 320dp and 1.3x text in dark and light', (
    tester,
  ) async {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        hostWidget(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showConfirmSheet(
                    context,
                    title: 'Tiêu đề xác nhận rất dài có thể xuống dòng trên màn hình nhỏ',
                    body: 'Nội dung chi tiết giải thích cho hành động xác nhận này cũng khá dài',
                    confirmLabel: 'Xác nhận ngay',
                    keepLabel: 'Quay lại',
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
          width: 320,
          textScale: 1.3,
          brightness: brightness,
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Dismiss sheet
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
    }
  });
}
