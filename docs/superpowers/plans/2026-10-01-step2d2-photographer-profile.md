# Step 2d2: Public Photographer Profile (S03) and Profile Hooks (S30 rows, S42 avatar) Implementation Plan

> **Battery/performance (2026-10-02, user):** this plan has no battery, idle, blur-budget or performance task or test steps. All of that runs once at the end in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Skip any such step inside a task (e.g. `expectIdle`, `expectBlurBudget`, listener counters, profiling); keep the functional tests.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Anyone signed in opens `/u/:uid` and sees in one scroll what a photographer shoots, how trustworthy they are and what they cost: a photo hero blurred into the page, avatar, name with the blue check, stats, bio, skills, and the tabs Portfolio / Gói / Lịch / Đánh giá, with a fixed bar "Nhắn tin hỏi trước" + "Đặt lịch · từ {giá}" (no phone, Zalo or WhatsApp before booking). The owner sees "Chỉnh sửa hồ sơ" instead. The profile tab (S30) gains the rows "Số điện thoại", "Kỹ năng" (with the completeness meter) and "Xem hồ sơ công khai"; "Sửa hồ sơ" (S42) and setup step 1 (S24) can change the avatar, and the avatar-style main button follows the new photo at once.

**Architecture:** One new core widget, `ImageBackdrop` (an `ImageFiltered` on a small decode of the photo inside its own `RepaintBoundary`, never a `BackdropFilter`). A one-shot public read model `PhotographerProfile` (= plan 3b1's `PhotographerSummary` + plan 2d1's `PhotographerIntro`) behind `PublicProfileRepository` (fake + Firestore adapter reusing 3b1's `photographerSummaryFrom`). S03 lives in `lib/features/photographer_profile/`: a `CustomScrollView` whose tab body is a `ValueListenableBuilder` of slivers, so switching tabs or calendar months rebuilds only that part; the portfolio is a lazy `SliverGrid` of `NetworkPhoto`s (decoded at tile size) paged by an `AsyncNotifier`. It reuses, without redefining: 3b1/3b3/3b4 read models and helpers (`ServiceRepository.activeFor`, `PostRepository.byPhotographer`, `RecommendationRepository.similar`, `startBooking`, `followProvider`), 2b's `PhotographerContactAction` (locked = inquiry only), 2c's `photographerSkillsProvider`/`skillCatalogProvider`/`skillsCompleteness`/`CompletenessMeter`, and 2d1's `AvailabilityCalendar` and `availabilityMonthProvider`. The avatar goes through 3c's `ImagePickerPort` and `MediaUploader` to `avatars/{uid}/{ulid}.jpg`; `users/{uid}` stores `avatarUrl` and the storage key `avatarPath` so the previous upload can be deleted.

**Tech Stack:** Flutter, Riverpod 3, go_router, `cloud_firestore` (adapters only), Firebase Storage through plan 3c's `MediaUploader`, Firestore and Storage rules + `@firebase/rules-unit-testing` (Node), `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §1.2 (`ImageBackdrop`, blur budget), §3b.1 (S03 "Nhắn tin hỏi trước" only before booking; phone gate on "Đặt lịch"), §3d.1 (`VerifiedMark` only for `verified`), §3d.2 (badges row hidden when there are none), §3e.9 (S03 "Thợ ảnh tương tự"), §4, §5 (S03, S30, S42), §6 step 2, §7; `docs/superpowers/specs/screens/discovery.md` (S03), `account.md` (S30, S42); `docs/superpowers/specs/components/shared-components.md` (`ImageBackdrop`, `AppAvatar`, `VerifiedMark`, `StatTile`, `SegmentedTabs`, `AppBottomSheet`, `AvailabilityCalendar`, `CompletenessMeter`, `BadgeChip`); `docs/superpowers/specs/data-model/README.md` §2.1 (ULID), §2.6 (store the storage key, not only the URL), `domain-model.md` (`Photographer`, `PhotographerStats`, `Service`, `User.avatar`); mock `docs/design/ui-mock.html` (`data-code="S03"`, `"S30"`, `"S42"`).

**Prerequisite (run order):** screen-codes → core-display-widgets → 2a → 2b → 3a1 → 3a2 → 3b1 → 3b2 → 2c → 2d1 → 3b3 → 3b4 → 3c → **2d2 (this plan)**. All of them must be done; do not re-create their files. This plan uses:

- screen-codes: `ScreenCode`, `ScreenCodes.photographerProfile` (`S03`), `.profile` (`S30`), `.editProfile` (`S42`); `test/support/idle.dart` (`expectIdle`); `docs/testing/battery-and-performance.md` (Android and iOS sections, the iOS one from the iOS-enablement plan).
- core-display-widgets: `VerifiedMark`, `VerifiedName(String name, {TextStyle? style})`, `StatTile({required String value, required String label})`, `StatTileRow({required List<StatTile> tiles})`, `hostWidget`.
- 2a: `/profile/phone?returnTo=…` (S33), `currentContactProvider` (read by `startBooking`), the S42 phone section of `EditProfileScreen`.
- 2b: `PhotographerContactAction({required String photographerId, required ContactAccess access, required String source, …, VoidCallback? onInquiry})`, `ContactAccess.locked`, `ContactDial`, `photographerContactRepositoryProvider`, `FakePhotographerContactRepository`, `externalLauncherProvider`/`FakeExternalLauncher`, `contactLinkRepositoryProvider`/`FakeContactLinkRepository`; route `/setup/4`.
- 3a1/3a2: `SegmentedTabs`/`SegmentOption`, `showAppSheet`, `expectBlurBudget` (`test/support/blur.dart`), `formatMoney`, `ErrorState`, `AppSkeleton`, `screenRouterApp` (`test/support/screen_host.dart`, wrapped in the test photo scope by 3b2).
- 3b1: `PhotographerSummary` (`heroUrl`, `hasRating`, …), `photographerSummaryFrom({required String id, Map<String, dynamic>? user, required Map<String, dynamic> photographer})`, `ServiceSummary`, `PostSummary` (`cover`), `PostPage`, `postRepositoryProvider`, `serviceRepositoryProvider`, `FakePostRepository`, `fixturePhotographer`, `fixturePost`.
- 3b2: `NetworkPhoto`, `AppAvatar`/`AppAvatarSize`, `formatRating`, `testPhotoScope` (`test/support/photo_scope.dart`).
- 3b3: `recommendationRepositoryProvider`, `RecommendationRepository.similar(String photographerId, {int limit = 8})`, `RecommendationPage`, `RecommendedPhotographer`.
- 3b4: `startBooking(BuildContext, WidgetRef, {required String photographerId, String? serviceId, DateTime? date})` and `bookingPath` (`lib/features/discovery/book_entry.dart`), `followProvider` / `FollowController.load` / `.toggle` (`lib/features/discovery/engagement_controller.dart`), l10n `engagementError`, `DiscoveryWorld` and `discoveryPhotographers()` / `discoveryServices()` / `discoveryPosts()` (`test/support/discovery_world.dart`).
- 3c: `ImagePickerPort.pickImages({required int max})`, `PickedImage`, `FakeImagePicker`, `MediaUploader.upload(PickedImage, {required String storagePath})` / `.delete`, `UploadEvent`, `UploadedMedia`, `FakeMediaUploader`, `imagePickerProvider`, `mediaUploaderProvider` (`lib/features/create_post/create_post_providers.dart`), `newUlid`, `firebase/storage.rules` and its tests.
- 2c: `PhotographerSkills` (`specialties`, `specialtyIds`, `evidencePostIds`, `yearsExperience`, `empty`), `SpecialtySkill` (`id`, `level`), `SkillLevels`, `SkillGroup`, `skillCatalogProvider` (`TaxonomyCatalog.label(SkillGroup, String)`), `photographerSkillsProvider` (`FutureProvider.autoDispose.family<PhotographerSkills, String>`), `skillsRepositoryProvider`, `FakeSkillsRepository`, `skillsCompleteness(PhotographerSkills).percent`, `CompletenessMeter({required int percent, String? nextHint})`, l10n `skillsLevelBasic` / `skillsLevelGood` / `skillsLevelExpert`; routes `/profile/skills`, `/setup/3`. **Years of experience are read from `PhotographerSkills.yearsExperience`** (one source of truth, edited on S39).
- 2d1: `AvailabilityCalendar`, `AvailabilityLegend`, `availabilityMonthProvider`, `availabilityRepositoryProvider`, `FakeAvailabilityRepository`, `calendarTodayProvider`, `calendarDay`/`monthOf`/`addMonths`/`lastDayOfMonth`, `PhotographerIntro`, `introFromFirestore`, `packageMeta`, `SetupIntroScreen`, `PhotographerWorld`, `myIntroProvider`, `photographerIntroRepositoryProvider`, the 2d1 `ProfileTab` changes (setup card, post-switch redirect); routes `/setup`, `/setup/1`, `/setup/2`.

**Routes:** this plan owns `/u/:uid` (with `?tab=portfolio|services|calendar|reviews`, which 3b4 already links to). It links by path only to `/u/:uid/book` (step 4, S05; built by `bookingPath`) and `/u/:uid/ask` (step 4: open or create the `inquiry` chat with this photographer, then replace it with `/chat/:chatId`; contract defined here), `/p/:postId` (S02, 3b4), `/profile/skills` (2c), `/setup/1`, `/setup/2` (2d1), `/setup/4` (2b), `/settings/profile` (S42), `/profile/phone` (2a).

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`require_trailing_commas` is a lint and `flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only; features and `data/` import `package:photobooking/core/core.dart`; files inside `core/` import each other directly.
- **Firebase isolation:** `cloud_firestore` appears only in `lib/data/photographer/firestore_public_profile_repository.dart` and the existing adapters (`lib/data/user/user_repository.dart`); `firebase_storage` stays in plan 3c's `firebase_media_uploader.dart`. Read models, ports, fakes, controllers, widgets and screens import no Firebase package.
- **Contact rules (product decisions, do not weaken):** before a booking S03 offers only the in-app "Nhắn tin hỏi trước" (`ContactAccess.locked`); no phone, Zalo or WhatsApp on S03; no phone number is ever shown or written into `users/{uid}`; "Đặt lịch" goes through `startBooking`, which sends a customer without a phone number to S33 first and back via `returnTo`.
- **Data conventions:** avatar files are `avatars/{uid}/{ULID}.jpg`; `users/{uid}` stores `avatarUrl` (display) and `avatarPath` (the storage key, so the old file can be deleted); money is integer VND shown with `formatMoney`; ids are opaque strings.
- **Theme and UI:** one `AppButton.primary` per screen ("Đặt lịch · từ …" for visitors, "Chỉnh sửa hồ sơ" for the owner on S03; "Lưu" stays the primary on S42, so "Đổi ảnh đại diện" is an outline button). The blue check only when `verified`. Card fills are translucent (no blur) except one `GlassCard` per group; at most 4 `BackdropFilter`s per screen, none nested; `ImageBackdrop` uses none. No raw hex; Vietnamese strings with full diacritics in `lib/l10n/app_vi.arb`, then `flutter gen-l10n`.
- **Tests:** every screen tested at 320dp and 1.3× text, light and dark; `ProviderScope(retry: (_, _) => null, …)`; every provider that reaches Firebase, Storage, the gallery or `url_launcher` is overridden with a fake; network images go through the test photo scope.
- **Battery:** no `Timer`, `Stream.periodic` or `AnimationController` in this plan's code; S03 has no Firestore listener except the availability month while the "Lịch" tab is shown (`autoDispose`); the portfolio builds only visible tiles; the hero blur is computed on a small decode, once.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/widgets/image_backdrop.dart` (create) | `ImageBackdrop` |
| `lib/core/core.dart` (modify) | export it |
| `lib/data/photographer/public_profile.dart` (create) | `PhotographerProfile`, `PublicProfileRepository`, `FakePublicProfileRepository` |
| `lib/data/photographer/firestore_public_profile_repository.dart` (create) | `photographerProfileFrom`, `FirestorePublicProfileRepository` |
| `lib/data/photographer/public_profile_providers.dart` (create) | `publicProfileRepositoryProvider`, `photographerProfileProvider` |
| `lib/features/photographer_profile/profile_section.dart` (create) | `ProfileSection`, `profileSectionFromQuery`, `inquiryPath`, `startingPriceOf`, `responseLabel`, `skillLevelLabel` |
| `lib/features/photographer_profile/profile_providers.dart` (create) | `profilePackagesProvider`, `similarPhotographersProvider`, `PortfolioState`, `PortfolioController`, `portfolioProvider` |
| `lib/features/photographer_profile/widgets/profile_header.dart` (create) | hero, avatar, name, meta, follow, stats, bio, skills, owner meter |
| `lib/features/photographer_profile/widgets/profile_sections.dart` (create) | portfolio, packages, calendar, reviews slivers; similar photographers |
| `lib/features/photographer_profile/widgets/profile_bottom_bar.dart` (create) | inquiry + book, or edit |
| `lib/features/photographer_profile/photographer_profile_screen.dart` (create) | S03 |
| `lib/app/router.dart` (modify) | `/u/:uid` |
| `lib/data/user/user_repository.dart` (modify) | `setAvatar` (port, Firestore, fake) |
| `firebase/firestore.rules`, `firebase/storage.rules`, `firebase/rules-test/rules.test.mjs` (modify) | `avatarPath`, `avatars/{uid}/…` |
| `lib/features/settings/avatar_controller.dart`, `avatar_editor.dart` (create) | avatar change |
| `lib/features/settings/edit_profile_screen.dart`, `lib/features/photographer_setup/setup_intro_screen.dart` (modify) | `AvatarEditor` on S42 and S24 step 1 |
| `lib/features/settings/button_style_controller.dart`, `lib/main.dart` (modify) | `ctaAvatarProvider` |
| `lib/features/shell/placeholder_tabs.dart` (modify) | S30 rows, `AppAvatar`, scroll layout |
| `lib/l10n/app_vi.arb` (modify) | strings (listed per task) |
| `docs/superpowers/specs/screens/discovery.md`, `account.md`, `components/shared-components.md` (modify) | align S03/S30/S42 and `ImageBackdrop` |
| `test/support/profile_world.dart` (create) | S03 harness on top of `DiscoveryWorld` |
| tests | listed per task; `test/battery/photographer_profile_battery_test.dart` |

---

### Task 1: `ImageBackdrop`

**Files:**
- Create: `lib/core/widgets/image_backdrop.dart`, `test/core/widgets/image_backdrop_test.dart`
- Modify: `lib/core/core.dart`

**Interfaces:**
- Consumes: `AuroraBackground`, `hostWidget`.
- Produces: `const ImageBackdrop({super.key, required ImageProvider image, double height = 0.62, double sigma = 24, double opacity = 0.5, Widget? child})` — paints `AuroraBackground`, then (unless `MediaQuery.highContrastOf`) the photo over the top `height` of the box: decoded at ¼ of the box width × device pixel ratio (32–512 px, `ResizeImage`), scaled 1.3×, saturation 130 %, alpha `opacity`, blur `sigma` (`ImageFiltered`, `TileMode.decal`), fading to transparent with a gradient mask, all inside a `RepaintBoundary` keyed `image-backdrop-layer` and `ExcludeSemantics`; then [child]. Load errors show only the aurora.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/image_backdrop_test.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

/// A valid 1×1 transparent PNG.
final _png = MemoryImage(Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]));

