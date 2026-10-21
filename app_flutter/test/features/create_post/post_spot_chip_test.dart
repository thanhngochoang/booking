// test/features/create_post/post_spot_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/create_post/create_post_screen.dart';
import 'package:photobooking/features/create_post/post_composer.dart';
import 'package:photobooking/features/explore/location_controller.dart';

import '../../support/content_fixtures.dart';
import '../../support/create_post_world.dart';
import '../../support/fake_spot_repository.dart';
import '../../support/screen_host.dart';
import '../../support/spot_entry_fixture.dart';

class _Env {
  _Env({this.device});

  final ApproxLocation? device;
  final world = CreatePostWorld();
  final spots = FakeSpotRepository();
  late final FakePostPublisher publisher;
  late final ServiceSummary service;

  Future<void> open(WidgetTester tester) async {
    await world.init();
    service = fixtureService('s1', photographerId: world.uid);
    world.services.add(service);
    publisher = FakePostPublisher(posts: world.posts, clock: () => fixtureNow);
    spots.seedDirectory([
      spotEntryFixture(
        id: 'cau-dat',
        name: 'Đồi chè Cầu Đất',
        city: 'Đà Lạt',
        lat: 11.85,
        lng: 108.55,
      ),
      spotEntryFixture(id: 'ho-tay', name: 'Hồ Tây'),
    ]);
    await tester.pumpWidget(
      screenApp(
        home: CreatePostScreen(onAddService: () {}, onPublished: (_) {}),
        overrides: [
          ...world.overrides,
          imagePickerProvider.overrideWithValue(
            FakeImagePicker([
              [const PickedImage(path: '/tmp/a.jpg', name: 'a.jpg')],
            ]),
          ),
          mediaUploaderProvider.overrideWithValue(FakeMediaUploader()),
          postPublisherProvider.overrideWithValue(publisher),
          spotRepositoryProvider.overrideWithValue(spots),
          locationRepositoryProvider.overrideWithValue(
            FakeLocationRepository(
              status: LocationPermissionStatus.granted,
              location: device,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  PostComposerController ctl(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(CreatePostScreen)))
          .read(postComposerProvider.notifier);

  /// Types the place and lets the directory (and the device position) load.
  Future<void> place(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('create-location')), text);
    await tester.pumpAndSettle();
  }

  Future<void> publish(WidgetTester tester) async {
    final c = ctl(tester);
    await c.pickImages();
    c.setService(service);
    await tester.runAsync(() async {
      await c.publish();
    });
    await tester.pumpAndSettle();
  }
}

final _chip = find.byKey(const Key('create-spot-chip'));

void main() {
  testWidgets(
    'location text "Đồi chè Cầu Đất buổi sáng" suggests Đồi chè Cầu Đất',
    (tester) async {
      final e = _Env();
      await e.open(tester);
      await e.place(tester, 'Đồi chè Cầu Đất buổi sáng');
      expect(_chip, findsOneWidget);
      expect(find.text('Gắn với Đồi chè Cầu Đất'), findsOneWidget);
      expect(find.bySemanticsLabel('Bỏ gắn Đồi chè Cầu Đất'), findsOneWidget);
    },
  );

  testWidgets('"ho tay" (no accents) suggests Hồ Tây', (tester) async {
    final e = _Env();
    await e.open(tester);
    await e.place(tester, 'ho tay');
    expect(find.text('Gắn với Hồ Tây'), findsOneWidget);
  });

  testWidgets(
    'no text match but the device position inside Hồ Tây\'s radius suggests it',
    (tester) async {
      final e = _Env(
        device: ApproxLocation(
          lat: 21.0502,
          lng: 105.8203,
          capturedAt: DateTime.now(),
        ),
      );
      await e.open(tester);
      await e.place(tester, 'Gần nhà');
      expect(find.text('Gắn với Hồ Tây'), findsOneWidget);
    },
  );

  testWidgets('nothing matching: no chip', (tester) async {
    final e = _Env();
    await e.open(tester);
    await e.place(tester, 'Quán cà phê góc phố');
    expect(_chip, findsNothing);
    await e.place(tester, '');
    expect(_chip, findsNothing);
  });

  testWidgets('× removes the chip and the post publishes without spotId', (
    tester,
  ) async {
    final e = _Env();
    await e.open(tester);
    await e.place(tester, 'Hồ Tây');
    expect(_chip, findsOneWidget);
    await tester.ensureVisible(_chip);
    await tester.pumpAndSettle();
    await tester.tap(_chip);
    await tester.pumpAndSettle();
    expect(_chip, findsNothing);
    await e.publish(tester);
    expect(e.publisher.published.single.spotId, isNull);
  });

  testWidgets('a failed publish drops the tag so the retry goes without it', (
    tester,
  ) async {
    final e = _Env();
    await e.open(tester);
    await e.place(tester, 'Hồ Tây');
    e.publisher.failWith = Exception('rules');
    await e.publish(tester);
    expect(e.publisher.published, isEmpty);
    expect(_chip, findsNothing);
    e.publisher.failWith = null;
    await tester.runAsync(() => e.ctl(tester).publish());
    expect(e.publisher.published.single.spotId, isNull);
  });

  testWidgets('publishing with the chip sends spotId', (tester) async {
    final e = _Env();
    await e.open(tester);
    await e.place(tester, 'Hồ Tây');
    await e.publish(tester);
    expect(e.publisher.published.single.spotId, 'ho-tay');
  });

  testWidgets(
    'a removed chip stays off while its spot is suggested, a new place suggests again',
    (tester) async {
      final e = _Env();
      await e.open(tester);
      await e.place(tester, 'Hồ Tây');
      await tester.ensureVisible(_chip);
      await tester.pumpAndSettle();
      await tester.tap(_chip);
      await tester.pumpAndSettle();
      await e.place(tester, 'Hồ Tây lúc hoàng hôn');
      expect(_chip, findsNothing);
      await e.place(tester, 'Đồi chè Cầu Đất');
      expect(find.text('Gắn với Đồi chè Cầu Đất'), findsOneWidget);
    },
  );
}
