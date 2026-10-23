// test/data/jobs/job_rules_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_rules.dart';

void main() {
  group('JobRules', () {
    test('milestoneAmountsOf matches the domain table', () {
      // 4_200_000 -> 2_100_000 shoot, 2_100_000 delivery
      final m1 = milestoneAmountsOf(4200000);
      expect(m1.shoot, 2100000);
      expect(m1.delivery, 2100000);

      // 1_500_001 -> 750_000 shoot, 750_001 delivery (remainder to delivery)
      final m2 = milestoneAmountsOf(1500001);
      expect(m2.shoot, 750000);
      expect(m2.delivery, 750001);

      // 1 -> 0 shoot, 1 delivery
      final m3 = milestoneAmountsOf(1);
      expect(m3.shoot, 0);
      expect(m3.delivery, 1);
    });

    test('cityKeyOf follows the shared fixture', () {
      final file = File('test/fixtures/city_keys.json');
      final list = jsonDecode(file.readAsStringSync()) as List;
      for (final item in list) {
        final raw = item[0] as String;
        final expected = item[1] as String;
        expect(cityKeyOf(cityOf(raw)), expected, reason: 'Failed for cityKeyOf(cityOf("$raw"))');
      }
    });

    test('cityOf extracts city correctly', () {
      expect(cityOf('Quận 1, TP.HCM'), 'TP.HCM');
      expect(cityOf('Hoàn Kiếm, Hà Nội'), 'Hà Nội');
      expect(cityOf('Đà Nẵng'), 'Đà Nẵng');
    });

    test('budgetFit: none without budget, inBudget at max, over by the difference', () {
      const budget = JobBudget(min: 2000000, max: 4000000);

      // without budget
      final noBudget = budgetFit(3000000, null);
      expect(noBudget.fit, BudgetFit.none);
      expect(noBudget.over, 0);

      // in budget (less than max)
      final inB1 = budgetFit(3500000, budget);
      expect(inB1.fit, BudgetFit.inBudget);
      expect(inB1.over, 0);

      // in budget (exact max)
      final inB2 = budgetFit(4000000, budget);
      expect(inB2.fit, BudgetFit.inBudget);
      expect(inB2.over, 0);

      // over budget
      final over = budgetFit(4500000, budget);
      expect(over.fit, BudgetFit.over);
      expect(over.over, 500000);
    });

    test('deadlineLeft is null after the deadline', () {
      final now = DateTime.utc(2026, 10, 20, 10, 0);
      final deadline = now.add(const Duration(hours: 5));
      final job = Job(
        id: 'j1',
        customerId: 'c1',
        customer: const JobCustomer(name: 'A'),
        specialtyId: 'spec1',
        title: 'Title',
        description: 'Desc',
        schedule: const JobSchedule(kind: ScheduleKind.fixed, durationMinutes: 60),
        dayFrom: '2026-10-25',
        dayTo: '2026-10-25',
        area: const JobArea(areaId: 'a1', name: 'N', city: 'C', cityKey: 'c', lat: 0, lng: 0, geohash5: 'g'),
        wants: const JobWants(),
        allowedProviders: AllowedProviders.all,
        quoteDeadline: deadline,
        status: JobStatus.open,
        createdAt: now,
        updatedAt: now,
      );

      // Before deadline
      final leftBefore = deadlineLeft(job, now.add(const Duration(hours: 1)));
      expect(leftBefore, isNotNull);
      expect(leftBefore!.inHours, 4);

      // Exactly at deadline
      final leftAt = deadlineLeft(job, deadline);
      expect(leftAt, isNull);

      // After deadline
      final leftAfter = deadlineLeft(job, deadline.add(const Duration(minutes: 1)));
      expect(leftAfter, isNull);
    });
  });
}