Widget _backdrop({bool highContrast = false}) => SizedBox(
  height: 600,
  child: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(highContrast: highContrast),
      child: ImageBackdrop(image: _png, child: const Center(child: Text('nội dung'))),
    ),
  ),
);

void main() {
  testWidgets('blurs one small decode in its own layer, never with a BackdropFilter', (tester) async {
    await tester.pumpWidget(hostWidget(_backdrop()));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsOneWidget);
    final layer = find.byKey(const Key('image-backdrop-layer'));
    expect(tester.widget(layer), isA<RepaintBoundary>());
    expect(find.descendant(of: layer, matching: find.byType(ImageFiltered)), findsOneWidget);
    expect(find.ancestor(of: layer, matching: find.byType(ExcludeSemantics)), findsWidgets);
    expect(find.text('nội dung'), findsOneWidget);
    expect(find.byType(AuroraBackground), findsOneWidget);
  });

  testWidgets('decodes at a quarter of the width in device pixels', (tester) async {
    await tester.pumpWidget(hostWidget(_backdrop()));
    final image = tester.widget<Image>(
      find.descendant(of: find.byType(ImageBackdrop), matching: find.byType(Image)),
    );
    final dpr = tester.view.devicePixelRatio;
    expect((image.image as ResizeImage).width, (390 * dpr / 4).ceil().clamp(32, 512));
  });

  testWidgets('high contrast shows only the aurora', (tester) async {
    await tester.pumpWidget(hostWidget(_backdrop(highContrast: true)));
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(AuroraBackground), findsOneWidget);
    expect(find.text('nội dung'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x (${b.name})', (tester) async {
      await tester.pumpWidget(hostWidget(_backdrop(), brightness: b, width: 320, textScale: 1.3));
      expect(tester.takeException(), isNull);
    });
  }
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/image_backdrop_test.dart`
Expected: FAIL, `ImageBackdrop` undefined.

- [ ] **Step 3: Implement**

```dart
// lib/core/widgets/image_backdrop.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:photobooking/core/widgets/aurora_background.dart';

/// The lead photo of an intro page (S03 cover, later S16 and S28), blurred
/// behind the content (spec §1.2): scaled 1.3×, blur σ[sigma], saturation
/// 130 %, [opacity] over the aurora, fading into the page over the top
/// [height] of the box.
///
/// Cheap by construction: the photo is decoded at a quarter of the box
/// width (the blur removes the detail anyway), the blur is an
/// `ImageFiltered` on that one image, not a `BackdropFilter`, and it sits in
/// its own `RepaintBoundary` behind the content, so scrolling never repaints
/// or re-blurs it. With high contrast on only the aurora shows. Decorative,
/// so it is excluded from semantics.
class ImageBackdrop extends StatelessWidget {
  const ImageBackdrop({
    super.key,
    required this.image,
    this.height = 0.62,
    this.sigma = 24,
    this.opacity = 0.5,
    this.child,
  });

  final ImageProvider image;

  /// Share of the box height the photo covers before it has faded out.
  final double height;
  final double sigma;
  final double opacity;
  final Widget? child;

  /// Saturation 130 % (Rec. 709 luma weights) with the alpha scaled by
  /// [opacity], in one colour matrix (no extra layer for the opacity).
  static ColorFilter _filter(double opacity) => ColorFilter.matrix(<double>[
    1.23622, -0.21456, -0.02166, 0, 0, //
    -0.06378, 1.08544, -0.02166, 0, 0,
    -0.06378, -0.21456, 1.27834, 0, 0,
    0, 0, 0, opacity, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final plain = MediaQuery.highContrastOf(context);
    return AuroraBackground(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!plain)
            LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                final h = box.maxHeight * height;
                final decodeWidth = (w * MediaQuery.devicePixelRatioOf(context) / 4)
                    .ceil()
                    .clamp(32, 512)
                    .toInt();
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: ExcludeSemantics(
                      child: RepaintBoundary(
                        key: const Key('image-backdrop-layer'),
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white, Colors.transparent],
                            stops: [0.5, 1],
                          ).createShader(rect),
                          child: ClipRect(
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: sigma,
                                sigmaY: sigma,
                                tileMode: TileMode.decal,
                              ),
                              child: ColorFiltered(
                                colorFilter: _filter(opacity),
                                child: Transform.scale(
                                  scale: 1.3,
                                  child: Image(
                                    image: ResizeImage.resizeIfNeeded(decodeWidth, null, image),
                                    width: w,
                                    height: h,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ?child,
        ],
      ),
    );
  }
}
```

Export from `lib/core/core.dart`: `export 'package:photobooking/core/widgets/image_backdrop.dart';`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/image_backdrop_test.dart && flutter analyze`
Expected: PASS, 5 tests; analyze clean.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core test/core/widgets/image_backdrop_test.dart
git commit -m "feat(core): ImageBackdrop, a cached photo blur without BackdropFilter

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Public profile read model, repository and provider

**Files:**
- Create: `lib/data/photographer/public_profile.dart`, `lib/data/photographer/firestore_public_profile_repository.dart`, `lib/data/photographer/public_profile_providers.dart`, `test/data/photographer/public_profile_test.dart`

**Interfaces:**
- Consumes: `PhotographerSummary`, `photographerSummaryFrom` (3b1), `PhotographerIntro`, `introFromFirestore` (2d1).
- Produces:
  - `class PhotographerProfile { const PhotographerProfile({required PhotographerSummary summary, PhotographerIntro intro = const PhotographerIntro()}); String get id; bool get published; }` (`published` = `intro.onboardingComplete`).
  - `abstract class PublicProfileRepository { Future<PhotographerProfile?> load(String uid); }` — one-shot (no listener); null when `photographers/{uid}` does not exist.
  - `FakePublicProfileRepository([Iterable<PhotographerProfile> seed])` with `add`, `Object? failWith`, `int loads`.
  - `PhotographerProfile photographerProfileFrom({required String id, Map<String, dynamic>? user, required Map<String, dynamic> photographer})`; `FirestorePublicProfileRepository({FirebaseFirestore? db})` (reads `users/{uid}` and `photographers/{uid}` in parallel).
  - `publicProfileRepositoryProvider`, `photographerProfileProvider` (`FutureProvider.autoDispose.family<PhotographerProfile?, String>`).

- [ ] **Step 1: Write the failing test**

```dart
// test/data/photographer/public_profile_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/firestore_public_profile_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';

import '../../support/content_fixtures.dart';

void main() {
  test('maps the public user and photographer documents, never a phone', () {
    final p = photographerProfileFrom(
      id: 'p1',
      user: {'displayName': 'Minh Trí', 'avatarUrl': 'https://img.test/a.jpg'},
      photographer: {
        'verified': true,
        'bio': 'Ánh sáng tự nhiên.',
        'equipment': ['Sony A7 IV'],
        'onboardingComplete': true,
        'serviceArea': {'city': 'Quận 3', 'radiusKm': 15},
        'stats': {'rating': 4.9, 'reviewCount': 58, 'completedCount': 112, 'responseMinutes': 60},
      },
    );
    expect(p.id, 'p1');
    expect((p.summary.displayName, p.summary.verified, p.summary.areaLabel), ('Minh Trí', true, 'Quận 3'));
    expect((p.summary.reviewCount, p.summary.completedCount), (58, 112));
    expect(p.intro, const PhotographerIntro(bio: 'Ánh sáng tự nhiên.', equipment: ['Sony A7 IV'], onboardingComplete: true));
    expect(p.published, isTrue);
  });

  test('the fake loads by id, counts loads and fails on request', () async {
    final repo = FakePublicProfileRepository([PhotographerProfile(summary: fixturePhotographer('p1'))]);
    expect((await repo.load('p1'))!.published, isFalse);
    expect(await repo.load('nobody'), isNull);
    expect(repo.loads, 2);
    repo.failWith = StateError('offline');
    await expectLater(repo.load('p1'), throwsStateError);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/photographer/public_profile_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement**

```dart
// lib/data/photographer/public_profile.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';

/// What S03 shows about a photographer: the discovery summary (name, avatar,
/// verified, stats, area, starting price) plus the intro of setup step 1.
/// Built only from public documents; contact numbers are never part of it.
@immutable
class PhotographerProfile {
  const PhotographerProfile({required this.summary, this.intro = const PhotographerIntro()});

  final PhotographerSummary summary;
  final PhotographerIntro intro;

  String get id => summary.id;

  /// Setup finished (S34 sets `onboardingComplete`); only then is the
  /// profile shown to other people.
  bool get published => intro.onboardingComplete;
}

abstract class PublicProfileRepository {
  /// One-shot read; null when [uid] has no photographer document.
  Future<PhotographerProfile?> load(String uid);
}

class FakePublicProfileRepository implements PublicProfileRepository {
  FakePublicProfileRepository([Iterable<PhotographerProfile> seed = const []]) {
    seed.forEach(add);
  }

  final _profiles = <String, PhotographerProfile>{};
  Object? failWith;
  int loads = 0;

  void add(PhotographerProfile p) => _profiles[p.id] = p;

