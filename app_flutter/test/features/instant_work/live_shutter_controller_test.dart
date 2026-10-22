import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';
import 'package:photobooking/features/instant_work/live_shutter_controller.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import '../../support/fake_instant_repository.dart';
import '../../support/instant_work_world.dart';

Future<(ProviderContainer, ProviderSubscription<AsyncValue<LiveShutterView>>)>
_open(InstantWorld world) async {
  final container = ProviderContainer(
    overrides: world.overrides,
    retry: (_, _) => null,
  );
  final sub = container.listen(liveShutterControllerProvider, (_, _) {});
  await container.read(liveShutterControllerProvider.future);
  return (container, sub);
}

void main() {
  test('primer is asked once after the first successful turn-on', () async {
    final repo = FakeInstantRepository(presence: presenceOf());
    final world = InstantWorld(repo: repo);
    final (container, sub) = await _open(world);
    final controller = container.read(liveShutterControllerProvider.notifier);
    var asked = 0;
    Future<void> primer() async => asked++;

    // A refusal is not a success: no primer.
    repo.liveShutterReasons = [LiveShutterReason.outsideServiceArea];
    await controller.setOnline(true, askPrimer: primer);
    expect(asked, 0);
    expect(sub.read().value!.reasons, [LiveShutterReason.outsideServiceArea]);

    repo.liveShutterReasons = const [];
    await controller.setOnline(true, askPrimer: primer);
    expect(asked, 1);
    expect(sub.read().value!.reasons, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(sub.read().value!.online, isTrue);

    await controller.setOnline(false, askPrimer: primer);
    await controller.setOnline(true, askPrimer: primer);
    expect(asked, 1);

    container.dispose();
    await repo.dispose();
  });

  test(
    'network error keeps the previous state and reports instantErrorNetwork',
    () async {
      final repo = FakeInstantRepository(presence: presenceOf());
      final (container, sub) = await _open(InstantWorld(repo: repo));
      final controller = container.read(liveShutterControllerProvider.notifier);
      final before = sub.read().value!;

      repo.failNext('setLiveShutter', 'network');
      Object? error;
      try {
        await controller.setOnline(true);
      } on Object catch (e) {
        error = e;
      }

      expect(error, const InstantError('network'));
      expect(
        instantErrorText(AppLocalizationsVi(), error!),
        'Mất kết nối. Thử lại nhé.',
      );
      expect(
        instantErrorText(AppLocalizationsVi(), const InstantError('conflict')),
        'Chưa thực hiện được. Thử lại nhé.',
      );
      final after = sub.read().value!;
      expect(after.busy, isFalse);
      expect(after.online, isFalse);
      expect(after.reasons, before.reasons);
      expect(after.presence, before.presence);

      container.dispose();
      await repo.dispose();
    },
  );

  test('switching on without a location permission adds the location lock '
      'and calls nothing', () async {
    final repo = FakeInstantRepository(presence: presenceOf());
    final world = InstantWorld(repo: repo)
      ..location.status = LocationPermissionStatus.notAsked
      ..location.statusAfterRequest = LocationPermissionStatus.denied;
    final (container, sub) = await _open(world);
    repo.calls.clear();

    await container
        .read(liveShutterControllerProvider.notifier)
        .setOnline(true);

    expect(world.location.requestCalls, 1);
    expect(repo.callsOf('setLiveShutter'), isEmpty);
    final v = sub.read().value!;
    expect(v.reasons, [LiveShutterReason.locationRequired]);
    expect(v.locked, isTrue);
    container.dispose();
    await repo.dispose();
  });

  test('price_changed on accept reloads the config', () async {
    final repo = FakeInstantRepository(
      presence: presenceOf(priceListVersion: null),
    );
    final (container, sub) = await _open(InstantWorld(repo: repo));
    expect(sub.read().value!.needsTerms, isTrue);
    repo.failNext('saveSettings', 'price_changed');
    repo.configValue = repo.configValue.copyWith(priceListVersion: 2);

    await expectLater(
      container.read(liveShutterControllerProvider.notifier).acceptPriceList(),
      throwsA(const InstantError('price_changed')),
    );
    final v = await container.read(liveShutterControllerProvider.future);
    expect(v.config.priceListVersion, 2);
    container.dispose();
    await repo.dispose();
  });
}
