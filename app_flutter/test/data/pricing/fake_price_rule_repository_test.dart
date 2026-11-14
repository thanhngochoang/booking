import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/pricing/day_pricing.dart' show Weekday;
import 'package:photobooking/data/pricing/price_rule_repository.dart';
import 'package:photobooking/data/pricing/price_rules.dart';

import '../../support/fake_price_rule_repository.dart';

const _weekend = PriceRuleInput(
  serviceId: 's1',
  price: 2500000,
  repeat: PriceRepeat.weekly,
  weekdays: {Weekday.sat, Weekday.sun},
);

PriceRule _oneOff(
  String id, {
  String from = '2026-12-20',
  String to = '2026-12-31',
  int price = 3000000,
  Map<String, Object?> exceptions = const {},
  String? start,
}) => PriceRule(
  id: id,
  serviceId: 's1',
  price: price,
  repeat: PriceRepeat.none,
  from: from,
  to: to,
  start: start,
  exceptions: exceptions,
);

Matcher _fails(String code, [String? field]) => throwsA(
  isA<PriceRuleException>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.field, 'field', field),
);

void main() {
  late FakePriceRuleRepository repo;

  setUp(() => repo = FakePriceRuleRepository());

  group('saveRule', () {
    test('creates a rule, records the call and shows it live', () async {
      final ids = await repo.saveRule(_weekend);

      expect(ids, hasLength(1));
      expect(repo.saves.single.input, _weekend);
      final seen = await repo.watchProviderRules('p1').first;
      expect(seen.single.id, ids.single);
      expect(seen.single.weekdays, {Weekday.sat, Weekday.sun});
    });

    test('a bad field is invalid_argument with that field', () async {
      await expectLater(
        repo.saveRule(
          const PriceRuleInput(
            serviceId: 's1',
            price: 2500000,
            repeat: PriceRepeat.weekly,
          ),
        ),
        _fails('invalid_argument', 'weekdays'),
      );
      expect(repo.ownerRules, isEmpty);
    });

    test('the 31st rule of a package is rule_limit', () async {
      for (var i = 0; i < kMaxRulesPerService; i++) {
        repo.seed(_oneOff('r$i'));
      }

      await expectLater(repo.saveRule(_weekend), _fails('rule_limit'));
    });

    test('editing keeps start, until, exceptions and the template', () async {
      repo.seed(
        const PriceRule(
          id: 'r1',
          serviceId: 's1',
          price: 2000000,
          repeat: PriceRepeat.weekly,
          weekdays: {Weekday.sat},
          start: '2026-11-01',
          until: '2027-03-01',
          exceptions: {'2026-11-07': null},
          template: 'weekend',
        ),
      );

      final ids = await repo.saveRule(_weekend, ruleId: 'r1');

      expect(ids, ['r1']);
      final rule = repo.ownerRules.single;
      expect(rule.price, 2500000);
      expect(rule.weekdays, {Weekday.sat, Weekday.sun});
      expect(rule.start, '2026-11-01');
      expect(rule.until, '2027-03-01');
      expect(rule.exceptions, {'2026-11-07': null});
      expect(rule.template, 'weekend');
    });

    test(
      'editing drops the exceptions the new pattern no longer covers',
      () async {
        repo.seed(
          const PriceRule(
            id: 'r1',
            serviceId: 's1',
            price: 2000000,
            repeat: PriceRepeat.weekly,
            weekdays: {Weekday.sat, Weekday.mon},
            exceptions: {
              '2026-11-07': null, // sat: still covered
              '2026-11-09': 2100000, // mon: no longer covered
              '2026-11-10': 2200000, // tue: never covered
            },
          ),
        );

        await repo.saveRule(_weekend, ruleId: 'r1');

        expect(repo.ownerRules.single.exceptions, {'2026-11-07': null});
      },
    );

    test('an edit that covers no exception leaves none', () async {
      repo.seed(
        const PriceRule(
          id: 'r1',
          serviceId: 's1',
          price: 2000000,
          repeat: PriceRepeat.weekly,
          weekdays: {Weekday.mon},
          exceptions: {'2026-11-09': 2100000},
        ),
      );

      await repo.saveRule(_weekend, ruleId: 'r1');

      expect(repo.ownerRules.single.exceptions, isEmpty);
    });

    test('the name is trimmed and a blank one is absent', () async {
      final a = await repo.saveRule(
        const PriceRuleInput(
          serviceId: 's1',
          price: 2500000,
          repeat: PriceRepeat.weekly,
          weekdays: {Weekday.sat},
          name: '  Cuối tuần  ',
        ),
      );
      final b = await repo.saveRule(
        const PriceRuleInput(
          serviceId: 's1',
          price: 2500000,
          repeat: PriceRepeat.weekly,
          weekdays: {Weekday.sun},
          name: '   ',
        ),
      );

      final byId = {for (final r in repo.ownerRules) r.id: r};
      expect(byId[a.single]!.name, 'Cuối tuần');
      expect(byId[b.single]!.name, isNull);
    });

    test('a rule of another provider is not_found', () async {
      repo.seed(_oneOff('theirs'), providerId: 'other');

      await expectLater(
        repo.saveRule(_weekend, ruleId: 'theirs'),
        _fails('not_found'),
      );
    });

    test(
      'applyToAll adds a scaled copy per other package, saved rule first',
      () async {
        repo.packages = const [
          PricedPackage(id: 's1', price: 2000000),
          PricedPackage(id: 's2', price: 3000000),
        ];

        final ids = await repo.saveRule(_weekend, applyToAll: true);

        expect(ids, hasLength(2));
        final byId = {for (final r in repo.ownerRules) r.id: r};
        expect(byId[ids.first]!.serviceId, 's1');
        expect(byId[ids.last]!.serviceId, 's2');
        expect(byId[ids.last]!.price, 3750000);
      },
    );

    test('applyToAll on an edit is invalid_argument applyToAll', () async {
      repo.seed(_oneOff('r1'));

      await expectLater(
        repo.saveRule(_weekend, ruleId: 'r1', applyToAll: true),
        _fails('invalid_argument', 'applyToAll'),
      );
    });

    test('a serviceId outside the packages is invalid_argument', () async {
      repo.packages = const [PricedPackage(id: 'other', price: 1000000)];

      await expectLater(
        repo.saveRule(_weekend),
        _fails('invalid_argument', 'serviceId'),
      );
    });
  });

  group('splitRule', () {
    test(
      'ends the series the day before and starts a new one at the price',
      () async {
        repo.seed(_oneOff('r1', from: '2026-12-20', to: '2026-12-31'));

        final ids = await repo.splitRule(
          'r1',
          DateTime.utc(2026, 12, 25),
          price: 4000000,
        );

        expect(ids, hasLength(2));
        final byId = {for (final r in repo.ownerRules) r.id: r};
        expect(byId['r1']!.until, '2026-12-24');
        expect(byId['r1']!.price, 3000000);
        expect(byId[ids.last]!.price, 4000000);
        expect(byId[ids.last]!.start, '2026-12-25');
      },
    );

    test('without a price the series just ends', () async {
      repo.seed(_oneOff('r1'));

      final ids = await repo.splitRule('r1', DateTime.utc(2026, 12, 25));

      expect(ids, ['r1']);
      expect(repo.ownerRules.single.until, '2026-12-24');
    });

    test(
      'on the first day: deleted without a price, repriced with one',
      () async {
        repo.seed(_oneOff('r1', from: '2026-12-20'));
        repo.seed(_oneOff('r2', from: '2026-12-20'));

        expect(await repo.splitRule('r1', DateTime.utc(2026, 12, 20)), isEmpty);
        expect(
          await repo.splitRule(
            'r2',
            DateTime.utc(2026, 12, 20),
            price: 5000000,
          ),
          ['r2'],
        );

        expect(repo.ownerRules.map((r) => r.id), ['r2']);
        expect(repo.ownerRules.single.price, 5000000);
      },
    );

    test(
      'nothing left before the day: the whole series is replaced or deleted',
      () async {
        // today is 2026-10-01: this weekly series ended its run in September.
        const dead = PriceRule(
          id: 'w1',
          serviceId: 's1',
          price: 2000000,
          repeat: PriceRepeat.weekly,
          weekdays: {Weekday.sat},
          start: '2026-08-01',
          exceptions: {'2026-10-17': 2100000},
        );
        repo.seed(dead);
        repo.seed(
          const PriceRule(
            id: 'w2',
            serviceId: 's1',
            price: 2000000,
            repeat: PriceRepeat.weekly,
            weekdays: {Weekday.sat},
            start: '2026-08-01',
            until: '2026-12-31',
          ),
        );
        // Split on 2026-09-15 with a price: the part before (08-01..09-14) is already over.
        final ids = await repo.splitRule(
          'w1',
          DateTime.utc(2026, 9, 15),
          price: 3000000,
        );

        expect(ids, ['w1']);
        expect(repo.ownerRules.map((r) => r.id), ['w1', 'w2']);
        final w1 = repo.ownerRules.firstWhere((r) => r.id == 'w1');
        expect(w1.price, 3000000);
        expect(w1.until, isNull);
        expect(w1.start, '2026-08-01');

        expect(await repo.splitRule('w2', DateTime.utc(2026, 9, 15)), isEmpty);
        expect(repo.ownerRules.map((r) => r.id), ['w1']);
      },
    );

    test(
      'with an occurrence left before the day it still writes two',
      () async {
        repo.seed(
          const PriceRule(
            id: 'w1',
            serviceId: 's1',
            price: 2000000,
            repeat: PriceRepeat.weekly,
            weekdays: {Weekday.sat},
            start: '2026-08-01',
          ),
        );

        final ids = await repo.splitRule(
          'w1',
          DateTime.utc(2026, 10, 20),
          price: 3000000,
        );

        expect(ids, hasLength(2));
        expect(repo.ownerRules, hasLength(2));
      },
    );

    test('a day outside the rule is invalid_argument day', () async {
      repo.seed(_oneOff('r1', from: '2026-12-20', to: '2026-12-31'));

      await expectLater(
        repo.splitRule('r1', DateTime.utc(2027, 1, 5)),
        _fails('invalid_argument', 'day'),
      );
    });

    test('the days before the split keep their price', () async {
      repo.seed(
        _oneOff(
          'r1',
          from: '2026-12-20',
          to: '2026-12-31',
          exceptions: {'2026-12-22': 3500000, '2026-12-28': 3600000},
        ),
      );

      final ids = await repo.splitRule(
        'r1',
        DateTime.utc(2026, 12, 25),
        price: 1000000,
      );

      final byId = {for (final r in repo.ownerRules) r.id: r};
      expect(byId['r1']!.exceptions, {'2026-12-22': 3500000});
      expect(byId[ids.last]!.exceptions, {'2026-12-28': 3600000});
    });
  });

  group('setException', () {
    test('custom, skip and clear', () async {
      repo.seed(_oneOff('r1'));
      final day = DateTime.utc(2026, 12, 25);

      await repo.setException('r1', day, const PriceException.custom(4000000));
      expect(repo.ownerRules.single.exceptions, {'2026-12-25': 4000000});

      await repo.setException('r1', day, const PriceException.skip());
      expect(repo.ownerRules.single.exceptions, {'2026-12-25': null});

      await repo.setException('r1', day, const PriceException.clear());
      expect(repo.ownerRules.single.exceptions, isEmpty);
      expect(repo.exceptions, hasLength(3));
    });

    test(
      'a day outside the pattern is invalid_argument day, clear is not',
      () async {
        repo.seed(_oneOff('r1'));
        final outside = DateTime.utc(2027, 2, 1);

        await expectLater(
          repo.setException('r1', outside, const PriceException.skip()),
          _fails('invalid_argument', 'day'),
        );
        await repo.setException('r1', outside, const PriceException.clear());
      },
    );

    test('the 51st exception is exception_limit', () async {
      repo.seed(
        PriceRule(
          id: 'r2',
          serviceId: 's1',
          price: 2000000,
          repeat: PriceRepeat.weekly,
          weekdays: Weekday.values.toSet(),
          exceptions: {
            for (var i = 0; i < kMaxExceptions; i++)
              '2027-${(i ~/ 28 + 1).toString().padLeft(2, '0')}-'
                      '${(i % 28 + 1).toString().padLeft(2, '0')}':
                  null,
          },
        ),
      );

      await expectLater(
        repo.setException(
          'r2',
          DateTime.utc(2027, 6, 1),
          const PriceException.custom(1500000),
        ),
        _fails('exception_limit'),
      );
    });
  });

  group('deleteRule', () {
    test('removes the rule; another provider\'s is not_found', () async {
      repo.seed(_oneOff('r1'));
      repo.seed(_oneOff('theirs'), providerId: 'other');

      await repo.deleteRule('r1');
      await expectLater(repo.deleteRule('theirs'), _fails('not_found'));

      expect(repo.ownerRules, isEmpty);
      expect(repo.deletes, ['r1', 'theirs']);
    });
  });

  group('test hooks', () {
    test('nextErrorCode fails the next write once', () async {
      repo.nextErrorCode = 'rule_limit';

      await expectLater(repo.saveRule(_weekend), _fails('rule_limit'));
      await repo.saveRule(_weekend);

      expect(repo.ownerRules, hasLength(1));
    });

    test('rulesForService and watchProviderRules follow writes', () async {
      final seen = <int>[];
      final sub = repo
          .watchProviderRules('p1')
          .listen((l) => seen.add(l.length));
      await Future<void>.delayed(Duration.zero);
      await repo.saveRule(_weekend);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(seen, [0, 1]);
      expect(await repo.rulesForService('p1', 's1'), hasLength(1));
      expect(await repo.rulesForService('p1', 's2'), isEmpty);
    });
  });
}