  @override
  Future<PhotographerProfile?> load(String uid) async {
    loads++;
    final error = failWith;
    if (error != null) {
      throw error;
    }
    return _profiles[uid];
  }
}
```

```dart
// lib/data/photographer/firestore_public_profile_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/content/firestore_photographer_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';

PhotographerProfile photographerProfileFrom({
  required String id,
  Map<String, dynamic>? user,
  required Map<String, dynamic> photographer,
}) => PhotographerProfile(
  summary: photographerSummaryFrom(id: id, user: user, photographer: photographer),
  intro: introFromFirestore(photographer),
);

class FirestorePublicProfileRepository implements PublicProfileRepository {
  FirestorePublicProfileRepository({FirebaseFirestore? db}) : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  @override
  Future<PhotographerProfile?> load(String uid) async {
    final (user, photographer) = await (
      _db.collection('users').doc(uid).get(),
      _db.collection('photographers').doc(uid).get(),
    ).wait;
    final data = photographer.data();
    if (data == null) {
      return null;
    }
    return photographerProfileFrom(id: uid, user: user.data(), photographer: data);
  }
}
```

```dart
// lib/data/photographer/public_profile_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/photographer/firestore_public_profile_repository.dart';
import 'package:photobooking/data/photographer/public_profile.dart';

final publicProfileRepositoryProvider = Provider<PublicProfileRepository>(
  (ref) => FirestorePublicProfileRepository(),
);

/// S03's profile, read once per visit (pull the screen again to refresh;
/// the owner's edits invalidate it on return).
final photographerProfileProvider = FutureProvider.autoDispose
    .family<PhotographerProfile?, String>(
      (ref, uid) => ref.watch(publicProfileRepositoryProvider).load(uid),
    );
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/photographer/public_profile_test.dart && flutter analyze`
Expected: PASS, 2 tests; analyze clean. If `photographerSummaryFrom` names a stats field differently than the map above (3b1 reads `stats.{rating, reviewCount, completedCount, responseMinutes, nextFreeDate}` and `serviceArea.city`), adapt the test map to 3b1's mapping, not the mapping.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/photographer test/data/photographer/public_profile_test.dart
git commit -m "feat(data): public photographer profile read model and adapter

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: S03 helpers and providers (sections, price, portfolio pages, similar)

**Files:**
- Create: `lib/features/photographer_profile/profile_section.dart`, `lib/features/photographer_profile/profile_providers.dart`, `test/features/photographer_profile/profile_providers_test.dart`
- Modify: `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `ServiceSummary`, `serviceRepositoryProvider`, `PostSummary`, `postRepositoryProvider`, `FakePostRepository`, `FakeServiceRepository`, `fixturePost`, `fixturePhotographer` (3b1); `recommendationRepositoryProvider`, `RecommendationRepository`, `RecommendationPage`, `RecommendedPhotographer` (3b3, `recommendation_models.dart` / `recommendation_providers.dart`); l10n `skillsLevelBasic`/`skillsLevelGood`/`skillsLevelExpert` (2c).
- Produces:
  - `enum ProfileSection { portfolio, services, calendar, reviews }`; `ProfileSection profileSectionFromQuery(String? value)` (`services`, `calendar`, `reviews`, anything else → portfolio); `String inquiryPath(String photographerId)` → `/u/<id>/ask`; `int? startingPriceOf(Iterable<ServiceSummary> services)` (lowest active price); `String responseLabel(int minutes, AppLocalizations l)` (`~45 phút`, `~1 giờ`); `String skillLevelLabel(int level, AppLocalizations l)`.
  - `profilePackagesProvider` (`FutureProvider.autoDispose.family<List<ServiceSummary>, String>`, active only, cheapest first); `similarPhotographersProvider` (`FutureProvider.autoDispose.family<List<PhotographerSummary>, String>`, empty on any failure, never the photographer themself).
  - `class PortfolioState { const PortfolioState({List<PostSummary> posts = const [], String? cursor, bool loadingMore = false}); bool get hasMore; }`; `class PortfolioController extends AsyncNotifier<PortfolioState> { PortfolioController(String photographerId); static const pageSize = 20; Future<void> loadMore(); }`; `portfolioProvider` (`AsyncNotifierProvider.autoDispose.family<PortfolioController, PortfolioState, String>`).
  - l10n: `profileResponseMinutes(minutes)` "~{minutes} phút", `profileResponseHours(hours)` "~{hours} giờ".

- [ ] **Step 1: Write the failing test**

```dart
// test/features/photographer_profile/profile_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';

class _Similar implements RecommendationRepository {
  _Similar({this.fail = false});
  final bool fail;

  @override
  Future<RecommendationPage> similar(String photographerId, {int limit = 8}) async {
    if (fail) {
      throw StateError('down');
    }
    return RecommendationPage(
      items: [
        for (final (i, id) in ['p2', photographerId, 'p3'].indexed)
          RecommendedPhotographer(photographer: fixturePhotographer(id), rank: i + 1, score: 1),
      ],
      requestId: 'r1',
      algorithm: 'test',
      algorithmVersion: '1',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  final l = AppLocalizationsVi();

  test('small helpers', () {
    expect(profileSectionFromQuery('services'), ProfileSection.services);
    expect(profileSectionFromQuery('calendar'), ProfileSection.calendar);
    expect(profileSectionFromQuery('reviews'), ProfileSection.reviews);
    expect(profileSectionFromQuery(null), ProfileSection.portfolio);
    expect(profileSectionFromQuery('x'), ProfileSection.portfolio);
    expect(inquiryPath('p1'), '/u/p1/ask');
    expect(startingPriceOf(discoveryServices().where((s) => s.photographerId == 'p1')), 1500000);
    expect(startingPriceOf(const []), isNull);
    expect(responseLabel(45, l), '~45 phút');
    expect(responseLabel(60, l), '~1 giờ');
    expect(responseLabel(150, l), '~3 giờ');
    expect([1, 2, 3].map((v) => skillLevelLabel(v, l)), ['Cơ bản', 'Thành thạo', 'Chuyên sâu']);
  });

  test('packages: active only, cheapest first', () async {
    final c = ProviderContainer(
      overrides: [serviceRepositoryProvider.overrideWithValue(FakeServiceRepository(discoveryServices()))],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    final list = await c.read(profilePackagesProvider('p1').future);
    expect(list.map((s) => s.id), ['s1', 's2']);
  });

  test('portfolio pages by 20 and stops at the end', () async {
    final posts = FakePostRepository([
      for (var i = 0; i < 25; i++) fixturePost('x$i', photographerId: 'p1', age: Duration(minutes: i + 1)),
    ]);
    final c = ProviderContainer(
      overrides: [postRepositoryProvider.overrideWithValue(posts)],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    final sub = c.listen(portfolioProvider('p1'), (_, _) {});
    addTearDown(sub.close);
    final first = await c.read(portfolioProvider('p1').future);
    expect((first.posts.length, first.hasMore), (20, true));
    await c.read(portfolioProvider('p1').notifier).loadMore();
    final all = c.read(portfolioProvider('p1')).value!;
    expect((all.posts.length, all.hasMore, all.posts.first.id), (25, false, 'x0'));
    await c.read(portfolioProvider('p1').notifier).loadMore(); // nothing more: no error
    expect(c.read(portfolioProvider('p1')).value!.posts.length, 25);
  });

  test('similar photographers leave out the photographer and fail quietly', () async {
    final ok = ProviderContainer(overrides: [recommendationRepositoryProvider.overrideWithValue(_Similar())], retry: (_, _) => null);
    addTearDown(ok.dispose);
    expect((await ok.read(similarPhotographersProvider('p1').future)).map((p) => p.id), ['p2', 'p3']);
    final down = ProviderContainer(overrides: [recommendationRepositoryProvider.overrideWithValue(_Similar(fail: true))], retry: (_, _) => null);
    addTearDown(down.dispose);
    expect(await down.read(similarPhotographersProvider('p1').future), isEmpty);
  });
}
```

(`RecommendationRepository` and the page types are in 3b3's `lib/data/recommendation/recommendation_models.dart`; `_Similar` implements only `similar` and lets `noSuchMethod` refuse the rest.)

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/photographer_profile/profile_providers_test.dart`
Expected: FAIL, `profile_section.dart` and `profile_providers.dart` not found.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`, then `flutter gen-l10n`:

```json
  "profileResponseMinutes": "~{minutes} phút",
  "@profileResponseMinutes": {"placeholders": {"minutes": {"type": "int"}}},
  "profileResponseHours": "~{hours} giờ",
  "@profileResponseHours": {"placeholders": {"hours": {"type": "int"}}},
```

```dart
// lib/features/photographer_profile/profile_section.dart
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The four tabs of S03.
enum ProfileSection { portfolio, services, calendar, reviews }

/// `?tab=` of `/u/:uid` (plan 3b4 links `?tab=services`).
ProfileSection profileSectionFromQuery(String? value) => switch (value) {
  'services' => ProfileSection.services,
  'calendar' => ProfileSection.calendar,
  'reviews' => ProfileSection.reviews,
  _ => ProfileSection.portfolio,
};

/// "Nhắn tin hỏi trước": step 4 opens (or creates) the `inquiry` chat with
/// this photographer at this path and replaces it with `/chat/:chatId`.
String inquiryPath(String photographerId) => '/u/$photographerId/ask';

/// "Đặt lịch · từ …": the cheapest active package, until the server's
/// `startingPrice` is there for every photographer.
int? startingPriceOf(Iterable<ServiceSummary> services) {
  int? min;
  for (final s in services) {
    if (s.active && (min == null || s.priceVnd < min)) {
      min = s.priceVnd;
    }
  }
  return min;
}

/// Median first-reply time in words: `~45 phút`, `~2 giờ`.
String responseLabel(int minutes, AppLocalizations l) => minutes < 60
    ? l.profileResponseMinutes(minutes)
    : l.profileResponseHours((minutes / 60).round());

String skillLevelLabel(int level, AppLocalizations l) => switch (level) {
  1 => l.skillsLevelBasic,
  2 => l.skillsLevelGood,
  _ => l.skillsLevelExpert,
};
```

```dart
// lib/features/photographer_profile/profile_providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';

/// S03 "Gói": active packages, cheapest first. One-shot.
final profilePackagesProvider = FutureProvider.autoDispose
    .family<List<ServiceSummary>, String>((ref, uid) async {
      final list = await ref.watch(serviceRepositoryProvider).activeFor(uid);
      return [
        for (final s in list)
          if (s.active) s,
      ]..sort((a, b) => a.priceVnd.compareTo(b.priceVnd));
    });

/// S03 "Thợ ảnh tương tự" (spec 3e.9). Never fails the screen: any error
/// gives an empty list and the section hides.
final similarPhotographersProvider = FutureProvider.autoDispose
    .family<List<PhotographerSummary>, String>((ref, uid) async {
      try {
        final page = await ref.watch(recommendationRepositoryProvider).similar(uid, limit: 8);
        return [
          for (final item in page.items)
            if (item.photographer.id != uid) item.photographer,
        ];
      } catch (_) {
        return const [];
      }
    });

@immutable
class PortfolioState {
  const PortfolioState({this.posts = const [], this.cursor, this.loadingMore = false});

  final List<PostSummary> posts;
  final String? cursor;
  final bool loadingMore;

  bool get hasMore => cursor != null;
}

/// The photographer's posts, newest first, 20 at a time ("Xem thêm ảnh").
class PortfolioController extends AsyncNotifier<PortfolioState> {
  PortfolioController(this.photographerId);

  final String photographerId;
  static const pageSize = 20;

  @override
  Future<PortfolioState> build() async {
    final page = await ref.watch(postRepositoryProvider).byPhotographer(photographerId, limit: pageSize);
    return PortfolioState(posts: page.posts, cursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) {
      return;
    }
    state = AsyncData(PortfolioState(posts: current.posts, cursor: current.cursor, loadingMore: true));
    try {
      final page = await ref
          .read(postRepositoryProvider)
          .byPhotographer(photographerId, cursor: current.cursor, limit: pageSize);
      state = AsyncData(PortfolioState(posts: [...current.posts, ...page.posts], cursor: page.nextCursor));
    } catch (_) {
      state = AsyncData(current); // keep what is shown; the button stays
    }
  }
}

final portfolioProvider = AsyncNotifierProvider.autoDispose
    .family<PortfolioController, PortfolioState, String>(PortfolioController.new);
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/features/photographer_profile/profile_providers_test.dart && flutter analyze`
Expected: PASS, 4 tests; analyze clean.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/photographer_profile lib/l10n test/features/photographer_profile
git commit -m "feat(profile): S03 sections, starting price, portfolio pages, similar

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 4: S03 "Hồ sơ nhiếp ảnh gia" screen and `/u/:uid`

**Files:**
- Create: `lib/features/photographer_profile/widgets/profile_header.dart`, `lib/features/photographer_profile/widgets/profile_sections.dart`, `lib/features/photographer_profile/widgets/profile_bottom_bar.dart`, `lib/features/photographer_profile/photographer_profile_screen.dart`, `test/support/profile_world.dart`, `test/features/photographer_profile/photographer_profile_screen_test.dart`
- Modify: `lib/app/router.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: Tasks 1–3; everything listed under Prerequisite for 3b1–3b4, 2b, 2c, 2d1.
- Produces:
  - `PhotographerProfileScreen({super.key, required String uid, ProfileSection initialSection = ProfileSection.portfolio})`; route `GoRoute(path: '/u/:uid', …)` reading `?tab=`. Step 4 adds `book` and `ask` as child routes of it.
  - `ProfileHeader({required PhotographerProfile profile, required bool owner})`, `PortfolioSliver`, `ServicesSliver`, `CalendarSliver`, `ReviewsSliver` (all `{required String photographerId}`, `ServicesSliver` also `required bool owner`), `ProfileBottomBar({required String photographerId, required bool owner, required VoidCallback onEdit})`.
  - Behaviour: hero = `summary.heroUrl` (cover, else avatar) in a 4:3 frame with the same photo blurred behind the page (`ImageBackdrop`; `AuroraBackground` when there is no photo); `AppAvatar` xl overlapping the hero; name (`VerifiedName` only when `verified`); "thể loại · khu vực" from 2c skills (else the summary's genres); "Theo dõi" / "Đang theo dõi" for visitors; four `StatTile`s (rating, shoots, reply time, years; "—" when unknown); bio; skill tags "Chân dung · Chuyên sâu"; equipment line; for the owner `CompletenessMeter`; `SegmentedTabs` Portfolio / Gói / Lịch / Đánh giá. Portfolio: lazy 2-column grid, a small badge on evidence posts (2c `evidencePostIds`), tap → `/p/:postId`, "Xem thêm ảnh", then "Thợ ảnh tương tự". Gói: packages (name, `packageMeta`, price); visitors tap → `startBooking(serviceId:)`, the owner → `/setup/2`. Lịch: read-only `AvailabilityCalendar` + legend, this month to +12. Đánh giá: "Chưa có đánh giá" until step 6. Bottom bar (visitor): `PhotographerContactAction(access: ContactAccess.locked, source: 'S03', onInquiry: push(inquiryPath))` + primary "Đặt lịch · từ 1,5M" → `startBooking`; no package → disabled + "Nhiếp ảnh gia chưa đăng gói". Owner: primary "Chỉnh sửa hồ sơ" → sheet (Giới thiệu `/setup/1`, Gói dịch vụ `/setup/2`, Kỹ năng `/profile/skills`, Ảnh đại diện và tên `/settings/profile`, Khu vực và liên hệ `/setup/4`); on return the profile, packages and skills are reloaded. Not published and not the owner → "Hồ sơ này chưa sẵn sàng"; unknown uid → "Không tìm thấy hồ sơ."; load error → `ErrorState` with "Thử lại".
  - Widget keys: `profile-tabs`, `profile-follow`, `profile-book`, `profile-edit`, `portfolio-<postId>`, `portfolio-more`, `service-<serviceId>`, `similar-<uid>`, `edit-intro`, `edit-packages`, `edit-skills`, `edit-photo`, `edit-contact`.
  - Test support: `ProfileWorld({UserRole role = UserRole.customer, bool hasPhone = true})` with `discovery` (3b4's `DiscoveryWorld`), `profiles`, `availability`, `skills`, `contacts`, `init()`, `overrides`, `app(String location, {Brightness brightness, double textScale})`, `router`.
  - l10n: `profileTabPortfolio` "Portfolio", `profileTabServices` "Gói", `profileTabCalendar` "Lịch", `profileTabReviews` "Đánh giá", `profileBook` "Đặt lịch", `profileBookFrom(price)` "Đặt lịch · từ {price}", `profileNoServices` "Nhiếp ảnh gia chưa đăng gói", `profileFollow` "Theo dõi", `profileFollowing` "Đang theo dõi", `profileStatReviews(count)` "{count} đánh giá", `profileStatNoReviews` "đánh giá", `profileStatShoots` "buổi chụp", `profileStatResponse` "phản hồi", `profileStatYears` "kinh nghiệm", `profileYearsValue(years)` "{years} năm", `profileEquipment(list)` "Thiết bị: {list}", `profileNoPortfolio` "Chưa có ảnh nào", `profileMorePhotos` "Xem thêm ảnh", `profileSimilar` "Thợ ảnh tương tự", `profilePhoto` "Ảnh portfolio", `profileEvidenceBadge` "Ảnh minh chứng kỹ năng", `profileNoReviewsTitle` "Chưa có đánh giá", `profileNoReviewsBody` "Đánh giá hiện ở đây sau những buổi chụp đầu tiên.", `profileNotFound` "Không tìm thấy hồ sơ.", `profileNotReadyTitle` "Hồ sơ này chưa sẵn sàng", `profileNotReadyBody` "Nhiếp ảnh gia đang hoàn thiện hồ sơ. Quay lại sau nhé.", `profileLoadError` "Không tải được hồ sơ.", `profileEdit` "Chỉnh sửa hồ sơ", `profileEditIntro` "Giới thiệu", `profileEditPackages` "Gói dịch vụ", `profileEditSkills` "Kỹ năng", `profileEditPhoto` "Ảnh đại diện và tên", `profileEditContact` "Khu vực và liên hệ".

- [ ] **Step 1: Write the failing tests**

```dart
// test/support/profile_world.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/photographer_profile/photographer_profile_screen.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';

import 'discovery_world.dart';
import 'screen_host.dart';

const profileBio = 'Ánh sáng tự nhiên, ít dàn dựng. Chuyên chân dung ngoài trời ở Sài Gòn.';

/// A phone tall enough that S03's header, tabs and the start of the tab
/// content are all laid out (slivers below the viewport are not built).
void usePhoneFor(WidgetTester tester, {double width = 390, double height = 1400}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 3b4's discovery world (p1 Minh Trí verified, p2 Hồng Nhung, p3, p4 …)
/// plus what S03 reads: public profiles, skills, the availability month,
/// the photographer's contact flags, and stub routes for every link.
class ProfileWorld {
  ProfileWorld({UserRole role = UserRole.customer, bool hasPhone = true})
    : discovery = DiscoveryWorld(role: role, hasPhone: hasPhone);

  final DiscoveryWorld discovery;
  final profiles = FakePublicProfileRepository();
  final availability = FakeAvailabilityRepository();
  final skills = FakeSkillsRepository();
  final contacts = FakePhotographerContactRepository();
  late GoRouter router;

  String get uid => discovery.uid;

  Future<void> init() async {
    await discovery.init();
    for (final p in discoveryPhotographers()) {
      profiles.add(
        PhotographerProfile(
          summary: p,
          intro: const PhotographerIntro(bio: profileBio, equipment: ['Sony A7 IV'], onboardingComplete: true),
        ),
      );
    }
    skills.seed(
      'p1',
      const PhotographerSkills(
        specialties: [
          SpecialtySkill(id: 'portrait', level: SkillLevels.expert, evidencePostIds: ['a']),
          SpecialtySkill(id: 'wedding'),
        ],
        languages: ['vi'],
        yearsExperience: 6,
      ),
    );
  }

  List<Override> get overrides => [
    ...discovery.overrides,
    publicProfileRepositoryProvider.overrideWithValue(profiles),
    availabilityRepositoryProvider.overrideWithValue(availability),
    calendarTodayProvider.overrideWithValue(DateTime.utc(2026, 10, 1)),
    skillsRepositoryProvider.overrideWithValue(skills),
    photographerContactRepositoryProvider.overrideWithValue(contacts),
    externalLauncherProvider.overrideWithValue(FakeExternalLauncher()),
    contactLinkRepositoryProvider.overrideWithValue(FakeContactLinkRepository()),
  ];

  Widget app(String location, {Brightness brightness = Brightness.dark, double textScale = 1.0}) {
    Widget stub(BuildContext _, GoRouterState s) => Text('stub ${s.uri}');
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/u/:uid',
          builder: (_, s) => PhotographerProfileScreen(
            uid: s.pathParameters['uid']!,
            initialSection: profileSectionFromQuery(s.uri.queryParameters['tab']),
          ),
          routes: [
            GoRoute(path: 'book', builder: stub),
            GoRoute(path: 'ask', builder: stub),
          ],
        ),
        for (final p in ['/home', '/profile/phone', '/profile/skills', '/setup/1', '/setup/2', '/setup/4', '/settings/profile', '/p/:id'])
          GoRoute(path: p, builder: stub),
      ],
    );
    return screenRouterApp(router: router, overrides: overrides, brightness: brightness, textScale: textScale);
  }
}
```

(The three `contact` imports are plan 2b's files; if 2b named the fakes' files differently, import them from where 2b put them: `FakeContactLinkRepository` lives with `ContactLinkRepository`, `FakeExternalLauncher` with `ExternalLauncher`.)

```dart
// test/features/photographer_profile/photographer_profile_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/user/user_profile.dart';

