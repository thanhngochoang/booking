import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/content/provider_type.dart';

void main() {
  test('missing providerType reads as individual', () {
    expect(ProviderType.fromCode(null), ProviderType.individual);
  });
  test('unknown providerType reads as individual', () {
    expect(ProviderType.fromCode('wizard'), ProviderType.individual);
    expect(ProviderType.fromCode(3), ProviderType.individual);
  });
  test('codes round trip and artist is an individual choice', () {
    for (final t in ProviderType.values) {
      expect(ProviderType.fromCode(t.code), t);
    }
    expect(ProviderType.artist.choice, ProviderChoice.individual);
    expect(ProviderType.studio.choice, ProviderChoice.studio);
  });
}
