import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/addons/addon_repository.dart';
import 'package:photobooking/data/addons/firestore_addon_repository.dart';
import 'package:photobooking/data/addons/service_addon.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

Map<String, dynamic> _doc(String kind, {bool active = true, String? name}) => {
  'kind': kind,
  'name': name ?? kind,
  'price': 100000,
  'unit': 'per_booking',
  'maxQty': 1,
  'serviceIds': <String>[],
  'active': active,
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 8)),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 8)),
};

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FirestoreAddonRepository repo;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = FirestoreAddonRepository(firestore: db, functions: functions);
  });

  CollectionReference<Map<String, dynamic>> col(String uid) =>
      db.collection('photographers').doc(uid).collection('addons');

  void answer(Object? data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
  }

  test(
    'activeFor returns only active add-ons ordered by kind then id',
    () async {
      await col('p1').doc('b').set(_doc('transport'));
      await col('p1').doc('a').set(_doc('transport'));
      await col('p1').doc('z').set(_doc('makeup'));
      await col('p1').doc('off').set(_doc('retouch', active: false));
      await col('p2').doc('x').set(_doc('makeup'));

      final list = await repo.activeFor('p1');

      expect(list.map((a) => a.id), ['z', 'a', 'b']);
      expect(list.every((a) => a.providerId == 'p1' && a.active), isTrue);
    },
  );

  test('watchMine returns inactive ones too', () async {
    await col('p1').doc('a').set(_doc('makeup'));
    await col('p1').doc('off').set(_doc('retouch', active: false));

    final list = await repo.watchMine('p1').first;

    expect(list.map((a) => a.id), ['a', 'off']);
  });

  test('save sends the callable payload with snake-case codes and returns '
      'addonId', () async {
    answer({'addonId': 'new1'});

    final id = await repo.save(
      const AddonInput(
        kind: AddonKind.retouch,
        name: 'Chỉnh thêm ảnh',
        price: 20000,
        unit: AddonUnit.perItem,
        maxQty: 10,
        choosePackages: true,
        serviceIds: ['s1'],
      ),
    );

    expect(id, 'new1');
    verify(
      () =>
          functions.httpsCallable('saveAddon', options: any(named: 'options')),
    ).called(1);
    final sent =
        verify(() => callable.call<Object?>(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(sent, {
      'kind': 'retouch',
      'name': 'Chỉnh thêm ảnh',
      'price': 20000,
      'unit': 'per_item',
      'maxQty': 10,
      'serviceIds': ['s1'],
      'active': true,
    });
  });

  test('save with an addonId sends it', () async {
    answer({'addonId': 'a1'});
    await repo.save(
      const AddonInput(
        kind: AddonKind.other,
        name: 'Khác',
        price: 10000,
        unit: AddonUnit.perBooking,
      ),
      addonId: 'a1',
    );
    final sent =
        verify(() => callable.call<Object?>(captureAny())).captured.single
            as Map<String, dynamic>;
    expect(sent['addonId'], 'a1');
  });

  test('delete sends {addonId}', () async {
    answer(<String, dynamic>{});
    await repo.delete('a1');
    verify(
      () => functions.httpsCallable(
        'deleteAddon',
        options: any(named: 'options'),
      ),
    ).called(1);
    verify(() => callable.call<Object?>({'addonId': 'a1'})).called(1);
  });

  test('a callable failure carries details.code and details.field', () async {
    when(() => callable.call<Object?>(any())).thenThrow(
      FirebaseFunctionsException(
        message: 'x',
        code: 'invalid-argument',
        details: {'code': 'contact_leak', 'field': 'name'},
      ),
    );
    await expectLater(
      repo.save(
        const AddonInput(
          kind: AddonKind.other,
          name: 'Khác',
          price: 10000,
          unit: AddonUnit.perBooking,
        ),
      ),
      throwsA(
        isA<AddonException>()
            .having((e) => e.code, 'code', 'contact_leak')
            .having((e) => e.field, 'field', 'name'),
      ),
    );
  });
}