import '../../support/content_fixtures.dart';
import '../../support/profile_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<ProfileWorld> _world(
  WidgetTester tester, {
  UserRole role = UserRole.customer,
  bool hasPhone = true,
  double width = 390,
}) async {
  usePhoneFor(tester, width: width, height: width < 390 ? 640 : 1400);
  final w = ProfileWorld(role: role, hasPhone: hasPhone);
  await w.init();
  return w;
}

Finder get _page => find.byType(Scrollable).first;

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.descendant(of: _key(key), matching: find.byType(FilledButton))).onPressed != null;

void main() {
  testWidgets('a visitor sees who, how good and from how much; no phone anywhere', (tester) async {
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    expect(find.byType(VerifiedMark), findsOneWidget);
    expect(find.textContaining('Minh Trí'), findsWidgets);
    expect(find.text('Chân dung · Cưới · Quận 3'), findsOneWidget);
    for (final t in ['4,9', '58 đánh giá', '112', '~1 giờ', '6 năm']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text(profileBio), findsOneWidget);
    expect(find.text('Chân dung · Chuyên sâu'), findsOneWidget);
    expect(find.text('Cưới · Thành thạo'), findsOneWidget);
    expect(find.text('Thiết bị: Sony A7 IV'), findsOneWidget);
    expect(find.text('Đặt lịch · từ 1,5M'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\+84|0\d{9}')), findsNothing);
    expect(_key('profile-edit'), findsNothing);
    expect(find.byType(CompletenessMeter), findsNothing, reason: 'only the owner sees it');
  });

  testWidgets('"Đặt lịch" books, or asks for a phone number first', (tester) async {
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('profile-book'));
    await tester.pumpAndSettle();
    expect(find.text('stub /u/p1/book'), findsOneWidget);

    final noPhone = await _world(tester, hasPhone: false);
    await tester.pumpWidget(noPhone.app('/u/p1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('profile-book'));
    await tester.pumpAndSettle();
    expect(find.textContaining('stub /profile/phone?returnTo='), findsOneWidget);
  });

  testWidgets('the chat button opens the inquiry and nothing else', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Nhắn tin hỏi trước'), findsOneWidget);
    for (final channel in ['Gọi', 'Zalo', 'WhatsApp']) {
      expect(find.text(channel), findsNothing);
    }
    await tester.tap(find.byType(ContactDial));
    await tester.pumpAndSettle();
    expect(find.text('stub /u/p1/ask'), findsOneWidget);
    h.dispose();
  });

  testWidgets('tabs: packages book with the package, calendar is read-only, reviews are empty', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world(tester);
    w.availability.seed('p1', AvailabilityDay(day: DateTime.utc(2026, 10, 10), state: DayState.booked));
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gói'));
    await tester.pumpAndSettle();
    expect(find.text('Cặp đôi nửa ngày'), findsOneWidget);
    expect(find.text('3.200.000₫'), findsOneWidget);
    expect(find.text('Gói cũ'), findsNothing, reason: 'hidden packages are not offered');
    await tester.ensureVisible(_key('service-s2'));
    await tester.tap(_key('service-s2'));
    await tester.pumpAndSettle();
    expect(find.text('stub /u/p1/book?serviceId=s2'), findsOneWidget);

    await tester.pumpWidget(w.app('/u/p1?tab=calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Tháng 10, 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('10 tháng 10, đã đặt'), findsOneWidget);
    expect(w.availability.watchers, 1);

    await tester.tap(find.text('Đánh giá'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có đánh giá'), findsOneWidget);
    expect(w.availability.watchers, 0, reason: 'leaving the calendar tab closes its listener');
    h.dispose();
  });

  testWidgets('?tab=services opens the packages tab', (tester) async {
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1?tab=services'));
    await tester.pumpAndSettle();
    expect(find.text('Cặp đôi nửa ngày'), findsOneWidget);
  });

  testWidgets('the portfolio marks evidence photos and opens a post', (tester) async {
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_key('portfolio-a'), 200, scrollable: _page);
    expect(find.descendant(of: _key('portfolio-a'), matching: find.byIcon(Icons.workspace_premium_outlined)), findsOneWidget);
    expect(find.descendant(of: _key('portfolio-e'), matching: find.byIcon(Icons.workspace_premium_outlined)), findsNothing);
    await tester.tap(_key('portfolio-a'));
    await tester.pumpAndSettle();
    expect(find.text('stub /p/a'), findsOneWidget);
  });

  testWidgets('"Xem thêm ảnh" loads the next page', (tester) async {
    final w = await _world(tester);
    for (var i = 0; i < 25; i++) {
      w.discovery.posts.add(fixturePost('m$i', photographerId: 'p9', age: Duration(minutes: i + 1)));
    }
    w.profiles.add(PhotographerProfile(summary: fixturePhotographer('p9', name: 'Thu Hà'), intro: const PhotographerIntro(onboardingComplete: true)));
    await tester.pumpWidget(w.app('/u/p9'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_key('portfolio-more'), 400, scrollable: _page);
    await tester.tap(_key('portfolio-more'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_key('portfolio-m24'), 400, scrollable: _page);
    expect(_key('portfolio-m24'), findsOneWidget);
    expect(_key('portfolio-more'), findsNothing);
  });

  testWidgets('without packages the booking button waits and says why', (tester) async {
    final w = await _world(tester);
    w.profiles.add(PhotographerProfile(summary: fixturePhotographer('p9', name: 'Thu Hà'), intro: const PhotographerIntro(onboardingComplete: true)));
    await tester.pumpWidget(w.app('/u/p9'));
    await tester.pumpAndSettle();
    expect(find.text('Nhiếp ảnh gia chưa đăng gói'), findsOneWidget);
    expect(_enabled(tester, 'profile-book'), isFalse);
    expect(find.text('Đặt lịch'), findsOneWidget);
  });

  testWidgets('the blue check only for verified photographers; follow toggles', (tester) async {
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p2'));
    await tester.pumpAndSettle();
    expect(find.byType(VerifiedMark), findsNothing);
    await tester.tap(_key('profile-follow'));
    await tester.pumpAndSettle();
    expect(find.text('Đang theo dõi'), findsOneWidget);
  });

  testWidgets('unpublished, unknown and failing profiles each say so', (tester) async {
    final w = await _world(tester);
    w.profiles.add(PhotographerProfile(summary: fixturePhotographer('p8', name: 'Ẩn'), intro: const PhotographerIntro()));
    await tester.pumpWidget(w.app('/u/p8'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ này chưa sẵn sàng'), findsOneWidget);

    await tester.pumpWidget(w.app('/u/nobody'));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy hồ sơ.'), findsOneWidget);

    w.profiles.failWith = StateError('offline');
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được hồ sơ.'), findsOneWidget);
    w.profiles.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(find.text(profileBio), findsOneWidget);
  });

  testWidgets('the owner edits instead of booking, even before publishing', (tester) async {
    final w = await _world(tester, role: UserRole.photographer);
    w.profiles.add(PhotographerProfile(summary: fixturePhotographer(w.uid, name: 'Lan Anh'), intro: const PhotographerIntro()));
    await tester.pumpWidget(w.app('/u/${w.uid}'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ này chưa sẵn sàng'), findsNothing);
    expect(_key('profile-book'), findsNothing);
    expect(_key('profile-follow'), findsNothing);
    expect(find.byType(ContactDial), findsNothing);
    expect(find.byType(CompletenessMeter), findsOneWidget);
    final loadsBefore = w.profiles.loads;
    await tester.tap(_key('profile-edit'));
    await tester.pumpAndSettle();
    await tester.tap(_key('edit-skills'));
    await tester.pumpAndSettle();
    expect(find.text('stub /profile/skills'), findsOneWidget);
    w.router.pop();
    await tester.pumpAndSettle();
    expect(w.profiles.loads, greaterThan(loadsBefore), reason: 'coming back reloads the profile');
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      final w = await _world(tester, width: 320);
      await tester.pumpWidget(w.app('/u/p1', brightness: b, textScale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('profile-tabs')));
      await tester.tap(find.text('Gói'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('profile-tabs')));
      await tester.tap(find.text('Lịch'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/photographer_profile`
Expected: FAIL to compile, the screen and widget files do not exist.

- [ ] **Step 3: Implement**

Add the strings of the Interfaces list to `lib/l10n/app_vi.arb` (placeholders: `price` String, `count` int, `years` int, `list` String) and run `flutter gen-l10n`.

```dart
// lib/features/photographer_profile/widgets/profile_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_completeness.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';

/// Top of S03: photo, avatar over it, name + check, genres · area, follow,
/// the four stats, bio, skill tags, equipment, and the owner's meter.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key, required this.profile, required this.owner});

  final PhotographerProfile profile;
  final bool owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = profile.summary;
    final skills = ref.watch(photographerSkillsProvider(s.id)).value ?? PhotographerSkills.empty;
    final catalog = ref.watch(skillCatalogProvider);
    final genres = skills.specialtyIds.isNotEmpty ? skills.specialtyIds : s.specialtyIds;
    final meta = [
      for (final id in genres.take(2)) catalog.label(SkillGroup.specialty, id),
      ?s.areaLabel,
    ].join(' · ');
    final nameStyle = theme.textTheme.headlineSmall?.copyWith(
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w600,
    );
    final cover = s.heroUrl;
    final years = skills.yearsExperience;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final coverHeight = box.maxWidth * 3 / 4;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: coverHeight,
                  child: cover == null
                      ? DecoratedBox(decoration: BoxDecoration(gradient: ctaGradientFor(theme.brightness)))
                      : NetworkPhoto(url: cover),
                ),
                Padding(
                  padding: EdgeInsets.only(top: coverHeight - 28, left: AppSpace.s4, right: AppSpace.s4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppAvatar(url: s.avatarUrl, name: s.displayName, size: AppAvatarSize.xl),
                      const SizedBox(width: AppSpace.s3),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s1),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: s.verified
                                    ? VerifiedName(s.displayName, style: nameStyle)
                                    : Text(s.displayName, style: nameStyle),
                              ),
                              if (meta.isNotEmpty) Text(meta, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      if (!owner)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s1),
                          child: _FollowButton(photographerId: s.id),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpace.s4),
              StatTileRow(
                tiles: [
                  StatTile(
                    value: s.hasRating ? formatRating(s.ratingAvg) : '—',
                    label: s.reviewCount > 0 ? l.profileStatReviews(s.reviewCount) : l.profileStatNoReviews,
                  ),
                  StatTile(value: '${s.completedCount}', label: l.profileStatShoots),
                  StatTile(
                    value: s.responseMinutes == null ? '—' : responseLabel(s.responseMinutes!, l),
                    label: l.profileStatResponse,
                  ),
                  StatTile(
                    value: years == null ? '—' : l.profileYearsValue(years),
                    label: l.profileStatYears,
                  ),
                ],
              ),
              if (profile.intro.bio.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s4),
                Text(profile.intro.bio, style: theme.textTheme.bodyMedium),
              ],
              if (skills.specialties.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s3),
                Wrap(
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s2,
                  children: [
                    for (final sk in skills.specialties)
                      _Tag('${catalog.label(SkillGroup.specialty, sk.id)} · ${skillLevelLabel(sk.level, l)}'),
                  ],
                ),
              ],
              if (profile.intro.equipment.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s2),
                Text(l.profileEquipment(profile.intro.equipment.join(', ')), style: theme.textTheme.bodySmall),
              ],
              if (owner) ...[
                const SizedBox(height: AppSpace.s4),
                CompletenessMeter(percent: skillsCompleteness(skills).percent),
              ],
              const SizedBox(height: AppSpace.s4),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3, vertical: AppSpace.s1),
        child: Text(text, style: theme.textTheme.labelMedium),
      ),
    );
  }
}

class _FollowButton extends ConsumerWidget {
  const _FollowButton({required this.photographerId});
  final String photographerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final following = ref.watch(followProvider)[photographerId] ?? false;
    return AppButton.outline(
      following ? l.profileFollowing : l.profileFollow,
      key: const Key('profile-follow'),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
      onPressed: () async {
        final ok = await ref.read(followProvider.notifier).toggle(photographerId);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l.engagementError)));
        }
      },
    );
  }
}
```

```dart
// lib/features/photographer_profile/widgets/profile_sections.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

