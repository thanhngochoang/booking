// test/features/notifications/s30_notification_links_test.dart
//
// Every S30 notification type (packages/domain/src/notification.ts) opens a
// target the app allowlists and its router knows (the targets are the ones
// `notification_hooks.ts` writes), with its own visual, not the info row.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/notifications/notification_targets.dart';
import 'package:photobooking/features/notifications/notification_visuals.dart';

/// Type → the target its hook writes, ids filled in.
const _targets = {
  'spot_claim_approved': '/organizer/spots/bd',
  'spot_claim_rejected': '/organizer/spots/claim',
  'spot_resident_added': '/spots/bd',
  'gate_staff_invited': '/organizer/gate-staff',
  'entry_day_closed': '/e/ent1',
  'event_venue_requested': '/e/ev1',
  'event_venue_answered': '/events/ev1/manage',
  'shoot_question': '/b/b1',
  'pass_ready': '/b/b1',
};

void main() {
  test('each S30 type has its own visual', () {
    final fallback = notificationVisualOf('something_new');
    for (final type in _targets.keys) {
      final v = notificationVisualOf(type);
      expect(
        v.icon == fallback.icon && v.tone == fallback.tone,
        isFalse,
        reason: type,
      );
    }
  });

  test('each S30 target is allowlisted and routed', () {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    addTearDown(c.dispose);
    final config = c.read(routerProvider).configuration;
    for (final MapEntry(key: type, value: target) in _targets.entries) {
      expect(safeTarget(target), target, reason: type);
      expect(
        config.findMatch(Uri.parse(target)).isError,
        isFalse,
        reason: '$type → $target',
      );
    }
  });
}
