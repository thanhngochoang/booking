import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_providers.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/features/disputes/dispute_entry.dart';

import '../../support/dispute_world.dart';
import '../../support/screen_host.dart';

Finder _key(String k) => find.byKey(Key(k));

PickedImage _pic(int i) => PickedImage(path: '/tmp/e$i.jpg', name: 'e$i.jpg');

/// Opens S18.01 from a button and records what the sheet resolved to.
class _Host extends StatelessWidget {
  const _Host({
    required this.subject,
    required this.closesAt,
    required this.origin,
  });

  final DisputeSubject subject;
  final DateTime closesAt;
  final DisputeOrigin origin;

  static final results = <String?>[];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const Key('open'),
        onPressed: () async {
          results.add(
            await showOpenDisputeSheet(
              context,
              subject: subject,
              summary: const DisputeSubjectSummary(
                title: 'Minh Trí · Chân dung 2 giờ',
                subtitle: 'T2 19/10 · 15:30–17:30',
              ),
              closesAt: closesAt,
              origin: origin,
            ),
          );
        },
        child: const Text('mở'),
      ),
    ),
  );
}

/// A gallery that ignores `max` (a real picker may), to show the sheet caps.
class _GreedyPicker implements ImagePickerPort {
  _GreedyPicker(this.answer);
  final List<PickedImage> answer;

  @override
  Future<List<PickedImage>> pickImages({required int max}) async => answer;
}

/// Bounded frames: the sheet animates in and uploads tick through microtasks.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<DisputeWorld> _open(
  WidgetTester tester, {
  DisputeSubject subject = const DisputeSubject.booking('b1'),
  DisputeOrigin origin = DisputeOrigin.booking,
  Duration left = const Duration(hours: 17, minutes: 30),
  List<List<PickedImage>> picks = const [],
  ImagePickerPort? picker,
  void Function(DisputeWorld w)? seed,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _Host.results.clear();
  final w = DisputeWorld(picks: picks);
  seed?.call(w);
  await tester.pumpWidget(
    screenApp(
      home: _Host(subject: subject, closesAt: w.now.add(left), origin: origin),
      overrides: picker == null
          ? w.overrides
          : [
              disputeRepositoryProvider.overrideWithValue(w.repo),
              imagePickerProvider.overrideWithValue(picker),
              clockProvider.overrideWithValue(() => w.now),
            ],
    ),
  );
  await tester.tap(_key('open'));
  await _settle(tester);
  return w;
}

Future<void> _describe(WidgetTester tester, String text) async {
  await tester.enterText(_key('dispute-description'), text);
  await tester.pump();
}

Future<void> _pickReason(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

Future<void> _addPhotos(WidgetTester tester) async {
  await tester.ensureVisible(_key('dispute-add-photo'));
  await tester.tap(_key('dispute-add-photo'));
  await _settle(tester);
}

bool _submitEnabled(WidgetTester tester) =>
    tester.widget<AppButton>(_key('dispute-submit')).onPressed != null;

List<String> _chipLabels(WidgetTester tester) => [
  for (final c in tester.widgetList<AppChip>(find.byType(AppChip))) c.label,
];

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(_key('dispute-submit'));
  await tester.tap(_key('dispute-submit'));
  await _settle(tester);
}