class _Quiet extends StatelessWidget {
  const _Quiet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.s6),
    child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
  );
}

/// S03 "Portfolio": a lazy two-column grid (only visible tiles are built,
/// each photo decoded at tile size by `NetworkPhoto`), "Xem thêm ảnh", then
/// "Thợ ảnh tương tự".
class PortfolioSliver extends ConsumerWidget {
  const PortfolioSliver({super.key, required this.photographerId});
  final String photographerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(portfolioProvider(photographerId));
    final evidence = ref.watch(photographerSkillsProvider(photographerId)).value?.evidencePostIds ?? const <String>{};
    return switch (state) {
      AsyncData(:final value) when value.posts.isEmpty => SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(child: _Quiet(l.profileNoPortfolio)),
          SliverToBoxAdapter(child: _Similar(photographerId: photographerId)),
        ],
      ),
      AsyncData(:final value) => SliverMainAxisGroup(
        slivers: [
          SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpace.s2,
              crossAxisSpacing: AppSpace.s2,
            ),
            itemCount: value.posts.length,
            itemBuilder: (context, i) => _PortfolioTile(
              post: value.posts[i],
              evidence: evidence.contains(value.posts[i].id),
            ),
          ),
          if (value.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpace.s3),
                child: AppButton.outline(
                  l.profileMorePhotos,
                  key: const Key('portfolio-more'),
                  loading: value.loadingMore,
                  onPressed: () => ref.read(portfolioProvider(photographerId).notifier).loadMore(),
                ),
              ),
            ),
          SliverToBoxAdapter(child: _Similar(photographerId: photographerId)),
        ],
      ),
      AsyncError() => SliverToBoxAdapter(
        child: ErrorState(
          message: l.profileLoadError,
          onRetry: () => ref.invalidate(portfolioProvider(photographerId)),
        ),
      ),
      _ => SliverToBoxAdapter(child: AppSkeleton.box(height: 180)),
    };
  }
}

