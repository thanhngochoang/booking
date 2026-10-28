import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/fake_pass_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the plugin brightness ignores a platform without the plugin', () async {
    const b = PluginScreenBrightness();
    await b.raise();
    await b.restore();
  });

  test('the scanner factory is overridable with a fake', () {
    final fake = FakePassScanner();
    final c = ProviderContainer(
      overrides: [passScannerFactoryProvider.overrideWithValue(() => fake)],
    );
    addTearDown(c.dispose);
    expect(c.read(passScannerFactoryProvider)(), same(fake));
  });

  testWidgets('a fake scanner emits codes and draws its failure', (t) async {
    final fake = FakePassScanner()
      ..failure = PassScannerFailure.permissionDenied;
    final seen = <String>[];
    fake.codes().listen(seen.add);
    await t.pumpWidget(
      MaterialApp(home: fake.preview(errorBuilder: (_, f) => Text(f.name))),
    );
    expect(find.text('permissionDenied'), findsOneWidget);
    fake.emit('VE-7F3K-2QAB');
    await t.pump();
    expect(seen, ['VE-7F3K-2QAB']);
    await fake.toggleTorch();
    expect(fake.torchToggles, 1);
  });
}
