import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/notifications/notification_targets.dart';

/// Mirrors CLIENT_TARGET_PATTERNS of packages/domain/test/client_targets.ts
/// with `:id` filled in; the two lists must stay the same set.
const _accepted = [
  // Before S17
  '/bookings',
  '/notifications',
  '/me/awards',
  '/b/x',
  '/chat/x',
  '/u/x/badges',
  '/u/x',
  '/u/x?tab=reviews',
  // Events
  '/e/x',
  '/events/x/manage',
  // Earnings
  '/work/earnings',
  '/work/earnings/account',
  // Jobs
  '/jobs/x',
  '/jobs/x/applications',
  // Chụp ngay
  '/instant/x',
  '/work/instant',
  '/work/instant/x',
  '/work/instant/offer/x',
  // Delivery
  '/b/x/delivery',
  // Studio
  '/studio/members',
  '/me/studio',
  // Verification
  '/verify/start',
  '/verify/business',
  // Disputes and support
  '/disputes/x',
  '/help/chat',
  // Payments
  '/me/payments',
  // Recruiting and collaborators
  '/recruit/x',
  '/studio/recruit?post=x',
  '/collab',
  '/collab?offer=x',
];

void main() {
  test('allowlisted targets pass through', () {
    for (final t in [
      '/b/01HZX9',
      '/chat/abc_DEF-1',
      '/u/p1',
      '/u/p1?tab=reviews',
      '/u/p1/badges',
      '/me/awards',
      '/bookings',
      '/notifications',
    ]) {
      expect(safeTarget(t), t, reason: t);
    }
  });

  test('existing patterns unchanged', () {
    for (final t in [
      '',
      'b/1',
      'https://evil.example/b/1',
      '//evil.example/b/1',
      'javascript:alert(1)',
      '/admin',
      '/b/',
      '/b/1/pay',
      '/b/1?x=1',
      '/b/a b',
      '/b/../me',
      '/u/p1?tab=reviews&x=1',
      '/u/p1?tab=albums',
      '/u/p1#frag',
      '/settings/notifications',
      '/u/p1/ask',
      '/chat/1/extra',
    ]) {
      expect(safeTarget(t), isNull, reason: t);
    }
  });

  test('safeTarget accepts each new pattern and refuses it with a query', () {
    for (final t in [
      '/e/x',
      '/events/x/manage',
      '/work/earnings',
      '/work/earnings/account',
      '/jobs/x',
      '/jobs/x/applications',
      '/instant/x',
      '/work/instant',
      '/work/instant/x',
      '/work/instant/offer/x',
      '/b/x/delivery',
      '/studio/members',
      '/me/studio',
      '/verify/start',
      '/verify/business',
      '/disputes/x',
      '/help/chat',
      '/me/payments',
      '/recruit/x',
      '/collab',
    ]) {
      expect(safeTarget(t), t, reason: t);
      expect(safeTarget('$t?x=1'), isNull, reason: '$t?x=1');
      expect(safeTarget('$t?post=x'), isNull, reason: '$t?post=x');
      expect(
        safeTarget('$t?offer=x'),
        t == '/collab' ? '/collab?offer=x' : isNull,
      );
    }
  });

  test('every pattern of the TypeScript allowlist port is accepted as is', () {
    for (final t in _accepted) {
      expect(safeTarget(t), t, reason: t);
    }
  });

  test('post and offer are the only accepted query keys', () {
    expect(safeTarget('/studio/recruit?post=x'), '/studio/recruit?post=x');
    expect(safeTarget('/collab?offer=x'), '/collab?offer=x');
    expect(
      safeTarget('/studio/recruit?post=01HZ_x-9'),
      '/studio/recruit?post=01HZ_x-9',
    );
    for (final t in [
      '/studio/recruit',
      '/collab?post=x',
      '/studio/recruit?offer=x',
      '/studio/recruit?post=x&a=1',
      '/studio/recruit?a=1&post=x',
      '/studio/recruit?post=../x',
      '/studio/recruit?post=',
      '/studio/recruit?post',
      '/studio/recruit?post=a%20b',
      '/studio/recruit?post=x&post=y',
      '/studio/recruit?post=x&post=x',
      '/collab?offer=x&offer=y',
      '/collab?offer=',
      '/collab?offer=x&post=x',
      '/u/p1?tab=reviews&tab=reviews',
      '/u/p1?tab=albums&tab=reviews',
      '/u/p1?tab=reviews&tab=albums',
      '/bookings?tab=events',
    ]) {
      expect(safeTarget(t), isNull, reason: t);
    }
  });

  test('bad ids are refused', () {
    expect(safeTarget('/jobs/../x'), isNull);
    expect(safeTarget('/e/${'a' * 129}'), isNull);
    expect(safeTarget('/e/${'a' * 128}'), '/e/${'a' * 128}');
    for (final t in [
      '/jobs/a b',
      '/jobs/a%2Fb',
      '/jobs/a%2e%2e',
      '/events/x%00/manage',
      '/work/instant/offer/',
      '/b/x/delivery/',
      '/b/x/delivery/y',
      '/work/earnings/',
      '/me/studio/x',
      '/disputes/',
      '/recruit/x/y',
      '/jobs/x#a',
      '/e/x#',
    ]) {
      expect(safeTarget(t), isNull, reason: t);
    }
  });

  test('only booking and chat targets need an existence check', () {
    expect(targetNeedsExistenceCheck('/b/1'), isTrue);
    expect(targetNeedsExistenceCheck('/chat/1'), isTrue);
    expect(targetNeedsExistenceCheck('/me/awards'), isFalse);
    expect(targetNeedsExistenceCheck('/u/p1'), isFalse);
    expect(targetNeedsExistenceCheck('/e/x'), isFalse);
    expect(targetNeedsExistenceCheck('/events/x/manage'), isFalse);
  });
}