class _PortfolioTile extends StatelessWidget {
  const _PortfolioTile({required this.post, required this.evidence});
  final PostSummary post;
  final bool evidence;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      button: true,
      label: [
        post.caption.isEmpty ? l.profilePhoto : post.caption,
        if (evidence) l.profileEvidenceBadge,
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        key: Key('portfolio-${post.id}'),
        borderRadius: radius,
        onTap: () => context.push('/p/${post.id}'),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetworkPhoto(url: post.cover.url),
              if (evidence)
                Positioned(
                  top: AppSpace.s1,
                  right: AppSpace.s1,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: AppColors.overlay, shape: BoxShape.circle),
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpace.s1),
                      child: Icon(Icons.workspace_premium_outlined, size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Similar extends ConsumerWidget {
  const _Similar({required this.photographerId});
  final String photographerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final list = ref.watch(similarPhotographersProvider(photographerId)).value ?? const [];
    if (list.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.s5),
        Semantics(header: true, child: Text(l.profileSimilar, style: theme.textTheme.titleMedium)),
        const SizedBox(height: AppSpace.s2),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s3),
            itemBuilder: (context, i) {
              final p = list[i];
              return InkWell(
                key: Key('similar-${p.id}'),
                onTap: () => context.push('/u/${p.id}'),
                child: SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      AppAvatar(url: p.avatarUrl, name: p.displayName, size: AppAvatarSize.lg),
                      const SizedBox(height: AppSpace.s1),
                      Text(
                        p.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// S03 "Gói": a visitor taps a package to book it (phone gate included);
/// the owner taps to edit packages.
class ServicesSliver extends ConsumerWidget {
  const ServicesSliver({super.key, required this.photographerId, required this.owner});
  final String photographerId;
  final bool owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final packages = ref.watch(profilePackagesProvider(photographerId));
    return switch (packages) {
      AsyncData(:final value) when value.isEmpty => SliverToBoxAdapter(child: _Quiet(l.profileNoServices)),
      AsyncData(:final value) => SliverList.separated(
        itemCount: value.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s2),
        itemBuilder: (context, i) => _ServiceTile(
          service: value[i],
          onTap: owner
              ? () => context.push('/setup/2')
              : () => startBooking(context, ref, photographerId: photographerId, serviceId: value[i].id),
        ),
      ),
      AsyncError() => SliverToBoxAdapter(
        child: ErrorState(
          message: l.profileLoadError,
          onRetry: () => ref.invalidate(profilePackagesProvider(photographerId)),
        ),
      ),
      _ => SliverToBoxAdapter(child: AppSkeleton.card(height: 72)),
    };
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});
  final ServiceSummary service;
  final VoidCallback onTap;

  /// List cards are radius 20 (spec §1 "Hình khối"); no blur on list rows.
  static const _radius = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = service;
    return Material(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
      borderRadius: _radius,
      child: InkWell(
        key: Key('service-${s.id}'),
        borderRadius: _radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: theme.textTheme.titleSmall),
                    Text(
                      packageMeta(l, durationMinutes: s.durationMinutes, editedCount: s.editedCount, deliveryDays: s.deliveryDays),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s3),
              Text(
                formatMoney(s.priceVnd),
                style: theme.textTheme.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// S03 "Lịch": the same `AvailabilityCalendar` as S20, read-only. Switching
/// months rebuilds only this sliver; its month listener closes when the
/// tab is left.
class CalendarSliver extends ConsumerStatefulWidget {
  const CalendarSliver({super.key, required this.photographerId});
  final String photographerId;

  @override
  ConsumerState<CalendarSliver> createState() => _CalendarSliverState();
}

class _CalendarSliverState extends ConsumerState<CalendarSliver> {
  late DateTime _month = monthOf(ref.read(calendarTodayProvider));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = ref.watch(calendarTodayProvider);
    final days = ref.watch(availabilityMonthProvider((uid: widget.photographerId, month: _month)));
    final known = days.value ?? const {};
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AvailabilityCalendar(
            month: _month,
            states: {for (final e in known.entries) e.key: e.value.state},
            today: today,
            minDate: today,
            maxDate: lastDayOfMonth(addMonths(monthOf(today), 12)),
            eventDays: {
              for (final e in known.entries)
                if (e.value.eventId != null) e.key,
            },
            onMonthChanged: (m) => setState(() => _month = m),
          ),
          const SizedBox(height: AppSpace.s3),
          const AvailabilityLegend(),
          if (days.hasError) ...[
            const SizedBox(height: AppSpace.s2),
            Text(l.calendarLoadError, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// S03 "Đánh giá": reviews arrive with step 6; until then a clear empty state.
class ReviewsSliver extends StatelessWidget {
  const ReviewsSliver({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s6),
        child: Column(
          children: [
            Text(l.profileNoReviewsTitle, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.s1),
            Text(l.profileNoReviewsBody, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
```

```dart
// lib/features/photographer_profile/widgets/profile_bottom_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/contact/contact_action.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';

/// The fixed bar of S03. Visitors: the in-app inquiry (the only contact
/// before a booking, spec 3b.1) and "Đặt lịch · từ …". Owner: "Chỉnh sửa
/// hồ sơ". Sits below the scroll view, so it never covers the last item.
class ProfileBottomBar extends ConsumerWidget {
  const ProfileBottomBar({super.key, required this.photographerId, required this.owner, required this.onEdit});

  final String photographerId;
  final bool owner;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final packages = ref.watch(profilePackagesProvider(photographerId));
    final from = startingPriceOf(packages.value ?? const []);
    final none = !owner && packages.hasValue && from == null;
    final Widget bar = owner
        ? AppButton.primary(
            l.profileEdit,
            key: const Key('profile-edit'),
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: onEdit,
          )
        : Row(
            children: [
              PhotographerContactAction(
                photographerId: photographerId,
                access: ContactAccess.locked,
                source: ScreenCodes.photographerProfile,
                onInquiry: () => context.push(inquiryPath(photographerId)),
              ),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: AppButton.primary(
                  from == null ? l.profileBook : l.profileBookFrom(formatMoney(from, short: true)),
                  key: const Key('profile-book'),
                  onPressed: from == null ? null : () => startBooking(context, ref, photographerId: photographerId),
                ),
              ),
            ],
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s3, AppSpace.s4, AppSpace.s3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (none) ...[
              Text(l.profileNoServices, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpace.s2),
            ],
            bar,
          ],
        ),
      ),
    );
  }
}
```

```dart
// lib/features/photographer_profile/photographer_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';
import 'package:photobooking/features/photographer_profile/widgets/profile_bottom_bar.dart';
import 'package:photobooking/features/photographer_profile/widgets/profile_header.dart';
import 'package:photobooking/features/photographer_profile/widgets/profile_sections.dart';

/// S03 "Hồ sơ nhiếp ảnh gia" at `/u/:uid`, for visitors and the owner.
class PhotographerProfileScreen extends ConsumerStatefulWidget {
  const PhotographerProfileScreen({super.key, required this.uid, this.initialSection = ProfileSection.portfolio});

  final String uid;
  final ProfileSection initialSection;

  @override
  ConsumerState<PhotographerProfileScreen> createState() => _PhotographerProfileScreenState();
}

class _PhotographerProfileScreenState extends ConsumerState<PhotographerProfileScreen> {
  late final ValueNotifier<ProfileSection> _section = ValueNotifier(widget.initialSection);

  @override
  void initState() {
    super.initState();
    // After the first frame: providers must not change while building.
    Future.microtask(() {
      if (!mounted) {
        return;
      }
      final me = ref.read(authRepositoryProvider).currentUser?.uid;
      if (me != null && me != widget.uid) {
        ref.read(followProvider.notifier).load(widget.uid);
      }
    });
  }

  @override
  void dispose() {
    _section.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    final target = await showAppSheet<String>(context, builder: (_) => const _EditSheet());
    if (target == null || !mounted) {
      return;
    }
    await context.push(target);
    if (!mounted) {
      return;
    }
    ref
      ..invalidate(photographerProfileProvider(widget.uid))
      ..invalidate(profilePackagesProvider(widget.uid))
      ..invalidate(photographerSkillsProvider(widget.uid));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profile = ref.watch(photographerProfileProvider(widget.uid));
    final owner = ref.read(authRepositoryProvider).currentUser?.uid == widget.uid;
    return ScreenCode(
      ScreenCodes.photographerProfile,
      child: switch (profile) {
        AsyncData(:final value?) when value.published || owner => _loaded(context, value, owner),
        AsyncData(:final value) => _Message(
          title: value == null ? l.profileNotFound : l.profileNotReadyTitle,
          body: value == null ? '' : l.profileNotReadyBody,
        ),
        AsyncError() => _Message(
          title: l.profileLoadError,
          onRetry: () => ref.invalidate(photographerProfileProvider(widget.uid)),
        ),
        _ => const _Loading(),
      },
    );
  }

  Widget _loaded(BuildContext context, PhotographerProfile p, bool owner) {
    final l = context.l10n;
    final hero = p.summary.heroUrl;
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? Padding(
                padding: const EdgeInsets.all(AppSpace.s1),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: AppColors.overlay, shape: BoxShape.circle),
                  child: BackButton(color: Colors.white, onPressed: () => context.pop()),
                ),
              )
            : null,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: ProfileHeader(profile: p, owner: owner)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: ValueListenableBuilder<ProfileSection>(
                valueListenable: _section,
                builder: (context, value, _) => SegmentedTabs<ProfileSection>(
                  key: const Key('profile-tabs'),
                  options: [
                    SegmentOption(value: ProfileSection.portfolio, label: l.profileTabPortfolio),
                    SegmentOption(value: ProfileSection.services, label: l.profileTabServices),
                    SegmentOption(value: ProfileSection.calendar, label: l.profileTabCalendar),
                    SegmentOption(value: ProfileSection.reviews, label: l.profileTabReviews),
                  ],
                  value: value,
                  onChanged: (s) => _section.value = s,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s3, AppSpace.s4, AppSpace.s6),
            sliver: ValueListenableBuilder<ProfileSection>(
              valueListenable: _section,
              builder: (context, value, _) => switch (value) {
                ProfileSection.portfolio => PortfolioSliver(photographerId: widget.uid),
                ProfileSection.services => ServicesSliver(photographerId: widget.uid, owner: owner),
                ProfileSection.calendar => CalendarSliver(photographerId: widget.uid),
                ProfileSection.reviews => const ReviewsSliver(),
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: ProfileBottomBar(photographerId: widget.uid, owner: owner, onEdit: _edit),
    );
    return hero == null
        ? AuroraBackground(child: scaffold)
        : ImageBackdrop(image: NetworkImage(hero), child: scaffold);
  }
}

class _EditSheet extends StatelessWidget {
  const _EditSheet();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final entries = [
      ('edit-intro', l.profileEditIntro, Icons.badge_outlined, '/setup/1'),
      ('edit-packages', l.profileEditPackages, Icons.sell_outlined, '/setup/2'),
      ('edit-skills', l.profileEditSkills, Icons.auto_awesome_outlined, '/profile/skills'),
      ('edit-photo', l.profileEditPhoto, Icons.account_circle_outlined, '/settings/profile'),
      ('edit-contact', l.profileEditContact, Icons.call_outlined, '/setup/4'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s2, AppSpace.s5, AppSpace.s2),
          child: Text(l.profileEdit, style: Theme.of(context).textTheme.titleLarge),
        ),
        for (final (key, label, icon, path) in entries)
          ListTile(
            key: Key(key),
            leading: Icon(icon),
            title: Text(label),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pop(path),
          ),
        const SizedBox(height: AppSpace.s3),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.body = '', this.onRetry});

  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AuroraBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(),
      body: onRetry != null ? ErrorState(message: title, onRetry: onRetry) : EmptyState(title: title, body: body),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => AuroraBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          AppSkeleton.box(height: 220),
          const SizedBox(height: AppSpace.s4),
          AppSkeleton.line(width: 180),
          const SizedBox(height: AppSpace.s2),
          AppSkeleton.line(width: 240),
          const SizedBox(height: AppSpace.s4),
          AppSkeleton.card(height: 90),
        ],
      ),
    ),
  );
}
```

In `lib/app/router.dart` add the imports `package:photobooking/features/photographer_profile/photographer_profile_screen.dart` and `package:photobooking/features/photographer_profile/profile_section.dart`, and before `StatefulShellRoute.indexedStack(`:

```dart
      GoRoute(
        path: '/u/:uid',
        builder: (_, state) => PhotographerProfileScreen(
          uid: state.pathParameters['uid']!,
          initialSection: profileSectionFromQuery(state.uri.queryParameters['tab']),
        ),
      ),
```

(`ContactAccess` is exported by `core.dart` from plan 2b's `lib/core/contact_channel.dart`; `PhotographerContactAction` is in 2b's `lib/features/contact/contact_action.dart`.)

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/features/photographer_profile && flutter analyze`
Expected: PASS (providers 4, screen 13); analyze clean. If `find.text('Chân dung · Cưới · Quận 3')` fails, print `catalog.label(SkillGroup.specialty, 'wedding')`: the label comes from 2c's catalogue and the test must use it. If the "Đánh giá" step still sees `watchers == 1`, the calendar sliver's provider is not `autoDispose` or something else watches it; fix that, not the test.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test
git commit -m "feat(profile): S03 public photographer profile at /u/:uid

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Avatar storage: `UserRepository.setAvatar`, Firestore and Storage rules

**Files:**
- Modify: `lib/data/user/user_repository.dart`, `test/data/user/fake_user_repository_test.dart`, `firebase/firestore.rules`, `firebase/storage.rules`, `firebase/rules-test/rules.test.mjs`

**Interfaces:**
- Produces:
  - `UserRepository.setAvatar(String uid, {required String url, required String storagePath}) → Future<String?>` — sets `users/{uid}.avatarUrl` and `.avatarPath` (merge) and returns the **previous** `avatarPath` (null when the old photo was not uploaded by the app, e.g. a Google photo). Firestore adapter: one `get` then one `set(merge)`. `FakeUserRepository` gains `Map<String, String> avatarPaths` and `bool failSetAvatar`.
  - Rules: `users/{uid}` may contain `avatarPath`, only as `avatars/<uid>/<26-char ULID>.jpg` of that same uid. Storage: `avatars/{uid}/{file}` readable by any signed-in user, written/overwritten/deleted only by `uid`, `image/*` up to 5 MB.

- [ ] **Step 1: Write the failing tests**

Append to `test/data/user/fake_user_repository_test.dart` inside `main()` (add `import 'package:photobooking/data/auth/auth_repository.dart';` if missing):

```dart
  test('setAvatar stores url and path and returns the previous path', () async {
    final users = FakeUserRepository();
    await users.ensureProfile(const AuthUser(uid: 'u1', displayName: 'Lan'));
    expect(await users.setAvatar('u1', url: 'https://s/a.jpg', storagePath: 'avatars/u1/A.jpg'), isNull);
    expect(await users.setAvatar('u1', url: 'https://s/b.jpg', storagePath: 'avatars/u1/B.jpg'), 'avatars/u1/A.jpg');
    expect((await users.watch('u1').first)!.avatarUrl, 'https://s/b.jpg');
    expect(users.avatarPaths['u1'], 'avatars/u1/B.jpg');
    users.failSetAvatar = true;
    await expectLater(users.setAvatar('u1', url: 'x', storagePath: 'y'), throwsStateError);
  });
```

Append to `firebase/rules-test/rules.test.mjs`:

```js
// ---- Plan 2d2: avatars ----
const ulidJpg = '01JB0Z8K3V5N6Q7R8S9T0V1W2X.jpg';

test('users keep the storage key of their own avatar only', async () => {
  const db = env.authenticatedContext('av1').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/av1'), { displayName: 'A' }));
  await assertSucceeds(updateDoc(doc(db, 'users/av1'), {
    avatarUrl: 'https://storage.test/a.jpg', avatarPath: `avatars/av1/${ulidJpg}`,
  }));
  await assertFails(updateDoc(doc(db, 'users/av1'), { avatarPath: `avatars/av2/${ulidJpg}` }));
  await assertFails(updateDoc(doc(db, 'users/av1'), { avatarPath: 'posts/av1/p/a.jpg' }));
  await assertFails(updateDoc(doc(db, 'users/av1'), { avatarPath: 'avatars/av1/a.jpg' }));
  await assertFails(updateDoc(doc(db, 'users/av1'), { avatarPath: 42 }));
});

test('a user uploads, replaces and deletes only their own avatar, images up to 5 MB', async () => {
  const st = env.authenticatedContext('av1').storage();
  const own = ref(st, `avatars/av1/${ulidJpg}`);
  await assertSucceeds(uploadBytes(own, photo(), jpeg));
  await assertSucceeds(uploadBytes(own, photo(8), jpeg));
  await assertSucceeds(getBytes(ref(env.authenticatedContext('av2').storage(), `avatars/av1/${ulidJpg}`)));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), `avatars/av1/${ulidJpg}`)));
  await assertFails(uploadBytes(ref(env.authenticatedContext('av2').storage(), 'avatars/av1/b.jpg'), photo(), jpeg));
  await assertFails(deleteObject(ref(env.authenticatedContext('av2').storage(), `avatars/av1/${ulidJpg}`)));
  await assertFails(uploadBytes(ref(st, 'avatars/av1/c.pdf'), photo(), { contentType: 'application/pdf' }));
  await assertFails(uploadBytes(ref(st, 'avatars/av1/d.jpg'), photo(5 * 1024 * 1024 + 1), jpeg));
  await assertSucceeds(deleteObject(own));
});
```

In the same file, plan 3c's test "every other Storage path is closed" uploads to `avatars/ph1/a.jpg` and expects a failure; that path is now open. Change that line to `await assertFails(uploadBytes(ref(st, 'misc/ph1/a.jpg'), photo(), jpeg));` (the test's purpose, a closed unknown path, is unchanged).

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/data/user/fake_user_repository_test.dart`; from `firebase/rules-test`: `npm test`
Expected: FAIL (`setAvatar` is not defined; the rules refuse `avatarPath` and every `avatars/` upload). If the emulator cannot run in this sandbox, say so and rely on the CI job "Firestore rules tests (emulator)".

- [ ] **Step 3: Implement**

In `lib/data/user/user_repository.dart`:

```dart
  // abstract class UserRepository — add:
  /// Points users/{uid} at a newly uploaded avatar ([url] for display,
  /// [storagePath] so it can be deleted later). Returns the previous
  /// storage path, or null when the old photo was not uploaded by the app.
  Future<String?> setAvatar(String uid, {required String url, required String storagePath});
```

```dart
  // FirestoreUserRepository — add:
  @override
  Future<String?> setAvatar(String uid, {required String url, required String storagePath}) async {
    final old = (await _doc(uid).get()).data()?['avatarPath'];
    await _doc(uid).set({
      'avatarUrl': url,
      'avatarPath': storagePath,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return old is String ? old : null;
  }
```

```dart
  // FakeUserRepository — add the fields and the method:
  final avatarPaths = <String, String>{};
  bool failSetAvatar = false;

  @override
  Future<String?> setAvatar(String uid, {required String url, required String storagePath}) async {
    if (failSetAvatar) {
      throw StateError('unavailable');
    }
    final old = avatarPaths[uid];
    avatarPaths[uid] = storagePath;
    final p = (_profiles[uid] ?? UserProfile(uid: uid, displayName: 'Người dùng')).copyWith(avatarUrl: url);
    _profiles[uid] = p;
    _c(uid).add(p);
    return old;
  }
```

`UserProfile.fromJson` ignores the extra `avatarPath` key (json_serializable allows unknown keys), so the model does not change.

In `firebase/firestore.rules`: add `'avatarPath'` to `userClientFields()`, add the function

```
    // users/{uid}.avatarPath: the storage key of the user's own uploaded
    // avatar, so the previous file can be deleted (data-model §2.6).
    function validAvatar(uid) {
      let d = request.resource.data;
      return !('avatarPath' in d)
        || (d.avatarPath is string
            && d.avatarPath.matches('^avatars/' + uid + '/[0-9A-HJKMNP-TV-Z]{26}[.]jpg$'));
    }
```

and append `&& validAvatar(uid)` to the `match /users/{uid}` create/update condition (keep the existing conditions and plan 2a's `private/{docId}` block).

In `firebase/storage.rules`, next to plan 3c's `posts` block:

```
    // Avatars: avatars/{uid}/{ulid}.jpg. Signed-in users may look at them;
    // only the owner adds, replaces or deletes, images up to 5 MB.
    match /avatars/{uid}/{file} {
      allow read: if request.auth != null;
      allow create, update: if request.auth != null
        && request.auth.uid == uid
        && request.resource.size < 5 * 1024 * 1024 + 1
        && request.resource.contentType.matches('image/.*');
      allow delete: if request.auth != null && request.auth.uid == uid;
    }
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/data/user && flutter analyze`; from `firebase/rules-test`: `npm test`
Expected: PASS, old and new tests. If the string concatenation inside `matches` is rejected, build the pattern first: `let pattern = '^avatars/' + uid + '/[0-9A-HJKMNP-TV-Z]{26}[.]jpg$';`.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/user test/data/user firebase
git commit -m "feat(rules): own avatar uploads and their storage key on users

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Avatar change on S42 and S24 step 1; the avatar button style follows at once

**Files:**
- Create: `lib/features/settings/avatar_controller.dart`, `lib/features/settings/avatar_editor.dart`, `test/features/settings/avatar_controller_test.dart`
- Modify: `lib/features/settings/edit_profile_screen.dart`, `lib/features/photographer_setup/setup_intro_screen.dart`, `lib/features/settings/button_style_controller.dart`, `lib/main.dart`, `lib/l10n/app_vi.arb`, `test/features/settings/settings_test.dart`, `test/support/photographer_world.dart`

**Interfaces:**
- Consumes: `imagePickerProvider`, `mediaUploaderProvider`, `FakeImagePicker`, `FakeMediaUploader`, `PickedImage`, `UploadedMedia`, `newUlid` (3c); `UserRepository.setAvatar` (Task 5); `AppAvatar` (3b2); `currentProfileProvider`, `buttonStyleProvider`.
- Produces:
  - `avatarControllerProvider` (`AsyncNotifierProvider.autoDispose<AvatarController, bool>`), `.change()`: pick one photo (cancel → nothing happens), upload to `avatars/{uid}/{ulid}.jpg`, `setAvatar`, then delete the previous upload; if `setAvatar` fails the new upload is deleted again (no orphan); value true after a change.
  - `const AvatarEditor({super.key})`: `AppAvatar` (lg) + outline "Đổi ảnh đại diện" (key `change-avatar`) with loading, and the snackbars "Đã đổi ảnh đại diện." / "Không đổi được ảnh. Thử lại nhé.". Placed at the top of S42's form and of S24 step 1's card.
  - `ctaAvatarProvider` (`Provider<ImageProvider?>` in `button_style_controller.dart`): the avatar for `CtaAvatarScope` when the style is `avatar` and a photo exists; `main.dart` passes it to `MyApp`. Because it follows `currentProfileProvider`, the main buttons switch to the new photo as soon as `users/{uid}` changes.
  - l10n: `editProfileChangeAvatar` "Đổi ảnh đại diện", `editProfileAvatarSaved` "Đã đổi ảnh đại diện.", `editProfileAvatarError` "Không đổi được ảnh. Thử lại nhé.".

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/settings/avatar_controller_test.dart
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';
import 'package:photobooking/features/settings/avatar_controller.dart';
import 'package:photobooking/features/settings/button_style_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = PickedImage(path: '/tmp/a.jpg', name: 'a.jpg');
const _b = PickedImage(path: '/tmp/b.jpg', name: 'b.jpg');
final _avatarPath = RegExp(r'^avatars/fake-1/[0-9A-HJKMNP-TV-Z]{26}\.jpg$');

Future<(ProviderContainer, FakeUserRepository, FakeMediaUploader)> _setup(
  List<List<PickedImage>> answers, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Lan');
  await users.ensureProfile(u);
  final uploader = FakeMediaUploader();
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
      imagePickerProvider.overrideWithValue(FakeImagePicker(answers)),
      mediaUploaderProvider.overrideWithValue(uploader),
    ],
  );
  addTearDown(c.dispose);
  final sub = c.listen(avatarControllerProvider, (_, _) {});
  addTearDown(sub.close);
  return (c, users, uploader);
}

void main() {
  test('uploads to avatars/{uid}/{ulid}.jpg, points the profile at it, removes the old one', () async {
    final (c, users, uploader) = await _setup([[_a], [_b]]);
    await c.read(avatarControllerProvider.notifier).change();
    final first = uploader.uploaded.single;
    expect(first, matches(_avatarPath));
    expect((await users.watch('fake-1').first)!.avatarUrl, 'https://storage.test/$first');
    expect(c.read(avatarControllerProvider).value, isTrue);

    await c.read(avatarControllerProvider.notifier).change();
    expect(uploader.deleted, [first]);
    expect(uploader.uploaded.single, isNot(first));
  });

  test('a cancelled pick changes nothing', () async {
    final (c, users, uploader) = await _setup([[]]);
    await c.read(avatarControllerProvider.notifier).change();
    expect(uploader.uploadCalls, 0);
    expect(c.read(avatarControllerProvider).value, isFalse);
    expect((await users.watch('fake-1').first)!.avatarUrl, isNull);
  });

  test('a failed upload keeps the old photo', () async {
    final (c, users, uploader) = await _setup([[_a]]);
    uploader.failNames.add('a.jpg');
    await c.read(avatarControllerProvider.notifier).change();
    expect(c.read(avatarControllerProvider).hasError, isTrue);
    expect(users.avatarPaths, isEmpty);
  });

  test('a failed profile write deletes the new upload again', () async {
    final (c, users, uploader) = await _setup([[_a]]);
    users.failSetAvatar = true;
    await c.read(avatarControllerProvider.notifier).change();
    expect(c.read(avatarControllerProvider).hasError, isTrue);
    expect(uploader.uploaded, isEmpty);
    expect(uploader.deleted.single, matches(_avatarPath));
  });

  test('the avatar button style follows a new photo at once', () async {
    final (c, users, _) = await _setup([[_a]], prefs: {'buttonStyle': 'avatar'});
    final cta = c.listen(ctaAvatarProvider, (_, _) {});
    addTearDown(cta.close);
    await c.read(currentProfileProvider.future);
    expect(cta.read(), isNull, reason: 'no photo yet: the gradient is used');
    await c.read(avatarControllerProvider.notifier).change();
    await Future<void>.delayed(Duration.zero);
    final url = (await users.watch('fake-1').first)!.avatarUrl!;
    expect(cta.read(), NetworkImage(url));
  });
}
```

In `test/features/settings/settings_test.dart`:

1. Imports: `package:photobooking/core/core.dart`, `package:photobooking/data/media/image_picker_port.dart`, `package:photobooking/data/media/media_uploader.dart`, `package:photobooking/features/create_post/create_post_providers.dart`, `'../../support/photo_scope.dart'`.
2. Give `_app` optional `FakeImagePicker? picker` and `FakeMediaUploader? uploader`; add `imagePickerProvider.overrideWithValue(picker ?? FakeImagePicker())` and `mediaUploaderProvider.overrideWithValue(uploader ?? FakeMediaUploader())` to its overrides, `retry: (_, _) => null` to its `ProviderScope`, and `builder: (context, child) => testPhotoScope(child: child!)` to its `MaterialApp.router`.
3. Append to `main()`:

```dart
  testWidgets('S42 changes the avatar and shows it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    final uploader = FakeMediaUploader();
    await tester.pumpWidget(await _app(
      auth: auth,
      users: users,
      prefs: prefs,
      picker: FakeImagePicker([
        [const PickedImage(path: '/tmp/a.jpg', name: 'a.jpg')],
      ]),
      uploader: uploader,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('change-avatar')));
    await tester.pumpAndSettle();
    expect(find.text('Đã đổi ảnh đại diện.'), findsOneWidget);
    expect(tester.widget<AppAvatar>(find.byType(AppAvatar)).url, 'https://storage.test/${uploader.uploaded.single}');
  });
```

In `test/support/photographer_world.dart` (plan 2d1): add `final picker = FakeImagePicker(); final uploader = FakeMediaUploader();`, the two overrides `imagePickerProvider.overrideWithValue(picker)` and `mediaUploaderProvider.overrideWithValue(uploader)`, and wrap the app's `builder` child in `testPhotoScope(child: …)` (imports as above), so S24 step 1 keeps working with the avatar row.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/settings`
Expected: FAIL to compile, `avatar_controller.dart` and `ctaAvatarProvider` do not exist.

- [ ] **Step 3: Implement**

Add the three strings to `lib/l10n/app_vi.arb`, run `flutter gen-l10n`.

```dart
// lib/features/settings/avatar_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';

/// Changes the signed-in user's avatar (S42, S24 step 1): pick one photo
/// from the gallery, upload it to `avatars/{uid}/{ulid}.jpg`, point
/// `users/{uid}` at it, then delete the previous upload. A cancelled pick
/// changes nothing. The value turns true after a change went through.
class AvatarController extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> change() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      return;
    }
    final picked = await ref.read(imagePickerProvider).pickImages(max: 1);
    if (picked.isEmpty) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final path = 'avatars/$uid/${newUlid()}.jpg';
      UploadedMedia? media;
      await for (final e in ref.read(mediaUploaderProvider).upload(picked.first, storagePath: path)) {
        if (e.isDone) {
          media = e.media;
        }
      }
      final done = media;
      if (done == null) {
        throw StateError('upload ended without a file');
      }
      final String? previous;
      try {
        previous = await ref.read(userRepositoryProvider).setAvatar(uid, url: done.url, storagePath: path);
      } catch (_) {
        await _quietDelete(path); // nothing points at the new file
        rethrow;
      }
      if (previous != null && previous != path) {
        await _quietDelete(previous);
      }
      return true;
    });
  }

  /// A leftover file is harmless; a failed clean-up must not fail the change.
  Future<void> _quietDelete(String path) async {
    try {
      await ref.read(mediaUploaderProvider).delete(path);
    } catch (_) {}
  }
}

final avatarControllerProvider =
    AsyncNotifierProvider.autoDispose<AvatarController, bool>(AvatarController.new);
```

```dart
// lib/features/settings/avatar_editor.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/features/settings/avatar_controller.dart';

/// The avatar and its "Đổi ảnh đại diện" button (S42, S24 step 1). The
/// circle crops the photo; it is uploaded as picked (at most 2048 px).
class AvatarEditor extends ConsumerWidget {
  const AvatarEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(currentProfileProvider).value;
    final busy = ref.watch(avatarControllerProvider).isLoading;
    ref.listen(avatarControllerProvider, (prev, next) {
      if (next.isLoading || !(prev?.isLoading ?? false)) {
        return;
      }
      final text = next.hasError ? l.editProfileAvatarError : (next.value ?? false) ? l.editProfileAvatarSaved : null;
      if (text != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(text)));
      }
    });
    return Row(
      children: [
        AppAvatar(url: profile?.avatarUrl, name: profile?.displayName ?? '', size: AppAvatarSize.lg),
        const SizedBox(width: AppSpace.s4),
        Expanded(
          child: AppButton.outline(
            l.editProfileChangeAvatar,
            key: const Key('change-avatar'),
            icon: const Icon(Icons.photo_library_outlined),
            loading: busy,
            onPressed: busy ? null : () => ref.read(avatarControllerProvider.notifier).change(),
          ),
        ),
      ],
    );
  }
}
```

`lib/features/settings/edit_profile_screen.dart` (as plan 2a left it): add `import 'package:photobooking/features/settings/avatar_editor.dart';` and make `const AvatarEditor(), const SizedBox(height: AppSpace.s5),` the first two children of the `Column` inside the `Form`.

`lib/features/photographer_setup/setup_intro_screen.dart` (plan 2d1): add the same import and insert `const AvatarEditor(), const SizedBox(height: AppSpace.s4),` right after `Text(l.setupIntroHint, …)` and its `SizedBox`, before the `setup-name` field.

`lib/features/settings/button_style_controller.dart`: add `import 'package:flutter/painting.dart';` and `import 'package:photobooking/data/auth/auth_providers.dart';`, and append:

```dart
/// What `CtaAvatarScope` paints behind main buttons: the viewer's photo when
/// they chose the avatar style and have one, else null (gradient). It
/// follows the profile stream, so a new avatar shows on the next frame.
final ctaAvatarProvider = Provider<ImageProvider?>((ref) {
  final url = ref.watch(currentProfileProvider).value?.avatarUrl;
  final avatarStyle = ref.watch(buttonStyleProvider) == ButtonStyleMode.avatar;
  return avatarStyle && url != null ? NetworkImage(url) : null;
});
```

`lib/main.dart`, in `_Root.build`: delete the `avatarUrl` and `useAvatar` locals and pass `ctaAvatar: ref.watch(ctaAvatarProvider),` to `MyApp`.

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/features/settings test/features/photographer_setup test/app && flutter analyze`
Expected: PASS (avatar controller 5, settings +1, 2d1's S24 tests still green); analyze clean.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test
git commit -m "feat(settings): change avatar on S42 and setup step 1; avatar button follows

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: S30 rows: phone, skills with the meter, public profile

**Files:**
- Modify: `lib/features/shell/placeholder_tabs.dart`, `lib/l10n/app_vi.arb`, `test/features/shell/placeholder_tabs_test.dart`, `test/features/responsive_test.dart`, `test/features/screen_codes_applied_test.dart` (if it exists)

**Interfaces:**
- Consumes: `photographerSkillsProvider`, `skillsCompleteness`, `CompletenessMeter`, `skillsRepositoryProvider`, `FakeSkillsRepository`, `PhotographerSkills`, `SpecialtySkill` (2c); `AppAvatar` (3b2); `myIntroProvider`, `_openSetupIfUnfinished` and the setup card (2d1); `AppTab.profile.path`.
- Produces (spec S30 "Bố cục bổ sung"):
  - Rows in one `GlassCard(highlight: false)` under the role card: "Số điện thoại" (key `profile-phone`) → `/profile/phone?returnTo=%2Fprofile` (S33, for both roles); for photographers "Kỹ năng" (key `profile-skills`) with `CompletenessMeter` (device-computed `skillsCompleteness`) → `/profile/skills`, reloading the skills on return; and "Xem hồ sơ công khai" (key `profile-public`) → `/u/{uid}`.
  - The header avatar becomes `AppAvatar` (lg) instead of the raw `CircleAvatar` (spec AppAvatar). The column moves from `LayoutBuilder` + `IntrinsicHeight` to `CustomScrollView` + `SliverFillRemaining(hasScrollBody: false)`: sign-out still sits at the bottom when there is room, and widgets without intrinsic sizes (the meter) are allowed.
  - l10n: `profilePhoneRow` "Số điện thoại", `profilePhoneBody` "Thêm hoặc đổi số dùng khi đặt lịch", `profileSkillsRow` "Kỹ năng", `profileSkillsBody` "Thể loại, mức độ và phong cách", `profilePublicRow` "Xem hồ sơ công khai", `profilePublicBody` "Hồ sơ như khách nhìn thấy".

The phone row shows no "đã có số" status on purpose: reading the private contact here would keep its listener open for as long as the tab shell lives (the tab stays mounted in the `IndexedStack`).

- [ ] **Step 1: Write the failing tests**

In `test/features/shell/placeholder_tabs_test.dart` (as plan 2d1 left it):

1. Imports: `package:photobooking/data/skills/photographer_skills.dart`, `package:photobooking/data/skills/skills_providers.dart`, `package:photobooking/data/skills/skills_repository.dart`, `package:photobooking/core/core.dart`.
2. In `_app` and in `routed`, add `skillsRepositoryProvider.overrideWithValue(skills ?? FakeSkillsRepository())` (give `routed` an optional `FakeSkillsRepository? skills` parameter) and, in `routed`, the routes `GoRoute(path: '/profile/phone', builder: (_, s) => Text('phone ${s.uri}'))`, `GoRoute(path: '/profile/skills', builder: (_, _) => const Text('skills'))`, `GoRoute(path: '/u/:uid', builder: (_, s) => Text('public ${s.pathParameters['uid']}'))`.
3. Append to `main()`:

```dart
  testWidgets('everyone can add a phone number from the profile', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(routed(auth, users, FakePhotographerIntroRepository()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-skills')), findsNothing);
    expect(find.byKey(const Key('profile-public')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('profile-phone')));
    await tester.tap(find.byKey(const Key('profile-phone')));
    await tester.pumpAndSettle();
    expect(find.text('phone /profile/phone?returnTo=%2Fprofile'), findsOneWidget);
  });

  testWidgets('photographers see skills with the meter and their public profile', (tester) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    final uid = auth.currentUser!.uid;
    final skills = FakeSkillsRepository()
      ..seed(uid, const PhotographerSkills(specialties: [SpecialtySkill(id: 'portrait')], languages: ['vi']));
    await tester.pumpWidget(routed(auth, users, FakePhotographerIntroRepository(), skills: skills));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('profile-skills')), matching: find.byType(CompletenessMeter)), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('profile-skills')));
    await tester.tap(find.byKey(const Key('profile-skills')));
    await tester.pumpAndSettle();
    expect(find.text('skills'), findsOneWidget);
    expect(skills.loadCalls, greaterThanOrEqualTo(1));

    await tester.pumpWidget(routed(auth, users, FakePhotographerIntroRepository(), skills: skills));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profile-public')));
    await tester.tap(find.byKey(const Key('profile-public')));
    await tester.pumpAndSettle();
    expect(find.text('public $uid'), findsOneWidget);
  });
