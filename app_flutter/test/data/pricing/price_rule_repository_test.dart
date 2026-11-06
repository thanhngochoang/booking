import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/pricing/day_pricing.dart' show Weekday;
import 'package:photobooking/data/pricing/firestore_price_rule_repository.dart';
import 'package:photobooking/data/pricing/price_rule_repository.dart';
import 'package:photobooking/data/pricing/price_rules.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

Map<String, dynamic> _doc(
  String serviceId, {
  String repeat = 'weekly',
  int price = 2000000,
  Map<String, Object?> extra = const {},
}) => {
  'serviceId': serviceId,
  'price': price,
  'repeat': repeat,
  if (repeat == 'weekly') 'weekdays': ['sat', 'sun'],
  'endsOn': '2027-01-01',
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 6)),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 6)),
  ...extra,
};

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FirestorePriceRuleRepository repo;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = FirestorePriceRuleRepository(firestore: db, functions: functions);
  });

  CollectionReference<Map<String, dynamic>> col(String uid) =>
      db.collection('photographers').doc(uid).collection('price_rules');

  void answer(Object? data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);
  }

  Map<String, dynamic> sent() =>
      verify(() => callable.call<Object?>(captureAny())).captured.single
          as Map<String, dynamic>;

  group('reads', () {
    test('watchProviderRules reads the provider\'s rules, parsed and ordered '
        'by package, tier, first day, id', () async {
      await col('p1').doc('w').set(_doc('s1'));
      await col('p1')
          .doc('n2')
          .set(
            _doc(
              's1',
              repeat: 'none',
              extra: {'from': '2027-02-01', 'to': '2027-02-03'},
            ),
          );
      await col('p1')
          .doc('n1')
          .set(
            _doc(
              's1',
              repeat: 'none',
              extra: {'from': '2027-01-01', 'to': '2027-01-03'},
            ),
          );
      await col('p1')
          .doc('y')
          .set(
            _doc(
              's1',
              repeat: 'yearly',
              extra: {'lunar': true, 'from': '12-23', 'to': '01-05'},
            ),
          );
      await col('p1').doc('other').set(_doc('s0'));
      await col('p2').doc('x').set(_doc('s1'));

      final rules = await repo.watchProviderRules('p1').first;

      expect(rules.map((r) => r.id), ['other', 'n1', 'n2', 'y', 'w']);
      final yearly = rules.firstWhere((r) => r.id == 'y');
      expect(yearly.lunar, isTrue);
      expect(yearly.repeat, PriceRepeat.yearly);
      expect(rules.last.weekdays, {Weekday.sat, Weekday.sun});
    });

    test('unusable documents are skipped', () async {
      await col('p1').doc('ok').set(_doc('s1'));
      await col('p1').doc('bad').set({'serviceId': 's1', 'price': 'x'});

      final rules = await repo.watchProviderRules('p1').first;

      expect(rules.map((r) => r.id), ['ok']);
    });

    test('watchProviderRules is live', () async {
      final seen = <List<String>>[];
      final sub = repo
          .watchProviderRules('p1')
          .listen((l) => seen.add([for (final r in l) r.id]));
      await Future<void>.delayed(Duration.zero);
      await col('p1').doc('a').set(_doc('s1'));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(seen.first, isEmpty);
      expect(seen.last, ['a']);
    });

    test('rulesForService reads only that package', () async {
      await col('p1').doc('a').set(_doc('s1'));
      await col('p1').doc('b').set(_doc('s2'));

      final rules = await repo.rulesForService('p1', 's1');

      expect(rules.map((r) => r.id), ['a']);
    });
  });

  group('writes go through the callables', () {
    test('saveRule sends the payload and returns the ids', () async {
      answer({
        'ruleIds': ['r1', 'r2'],
      });

      final ids = await repo.saveRule(
        const PriceRuleInput(
          serviceId: 's1',
          price: 2500000,
          repeat: PriceRepeat.yearly,
          name: ' Tết ',
          lunar: true,
          from: '12-23',
          to: '01-05',
          template: 'tet',
        ),
        applyToAll: true,
      );

      expect(ids, ['r1', 'r2']);
      verify(
        () => functions.httpsCallable(
          'savePriceRule',
          options: any(named: 'options'),
        ),
      ).called(1);
      expect(sent(), {
        'serviceId': 's1',
        'price': 2500000,
        'repeat': 'yearly',
        'name': 'Tết',
        'lunar': true,
        'from': '12-23',
        'to': '01-05',
        'template': 'tet',
        'applyToAll': true,
      });
    });

    test('saveRule of a weekly rule sends weekdays and no from/to', () async {
      answer({
        'ruleIds': ['r1'],
      });

      await repo.saveRule(
        const PriceRuleInput(
          serviceId: 's1',
          price: 2000000,
          repeat: PriceRepeat.weekly,
          weekdays: {Weekday.sat, Weekday.sun},
        ),
        ruleId: 'r1',
      );

      expect(sent(), {
        'ruleId': 'r1',
        'serviceId': 's1',
        'price': 2000000,
        'repeat': 'weekly',
        'weekdays': ['sat', 'sun'],
      });
    });

    test('saveRule refuses a response without ruleIds', () async {
      answer(<String, dynamic>{});

      await expectLater(
        repo.saveRule(
          const PriceRuleInput(
            serviceId: 's1',
            price: 1000000,
            repeat: PriceRepeat.weekly,
            weekdays: {Weekday.mon},
          ),
        ),
        throwsA(
          isA<PriceRuleException>().having(
            (e) => e.code,
            'code',
            'invalid_response',
          ),
        ),
      );
    });

    test('splitRule sends the UTC day key and the price', () async {
      answer({
        'ruleIds': ['r1', 'r3'],
      });

      final ids = await repo.splitRule(
        'r1',
        DateTime.utc(2027, 3, 5),
        price: 3000000,
      );

      expect(ids, ['r1', 'r3']);
      verify(
        () => functions.httpsCallable(
          'splitPriceRule',
          options: any(named: 'options'),
        ),
      ).called(1);
      expect(sent(), {'ruleId': 'r1', 'day': '2027-03-05', 'price': 3000000});
    });

    test(
      'splitRule without a price ends the series and may return no ids',
      () async {
        answer({'ruleIds': <String>[]});

        final ids = await repo.splitRule('r1', DateTime.utc(2027, 3, 5));

        expect(ids, isEmpty);
        expect(sent(), {'ruleId': 'r1', 'day': '2027-03-05'});
      },
    );

    test('setException sends int, null or "clear" as price', () async {
      answer(<String, dynamic>{});
      final day = DateTime.utc(2027, 3, 6);

      await repo.setException('r1', day, const PriceException.custom(1800000));
      await repo.setException('r1', day, const PriceException.skip());
      await repo.setException('r1', day, const PriceException.clear());

      verify(
        () => functions.httpsCallable(
          'setPriceRuleException',
          options: any(named: 'options'),
        ),
      ).called(3);
      final payloads = verify(() => callable.call<Object?>(captureAny()))
          .captured
          .cast<Map<String, dynamic>>();
      expect(payloads, [
        {'ruleId': 'r1', 'day': '2027-03-06', 'price': 1800000},
        {'ruleId': 'r1', 'day': '2027-03-06', 'price': null},
        {'ruleId': 'r1', 'day': '2027-03-06', 'price': 'clear'},
      ]);
      expect(payloads[1].containsKey('price'), isTrue);
    });

    test('deleteRule sends {ruleId}', () async {
      answer(<String, dynamic>{});

      await repo.deleteRule('r1');

      verify(
        () => functions.httpsCallable(
          'deletePriceRule',
          options: any(named: 'options'),
        ),
      ).called(1);
      verify(() => callable.call<Object?>({'ruleId': 'r1'})).called(1);
    });

    test('nothing is written to Firestore directly', () async {
      answer({
        'ruleIds': ['r1'],
      });

      await repo.saveRule(
        const PriceRuleInput(
          serviceId: 's1',
          price: 1000000,
          repeat: PriceRepeat.weekly,
          weekdays: {Weekday.mon},
        ),
      );

      expect((await col('p1').get()).docs, isEmpty);
    });
  });

  group('errors', () {
    void failWith(Object details, {String code = 'failed-precondition'}) {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(message: 'x', code: code, details: details),
      );
    }

    test('details.code and details.field are carried', () async {
      failWith({
        'code': 'invalid_argument',
        'field': 'weekdays',
      }, code: 'invalid-argument');

      await expectLater(
        repo.deleteRule('r1'),
        throwsA(
          isA<PriceRuleException>()
              .having((e) => e.code, 'code', 'invalid_argument')
              .having((e) => e.field, 'field', 'weekdays'),
        ),
      );
    });

    test('rule_limit and exception_limit come from details.code', () async {
      failWith({'code': 'rule_limit'});
      await expectLater(
        repo.deleteRule('r1'),
        throwsA(
          isA<PriceRuleException>().having((e) => e.code, 'code', 'rule_limit'),
        ),
      );
      failWith({'code': 'exception_limit'});
      await expectLater(
        repo.setException(
          'r1',
          DateTime.utc(2027, 1, 1),
          const PriceException.skip(),
        ),
        throwsA(
          isA<PriceRuleException>().having(
            (e) => e.code,
            'code',
            'exception_limit',
          ),
        ),
      );
    });

    test('without details the HttpsError code is used', () async {
      failWith('nope', code: 'unavailable');

      await expectLater(
        repo.deleteRule('r1'),
        throwsA(
          isA<PriceRuleException>().having(
            (e) => e.code,
            'code',
            'unavailable',
          ),
        ),
      );
    });
  });

  group('priceRuleErrorOf', () {
    test('invalid_argument keeps its field', () {
      final e = priceRuleErrorOf(
        const PriceRuleException('invalid_argument', field: 'to'),
      );
      expect(e.code, PriceRuleErrorCode.invalidArgument);
      expect(e.field, 'to');
    });

    test('the limit codes, permission and not found', () {
      PriceRuleErrorCode of(String c) =>
          priceRuleErrorOf(PriceRuleException(c)).code;
      expect(of('rule_limit'), PriceRuleErrorCode.ruleLimit);
      expect(of('exception_limit'), PriceRuleErrorCode.exceptionLimit);
      expect(of('permission_denied'), PriceRuleErrorCode.permissionDenied);
      expect(of('not_found'), PriceRuleErrorCode.notFound);
      expect(of('failed-precondition'), PriceRuleErrorCode.unknown);
    });

    test('unavailable and socket errors are network; the rest unknown', () {
      expect(
        priceRuleErrorOf(const PriceRuleException('unavailable')).code,
        PriceRuleErrorCode.network,
      );
      expect(
        priceRuleErrorOf(const SocketException('down')).code,
        PriceRuleErrorCode.network,
      );
      expect(
        priceRuleErrorOf(StateError('x')).code,
        PriceRuleErrorCode.unknown,
      );
    });
  });

  group('PriceRuleInput', () {
    test('fromRule copies the form fields and drops server-kept ones', () {
      const rule = PriceRule(
        id: 'r1',
        serviceId: 's1',
        price: 2000000,
        repeat: PriceRepeat.none,
        name: 'Hè',
        from: '2027-06-01',
        to: '2027-06-10',
        start: '2027-05-01',
        exceptions: {'2027-06-02': null},
      );

      expect(PriceRuleInput.fromRule(rule).toPayload(), {
        'serviceId': 's1',
        'price': 2000000,
        'repeat': 'none',
        'name': 'Hè',
        'from': '2027-06-01',
        'to': '2027-06-10',
      });
    });

    test('a blank name is not sent', () {
      const input = PriceRuleInput(
        serviceId: 's1',
        price: 1000000,
        repeat: PriceRepeat.weekly,
        name: '  ',
        weekdays: {Weekday.fri},
      );
      expect(input.toPayload().containsKey('name'), isFalse);
    });

    test('validate names the first bad field', () {
      final today = DateTime.utc(2026, 11, 6);
      const bad = PriceRuleInput(
        serviceId: 's1',
        price: 1000000,
        repeat: PriceRepeat.none,
        from: '2027-06-10',
        to: '2027-06-01',
      );
      expect(
        bad.validate(today: today, serviceIds: ['s1'], creating: true),
        'to',
      );
      expect(
        bad.validate(today: today, serviceIds: ['s2'], creating: true),
        'serviceId',
      );
    });
  });

  group('PriceException', () {
    test('payloads are int, null and "clear"', () {
      expect(const PriceException.custom(1500000).payload, 1500000);
      expect(const PriceException.skip().payload, isNull);
      expect(const PriceException.clear().payload, 'clear');
    });

    test('a switch is exhaustive and values compare', () {
      String label(PriceException e) => switch (e) {
        CustomDayPrice(:final price) => 'price $price',
        SkipDay() => 'skip',
        ClearDayException() => 'clear',
      };
      expect(label(const PriceException.custom(7)), 'price 7');
      expect(label(const PriceException.skip()), 'skip');
      expect(label(const PriceException.clear()), 'clear');
      expect(const PriceException.custom(7), const PriceException.custom(7));
      expect(const PriceException.skip(), isNot(const PriceException.clear()));
    });
  });
}
