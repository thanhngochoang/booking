import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/content/provider_type.dart';

import '../../support/awards_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<AwardsWorld> _open(
  WidgetTester tester, {
  void Function(AwardsWorld w)? seed,
  double width = 390,
  double textScale = 1.0,
}) async {
  usePhone(tester, width: width, height: width < 390 ? 700 : 900);
  final w = AwardsWorld();
  await w.init();
  seed?.call(w);
  await tester.pumpWidget(w.app(textScale: textScale));
  await tester.pumpAndSettle();
  return w;
}

void main() {
  testWidgets('progress shows approved out of 3', (tester) async {
    await _open(
      tester,
      seed: (w) {
        w.awardRepo.add(w.award('a1'));
        w.awardRepo.add(w.award('a2', competition: 'VIPA'));
        w.awardRepo.add(w.award('a3', status: AwardStatus.pending));
      },
    );
    expect(find.text('Hạng Nhiếp ảnh gia (NAG)'), findsOneWidget);
    expect(_key('awards-tier-count'), findsOneWidget);
    expect(tester.widget<Text>(_key('awards-tier-count')).data, '2 / 3');
    expect(
      find.text('Còn 1 giải đã duyệt nữa để nhận tích vàng'),
      findsOneWidget,
    );
    expect(find.text('Đã khai · 3 giải'), findsOneWidget);
    expect(find.text('ĐÃ DUYỆT'), findsNWidgets(2));
    expect(find.text('CHỜ DUYỆT'), findsOneWidget);
  });

  testWidgets('an artist sees Bạn là Nhiếp ảnh gia', (tester) async {
    await _open(
      tester,
      seed: (w) {
        for (final id in ['a1', 'a2', 'a3']) {
          w.awardRepo.add(w.award(id));
        }
        w.awardRepo.setTier(
          AwardTier(
            providerType: ProviderType.artist,
            approvedCount: 3,
            // 05/10/2026 in Vietnam.
            artistSince: DateTime.utc(2026, 10, 4, 18),
          ),
        );
      },
    );
    expect(find.text('Bạn là Nhiếp ảnh gia · từ 05/10/2026'), findsOneWidget);
    expect(_key('awards-tier-count'), findsNothing);
  });

  testWidgets('a studio has no tier card', (tester) async {
    await _open(
      tester,
      seed: (w) {
        w.awardRepo.add(w.award('a1'));
        w.awardRepo.setTier(
          const AwardTier(providerType: ProviderType.studio, approvedCount: 1),
        );
      },
    );
    expect(_key('awards-tier-card'), findsNothing);
    expect(find.text('Hạng Nhiếp ảnh gia (NAG)'), findsNothing);
    expect(find.text('Đã khai · 1 giải'), findsOneWidget);
  });

  testWidgets('a needs_info award shows the staff note', (tester) async {
    await _open(
      tester,
      seed: (w) => w.awardRepo.add(
        w.award(
          'a1',
          status: AwardStatus.needsInfo,
          note: 'Thiếu ảnh giấy chứng nhận',
          category: 'Phong cảnh',
        ),
      ),
    );
    expect(find.text('BỔ SUNG'), findsOneWidget);
    expect(find.text('Thiếu ảnh giấy chứng nhận'), findsOneWidget);
    expect(find.text('Phong cảnh'), findsNothing);
  });

  testWidgets('S25.01 switches to Bạn là Nhiếp ảnh gia when the third award '
      'is approved', (tester) async {
    final w = await _open(
      tester,
      seed: (w) {
        w.awardRepo.add(w.award('a1'));
        w.awardRepo.add(w.award('a2'));
        w.awardRepo.add(w.award('a3', status: AwardStatus.pending));
      },
    );
    expect(find.textContaining('Bạn là Nhiếp ảnh gia'), findsNothing);
    w.awardRepo.setTier(
      AwardTier(
        providerType: ProviderType.artist,
        approvedCount: 3,
        artistSince: DateTime.utc(2026, 10, 5, 3),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bạn là Nhiếp ảnh gia · từ 05/10/2026'), findsOneWidget);
    expect(find.textContaining('Còn '), findsNothing);
  });

  testWidgets('deleting asks first', (tester) async {
    final w = await _open(
      tester,
      seed: (w) => w.awardRepo.add(w.award('a1', competition: 'VIPA')),
    );
    await tester.longPress(_key('award-a1'));
    await tester.pumpAndSettle();
    expect(find.text('Xoá giải thưởng?'), findsOneWidget);
    expect(w.awardRepo.calls, isEmpty);

    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(w.awardRepo.calls, isEmpty);
    expect(find.textContaining('VIPA'), findsOneWidget);

    await tester.longPress(_key('award-a1'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xoá'));
    await tester.pumpAndSettle();
    expect(w.awardRepo.calls, ['delete:a1']);
    expect(find.textContaining('VIPA'), findsNothing);
  });

  testWidgets('editing an approved award warns it will be reviewed again', (
    tester,
  ) async {
    await _open(
      tester,
      seed: (w) {
        w.awardRepo.add(w.award('a1', competition: 'VIPA'));
        w.awardRepo.add(
          w.award('a2', status: AwardStatus.pending, competition: 'Ảnh Đẹp'),
        );
      },
    );
    await tester.tap(find.textContaining('VIPA'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa giải đã duyệt?'), findsOneWidget);
    expect(find.textContaining('Giải sẽ được duyệt lại'), findsOneWidget);
    expect(find.text('Sửa giải thưởng'), findsNothing);

    await tester.tap(find.text('Tiếp tục sửa'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa giải thưởng'), findsOneWidget);
    expect(
      tester.widget<TextField>(_key('award-competition')).controller!.text,
      'VIPA',
    );

    // A pending award opens straight away.
    await tester.tap(_key('award-close'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ảnh Đẹp'));
    await tester.pumpAndSettle();
    expect(find.text('Sửa giải đã duyệt?'), findsNothing);
    expect(find.text('Sửa giải thưởng'), findsOneWidget);
  });

  testWidgets('no awards shows the empty state with one primary action', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Giải thưởng giúp khách tin tác phẩm của bạn'), findsOne);
    expect(find.text('Thêm giải thưởng'), findsOneWidget);
    expect(_key('awards-add'), findsNothing);
    await tester.tap(find.text('Thêm giải thưởng'));
    await tester.pumpAndSettle();
    expect(_key('award-competition'), findsOneWidget);
  });

  testWidgets('the info button explains the tier rule', (tester) async {
    await _open(tester, seed: (w) => w.awardRepo.add(w.award('a1')));
    await tester.tap(_key('awards-info'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ít nhất 3 giải đã được duyệt'), findsOneWidget);
    await tester.tap(_key('awards-info-close'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ít nhất 3 giải đã được duyệt'), findsNothing);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('fits $width wide at text scale 1.3', (tester) async {
      await _open(
        tester,
        width: width,
        textScale: 1.3,
        seed: (w) {
          w.awardRepo.add(
            w.award(
              'a1',
              competition: 'Giải thưởng Ảnh Việt Nam rất dài tên',
              status: AwardStatus.needsInfo,
              note: 'Thiếu ảnh giấy chứng nhận, vui lòng bổ sung thêm',
            ),
          );
          w.awardRepo.add(w.award('a2', status: AwardStatus.pending));
        },
      );
      expect(tester.takeException(), isNull);
    });
  }
}