```

In `test/features/responsive_test.dart` and `test/features/screen_codes_applied_test.dart` (if present) add `skillsRepositoryProvider.overrideWithValue(FakeSkillsRepository())` next to the 2d1 intro override.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/shell/placeholder_tabs_test.dart`
Expected: the two new tests FAIL (no rows).

- [ ] **Step 3: Implement**

Add the six strings to `lib/l10n/app_vi.arb`, run `flutter gen-l10n`.

In `lib/features/shell/placeholder_tabs.dart` add the imports `package:photobooking/app/tabs.dart`, `package:photobooking/data/skills/skills_completeness.dart`, `package:photobooking/data/skills/skills_providers.dart`, add these two widgets:

```dart
/// S30 rows: phone for everyone; skills and the public profile for
/// photographers.
class _AccountRows extends StatelessWidget {
  const _AccountRows({required this.uid, required this.isPhotographer});

  final String? uid;
  final bool isPhotographer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final id = uid;
    return GlassCard(
      highlight: false,
      child: Column(
        children: [
          ListTile(
            key: const Key('profile-phone'),
            leading: const Icon(Icons.phone_outlined),
            title: Text(l.profilePhoneRow),
            subtitle: Text(l.profilePhoneBody),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/profile/phone?returnTo=${Uri.encodeComponent(AppTab.profile.path)}'),
          ),
          if (isPhotographer && id != null) ...[
            _SkillsTile(uid: id),
            ListTile(
              key: const Key('profile-public'),
              leading: const Icon(Icons.storefront_outlined),
              title: Text(l.profilePublicRow),
              subtitle: Text(l.profilePublicBody),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/u/$id'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillsTile extends ConsumerWidget {
  const _SkillsTile({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final skills = ref.watch(photographerSkillsProvider(uid)).value;
    return ListTile(
      key: const Key('profile-skills'),
      leading: const Icon(Icons.auto_awesome_outlined),
      title: Text(l.profileSkillsRow),
      subtitle: skills == null
          ? Text(l.profileSkillsBody)
          : Padding(
              padding: const EdgeInsets.only(top: AppSpace.s1),
              child: CompletenessMeter(percent: skillsCompleteness(skills).percent),
            ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        await context.push('/profile/skills');
        if (context.mounted) {
          ref.invalidate(photographerSkillsProvider(uid));
        }
      },
    );
  }
}
```

