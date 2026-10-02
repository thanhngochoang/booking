// test/features/discovery/book_entry_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/features/discovery/book_entry.dart';

import '../../support/discovery_world.dart';
import '../../support/screen_host.dart';

class _Button extends ConsumerWidget {
  const _Button({this.serviceId, this.date});
  final String? serviceId;
  final DateTime? date;
  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    onPressed: () => startBooking(
      context,
      ref,
      photographerId: 'p1',
      serviceId: serviceId,
      date: date,
    ),
    child: const Text('đặt'),
  );
}

Future<Widget> _app(
  DiscoveryWorld w, {
  String? serviceId,
  DateTime? date,
}) async {
  await w.init();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: _Button(serviceId: serviceId, date: date),
        ),
      ),
      GoRoute(path: '/u/:id/book', builder: (_, s) => Text('book ${s.uri}')),
      GoRoute(
        path: '/profile/phone',
        builder: (_, s) => Text('phone ${s.uri.queryParameters['returnTo']}'),
      ),
    ],
  );
  return screenRouterApp(router: router, overrides: w.overrides);
}

void main() {
  test('bookingPath carries the service and the day', () {
    expect(bookingPath(photographerId: 'p1'), '/u/p1/book');
    expect(
      bookingPath(photographerId: 'p1', serviceId: 's1'),
      '/u/p1/book?serviceId=s1',
    );
    expect(
      bookingPath(
        photographerId: 'p1',
        serviceId: 's1',
        date: DateTime.utc(2026, 10, 12),
      ),
      '/u/p1/book?serviceId=s1&date=2026-10-12',
    );
    expect(
      bookingPath(photographerId: 'p1', date: DateTime(2026, 1, 5)),
      '/u/p1/book?date=2026-01-05',
    );
  });

  testWidgets('with a phone number the booking opens straight away', (
    tester,
  ) async {
    await tester.pumpWidget(await _app(DiscoveryWorld(), serviceId: 's1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('đặt'));
    await tester.pumpAndSettle();
    expect(find.text('book /u/p1/book?serviceId=s1'), findsOneWidget);
  });

  testWidgets(
    'without a phone number S04.05 comes first, with the booking as returnTo',
    (tester) async {
      await tester.pumpWidget(
        await _app(
          DiscoveryWorld(hasPhone: false),
          serviceId: 's1',
          date: DateTime.utc(2026, 10, 12),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('đặt'));
      await tester.pumpAndSettle();
      expect(
        find.text('phone /u/p1/book?serviceId=s1&date=2026-10-12'),
        findsOneWidget,
      );
    },
  );
}
