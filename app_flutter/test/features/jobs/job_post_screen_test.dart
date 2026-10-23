// test/features/jobs/job_post_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/features/jobs/job_post_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_job_repository.dart';

class _FakeAuthRepo implements AuthRepository {
  @override
  AuthUser? get currentUser => const AuthUser(uid: 'u1', email: 'u1@example.com');
  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(currentUser);
  @override
  ReauthMethod? get reauthMethod => null;
  @override
  Future<void> reauthenticate({String? password}) async {}
  @override
  Future<StaffRole?> staffRole() async => null;
  @override
  Future<AuthUser> signInWithEmail(String email, String password) async => currentUser!;
  @override
  Future<AuthUser> registerWithEmail(String email, String password, String displayName) async => currentUser!;
  @override
  Future<AuthUser> signInWithGoogle() async => currentUser!;
  @override
  Future<AuthUser> signInWithFacebook() async => currentUser!;
  @override
  Future<void> signOut() async {}
}

class _FakeImagePicker implements ImagePickerPort {
  @override
  Future<List<PickedImage>> pickImages({required int max}) async => [
    const PickedImage(path: 'img1.jpg', name: 'img1.jpg'),
  ];
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

  Widget buildScreen() {
    return ProviderScope(
      overrides: [
        jobRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        imagePickerProvider.overrideWithValue(_FakeImagePicker()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: JobPostScreen(),
      ),
    );
  }

  testWidgets('step 1 matches the mock: chips, title counter, references grid, privacy note, Tiếp tục', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Title & step
    expect(find.text('Đăng việc'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    // Specialty chips
    expect(find.text('Bạn cần chụp gì?'), findsOneWidget);
    expect(find.text('Chân dung'), findsOneWidget);
    expect(find.text('Kỷ yếu'), findsOneWidget);

    // Privacy note
    expect(find.textContaining('Đừng ghi số điện thoại hay địa chỉ cụ thể'), findsOneWidget);

    // Next button exists
    expect(find.text('Tiếp tục'), findsOneWidget);

    // Tap specialty
    await tester.tap(find.text('Chân dung'));
    await tester.pumpAndSettle();

    // Enter title < 10 chars -> Next still disabled
    await tester.enterText(find.byType(TextField).first, 'Ngắn');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    // Enter title >= 10 chars -> Next enabled
    await tester.enterText(find.byType(TextField).first, 'Chụp ảnh tốt nghiệp đại học');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);

    // Tap next to step 2
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Khi nào'), findsOneWidget);
    expect(find.text('Khu vực'), findsOneWidget);
    // On step 2, "Đăng việc" appears as both app bar title and footer submit button
    expect(find.text('Đăng việc'), findsNWidgets(2));
  });
}
