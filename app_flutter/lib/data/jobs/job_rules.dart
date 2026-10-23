// lib/data/jobs/job_rules.dart
//
// Pure domain rules, calculations and error adapters for jobs and quotes.
import 'dart:io' show SocketException;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:photobooking/core/text_fold.dart';
import 'package:photobooking/data/jobs/job.dart';

/// A domain or network error from a job callable or repository call.
class JobError implements Exception {
  const JobError(this.code, {this.field});
  final String code;
  final String? field;

  @override
  String toString() => field != null ? 'JobError($code, field: $field)' : 'JobError($code)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobError &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          field == other.field;

  @override
  int get hashCode => Object.hash(code, field);
}

/// Turns any exception into a [JobError].
/// Reads `details.code` and `details.field` from [FirebaseFunctionsException].
/// Unavailable/deadline-exceeded or [SocketException] becomes `network`.
JobError jobErrorOf(Object error) {
  if (error is JobError) {
    return error;
  }
  if (error is FirebaseFunctionsException) {
    final details = error.details;
    String? code;
    String? field;
    if (details is Map) {
      if (details['code'] is String) {
        code = details['code'] as String;
      }
      if (details['field'] is String) {
        field = details['field'] as String;
      }
    }
    if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
      return const JobError('network');
    }
    if (code != null) {
      return JobError(code, field: field);
    }
    return JobError(error.message ?? error.code, field: field);
  }
  if (error is SocketException) {
    return const JobError('network');
  }
  return JobError(error.toString());
}

/// Exact integer split of a net amount into shoot and delivery milestones (50/50).
/// Remainder goes to delivery: shoot = floor(price * 50 / 100), delivery = price - shoot.
({int shoot, int delivery}) milestoneAmountsOf(int price) {
  if (price < 0) {
    throw ArgumentError.value(price, 'price', 'must be non-negative');
  }
  final shoot = (price * 50) ~/ 100;
  final delivery = price - shoot;
  return (shoot: shoot, delivery: delivery);
}

/// Computes the city name from an area name (e.g. "Quận 1, TP.HCM" -> "TP.HCM").
String cityOf(String areaName) {
  final parts = areaName.split(', ');
  final last = parts.last;
  return parts.length > 1 ? last.trim() : areaName.trim();
}

/// Normalizes a city/area string to [a-z0-9] after folding Vietnamese diacritics.
/// Matches the TS `cityKeyOf(s: string)`.
String cityKeyOf(String s) {
  final folded = foldVietnamese(s).toLowerCase();
  return folded.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

enum BudgetFit { none, inBudget, over }

/// How a quote price compares to the customer's budget.
({BudgetFit fit, int over}) budgetFit(int price, JobBudget? budget) {
  if (budget == null) {
    return (fit: BudgetFit.none, over: 0);
  }
  if (price <= budget.max) {
    return (fit: BudgetFit.inBudget, over: 0);
  }
  return (fit: BudgetFit.over, over: price - budget.max);
}

/// Duration left until [Job.quoteDeadline], or null if already passed.
Duration? deadlineLeft(Job job, DateTime now) {
  if (!now.isBefore(job.quoteDeadline)) {
    return null;
  }
  return job.quoteDeadline.difference(now);
}
