import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

import '../../support/awards_world.dart';
import '../../support/content_fixtures.dart';
import '../../support/screen_host.dart';

Finder _key(String k) => find.byKey(Key(k));

const _pic = PickedImage(path: '/tmp/a.jpg', name: 'a.jpg');

Future<AwardsWorld> _open(
  WidgetTester tester, {
  String? awardId,
  void Function(AwardsWorld w)? seed,
  double width = 390,
  double textScale = 1.0,
}) async {
  usePhone(tester, width: width, height: width < 390 ? 700 : 900);
  AwardSheetHost.results.clear();
  final w = AwardsWorld();
  await w.init();
  seed?.call(w);
  await tester.pumpWidget(w.sheetApp(awardId: awardId, textScale: textScale));
  await tester.tap(_key('open'));
  await tester.pumpAndSettle();
  return w;
}

/// Fills the three required fields (competition, year, result).
Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(_key('award-competition'), 'VIPA 2024');
  await tester.enterText(_key('award-year'), '2024');
  await tester.tap(_key('award-result-gold'));
  await tester.pumpAndSettle();
}

Future<void> _openProof(WidgetTester tester) async {
  await tester.ensureVisible(_key('award-proof'));
  await tester.tap(_key('award-proof'));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester) =>
    tester.widget<AppButton>(_key('award-submit')).onPressed != null;

/// An uploader driven by the test whose uploads keep running after the
/// listener is gone, like a real upload task.
class _ManualUploader implements MediaUploader {
  final Map<String, StreamController<UploadEvent>> pending = {};
  final List<String> deleted = [];

  @override
  Stream<UploadEvent> upload(PickedImage image, {required String storagePath}) {
    final c = StreamController<UploadEvent>();
    pending[storagePath] = c;
    return c.stream;
  }

  void finish(String path) {
    pending[path]!
      ..add(
        UploadEvent.done(
          UploadedMedia(url: 'https://storage.test/$path', storagePath: path),
        ),
      )
      ..close();
  }

  @override
  Future<void> delete(String storagePath) async => deleted.add(storagePath);
}

Future<(AwardsWorld, _ManualUploader)> _openManual(WidgetTester tester) async {
  usePhone(tester);
  AwardSheetHost.results.clear();
  final w = AwardsWorld();
  await w.init();
  final manual = _ManualUploader();
  w.uploaderOverride = manual;
  w.picker.answers.add([_pic]);
  await tester.pumpWidget(
    screenApp(home: const AwardSheetHost(), overrides: w.overrides),
  );
  await tester.tap(_key('open'));
  await tester.pumpAndSettle();
  await _openProof(tester);
  await tester.tap(_key('award-add-image'));
  await tester.pump();
  await tester.pump();
  expect(manual.pending, hasLength(1));
  return (w, manual);
}