void main() {
  testWidgets('the sheet shows the booking reasons in mock order and the '
      'window "Còn 18 giờ…"', (tester) async {
    await _open(tester);
    expect(
      find.byWidgetPredicate(
        (w) => w is ScreenCode && w.code == ScreenCodes.openDispute,
      ),
      findsOneWidget,
    );
    expect(find.text('Báo vấn đề'), findsOneWidget);
    expect(
      find.text(
        'Còn 18 giờ để báo vấn đề. Tiền của buổi chụp được giữ tới khi có '
        'kết quả.',
      ),
      findsOneWidget,
    );
    expect(find.text('Vấn đề là gì?'), findsOneWidget);
    expect(_chipLabels(tester), [
      'Thợ không đến',
      'Không đúng thoả thuận',
      'Thiếu ảnh',
      'Khác ảnh mẫu',
      'Link hỏng',
      'Lý do khác',
    ]);
    expect(find.text('Ảnh bằng chứng · 0/5'), findsOneWidget);
    expect(
      find.text('Ảnh chỉ bạn, người bị khiếu nại và đội hỗ trợ xem được.'),
      findsOneWidget,
    );
    expect(find.byType(CtaSurface), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Gửi khiếu nại'), findsOneWidget);
  });

  testWidgets('delivery origin shows the delivery title, window copy and four '
      'reasons', (tester) async {
    await _open(
      tester,
      origin: DisputeOrigin.deliveryCheck,
      left: const Duration(hours: 46, minutes: 10),
    );
    expect(find.text('Báo vấn đề với ảnh gốc'), findsOneWidget);
    expect(
      find.text(
        'Còn 47 giờ để kiểm tra bộ ảnh gốc. Đợt thanh toán thứ hai được giữ '
        'tới khi có kết quả.',
      ),
      findsOneWidget,
    );
    expect(_chipLabels(tester), [
      'Thiếu ảnh',
      'Khác ảnh mẫu',
      'Link hỏng',
      'Lý do khác',
    ]);
  });

  testWidgets('ticket subject shows the ticket reasons and "Tiền vé…"', (
    tester,
  ) async {
    await _open(
      tester,
      subject: const DisputeSubject.ticket(
        eventId: 'ev1',
        registrationId: 'r1',
      ),
      origin: DisputeOrigin.ticket,
      left: const Duration(hours: 21),
    );
    expect(
      find.text(
        'Còn 21 giờ để báo vấn đề. Tiền vé được giữ tới khi có kết quả.',
      ),
      findsOneWidget,
    );
    expect(_chipLabels(tester), [
      'Sự kiện không diễn ra',
      'Khác mô tả',
      'Lý do khác',
    ]);
  });

  testWidgets('submit is disabled until a reason is picked and the '
      'description has 10 characters', (tester) async {
    await _open(tester);
    expect(_submitEnabled(tester), isFalse);

    await _pickReason(tester, 'Thiếu ảnh');
    expect(_submitEnabled(tester), isFalse);

    await _describe(tester, '  Thiếu 12  ');
    expect(_submitEnabled(tester), isFalse);
    expect(find.text('Viết ít nhất 10 ký tự'), findsOneWidget);

    await _describe(tester, 'Thiếu 12 ảnh');
    expect(_submitEnabled(tester), isTrue);
    expect(find.text('Viết ít nhất 10 ký tự'), findsNothing);
  });

  testWidgets('"Lý do khác" needs no extra field: the description explains', (
    tester,
  ) async {
    await _open(tester);
    await _pickReason(tester, 'Lý do khác');
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('the counter shows n/1000', (tester) async {
    await _open(tester);
    expect(find.text('0/1000'), findsOneWidget);
    await _describe(tester, 'Thiếu 12 ảnh');
    expect(find.text('12/1000'), findsOneWidget);
  });

  testWidgets('picking 6 photos keeps 5', (tester) async {
    final w = await _open(
      tester,
      picker: _GreedyPicker([for (var i = 0; i < 6; i++) _pic(i)]),
    );
    await _addPhotos(tester);
    expect(find.text('Ảnh bằng chứng · 5/5'), findsOneWidget);
    expect(w.uploader.uploaded, hasLength(5));
    // Full: no add tile.
    expect(_key('dispute-add-photo'), findsNothing);
  });

  testWidgets('evidence uploads pass purpose ImagePurpose.document to the '
      'uploader', (tester) async {
    final w = await _open(
      tester,
      picks: [
        [_pic(1), _pic(2), _pic(3)],
      ],
    );
    await _addPhotos(tester);
    expect(w.uploader.uploaded, hasLength(3));
    expect(w.uploader.purposes.values.toSet(), {ImagePurpose.document});
    for (final p in w.uploader.uploaded) {
      expect(p, startsWith('disputeEvidence/c1/'));
    }
    // Never more than two uploads at the same time.
    expect(w.uploader.maxConcurrent, lessThanOrEqualTo(2));
  });

  testWidgets('a failed upload shows the retry text and blocks submit until '
      'retried or removed', (tester) async {
    final w = await _open(
      tester,
      picks: [
        [_pic(1), _pic(2)],
      ],
      seed: (w) => w.uploader.failNames.add('e2.jpg'),
    );
    await _pickReason(tester, 'Thiếu ảnh');
    await _describe(tester, 'Thiếu 12 ảnh so với gói');
    await _addPhotos(tester);
    expect(
      find.text('Một ảnh chưa tải lên được. Chạm để thử lại.'),
      findsOneWidget,
    );
    expect(_submitEnabled(tester), isFalse);

    // Retry succeeds.
    w.uploader.failNames.clear();
    await tester.tap(_key('dispute-photo-retry-1'));
    await _settle(tester);
    expect(
      find.text('Một ảnh chưa tải lên được. Chạm để thử lại.'),
      findsNothing,
    );
    expect(w.uploader.uploaded, hasLength(2));
    expect(_submitEnabled(tester), isTrue);
  });

  testWidgets('removing a failed photo also unblocks submit', (tester) async {
    await _open(
      tester,
      picks: [
        [_pic(1)],
      ],
      seed: (w) => w.uploader.failNames.add('e1.jpg'),
    );
    await _pickReason(tester, 'Thiếu ảnh');
    await _describe(tester, 'Thiếu 12 ảnh so với gói');
    await _addPhotos(tester);
    expect(_submitEnabled(tester), isFalse);
    await tester.tap(_key('dispute-photo-remove-0'));
    await _settle(tester);
    expect(find.text('Ảnh bằng chứng · 0/5'), findsOneWidget);
    expect(_submitEnabled(tester), isTrue);
  });

  testWidgets('submit sends reason code, trimmed description and the uploaded '
      'paths, then pops the dispute id', (tester) async {
    final w = await _open(
      tester,
      picks: [
        [_pic(1), _pic(2)],
      ],
    );
    await _pickReason(tester, 'Thiếu ảnh');
    await _describe(tester, '  Gói 40 ảnh nhưng chỉ nhận 28 ảnh.  ');
    await _addPhotos(tester);
    final uploaded = [...w.uploader.uploaded];
    await _submit(tester);

    final draft = w.repo.opened.single;
    expect(draft.subjectType, DisputeSubjectType.booking);
    expect(draft.subjectId, 'b1');
    expect(draft.eventId, isNull);
    expect(draft.reason, DisputeReason.photosMissing);
    expect(draft.description, 'Gói 40 ảnh nhưng chỉ nhận 28 ảnh.');
    expect(draft.evidencePaths, uploaded);
    for (final p in uploaded) {
      expect(p, startsWith('disputeEvidence/c1/${draft.disputeId}/'));
    }
    expect(_Host.results, [draft.disputeId]);
    expect(find.text('Vấn đề là gì?'), findsNothing);
    // The photos now belong to the dispute: nothing deleted.
    expect(w.uploader.deleted, isEmpty);
  });

  testWidgets('a ticket draft carries the event id', (tester) async {
    final w = await _open(
      tester,
      subject: const DisputeSubject.ticket(
        eventId: 'ev1',
        registrationId: 'r1',
      ),
      origin: DisputeOrigin.ticket,
    );
    await _pickReason(tester, 'Sự kiện không diễn ra');
    await _describe(tester, 'Tới nơi không có ai tổ chức cả.');
    await _submit(tester);
    final draft = w.repo.opened.single;
    expect(draft.subjectType, DisputeSubjectType.ticket);
    expect(draft.subjectId, 'r1');
    expect(draft.eventId, 'ev1');
    expect(draft.reason, DisputeReason.eventNotHeld);
  });

  for (final (code, copy) in [
    ('conflict', 'Đã có một khiếu nại đang mở cho khoản này.'),
    ('deadline_passed', 'Đã quá thời hạn báo vấn đề.'),
    ('not_eligible', 'Khoản này không còn mở khiếu nại được.'),
    ('network', 'Chưa gửi được. Kiểm tra kết nối rồi thử lại.'),
  ]) {
    testWidgets('$code shows "$copy" and keeps the sheet', (tester) async {
      final w = await _open(
        tester,
        seed: (w) => w.repo.failWith = DisputeError(code),
      );
      await _pickReason(tester, 'Thiếu ảnh');
      await _describe(tester, 'Thiếu 12 ảnh so với gói');
      await _submit(tester);
      expect(find.text(copy), findsOneWidget);
      expect(find.text('Vấn đề là gì?'), findsOneWidget);
      expect(_Host.results, isEmpty);

      // A retry sends the same dispute id.
      w.repo.failWith = null;
      await _submit(tester);
      expect(w.repo.opened, hasLength(2));
      expect(w.repo.opened[1].disputeId, w.repo.opened[0].disputeId);
      expect(_Host.results, [w.repo.opened[0].disputeId]);
    });
  }

  testWidgets('dragging down after typing asks "Bỏ nội dung đang viết?"', (
    tester,
  ) async {
    await _open(tester);
    await _describe(tester, 'Thiếu ảnh');
    await tester.drag(_key('dispute-sheet-header'), const Offset(0, 400));
    await _settle(tester);
    expect(find.text('Bỏ nội dung đang viết?'), findsOneWidget);

    await tester.tap(find.text('Viết tiếp'));
    await _settle(tester);
    expect(find.text('Vấn đề là gì?'), findsOneWidget);
    expect(_Host.results, isEmpty);

    await tester.drag(_key('dispute-sheet-header'), const Offset(0, 400));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Bỏ'));
    await _settle(tester);
    expect(find.text('Vấn đề là gì?'), findsNothing);
    expect(_Host.results, [null]);
  });

  testWidgets('a tap outside after picking a reason also asks first', (
    tester,
  ) async {
    await _open(tester);
    await _pickReason(tester, 'Link hỏng');
    await tester.tapAt(const Offset(195, 10));
    await _settle(tester);
    expect(find.text('Bỏ nội dung đang viết?'), findsOneWidget);
    expect(_Host.results, isEmpty);
  });

  testWidgets('an untouched sheet closes on a drag without asking', (
    tester,
  ) async {
    await _open(tester);
    await tester.drag(_key('dispute-sheet-header'), const Offset(0, 400));
    await _settle(tester);
    expect(find.text('Bỏ nội dung đang viết?'), findsNothing);
    expect(find.text('Vấn đề là gì?'), findsNothing);
    expect(_Host.results, [null]);
  });

  testWidgets('closing the sheet after uploads deletes them', (tester) async {
    final w = await _open(
      tester,
      picks: [
        [_pic(1), _pic(2)],
      ],
    );
    await _addPhotos(tester);
    final uploaded = [...w.uploader.uploaded];
    expect(uploaded, hasLength(2));

    await tester.tap(_key('dispute-close'));
    await _settle(tester);
    expect(find.text('Bỏ nội dung đang viết?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Bỏ'));
    await _settle(tester);
    expect(w.uploader.deleted.toSet(), uploaded.toSet());
    expect(w.repo.opened, isEmpty);
  });

  testWidgets('removing an uploaded photo deletes it', (tester) async {
    final w = await _open(
      tester,
      picks: [
        [_pic(1)],
      ],
    );
    await _addPhotos(tester);
    final path = w.uploader.uploaded.single;
    await tester.tap(_key('dispute-photo-remove-0'));
    await _settle(tester);
    expect(w.uploader.deleted, [path]);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _Host.results.clear();
    final w = DisputeWorld(
      picks: [
        [_pic(1), _pic(2), _pic(3), _pic(4)],
      ],
    );
    await tester.pumpWidget(
      screenApp(
        home: _Host(
          subject: const DisputeSubject.booking('b1'),
          closesAt: w.now.add(const Duration(hours: 18)),
          origin: DisputeOrigin.booking,
        ),
        overrides: w.overrides,
        textScale: 1.3,
      ),
    );
    await tester.tap(_key('open'));
    await _settle(tester);
    await _addPhotos(tester);
    expect(tester.takeException(), isNull);
  });
}
