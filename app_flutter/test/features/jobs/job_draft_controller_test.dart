// test/features/jobs/job_draft_controller_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/job_rules.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/features/jobs/job_draft_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_job_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._user);
  final AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(_user);

  @override
  ReauthMethod? get reauthMethod => null;

  @override
  Future<void> reauthenticate({String? password}) async {}

  @override
  Future<StaffRole?> staffRole() async => null;

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async => _user!;
  @override
  Future<AuthUser> registerWithEmail(String email, String password, String displayName) async => _user!;
  @override
  Future<AuthUser> signInWithGoogle() async => _user!;
  @override
  Future<AuthUser> signInWithFacebook() async => _user!;
  @override
  Future<void> signOut() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeJobRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = FakeJobRepository(currentUid: 'u1');
  });

  ProviderContainer makeContainer({Map<String, Object>? initialPrefs}) {
    if (initialPrefs != null) {
      SharedPreferences.setMockInitialValues(initialPrefs);
    }
    return ProviderContainer(
      overrides: [
        jobRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(
          const AuthUser(uid: 'u1', email: 'u1@example.com'),
        )),
      ],
    );
  }

  test('going back to step 1 keeps everything', () {
    final container = makeContainer();
    final ctl = container.read(jobDraftStateProvider.notifier);

    ctl.setSpecialty('portrait');
    ctl.setTitle('Chụp ảnh tốt nghiệp đại học');
    ctl.setDescription('Cần thợ quen chụp góc đẹp');

    expect(ctl.next(), isTrue);
    expect(container.read(jobDraftStateProvider).step, 2);

    ctl.setBudget(1000000, 2000000);
    ctl.setAllowed(AllowedProviders.artist);

    ctl.back();
    final state = container.read(jobDraftStateProvider);
    expect(state.step, 1);
    expect(state.draft.specialtyId, 'portrait');
    expect(state.draft.title, 'Chụp ảnh tốt nghiệp đại học');
    expect(state.draft.description, 'Cần thợ quen chụp góc đẹp');
    expect(state.draft.budget?.min, 1000000);
    expect(state.draft.allowedProviders, AllowedProviders.artist);
  });

  test('saveDraft stores the draft under jobDraft:<uid> and opening restores it', () async {
    final container = makeContainer();
    final ctl = container.read(jobDraftStateProvider.notifier);

    ctl.setSpecialty('wedding');
    ctl.setTitle('Chụp phóng sự cưới ngày 20/11');
    await ctl.saveDraft();

    final savedStr = prefs.getString('jobDraft:u1');
    expect(savedStr, isNotNull);
    final decoded = jsonDecode(savedStr!) as Map<String, dynamic>;
    expect(decoded['specialtyId'], 'wedding');
    expect(decoded['title'], 'Chụp phóng sự cưới ngày 20/11');

    // Create a new container to simulate opening again with same prefs
    final container2 = ProviderContainer(
      overrides: [
        jobRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(
          const AuthUser(uid: 'u1', email: 'u1@example.com'),
        )),
      ],
    );

    final restored = container2.read(jobDraftStateProvider);
    expect(restored.draft.specialtyId, 'wedding');
    expect(restored.draft.title, 'Chụp phóng sự cưới ngày 20/11');
  });

  test('discard deletes uploaded references and the stored draft', () async {
    final container = makeContainer();
    final ctl = container.read(jobDraftStateProvider.notifier);

    ctl.setSpecialty('event');
    ctl.setTitle('Chụp sự kiện khai trương');
    await ctl.saveDraft();

    await ctl.addReferences([
      const PickedImage(path: 'p1.jpg', name: 'p1.jpg'),
    ]);
    expect(repo.uploadedReferences, isNotEmpty);
    expect(container.read(jobDraftStateProvider).draft.references, hasLength(1));

    await ctl.discard();
    expect(repo.uploadedReferences, isEmpty);
    expect(prefs.getString('jobDraft:u1'), isNull);
    expect(container.read(jobDraftStateProvider).draft.specialtyId, isEmpty);
  });

  test('the budget chip clears both amounts', () {
    final container = makeContainer();
    final ctl = container.read(jobDraftStateProvider.notifier);

    ctl.setBudget(500000, 1500000);
    expect(container.read(jobDraftStateProvider).draft.budget, isNotNull);

    ctl.clearBudget();
    expect(container.read(jobDraftStateProvider).draft.budget, isNull);
  });

  test('a fixed schedule needs end after start before Tiếp tục is enabled on step 2', () {
    final container = makeContainer();
    final ctl = container.read(jobDraftStateProvider.notifier);

    ctl.setSpecialty('portrait');
    ctl.setTitle('Chụp ảnh chân dung ngoài trời');
    expect(ctl.next(), isTrue);

    // Now on step 2:
    expect(container.read(jobDraftStateProvider).step, 2);

    // Fixed schedule with no day
    ctl.setSchedule(const JobSchedule(kind: ScheduleKind.fixed, durationMinutes: 60));
    expect(ctl.canProceed(), isFalse);

    // Day and start set, but no end
    ctl.setSchedule(const JobSchedule(
      kind: ScheduleKind.fixed,
      day: '2026-10-30',
      start: '09:00',
      durationMinutes: 60,
    ));
    expect(ctl.canProceed(), isFalse);

    // End before start
    ctl.setSchedule(const JobSchedule(
      kind: ScheduleKind.fixed,
      day: '2026-10-30',
      start: '09:00',
      end: '08:00',
      durationMinutes: 60,
    ));
    expect(ctl.canProceed(), isFalse);

    // End equal to start
    ctl.setSchedule(const JobSchedule(
      kind: ScheduleKind.fixed,
      day: '2026-10-30',
      start: '09:00',
      end: '09:00',
      durationMinutes: 60,
    ));
    expect(ctl.canProceed(), isFalse);

    // End after start
    ctl.setSchedule(const JobSchedule(
      kind: ScheduleKind.fixed,
      day: '2026-10-30',
      start: '09:00',
      end: '11:00',
      durationMinutes: 120,
    ));
    expect(ctl.canProceed(), isTrue);
  });

  test('submit maps a field error to that field', () async {
    final container = makeContainer();
    final ctl = container.read(jobDraftStateProvider.notifier);

    ctl.setSpecialty('portrait');
    ctl.setTitle('Chụp chân dung 0901234567');
    ctl.setDescription('Liên hệ zalo 0901234567');

    // Simulate fake throwing JobError
    repo.nextCreateError = const JobError('invalid_argument', field: 'description.contact');
    var res = await ctl.submit();
    expect(res, isNull);
    expect(container.read(jobDraftStateProvider).errors['description'], 'Bỏ số điện thoại hoặc link khỏi mô tả');

    repo.nextCreateError = const JobError('invalid_argument', field: 'description');
    res = await ctl.submit();
    expect(res, isNull);
    expect(container.read(jobDraftStateProvider).errors['description'], 'Mô tả tối đa 1000 ký tự');

    repo.nextCreateError = const JobError('invalid_argument', field: 'title.contact');
    res = await ctl.submit();
    expect(res, isNull);
    expect(container.read(jobDraftStateProvider).errors['title'], 'Bỏ số điện thoại hoặc link khỏi tiêu đề');

    repo.nextCreateError = const JobError('invalid_argument', field: 'title');
    res = await ctl.submit();
    expect(res, isNull);
    expect(container.read(jobDraftStateProvider).errors['title'], 'Tiêu đề cần 10–60 ký tự');
  });

  test('submit returns jobId and matched', () async {
    final container = makeContainer();
    final ctl = container.read(jobDraftStateProvider.notifier);

    ctl.setSpecialty('portrait');
    ctl.setTitle('Chụp ảnh chân dung tốt nghiệp');
    repo.nextCreateMatched = 3;

    final res = await ctl.submit();
    expect(res, isNotNull);
    expect(res!.jobId, isNotEmpty);
    expect(res.matched, 3);
  });
}