void main() {
  testWidgets('submit stays disabled without a proof', (tester) async {
    await _open(tester);
    expect(find.text('Thêm giải thưởng'), findsOneWidget);
    await _fill(tester);
    expect(_enabled(tester), isFalse);

    // An https link is a proof.
    await _openProof(tester);
    await tester.enterText(_key('award-link-0'), 'https://vipa.vn/2024');
    await tester.pumpAndSettle();
    await tester.tap(_key('award-proof-done'));
    await tester.pumpAndSettle();
    expect(_enabled(tester), isTrue);
    expect(find.text('0 ảnh · 1 link'), findsOneWidget);
  });

  testWidgets('an http link shows the https error', (tester) async {
    await _open(tester);
    await _fill(tester);
    await _openProof(tester);
    await tester.enterText(_key('award-link-0'), 'http://vipa.vn/2024');
    await tester.pumpAndSettle();
    expect(find.text('Link phải bắt đầu bằng https://'), findsOneWidget);
    await tester.tap(_key('award-proof-done'));
    await tester.pumpAndSettle();
    expect(_enabled(tester), isFalse);
  });

  testWidgets('a failed upload tile can be retried', (tester) async {
    final w = await _open(
      tester,
      seed: (w) => w.uploader.failNames.add('a.jpg'),
    );
    w.picker.answers.add([_pic]);
    await _fill(tester);
    await _openProof(tester);
    await tester.tap(_key('award-add-image'));
    await tester.pumpAndSettle();
    expect(_key('proof-retry-0'), findsOneWidget);
    expect(w.uploader.uploaded, isEmpty);

    w.uploader.failNames.clear();
    await tester.tap(_key('proof-retry-0'));
    await tester.pumpAndSettle();
    expect(_key('proof-retry-0'), findsNothing);
    expect(w.uploader.uploadCalls, 2);
    expect(w.uploader.uploaded, hasLength(1));
    expect(w.uploader.uploaded.single, startsWith('awardProofs/${w.uid}/'));
    await tester.tap(_key('award-proof-done'));
    await tester.pumpAndSettle();
    expect(_enabled(tester), isTrue);
  });

  testWidgets('closing without saving deletes uploaded files', (tester) async {
    final w = await _open(tester);
    w.picker.answers.add([_pic]);
    await _openProof(tester);
    await tester.tap(_key('award-add-image'));
    await tester.pumpAndSettle();
    expect(w.uploader.uploaded, hasLength(1));
    final path = w.uploader.uploaded.single;
    await tester.tap(_key('award-proof-done'));
    await tester.pumpAndSettle();

    await tester.tap(_key('award-close'));
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi?'), findsOneWidget);
    // Keep editing: nothing is deleted yet.
    await tester.tap(find.text('Tiếp tục sửa'));
    await tester.pumpAndSettle();
    expect(w.uploader.deleted, isEmpty);

    await tester.tap(_key('award-close'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Bỏ'));
    await tester.pumpAndSettle();
    expect(_key('award-competition'), findsNothing);
    expect(w.uploader.deleted, [path]);
    expect(AwardSheetHost.results, [null]);
  });

  testWidgets('closing an untouched sheet does not ask', (tester) async {
    await _open(tester);
    await tester.tap(_key('award-close'));
    await tester.pumpAndSettle();
    expect(_key('award-competition'), findsNothing);
    expect(find.text('Bỏ thay đổi?'), findsNothing);
  });

  testWidgets('removing an uploaded tile deletes its file', (tester) async {
    final w = await _open(tester);
    w.picker.answers.add([_pic]);
    await _openProof(tester);
    await tester.tap(_key('award-add-image'));
    await tester.pumpAndSettle();
    final path = w.uploader.uploaded.single;
    await tester.tap(_key('proof-remove-0'));
    await tester.pumpAndSettle();
    expect(w.uploader.deleted, [path]);
    expect(_key('proof-tile-0'), findsNothing);
  });

  testWidgets('a valid award is sent for review with its proofs', (
    tester,
  ) async {
    final w = await _open(tester);
    w.picker.answers.add([_pic]);
    await _fill(tester);
    await tester.enterText(_key('award-category'), 'Phong cảnh');
    await _openProof(tester);
    await tester.tap(_key('award-add-image'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('award-link-0'), 'https://vipa.vn/2024');
    await tester.tap(_key('award-proof-done'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('award-submit'));
    await tester.tap(_key('award-submit'));
    await tester.pumpAndSettle();

    expect(w.awardRepo.calls.single, startsWith('create:'));
    final d = w.awardRepo.drafts.single;
    expect(d.competition, 'VIPA 2024');
    expect(d.year, 2024);
    expect(d.category, 'Phong cảnh');
    expect(d.result, AwardResult.gold);
    expect(d.proofPaths, w.uploader.uploaded);
    expect(d.proofPaths.single, contains('/${d.awardId}/'));
    expect(d.proofLinks, ['https://vipa.vn/2024']);
    expect(AwardSheetHost.results, [true]);
    // Saved files belong to the award now.
    expect(w.uploader.deleted, isEmpty);
  });

  testWidgets('a year outside 1950 to this year is refused', (tester) async {
    await _open(tester);
    await _fill(tester);
    await tester.enterText(_key('award-year'), '2031');
    await tester.pumpAndSettle();
    expect(find.text('Năm từ 1950 đến 2026'), findsOneWidget);
    await tester.enterText(_key('award-year'), '1949');
    await tester.pumpAndSettle();
    expect(find.text('Năm từ 1950 đến 2026'), findsOneWidget);
  });

  testWidgets('a rejected save keeps the sheet and says why', (tester) async {
    final w = await _open(tester);
    w.awardRepo.failWith = const AwardError('limit_exceeded');
    await _fill(tester);
    await _openProof(tester);
    await tester.enterText(_key('award-link-0'), 'https://vipa.vn/2024');
    await tester.tap(_key('award-proof-done'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('award-submit'));
    await tester.tap(_key('award-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đã khai tối đa 50 giải.'), findsOneWidget);
    expect(_key('award-competition'), findsOneWidget);
    expect(AwardSheetHost.results, isEmpty);
  });

  testWidgets('editing loads the award and saves it with update', (
    tester,
  ) async {
    final w = await _open(
      tester,
      awardId: 'a1',
      seed: (w) => w.awardRepo.add(
        w.award('a1', competition: 'VIPA', year: 2024, category: 'Chân dung'),
      ),
    );
    expect(find.text('Sửa giải thưởng'), findsOneWidget);
    expect(
      tester.widget<TextField>(_key('award-competition')).controller!.text,
      'VIPA',
    );
    expect(
      tester.widget<TextField>(_key('award-category')).controller!.text,
      'Chân dung',
    );
    // The fake draft has no proofs: add one, then save.
    await _openProof(tester);
    await tester.enterText(_key('award-link-0'), 'https://vipa.vn/x');
    await tester.tap(_key('award-proof-done'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('award-submit'));
    await tester.tap(_key('award-submit'));
    await tester.pumpAndSettle();
    expect(w.awardRepo.calls, ['update:a1']);
    expect(AwardSheetHost.results, [true]);
  });

  testWidgets('the work picker lists own work posts and chooses one', (
    tester,
  ) async {
    final w = await _open(
      tester,
      seed: (w) {
        w.posts.add(
          fixturePost('w1', photographerId: w.uid, caption: 'Sương sớm'),
        );
        w.posts.add(
          fixturePost(
            'r1',
            photographerId: w.uid,
            kind: PostKind.realShoot,
            caption: 'Không phải tác phẩm',
          ),
        );
      },
    );
    await tester.ensureVisible(_key('award-work'));
    await tester.tap(_key('award-work'));
    await tester.pumpAndSettle();
    expect(_key('post-pick-w1'), findsOneWidget);
    expect(_key('post-pick-r1'), findsNothing);
    await tester.tap(_key('post-pick-w1'));
    await tester.pumpAndSettle();
    expect(find.text('Đã chọn một tác phẩm'), findsOneWidget);
    expect(w.awardRepo.calls, isEmpty);

    // Clearing it again.
    await tester.tap(_key('award-work'));
    await tester.pumpAndSettle();
    await tester.tap(_key('award-work-clear'));
    await tester.pumpAndSettle();
    expect(find.text('Không gắn tác phẩm'), findsOneWidget);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('fits $width wide at text scale 1.3', (tester) async {
      final w = await _open(tester, width: width, textScale: 1.3);
      w.picker.answers.add([_pic, _pic, _pic]);
      await _fill(tester);
      expect(tester.takeException(), isNull);
      await _openProof(tester);
      await tester.tap(_key('award-add-image'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('removing a tile mid-upload deletes the file when it finishes', (
    tester,
  ) async {
    final (_, manual) = await _openManual(tester);
    final path = manual.pending.keys.single;
    await tester.tap(_key('proof-remove-0'));
    await tester.pump();
    expect(_key('proof-tile-0'), findsNothing);
    expect(manual.deleted, isEmpty);

    manual.finish(path);
    await tester.pumpAndSettle();
    expect(manual.deleted, [path]);
    expect(_key('proof-tile-0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing the sheet mid-upload deletes the file when it '
      'finishes', (tester) async {
    final (_, manual) = await _openManual(tester);
    final path = manual.pending.keys.single;
    await tester.tap(_key('award-proof-done'));
    await tester.pumpAndSettle();
    await tester.tap(_key('award-close'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Bỏ'));
    await tester.pumpAndSettle();
    expect(_key('award-competition'), findsNothing);

    manual.finish(path);
    await tester.pumpAndSettle();
    expect(manual.deleted, [path]);
    expect(tester.takeException(), isNull);
  });
}
