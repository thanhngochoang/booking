// test/features/contact/contact_action_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/features/contact/contact_action.dart';

import '../../core/widgets/widget_host.dart';

const _subject = ContactSubject.booking('b1');
const _numbers = ContactNumbers(phone: '+84903123456');
const _all = ContactChannels(call: true, zalo: true, whatsapp: true);
const _channelList = [
  ContactChannel.call,
  ContactChannel.zalo,
  ContactChannel.whatsapp,
];
const _button = Key('contact-dial-button');

class _SlowLinks implements ContactLinkRepository {
  final completer = Completer<Uri>();
  @override
  Future<Uri> link({
    required ContactSubject subject,
    required ContactChannel channel,
  }) => completer.future;
}

class _Harness {
  _Harness({
    bool unlocked = true,
    Set<String> unsupported = const {},
    bool failOpen = false,
  }) : links = FakeContactLinkRepository()
         ..add(_subject, numbers: _numbers, channels: _all, unlocked: unlocked),
       external = FakeExternalLauncher(
         unsupportedSchemes: unsupported,
         failOpen: failOpen,
       );
  final FakeContactLinkRepository links;
  final FakeExternalLauncher external;
  final events = <Map<String, Object?>>[];
  int inquiries = 0;

  void log(String name, Map<String, Object?> params) =>
      events.add({'name': name, ...params});
}

