import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/addons/service_addon.dart';

AddonInput _input({
  String name = 'Trang điểm',
  int price = 800000,
  AddonUnit unit = AddonUnit.perPerson,
  int maxQty = 4,
  String? description,
  bool choosePackages = false,
  List<String> serviceIds = const [],
}) => AddonInput(
  kind: AddonKind.makeup,
  name: name,
  description: description,
  price: price,
  unit: unit,
  maxQty: maxQty,
  choosePackages: choosePackages,
  serviceIds: serviceIds,
);

ServiceAddon _addon(List<String> ids) => ServiceAddon(
  id: 'a',
  providerId: 'p',
  kind: AddonKind.other,
  name: 'X',
  price: 10000,
  unit: AddonUnit.perBooking,
  maxQty: 1,
  serviceIds: ids,
  active: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('serviceAddonFromFirestore maps every field and providerId from the '
      'argument', () {
    final a = serviceAddonFromFirestore('p1', 'a1', {
      'providerId': 'someone-else',
      'kind': 'transport',
      'name': 'Xe đón',
      'description': 'Nội thành',
      'price': 300000,
      'unit': 'per_booking',
      'maxQty': 1,
      'serviceIds': ['s1', 's2'],
      'active': true,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 8)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 9)),
    })!;
    expect(a.id, 'a1');
    expect(a.providerId, 'p1');
    expect(a.kind, AddonKind.transport);
    expect(a.name, 'Xe đón');
    expect(a.description, 'Nội thành');
    expect(a.price, 300000);
    expect(a.unit, AddonUnit.perBooking);
    expect(a.maxQty, 1);
    expect(a.serviceIds, ['s1', 's2']);
    expect(a.active, isTrue);
    expect(a.createdAt, DateTime.utc(2026, 10, 8));
    expect(a.updatedAt, DateTime.utc(2026, 10, 9));
  });

  test('unknown kind or unit → null', () {
    Map<String, dynamic> doc({
      String kind = 'makeup',
      String unit = 'per_item',
    }) => {'kind': kind, 'name': 'X', 'price': 10000, 'unit': unit};
    expect(serviceAddonFromFirestore('p', 'a', doc(kind: 'spa')), isNull);
    expect(serviceAddonFromFirestore('p', 'a', doc(unit: 'per_hour')), isNull);
    expect(serviceAddonFromFirestore('p', 'a', doc()), isNotNull);
    expect(serviceAddonFromFirestore('p', 'a', null), isNull);
  });

  test('appliesTo: empty serviceIds applies to all', () {
    expect(_addon(const []).appliesTo('s9'), isTrue);
    expect(_addon(const ['s1']).appliesTo('s1'), isTrue);
    expect(_addon(const ['s1']).appliesTo('s2'), isFalse);
  });

  group('validateAddonInput mirrors the server limits', () {
    test('a valid form has no error', () {
      expect(validateAddonInput(_input()), isNull);
    });

    test('name 1 and 61 graphemes → nameLength', () {
      expect(validateAddonInput(_input(name: 'a')), AddonInputError.nameLength);
      expect(
        validateAddonInput(_input(name: 'a' * 61)),
        AddonInputError.nameLength,
      );
      expect(validateAddonInput(_input(name: 'a' * 60)), isNull);
    });

    test('price 9.999 and 50.000.001 → priceRange', () {
      expect(
        validateAddonInput(_input(price: 9999)),
        AddonInputError.priceRange,
      );
      expect(
        validateAddonInput(_input(price: 50000001)),
        AddonInputError.priceRange,
      );
      expect(validateAddonInput(_input(price: 10000)), isNull);
      expect(validateAddonInput(_input(price: 50000000)), isNull);
    });

    test('maxQty 0 and 11 → maxQtyRange for per_person', () {
      expect(
        validateAddonInput(_input(maxQty: 0)),
        AddonInputError.maxQtyRange,
      );
      expect(
        validateAddonInput(_input(maxQty: 11)),
        AddonInputError.maxQtyRange,
      );
    });

    test('per_booking ignores maxQty', () {
      expect(
        validateAddonInput(_input(unit: AddonUnit.perBooking, maxQty: 0)),
        isNull,
      );
    });

    test('"0903 123 456" in the name → nameContact', () {
      expect(
        validateAddonInput(_input(name: '0903 123 456')),
        AddonInputError.nameContact,
      );
    });

    test('a phone in the description → descriptionContact', () {
      expect(
        validateAddonInput(_input(description: 'Gọi 0903 123 456')),
        AddonInputError.descriptionContact,
      );
    });

    test('words the server filter allows pass, as on the server', () {
      expect(
        validateAddonInput(
          _input(description: 'Chỉnh ảnh chuẩn đăng Facebook'),
        ),
        isNull,
      );
      expect(validateAddonInput(_input(name: 'Đồ Zalora')), isNull);
      expect(validateAddonInput(_input(description: 'giá 3.000.000đ')), isNull);
      expect(
        validateAddonInput(_input(name: 'nhắn Zalo nhé')),
        AddonInputError.nameContact,
      );
    });

    test('Chọn gói with no package → packagesEmpty', () {
      expect(
        validateAddonInput(_input(choosePackages: true)),
        AddonInputError.packagesEmpty,
      );
      expect(
        validateAddonInput(_input(choosePackages: true, serviceIds: ['s1'])),
        isNull,
      );
    });
  });
}