and replace the `body:` of `ProfileTab`'s `Scaffold` (inside the `ScreenCode` wrapper) with:

```dart
      body: SafeArea(
        // Scrolls on short or landscape screens; sign-out still sits at the
        // bottom when there is room.
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpace.s5),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: AppAvatar(
                        url: profile?.avatarUrl,
                        name: profile?.displayName ?? '',
                        size: AppAvatarSize.lg,
                      ),
                    ),
                    // … unchanged: name, role label, 2d1's setup card, the
                    // role-switch GlassCard …
                    const SizedBox(height: AppSpace.s4),
                    _AccountRows(uid: profile?.uid, isPhotographer: isPhotographer),
                    const Spacer(),
                    const SizedBox(height: AppSpace.s5),
                    // … unchanged: the sign-out AppButton.outline …
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
```

The comments mark where the existing children stay exactly as they are (move them over unchanged); remove the old `CircleAvatar`, `LayoutBuilder`, `SingleChildScrollView`, `ConstrainedBox` and `IntrinsicHeight` wrappers.

- [ ] **Step 4: Run the whole suite**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests pass, including the existing profile-tab tests (sign-out, role switch) and the responsive test at 320×568 with 1.3× text.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test
git commit -m "feat(shell): S30 phone, skills and public profile rows

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Spec alignment, battery and performance check (moved)

Moved to `docs/superpowers/plans/2026-10-02-final-battery-performance.md` (section "2026-10-01-step2d2-photographer-profile.md"). Nothing to do here.
