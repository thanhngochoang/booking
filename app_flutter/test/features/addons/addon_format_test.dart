import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/features/addons/addon_format.dart';
import 'package:photobooking/l10n/app_localizations.dart';

BookingAddonLine _line(String name, AddonKind kind, AddonUnit unit, int qty) =>
    BookingAddonLine(
      addonId: name,
      kind: kind,
      name: name,
      unit: unit,
      unitPrice: 10000,
      qty: qty,
      amount: 10000 * qty,
    );

void main() {
  final l = lookupAppLocalizations(const Locale('vi'));

  test('addonKindIcon maps the five kinds', () {
    expect(addonKindIcon(AddonKind.makeup), AppIcons.face);
    expect(addonKindIcon(AddonKind.retouch), AppIcons.autoAwesome);
    expect(addonKindIcon(AddonKind.transport), AppIcons.car);
    expect(addonKindIcon(AddonKind.outfit), AppIcons.checkroom);
    expect(addonKindIcon(AddonKind.other), AppIcons.addCircle);
  });

  test('addonPriceLabel', () {
    String label(AddonKind k, AddonUnit u, int p) =>
        addonPriceLabel(l, kind: k, unit: u, price: p);
    expect(
      label(AddonKind.makeup, AddonUnit.perPerson, 800000),
      '800.000₫ / người',
    );
    expect(label(AddonKind.retouch, AddonUnit.perItem, 20000), '20.000₫ / ảnh');
    expect(label(AddonKind.outfit, AddonUnit.perItem, 250000), '250.000₫ / bộ');
    expect(
      label(AddonKind.transport, AddonUnit.perBooking, 300000),
      '300.000₫ · một lần',
    );
    expect(label(AddonKind.other, AddonUnit.perItem, 50000), '50.000₫ / lần');
  });

  test('addonLineLabel', () {
    expect(
      addonLineLabel(
        l,
        _line('Trang điểm', AddonKind.makeup, AddonUnit.perPerson, 2),
      ),
      'Trang điểm · 2 người',
    );
    expect(
      addonLineLabel(
        l,
        _line('Chỉnh thêm ảnh', AddonKind.retouch, AddonUnit.perItem, 10),
      ),
      'Chỉnh thêm ảnh · 10 ảnh',
    );
    expect(
      addonLineLabel(
        l,
        _line('Xe đón', AddonKind.transport, AddonUnit.perBooking, 1),
      ),
      'Xe đón',
    );
  });

  test('addonsSummary: qty 1 shows no ×', () {
    expect(
      addonsSummary(l, [
        _line('Trang điểm', AddonKind.makeup, AddonUnit.perPerson, 2),
        _line(
          'Xe đón trong nội thành',
          AddonKind.transport,
          AddonUnit.perBooking,
          1,
        ),
      ]),
      '+ Trang điểm ×2 · Xe đón trong nội thành',
    );
    expect(addonsSummary(l, const []), '');
  });
}
