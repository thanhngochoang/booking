import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('drafts and the step are kept per user and survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SetupDraftStore(prefs);
    const intro = IntroDraft(
      displayName: 'Minh Trí',
      bio: 'Ánh sáng',
      equipment: ['Sony'],
    );
    const pkg = PackageDraft(
      name: 'Chân dung',
      price: '1.500.000',
      durationMinutes: 120,
    );
    await store.saveIntro('u1', intro);
    await store.savePackage('u1', pkg);
    await store.setStep('u1', 2);
    final again = SetupDraftStore(prefs);
    expect(again.intro('u1'), intro);
    expect(again.package('u1'), pkg);
    expect(again.step('u1'), 2);
    expect(again.intro('u2'), isNull);
    expect(again.step('u2'), 1);
    await again.clearIntro('u1');
    await again.clearPackage('u1');
    expect(again.intro('u1'), isNull);
    expect(again.package('u1'), isNull);
  });

  test('a broken draft is ignored', () async {
    SharedPreferences.setMockInitialValues({'setup.intro.u1': '{not json'});
    final store = SetupDraftStore(await SharedPreferences.getInstance());
    expect(store.intro('u1'), isNull);
  });

  test('resume paths', () {
    expect(setupResumePath(1), '/setup/1');
    expect(setupResumePath(2), '/setup/2');
    expect(setupResumePath(3), '/setup/3');
    expect(setupResumePath(4), '/setup/4');
    expect(setupResumePath(9), '/setup/1');
    expect(const PackageDraft().isEmpty, isTrue);
    expect(const PackageDraft(durationMinutes: 60).isEmpty, isFalse);
  });
}
