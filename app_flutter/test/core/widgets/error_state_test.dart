import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import 'widget_host.dart';

void main() {
  testWidgets('shows the message and a retry button that works', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      hostWidget(
        ErrorState(message: 'Không có kết nối', onRetry: () => retried++),
      ),
    );
    expect(find.text('Không có kết nối'), findsOneWidget);
    await tester.tap(find.byKey(const Key('error-retry')));
    expect(retried, 1);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('without a handler there is no button', (tester) async {
    await tester.pumpWidget(hostWidget(const ErrorState(message: 'Lỗi')));
    expect(find.byKey(const Key('error-retry')), findsNothing);
  });

  testWidgets('fits 320dp at 1.3x', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        ErrorState(
          message: 'Không tải được sự kiện. Kiểm tra mạng rồi thử lại nhé bạn.',
          onRetry: () {},
        ),
        width: 320,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  group('errorMessage', () {
    testWidgets('maps network and timeout errors to authErrorNetwork', (
      tester,
    ) async {
      late final AppLocalizations l;
      await tester.pumpWidget(
        hostWidget(
          Builder(
            builder: (context) {
              l = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(errorMessage(Exception('network error'), l), l.authErrorNetwork);
      expect(errorMessage(Exception('offline'), l), l.authErrorNetwork);
      expect(errorMessage(Exception('socket failure'), l), l.authErrorNetwork);
      expect(errorMessage(Exception('something unknown'), l), l.authErrorUnknown);
    });
  });
}