Future<void> _pump(
  WidgetTester tester,
  _Harness h, {
  ContactAccess access = ContactAccess.unlocked,
  List<ContactChannel> channels = _channelList,
  ContactLinkRepository? links,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contactLinkRepositoryProvider.overrideWithValue(links ?? h.links),
        externalLauncherProvider.overrideWithValue(h.external),
      ],
      child: hostWidget(
        Padding(
          padding: const EdgeInsets.only(top: 300, left: 290),
          child: ContactAction(
            access: access,
            channels: channels,
            subject: access == ContactAccess.unlocked ? _subject : null,
            source: 'S05.02',
            onInquiry: () => h.inquiries++,
            onEvent: h.log,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(_button));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Zalo opens the server-built link and logs the tap without a number',
    (tester) async {
      final h = _Harness();
      await _pump(tester, h);
      await _pick(tester, 'contact-zalo');
      expect(h.external.opened.map((u) => u.toString()), [
        'https://zalo.me/84903123456',
      ]);
      expect(h.links.requests.single.channel, ContactChannel.zalo);
      expect(h.events, [
        {'name': 'contact_tapped', 'channel': 'zalo', 'source': 'S05.02'},
      ]);
      expect(h.events.toString(), isNot(contains('903')));
    },
  );

  testWidgets('the dialer entry opens tel: with the plus', (tester) async {
    final h = _Harness();
    await _pump(tester, h);
    await _pick(tester, 'contact-call');
    expect(h.external.opened.single.toString(), 'tel:+84903123456');
  });

  testWidgets('one channel: the first tap goes straight through', (
    tester,
  ) async {
    final h = _Harness();
    await _pump(tester, h, channels: const [ContactChannel.whatsapp]);
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();
    expect(h.external.opened.single.toString(), 'https://wa.me/84903123456');
    expect(find.byKey(const Key('contact-tray')), findsNothing);
  });

  testWidgets(
    'a locked answer from the server shows the unlock hint and logs contact_locked',
    (tester) async {
      final h = _Harness(unlocked: false);
      await _pump(tester, h);
      await _pick(tester, 'contact-zalo');
      expect(h.external.opened, isEmpty);
      expect(
        find.text('Liên hệ qua điện thoại mở sau khi bạn đặt lịch'),
        findsOneWidget,
      );
      expect(h.events.map((e) => e['name']), [
        'contact_tapped',
        'contact_locked',
      ]);
      expect(h.events.last['source'], 'S05.02');
    },
  );

  testWidgets('a link the OS cannot open shows a retry message', (
    tester,
  ) async {
    final h = _Harness(failOpen: true);
    await _pump(tester, h);
    await _pick(tester, 'contact-zalo');
    expect(find.text('Không mở được liên hệ. Thử lại nhé.'), findsOneWidget);
  });

  testWidgets('the dialer is hidden on a device that cannot place calls', (
    tester,
  ) async {
    final h = _Harness(unsupported: {'tel'});
    await _pump(tester, h);
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-call')), findsNothing);
    expect(find.byKey(const Key('contact-zalo')), findsOneWidget);
    expect(find.byKey(const Key('contact-whatsapp')), findsOneWidget);
  });

  testWidgets('only the dialer on such a device leaves nothing to show', (
    tester,
  ) async {
    final h = _Harness(unsupported: {'tel'});
    await _pump(tester, h, channels: const [ContactChannel.call]);
    expect(find.byKey(_button), findsNothing);
  });

  testWidgets(
    'before booking: the inquiry button opens the chat and asks the server for nothing',
    (tester) async {
      final h = _Harness();
      await _pump(tester, h, access: ContactAccess.locked);
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(h.inquiries, 1);
      expect(h.links.requests, isEmpty);
      expect(h.external.opened, isEmpty);
      expect(h.events, [
        {'name': 'contact_tapped', 'channel': 'in_app', 'source': 'S05.02'},
      ]);
    },
  );

  testWidgets(
    'shows a spinner while the link is being fetched, then opens it',
    (tester) async {
      final h = _Harness();
      final slow = _SlowLinks();
      await _pump(tester, h, links: slow);
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('contact-whatsapp')));
      // The spinner never settles, so pump a fixed time instead.
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.descendant(
          of: find.byKey(_button),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      slow.completer.complete(Uri.parse('https://wa.me/84903123456'));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(h.external.opened.single.toString(), 'https://wa.me/84903123456');
    },
  );

  testWidgets('no phone number is ever on screen', (tester) async {
    final h = _Harness();
    await _pump(tester, h);
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();
    expect(find.textContaining('903'), findsNothing);
    expect(find.textContaining('+84'), findsNothing);
  });

  group('PhotographerContactAction', () {
    Future<void> pumpFor(
      WidgetTester tester,
      FakePhotographerContactRepository repo, {
      required ContactAccess access,
    }) async {
      final h = _Harness();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            photographerContactRepositoryProvider.overrideWithValue(repo),
            contactLinkRepositoryProvider.overrideWithValue(h.links),
            externalLauncherProvider.overrideWithValue(h.external),
          ],
          child: hostWidget(
            Padding(
              padding: const EdgeInsets.only(top: 300, left: 290),
              child: PhotographerContactAction(
                photographerId: 'p1',
                access: access,
                subject: access == ContactAccess.unlocked ? _subject : null,
                source: 'S05.02',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'unlocked: the tray lists exactly the channels the photographer switched on',
      (tester) async {
        final repo = FakePhotographerContactRepository()
          ..seed(
            'p1',
            channels: const ContactChannels(call: true, whatsapp: true),
          );
        await pumpFor(tester, repo, access: ContactAccess.unlocked);
        await tester.tap(find.byKey(_button));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('contact-call')), findsOneWidget);
        expect(find.byKey(const Key('contact-zalo')), findsNothing);
        expect(find.byKey(const Key('contact-whatsapp')), findsOneWidget);
      },
    );

    testWidgets(
      'unlocked but nothing switched on (or flags missing): no button',
      (tester) async {
        await pumpFor(
          tester,
          FakePhotographerContactRepository()
            ..seed('p1', channels: const ContactChannels()),
          access: ContactAccess.unlocked,
        );
        expect(find.byKey(_button), findsNothing);
        await pumpFor(
          tester,
          FakePhotographerContactRepository(),
          access: ContactAccess.unlocked,
        );
        expect(find.byKey(_button), findsNothing);
      },
    );

    testWidgets(
      'locked: inquiry button, unless the photographer turned inquiries off',
      (tester) async {
        await pumpFor(
          tester,
          FakePhotographerContactRepository(),
          access: ContactAccess.locked,
        );
        expect(find.byKey(_button), findsOneWidget);
        await pumpFor(
          tester,
          FakePhotographerContactRepository()..seed(
            'p1',
            channels: const ContactChannels(call: true, acceptInquiries: false),
          ),
          access: ContactAccess.locked,
        );
        expect(find.byKey(_button), findsNothing);
      },
    );
  });

  testWidgets('canOpen is probed once, not on every rebuild', (tester) async {
    final h = _Harness();
    Widget tree(double pad) => ProviderScope(
      overrides: [
        contactLinkRepositoryProvider.overrideWithValue(h.links),
        externalLauncherProvider.overrideWithValue(h.external),
      ],
      child: hostWidget(
        Padding(
          padding: EdgeInsets.only(top: 300, left: 290 - pad),
          child: ContactAction(
            access: ContactAccess.unlocked,
            channels: _channelList,
            subject: _subject,
            source: 'S05.02',
            onEvent: h.log,
          ),
        ),
      ),
    );
    await tester.pumpWidget(tree(0));
    await tester.pumpAndSettle();
    final first = h.external.canOpenCalls;
    expect(first, greaterThan(0));
    for (var i = 1; i <= 3; i++) {
      await tester.pumpWidget(tree(i.toDouble()));
      await tester.pumpAndSettle();
    }
    expect(h.external.canOpenCalls, first);
  });
}
