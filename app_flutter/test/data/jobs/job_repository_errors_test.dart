// test/data/jobs/job_repository_errors_test.dart
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/jobs/job_rules.dart';

void main() {
  group('jobErrorOf', () {
    test('details.code and details.field become a JobError', () {
      final functionsException = FirebaseFunctionsException(
        message: 'Invalid argument supplied',
        code: 'invalid-argument',
        details: {
          'code': 'deadline_passed',
          'field': 'quoteDeadline',
        },
      );

      final error = jobErrorOf(functionsException);
      expect(error.code, 'deadline_passed');
      expect(error.field, 'quoteDeadline');
    });

    test('unavailable becomes network', () {
      final unavailEx = FirebaseFunctionsException(
        message: 'Service unavailable',
        code: 'unavailable',
      );
      expect(jobErrorOf(unavailEx).code, 'network');

      final timeoutEx = FirebaseFunctionsException(
        message: 'Deadline exceeded',
        code: 'deadline-exceeded',
      );
      expect(jobErrorOf(timeoutEx).code, 'network');

      final socketEx = const SocketException('No route to host');
      expect(jobErrorOf(socketEx).code, 'network');
    });

    test('a plain message falls back to the code', () {
      final exWithoutDetails = FirebaseFunctionsException(
        message: 'Permission denied for user',
        code: 'permission-denied',
      );
      final err = jobErrorOf(exWithoutDetails);
      expect(err.code, 'Permission denied for user');
      expect(err.field, isNull);

      final genericEx = Exception('Something went wrong');
      final err2 = jobErrorOf(genericEx);
      expect(err2.code, contains('Something went wrong'));
    });
  });
}
