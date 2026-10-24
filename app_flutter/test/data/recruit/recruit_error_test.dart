import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/recruit/recruit_post.dart';

void main() {
  test('every server code maps to its RecruitErrorCode; unknown → unknown; '
      'FirebaseFunctionsException unavailable → network', () {
    const table = {
      'not_accepting_orders': RecruitErrorCode.notAcceptingOrders,
      'invalid_argument': RecruitErrorCode.invalidArgument,
      'limit_exceeded': RecruitErrorCode.limitExceeded,
      'rate_limited': RecruitErrorCode.rateLimited,
      'recruit_blocked': RecruitErrorCode.recruitBlocked,
      'deadline_passed': RecruitErrorCode.deadlinePassed,
      'conflict': RecruitErrorCode.conflict,
      'membership_conflict': RecruitErrorCode.membershipConflict,
      'cooldown': RecruitErrorCode.cooldown,
      'studio_full': RecruitErrorCode.studioFull,
      'collab_full': RecruitErrorCode.collabFull,
      'member_busy': RecruitErrorCode.memberBusy,
      'day_taken': RecruitErrorCode.dayTaken,
      'not_found': RecruitErrorCode.notFound,
      'permission_denied': RecruitErrorCode.permissionDenied,
      'not_eligible': RecruitErrorCode.notEligible,
      'blocked': RecruitErrorCode.blocked,
    };
    for (final e in table.entries) {
      expect(recruitErrorCodeFrom(e.key), e.value, reason: e.key);
      // From a callable refusal: `details.code` wins over the transport code.
      final err = recruitErrorOf(
        FirebaseFunctionsException(
          message: 'x',
          code: 'failed-precondition',
          details: {'code': e.key},
        ),
      );
      expect(err.code, e.value, reason: 'details ${e.key}');
    }
    expect(recruitErrorCodeFrom('something_new'), RecruitErrorCode.unknown);
    expect(
      recruitErrorOf(
        FirebaseFunctionsException(message: 'boom', code: 'internal'),
      ).code,
      RecruitErrorCode.unknown,
    );
    for (final transport in ['unavailable', 'deadline-exceeded']) {
      expect(
        recruitErrorOf(
          FirebaseFunctionsException(message: 'offline', code: transport),
        ).code,
        RecruitErrorCode.network,
        reason: transport,
      );
    }
    expect(
      recruitErrorOf(const SocketException('no route')).code,
      RecruitErrorCode.network,
    );
    expect(recruitErrorOf(StateError('x')).code, RecruitErrorCode.unknown);
  });

  test('without details the message is the code (like bookingErrorOf)', () {
    final err = recruitErrorOf(
      FirebaseFunctionsException(message: 'rate_limited', code: 'unknown'),
    );
    expect(err.code, RecruitErrorCode.rateLimited);
  });

  test('details.field is kept; a <name>.contact field is contact info', () {
    final err = recruitErrorOf(
      FirebaseFunctionsException(
        message: 'x',
        code: 'invalid-argument',
        details: {'code': 'invalid_argument', 'field': 'message.contact'},
      ),
    );
    expect(err.code, RecruitErrorCode.invalidArgument);
    expect(err.field, 'message.contact');
    expect(err.isContact, isTrue);
    expect(
      const RecruitError(
        RecruitErrorCode.invalidArgument,
        field: 'title',
      ).isContact,
      isFalse,
    );
  });

  test('a RecruitError passes through unchanged', () {
    const e = RecruitError(RecruitErrorCode.collabFull);
    expect(identical(recruitErrorOf(e), e), isTrue);
  });
}
