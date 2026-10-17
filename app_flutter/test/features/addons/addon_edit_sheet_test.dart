import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/photographer/service_package.dart';

import '../../support/addons_world.dart';
import '../../support/photographer_world.dart';

const _portrait = ServicePackage(
  id: 'p1',
  name: 'Chân dung 2 giờ',
  priceVnd: 1500000,
  durationMinutes: 120,
);
const _couple = ServicePackage(
  id: 'p2',
  name: 'Cặp đôi nửa ngày',
  priceVnd: 3200000,
  durationMinutes: 240,
);

Finder _key(String k) => find.byKey(Key(k));

Future<void> _tick(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// S08.06 with the sheet open: empty ("Thêm dịch vụ") or on [addon].
Future<AddonsWorld> _open(
  WidgetTester tester, {
  bool edit = false,
  String? description,
}) async {
  usePhone(tester, height: 1400);
  final w = AddonsWorld();
  await w.init(packages: const [_portrait, _couple]);
  if (edit) {
    w.seed(
      'a1',
      name: 'Trang điểm',
      description: description,
      serviceIds: const ['p1'],
    );
  }
  await tester.pumpWidget(w.app());
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(_key(edit ? 'addon-a1' : 'addons-add'));
  await _tick(tester);
  return w;
}

Future<void> _fill(
  WidgetTester tester, {
  String name = 'Làm tóc',
  String price = '300000',
}) async {
  await tester.enterText(_key('addon-name'), name);
  await tester.enterText(_key('addon-price'), price);
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(_key('addon-save'));
  await tester.tap(_key('addon-save'));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('Một lần hides Tối đa', (tester) async {
    await _open(tester);
    expect(find.text('Tối đa'), findsNothing);
    expect(find.text('Giá (₫)'), findsOneWidget);
    await tester.tap(find.text('Theo người'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Tối đa'), findsOneWidget);
    await tester.tap(find.text('Một lần'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Tối đa'), findsNothing);
  });

  testWidgets('Theo số lượng with kind Chỉnh ảnh labels the price '
      '"Giá / ảnh (₫)" and Tối đa "{n} ảnh"', (tester) async {
    await _open(tester);
    await tester.ensureVisible(_key('addon-kind-retouch'));
    await tester.tap(_key('addon-kind-retouch'));
    await tester.tap(find.text('Theo số lượng'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Giá / ảnh (₫)'), findsOneWidget);
    await tester.enterText(_key('addon-max'), '3');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ảnh'), findsOneWidget);
    expect(tester.widget<TextField>(_key('addon-max')).controller!.text, '3');
  });

  testWidgets('Tối đa outside 1–10 shows "Tối đa từ 1 tới 10" and saves '
      'nothing', (tester) async {
    final w = await _open(tester);
    await _fill(tester);
    await tester.tap(find.text('Theo người'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(_key('addon-max'), '11');
    await _save(tester);
    expect(find.text('Tối đa từ 1 tới 10'), findsOneWidget);
    expect(w.addons.saves, isEmpty);
  });

  testWidgets('invalid name shows "Tên 2–60 ký tự" and does not call save', (
    tester,
  ) async {
    final w = await _open(tester);
    await _fill(tester, name: 'A');
    await _save(tester);
    expect(find.text('Tên 2–60 ký tự'), findsOneWidget);
    expect(w.addons.saves, isEmpty);
  });

  testWidgets('price 5.000 shows "Giá từ 10.000₫ tới 50.000.000₫"', (
    tester,
  ) async {
    final w = await _open(tester);
    await _fill(tester, price: '5000');
    expect(find.text('5.000'), findsOneWidget);
    await _save(tester);
    expect(find.text('Giá từ 10.000₫ tới 50.000.000₫'), findsOneWidget);
    expect(w.addons.saves, isEmpty);
  });

  testWidgets('server contact_leak on description shows the contact message '
      'under Mô tả', (tester) async {
    final w = await _open(tester);
    await _fill(tester);
    await tester.enterText(_key('addon-description'), 'Nhắn mình qua chat');
    w.addons.nextErrorCode = 'contact_leak';
    w.addons.nextErrorField = 'description';
    await _save(tester);
    expect(
      find.text('Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung'),
      findsOneWidget,
    );
    final field = find.ancestor(
      of: find.text('Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung'),
      matching: find.byKey(const Key('addon-description')),
    );
    expect(field, findsOneWidget);
  });

  testWidgets('a phone in Mô tả shows the contact message under Mô tả and '
      'does not call save', (tester) async {
    final w = await _open(tester);
    await _fill(tester);
    await tester.enterText(_key('addon-description'), 'Gọi 0903 123 456');
    await _save(tester);
    final field = find.ancestor(
      of: find.text('Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung'),
      matching: find.byKey(const Key('addon-description')),
    );
    expect(field, findsOneWidget);
    expect(w.addons.saves, isEmpty);
  });

  testWidgets('"Chỉnh ảnh chuẩn đăng Facebook" in Mô tả saves', (tester) async {
    final w = await _open(tester);
    await _fill(tester, name: 'Chỉnh ảnh');
    await tester.enterText(
      _key('addon-description'),
      'Chỉnh ảnh chuẩn đăng Facebook',
    );
    await _save(tester);
    await _tick(tester);
    expect(
      find.text('Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung'),
      findsNothing,
    );
    expect(
      w.addons.saves.single.input.description,
      'Chỉnh ảnh chuẩn đăng Facebook',
    );
  });

  testWidgets('server addon_limit shows the limit message', (tester) async {
    final w = await _open(tester);
    await _fill(tester);
    w.addons.nextErrorCode = 'addon_limit';
    await _save(tester);
    expect(
      find.text(
        'Bạn đã bật đủ 10 dịch vụ. Tắt bớt một dịch vụ để bật dịch vụ này.',
      ),
      findsOneWidget,
    );
    expect(find.text('Thêm dịch vụ đi kèm'), findsOneWidget, reason: 'stays');
  });

  testWidgets('Chọn gói with nothing ticked shows "Chọn ít nhất một gói"', (
    tester,
  ) async {
    final w = await _open(tester);
    await _fill(tester);
    await tester.tap(_key('addon-applies-pick'));
    await _tick(tester);
    expect(find.text('Chọn gói áp dụng'), findsOneWidget);
    await tester.tap(_key('addon-packages-done'));
    await _tick(tester);
    await _save(tester);
    expect(find.text('Chọn ít nhất một gói'), findsOneWidget);
    expect(w.addons.saves, isEmpty);
  });

  testWidgets('Lưu sends kind, name, description, price, unit, maxQty, '
      'serviceIds and closes with "Đã lưu dịch vụ"', (tester) async {
    final w = await _open(tester);
    await tester.ensureVisible(_key('addon-kind-outfit'));
    await tester.tap(_key('addon-kind-outfit'));
    await _fill(tester, name: 'Thuê áo dài', price: '250000');
    await tester.enterText(_key('addon-description'), 'Áo dài truyền thống');
    await tester.tap(find.text('Theo số lượng'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(_key('addon-max'), '2');
    await tester.tap(_key('addon-applies-pick'));
    await _tick(tester);
    await tester.tap(_key('addon-package-p2'));
    await tester.tap(_key('addon-packages-done'));
    await _tick(tester);
    await _save(tester);
    await _tick(tester);
    final s = w.addons.saves.single;
    expect(s.addonId, isNull);
    expect(s.input.kind, AddonKind.outfit);
    expect(s.input.name, 'Thuê áo dài');
    expect(s.input.description, 'Áo dài truyền thống');
    expect(s.input.price, 250000);
    expect(s.input.unit, AddonUnit.perItem);
    expect(s.input.maxQty, 2);
    expect(s.input.serviceIds, ['p2']);
    expect(s.input.toPayload()['serviceIds'], ['p2']);
    expect(find.text('Thêm dịch vụ đi kèm'), findsNothing, reason: 'closed');
    expect(find.text('Đã lưu dịch vụ'), findsOneWidget);
  });

  testWidgets('edit mode shows "Xoá dịch vụ"; confirming calls delete and '
      'closes with "Đã xoá dịch vụ"', (tester) async {
    final w = await _open(tester, edit: true);
    expect(find.text('Sửa dịch vụ đi kèm'), findsOneWidget);
    await tester.ensureVisible(_key('addon-delete'));
    await tester.tap(_key('addon-delete'));
    await _tick(tester);
    expect(find.text('Booking đã đặt vẫn giữ dịch vụ này.'), findsOneWidget);
    await tester.tap(find.text('Xoá'));
    await tester.pump(const Duration(milliseconds: 100));
    await _tick(tester);
    await _tick(tester);
    expect(w.addons.deletes, ['a1']);
    expect(find.text('Sửa dịch vụ đi kèm'), findsNothing);
    expect(find.text('Đã xoá dịch vụ'), findsOneWidget);
  });

  testWidgets('cancelling the confirm sheet deletes nothing', (tester) async {
    final w = await _open(tester, edit: true);
    await tester.ensureVisible(_key('addon-delete'));
    await tester.tap(_key('addon-delete'));
    await _tick(tester);
    await tester.tap(find.text('Giữ lại'));
    await _tick(tester);
    await _tick(tester);
    expect(w.addons.deletes, isEmpty);
    expect(find.text('Sửa dịch vụ đi kèm'), findsOneWidget);
  });

  testWidgets('edit mode fills the form and saves with the add-on id', (
    tester,
  ) async {
    final w = await _open(tester, edit: true, description: 'Tự nhiên');
    expect(
      tester.widget<TextField>(_key('addon-name')).controller!.text,
      'Trang điểm',
    );
    expect(
      tester.widget<TextField>(_key('addon-description')).controller!.text,
      'Tự nhiên',
    );
    expect(find.text('Chân dung 2 giờ'), findsOneWidget);
    await _save(tester);
    expect(w.addons.saves.single.addonId, 'a1');
    expect(w.addons.saves.single.input.serviceIds, ['p1']);
  });

  testWidgets('Lưu is disabled while saving (AppButton.loading)', (
    tester,
  ) async {
    final w = await _open(tester);
    await _fill(tester);
    w.addons.holdSave = true;
    await _save(tester);
    final button = tester.widget<FilledButton>(
      find.descendant(
        of: _key('addon-save'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(tester.widget<TextField>(_key('addon-name')).enabled, isFalse);
    w.addons.releaseSave();
    await tester.pump(const Duration(milliseconds: 100));
    await _tick(tester);
    expect(w.addons.saves, hasLength(1));
  });
}
