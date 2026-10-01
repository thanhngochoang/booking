// test/battery/feed_cards_battery_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/reason.dart';

import '../core/widgets/widget_host.dart';
import '../support/blur.dart';
import '../support/content_fixtures.dart';
import '../support/idle.dart';
import '../support/photo_scope.dart';

Widget _feed(List<PhotoRequest> log) => hostWidget(
  testPhotoScope(
    log: log,
    child: SingleChildScrollView(
      child: Column(
        children: [
          for (var i = 0; i < 5; i++)
            SizedBox(
              width: 300,
              child: PhotoCard(
                imageUrl: 'https://img.test/post$i.jpg',
                aspect: 4 / 5,
                title: 'Minh Trí',
                subtitle: 'Quận 3',
                leadingPill: const PhotoPill(label: 'Rảnh T7 này', dot: true),
                action: const Icon(Icons.bookmark_border),
                onTap: () {},
              ),
            ),
          for (var i = 0; i < 5; i++)
            PhotographerCard(
              data: fixturePhotographer('p$i', verified: i.isEven),
              reasons: const [Reason(code: ReasonCode.near, text: '1,2 km')],
              distanceKm: 1.2,
              availabilityLabel: 'Rảnh 12/10',
              onProfile: () {},
              onBook: () {},
            ),
          const AppAvatar(name: 'Minh Trí', url: 'https://img.test/a.jpg'),
        ],
      ),
    ),
  ),
  width: 390,
);

void main() {
  testWidgets(
    'a settled feed of cards keeps no frame scheduled and adds no blur',
    (tester) async {
      await tester.pumpWidget(_feed([]));
      await expectIdle(tester);
      expectBlurBudget(max: 0);
    },
  );

  testWidgets(
    'every photo is requested with a decode width, and avatars never retry',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final log = <PhotoRequest>[];
      await tester.pumpWidget(_feed(log));
      expect(log, isNotEmpty);
      for (final r in log) {
        expect(r.cacheWidth, isNotNull, reason: r.url);
        expect(r.cacheWidth! % 50, 0, reason: 'rounded to 50 px buckets');
      }
      final avatar = log.firstWhere((r) => r.url == 'https://img.test/a.jpg');
      expect(avatar.retry, isFalse);
      expect(
        avatar.cacheWidth,
        lessThanOrEqualTo(200),
        reason: '48 dp x 3 = 144 px, never the original',
      );
    },
  );

  group('the production image widget', () {
    final src = File('lib/core/widgets/network_photo.dart').readAsStringSync();

    test('decodes at display size and caches on disk', () {
      expect(src, contains('memCacheWidth: widget.cacheWidth'));
      expect(src, contains('CachedNetworkImage('));
      expect(src, isNot(contains('Image.network')));
      // `CachedNetworkImage(` contains the text, so match a bare NetworkImage.
      expect(RegExp(r'(?<![A-Za-z])NetworkImage\(').hasMatch(src), isFalse);
    });

    test('has no retry loop, timer or ticker of its own', () {
      for (final banned in [
        'Timer',
        'Ticker',
        'AnimationController',
        'Stream.periodic',
      ]) {
        expect(src, isNot(contains(banned)), reason: banned);
      }
      // The only animation is the 150 ms fade-in, which ends by itself.
      expect(
        src,
        contains('fadeInDuration: const Duration(milliseconds: 150)'),
      );
    });
  });

  test('no card widget uses BackdropFilter or a repeating animation', () {
    for (final name in [
      'app_avatar.dart',
      'reason_chips.dart',
      'photo_card.dart',
      'photographer_card.dart',
      'network_photo.dart',
    ]) {
      final s = File('lib/core/widgets/$name').readAsStringSync();
      expect(s, isNot(contains('BackdropFilter')), reason: name);
      expect(s, isNot(contains('AnimationController')), reason: name);
      expect(s, isNot(contains('.repeat(')), reason: name);
    }
  });
}
