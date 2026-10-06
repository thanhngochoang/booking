import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/notifications/notification_targets.dart';

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

  test('anything else is refused', () {
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

  test('only booking and chat targets need an existence check', () {
    expect(targetNeedsExistenceCheck('/b/1'), isTrue);
    expect(targetNeedsExistenceCheck('/chat/1'), isTrue);
    expect(targetNeedsExistenceCheck('/me/awards'), isFalse);
    expect(targetNeedsExistenceCheck('/u/p1'), isFalse);
  });
}
