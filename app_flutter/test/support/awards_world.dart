// test/support/awards_world.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/award/award_providers.dart';
import 'package:photobooking/data/award/award_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/features/awards/edit_award_sheet.dart';
import 'package:photobooking/features/awards/my_awards_screen.dart';

import 'content_fixtures.dart';
import 'create_post_world.dart';
import 'screen_host.dart';

/// The signed-in photographer of [CreatePostWorld] with in-memory awards, a
/// fake uploader and picker, and S25.01 mounted at `/me/awards`.
class AwardsWorld extends CreatePostWorld {
  AwardsWorld({super.prefsValues});

  late FakeAwardRepository awardRepo;
  final uploader = FakeMediaUploader();
  final picker = QueuePicker();
  late GoRouter router;

  @override
  Future<void> init() async {
    await super.init();
    awardRepo = FakeAwardRepository(uid: uid);
  }

  /// An award of the signed-in user.
  Award award(
    String id, {
    AwardStatus status = AwardStatus.approved,
    String competition = 'Sony World Photography Awards',
    int year = 2025,
    AwardResult result = AwardResult.gold,
    String? category,
    String? note,
  }) => fixtureAward(
    id,
    photographerId: uid,
    status: status,
    competition: competition,
    year: year,
    result: result,
    category: category,
    reviewNote: note,
  );

  @override
  List<Override> get overrides => [
    ...super.overrides,
    awardRepositoryProvider.overrideWithValue(awardRepo),
    mediaUploaderProvider.overrideWithValue(uploader),
    imagePickerProvider.overrideWithValue(picker),
    clockProvider.overrideWithValue(() => fixtureNow),
  ];

  Widget app({
    String location = '/me/awards',
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) {
    Widget stub(BuildContext _, GoRouterState s) => Text('stub ${s.uri}');
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/me/awards', builder: (_, _) => const MyAwardsScreen()),
        GoRoute(path: '/profile', builder: stub),
      ],
    );
    return screenRouterApp(
      router: router,
      overrides: overrides,
      brightness: brightness,
      textScale: textScale,
    );
  }

  /// A host with one button that opens S25.02 for [awardId] (new when null).
  Widget sheetApp({
    String? awardId,
    double textScale = 1.0,
    Brightness brightness = Brightness.dark,
  }) => screenApp(
    home: AwardSheetHost(awardId: awardId),
    overrides: overrides,
    brightness: brightness,
    textScale: textScale,
  );
}

/// Uses a phone-sized, tall view so sheets lay out fully.
void usePhone(WidgetTester tester, {double width = 390, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Opens S25.02 from a button and records what it returns.
class AwardSheetHost extends StatelessWidget {
  const AwardSheetHost({super.key, this.awardId});
  final String? awardId;

  static final results = <Object?>[];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const Key('open'),
        onPressed: () async {
          results.add(await showEditAwardSheet(context, awardId: awardId));
        },
        child: const Text('mở'),
      ),
    ),
  );
}

/// An image picker that answers with the queued lists, one per call.
class QueuePicker implements ImagePickerPort {
  final answers = <List<PickedImage>>[];
  int calls = 0;

  @override
  Future<List<PickedImage>> pickImages({required int max}) async {
    calls++;
    return answers.isEmpty ? const [] : answers.removeAt(0).take(max).toList();
  }
}
