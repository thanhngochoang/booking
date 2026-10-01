# Step 2b: Contact Dial, Launcher and Photographer Contact Channels (S32, S34) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A customer who has booked can tap one small "Liên hệ" button, see a tray with the channels the photographer switched on (Gọi điện, Zalo, WhatsApp) and open the chosen one in the phone, Zalo or WhatsApp without the app ever holding the photographer's number (S32). A photographer sets service area and contact channels in step 4/4 of profile setup (S34).

**Architecture:** `ContactDial` is a pure widget in `core/` (no data access, never opens URLs); it only reports `onSelected(channel)`. `ContactAction` (feature layer) glues it to `ContactLauncher`, which asks a `ContactLinkRepository` port for the one URL to open (a callable `getContactLink`, the server decides whether contact is unlocked) and opens it with `url_launcher`. The photographer's channel **flags** are public (`photographers/{uid}.contactChannels`); the **numbers** live in `photographers/{uid}/private/contact`, readable only by the owner, so the only way a customer gets a number is the server-built URL. S34 validates in a pure function, then writes flags, numbers and `serviceArea` in one batch behind a `PhotographerContactRepository` port (Firestore adapter + in-memory fake) with matching Firestore rules and rules tests.

**Tech Stack:** Flutter, Riverpod 3, go_router, `flutter_svg` (already present), new `url_launcher` and `cloud_functions`, `cloud_firestore` (adapter only), Firestore rules + `@firebase/rules-unit-testing` (Node), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3b.1–3b.6 and §7; `docs/superpowers/specs/screens/booking.md` (S32); `docs/superpowers/specs/screens/photographer.md` (S34); `docs/superpowers/specs/components/shared-components.md` (ContactDial, ContactLauncher, PhoneField, StepProgress); `docs/superpowers/specs/data-model/domain-model.md` (`ContactChannels`, `ContactNumbers`, `ContactAccessLog`, `contact_unlocked`, `get_contact_link`) and `data-model/README.md` (conventions, ports).

**Prerequisite (both must be done first):**

- `docs/superpowers/plans/2026-10-01-screen-codes.md`: `ScreenCode(String code, {Key? key, String? label, required Widget child})` and `ScreenCodes.contactAfterBooking` (`S32`), `ScreenCodes.setupContact` (`S34`) in `package:photobooking/core/core.dart`.
- `docs/superpowers/plans/2026-10-01-step2a-phone-and-customer-contact.md`: in `lib/core/phone.dart` `normalizePhone(String input, {bool international = false}) → String?`, `nationalDigits`, `formatNational`, `phoneFromField(String fieldText) → String?`, `nationalFromE164(String e164) → String`, `validatePhone(String? fieldText, AppLocalizations l) → String?`; `PhoneField` in `lib/core/widgets/phone_field.dart`; `UserContact`; `safeReturnTo`; and the test harness `hostWidget(Widget child, {Brightness brightness, double width = 390, double textScale = 1.0})` in `test/core/widgets/widget_host.dart`.
- `docs/superpowers/plans/2026-10-01-core-display-widgets.md` Task 5: `const StepProgress({super.key, required int current, required int total, String? label})`, which renders "4 / 4" and the semantics value "Bước 4 trên 4".

## How step 2 is split

| Plan | Content | Screens |
|---|---|---|
| 2a | phone logic, `PhoneField`, `UserContact` + rules, S33, S42 phone section | S33, S42 |
| **2b (this)** | `ContactDial`, `ContactLauncher`, `ContactLinkRepository` port, photographer contact channels, `PhoneField(international)` | S32, S34 |
| 2c | skills model, `SkillChip`, `LevelSelector`, `EvidencePicker`, `CompletenessMeter` | S38–S40 |
| 2d | photographer profile, setup steps 1–2, calendar | S03, S20, S24 |

## Out of scope: the server side (a separate, later plan)

The callable Cloud Function `getContactLink` does **not exist** and is not written here (no `functions/` code). This plan builds the client, the port and a fake. The contract the later Functions plan must implement (and the client already relies on):

- **Request** `{ bookingId | registrationId: string, channel: "call" | "zalo" | "whatsapp" }`.
- **Checks:** caller is the customer of that booking / registration; `contact_unlocked(subject)` (booking `requested | accepted | upcoming | completed (≤30 days)`, or ticket `paid` until 7 days after the event; `domain-model.md`); the channel flag is on in `photographers/{uid}.contactChannels`. Writes one `ContactAccessLog` row (`granted` true or false). Never logs the number.
- **Response** `{ url: string }`, built exactly like `contactUriFor` in Task 4: `tel:+84…`, `https://zalo.me/84…`, `https://wa.me/…` (no `+`), from `phone`, `zaloPhone ?? phone`, `whatsappPhone ?? phone`.
- **Errors:** `HttpsError("failed-precondition", "contact_locked", { code: "contact_locked" })` when locked; any other `details.code` (`permission_denied`, `not_found`, `invalid_argument`) is shown as a generic failure.
- Until it ships, `FunctionsContactLinkRepository` fails with `unavailable` in a real build; everything is tested against `FakeContactLinkRepository`.

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`require_trailing_commas` is a lint and `flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only; features import `package:photobooking/core/core.dart`; files inside `core/` import each other directly.
- `cloud_firestore` and `cloud_functions` may appear only in `lib/data/**` adapters, `firebase_options.dart` and `main.dart`. Domain, core and features use the repository interfaces. Data conventions (`data-model/README.md`): opaque string ids, UTC instants, enum codes as strings (`in_app`, `call`, `zalo`, `whatsapp`), no Firebase types in models.
- **Contact rules (product decisions, do not weaken):** phone, Zalo and WhatsApp open only after booking/ticket payment (`ContactAccess.unlocked`); before that the only contact is the in-app "Nhắn tin hỏi trước". The UI never shows a phone number; the app never stores the photographer's number it opens; no number goes to logs, analytics or the clipboard; photographer numbers are never in a publicly readable document.
- The URL returned by the server is **not trusted blindly**: `ContactLauncher` opens it only if it is `tel:+<digits>` for Gọi, `https://zalo.me/<digits>` for Zalo, `https://wa.me/<digits>` for WhatsApp, with no query, fragment, port or user info.
- Phone validity (plan 2a): Vietnamese `^(?:\+84|0)(3|5|7|8|9)\d{8}$`, stored as `+84…`. WhatsApp's own number accepts `^\+\d{8,15}$`. Zalo's own number must be Vietnamese.
- Icons for Zalo/WhatsApp are the existing `assets/social/zalo.svg`, `whatsapp.svg` (already declared by `assets/social/` in `pubspec.yaml`, shown with `flutter_svg`, monochrome in `onSurface`); never green/blue fills. Every icon has a text label and `Semantics`.
- Tap targets are at least 44dp with 8dp between targets; all moving parts honour `MediaQuery.disableAnimationsOf`. Layouts must not overflow at 320dp width and 1.3x text.
- UI strings only in `lib/l10n/app_vi.arb` (Vietnamese, full diacritics), then `flutter gen-l10n`. The spec's string ids (`s32_label`, `s34_title`, ...) become camelCase arb keys (`contactLabel`, `setupContactTitle`, ...), the convention used by the existing arb. Colours/spacing from `AppColors`/`AppSpace`/`AppRadius`; one `AppButton.primary` per screen.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/phone.dart`, `lib/core/widgets/phone_field.dart` (modify) | `international` support |
| `lib/core/contact_channel.dart` (create) | `ContactChannel`, `ContactAccess` |
| `lib/core/widgets/contact_dial.dart` (create) | `ContactDial`, `ContactDialStyle` |
| `lib/core/core.dart` (modify) | export the three new core files |
| `lib/data/photographer/photographer_contact.dart` (create) | `ContactChannels`, `ContactNumbers`, `ServiceArea` |
| `lib/data/photographer/photographer_contact_repository.dart` (create) | port, Firestore adapter, fake |
| `lib/data/photographer/photographer_contact_providers.dart` (create) | providers |
| `lib/data/contact/contact_link_repository.dart` (create) | `ContactSubject`, errors, `contactUriFor`, `isAllowedContactUri`, port, fake |
| `lib/data/contact/functions_contact_link_repository.dart` (create) | thin `cloud_functions` adapter |
| `lib/data/contact/external_launcher.dart` (create) | `ExternalLauncher` port, `url_launcher` adapter, fake |
| `lib/data/contact/contact_launcher.dart` (create) | `ContactLauncher`, `ContactOpenResult` |
| `lib/data/contact/contact_providers.dart` (create) | providers |
| `lib/data/booking/contact_access.dart` (create) | `contactAccessForBooking` |
| `lib/features/contact/contact_action.dart` (create) | `ContactAction`, `PhotographerContactAction` (S32 behaviour) |
| `lib/features/photographer_setup/contact_setup_logic.dart` (create) | pure S34 validation |
| `lib/features/photographer_setup/contact_setup_controller.dart` (create) | save controller + prefill |
| `lib/features/photographer_setup/contact_setup_screen.dart` (create) | S34 |
| `lib/app/router.dart` (modify) | route `/setup/4` |
| `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs` (modify) | rules + tests |
| `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` (modify) | package visibility for `tel` / `https` |
| `pubspec.yaml`, `pubspec.lock` (modify) | `url_launcher`, `cloud_functions` |
| `lib/l10n/app_vi.arb` (modify) | strings |
| `docs/superpowers/specs/screens/photographer.md`, `.../components/shared-components.md` (modify) | align with what was built |
| tests | listed per task |

---

### Task 1: `PhoneField` with `international: true`

**Files:**
- Modify: `lib/core/phone.dart`, `lib/core/widgets/phone_field.dart`, `lib/l10n/app_vi.arb`, `test/core/phone_test.dart`, `test/core/widgets/phone_field_test.dart`

**Interfaces:**
- Consumes: plan 2a's `normalizePhone`, `nationalDigits`, `formatNational`, `phoneFromField`, `validatePhone`, `PhoneField`.
- Produces:
  - `String? phoneFromField(String fieldText, {bool international = false})`: national fields get `+84` prepended, international fields are normalised as typed (Vietnamese `0903…` still reads as `+84903…`).
  - `String? validatePhone(String? fieldText, AppLocalizations l, {bool international = false})`.
  - `String internationalInput(String input)`: keeps a leading `+` and digits only, at most 15 digits.
  - `const PhoneField({..., bool international = false, String? label})`. International: no fixed prefix, hint `+1 415 555 2671`, digits-only formatter, error `phoneInvalidInternational`. `label` overrides "Số điện thoại".
  - l10n: `phoneInvalidInternational` = "Nhập số có mã quốc gia, ví dụ: +1 415 555 2671".

- [ ] **Step 1: Write the failing tests**

Append inside `main()` of `test/core/phone_test.dart` (the `AppLocalizationsVi` import already exists):

```dart
  group('international field', () {
    final l = AppLocalizationsVi();
    test('phoneFromField international keeps other countries and still reads Vietnamese', () {
      expect(phoneFromField('+1 415 555 2671', international: true), '+14155552671');
      expect(phoneFromField('0903 123 456', international: true), '+84903123456');
      expect(phoneFromField('+84012345678', international: true), isNull);
      expect(phoneFromField('415 555 2671', international: true), isNull); // no +
      expect(phoneFromField('', international: true), isNull);
    });

    test('internationalInput keeps one leading + and at most 15 digits', () {
      expect(internationalInput('+1 (415) 555-2671'), '+14155552671');
      expect(internationalInput('0903 123 456'), '0903123456');
      expect(internationalInput('12345678901234567'), '123456789012345');
      expect(internationalInput('1+2'), '12');
      expect(internationalInput('abc'), '');
    });

    test('validatePhone has its own message for international fields', () {
      expect(validatePhone('', l, international: true), l.phoneRequired);
      expect(validatePhone('12345', l, international: true), l.phoneInvalidInternational);
      expect(validatePhone('+14155552671', l, international: true), isNull);
      expect(validatePhone('+14155552671', l), l.phoneInvalid); // national field still refuses it
    });
  });
```

Append inside `main()` of `test/core/widgets/phone_field_test.dart`:

```dart
  group('international', () {
    Future<TextEditingController> pumpIntl(
      WidgetTester tester, {
      GlobalKey<FormState>? form,
      String? label,
      double width = 390,
      double textScale = 1.0,
    }) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        hostWidget(
          Form(
            key: form,
            child: PhoneField(controller: c, international: true, label: label),
          ),
          width: width,
          textScale: textScale,
        ),
      );
      return c;
    }

    testWidgets('keeps the + and digits, drops the rest, no fixed +84 prefix', (tester) async {
      final c = await pumpIntl(tester);
      await tester.enterText(find.byType(TextFormField), '+1 (415) 555-2671');
      expect(c.text, '+14155552671');
      expect(find.text('+84 '), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.phone);
    });

    testWidgets('error message asks for a country code', (tester) async {
      final form = GlobalKey<FormState>();
      await pumpIntl(tester, form: form);
      await tester.enterText(find.byType(TextFormField), '4155552671');
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(
        find.text('Nhập số có mã quốc gia, ví dụ: +1 415 555 2671'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField), '+14155552671');
      expect(form.currentState!.validate(), isTrue);
    });

    testWidgets('a custom label replaces "Số điện thoại"', (tester) async {
      await pumpIntl(tester, label: 'Số WhatsApp');
      expect(find.text('Số WhatsApp'), findsOneWidget);
      expect(find.text('Số điện thoại'), findsNothing);
    });

    testWidgets('fits 320dp at 1.3x', (tester) async {
      await pumpIntl(tester, width: 320, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  });
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/phone_test.dart test/core/widgets/phone_field_test.dart`
Expected: FAIL to compile: "The named parameter 'international' isn't defined" for `phoneFromField`, `validatePhone` and `PhoneField`; `internationalInput` undefined.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb` (next to the other phone strings), then run `flutter gen-l10n`:

```json
  "phoneInvalidInternational": "Nhập số có mã quốc gia, ví dụ: +1 415 555 2671",
```

In `lib/core/phone.dart` replace the two definitions below (from plan 2a)

```dart
/// E.164 from the text of a `PhoneField`, or null while it is not valid.
String? phoneFromField(String fieldText) =>
    normalizePhone('+84${nationalDigits(fieldText)}');
```

and

```dart
String? validatePhone(String? fieldText, AppLocalizations l) {
  final t = (fieldText ?? '').trim();
  if (t.isEmpty) return l.phoneRequired;
  return phoneFromField(t) == null ? l.phoneInvalid : null;
}
```

with:

```dart
/// E.164 from the text of a `PhoneField`, or null while it is not valid.
/// A national field (default) holds only the digits after the fixed "+84";
/// an [international] field holds the whole number as typed.
String? phoneFromField(String fieldText, {bool international = false}) =>
    international
    ? normalizePhone(fieldText, international: true)
    : normalizePhone('+84${nationalDigits(fieldText)}');

/// What an international field keeps: one leading "+" if present, then digits
/// only, at most 15 (the E.164 maximum).
String internationalInput(String input) {
  final s = input.trim();
  var digits = s.replaceAll(RegExp(r'\D'), '');
  if (digits.length > 15) digits = digits.substring(0, 15);
  return s.startsWith('+') ? '+$digits' : digits;
}

String? validatePhone(
  String? fieldText,
  AppLocalizations l, {
  bool international = false,
}) {
  final t = (fieldText ?? '').trim();
  if (t.isEmpty) return l.phoneRequired;
  if (phoneFromField(t, international: international) != null) return null;
  return international ? l.phoneInvalidInternational : l.phoneInvalid;
}
```

Replace the whole of `lib/core/widgets/phone_field.dart` with:

```dart
// lib/core/widgets/phone_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/phone.dart';

/// Phone number input. By default a Vietnamese number with a fixed "+84"
/// prefix: the text is the national form `903 123 456`, and typing or pasting
/// `0903…` or `+84…` is normalised. With [international] (WhatsApp) the field
/// holds the whole number, `+` and digits, e.g. `+14155552671`.
/// Read the number with [phoneFromField] (pass the same [international]).
///
/// Note: only a paste (or a whole-text edit) can carry a "+84" into a national
/// field; typing "+" digit by digit is read as national digits.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.validator,
    this.autofocus = false,
    this.international = false,
    this.label,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// Defaults to [validatePhone] (required and well-formed).
  final FormFieldValidator<String>? validator;
  final bool autofocus;

  /// Accept any country's number (`+` and 8–15 digits), for WhatsApp.
  final bool international;

  /// Replaces the default "Số điện thoại".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: [
        international
            ? AutofillHints.telephoneNumber
            : AutofillHints.telephoneNumberNational,
      ],
      inputFormatters: [
        international ? _InternationalPhoneFormatter() : _NationalPhoneFormatter(),
      ],
      onChanged: onChanged,
      validator:
          validator ?? (v) => validatePhone(v, l, international: international),
      decoration: InputDecoration(
        labelText: label ?? l.phoneLabel,
        hintText: international ? '+1 415 555 2671' : '903 123 456',
        prefixText: international ? null : '+84 ',
        prefixIcon: const Icon(Icons.phone_outlined),
        errorText: errorText,
      ),
    );
  }
}

class _NationalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    final text = formatNational(nationalDigits(next.text));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _InternationalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    final text = internationalInput(next.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/phone_test.dart test/core/widgets/phone_field_test.dart && flutter analyze`
Expected: PASS (all earlier 2a tests plus the new ones); analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/l10n test/core
git commit -m "feat(core): PhoneField international mode for WhatsApp numbers

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Contact vocabulary and photographer contact data

**Files:**
- Create: `lib/core/contact_channel.dart`, `lib/data/photographer/photographer_contact.dart`, `lib/data/photographer/photographer_contact_repository.dart`, `lib/data/photographer/photographer_contact_providers.dart`, `test/core/contact_channel_test.dart`, `test/data/photographer/photographer_contact_repository_test.dart`
- Modify: `lib/core/core.dart`

**Interfaces:**
- Consumes: `authRepositoryProvider` from `lib/data/auth/auth_providers.dart`.
- Produces:
  - `enum ContactChannel { inApp, call, zalo, whatsapp }` with `String code` (`in_app`, `call`, `zalo`, `whatsapp`), `bool get isExternal`, `static ContactChannel? fromCode(String?)`. `enum ContactAccess { locked, unlocked }`.
  - `class ContactChannels { const ContactChannels({bool call = false, bool zalo = false, bool whatsapp = false, bool acceptInquiries = true}); Map<String, dynamic> toMap(); static ContactChannels? fromMap(Object?); List<ContactChannel> get external; bool get hasExternal; copyWith; ==; }` (public flags, no numbers).
  - `class ContactNumbers { const ContactNumbers({required String phone, String? zaloPhone, String? whatsappPhone}); Map<String, dynamic> toMap() (omits nulls); static ContactNumbers? fromMap(Map<String, dynamic>?); String? numberFor(ContactChannel) }`: `call → phone`, `zalo → zaloPhone ?? phone`, `whatsapp → whatsappPhone ?? phone`, `inApp → null`.
  - `class ServiceArea { const ServiceArea({required String city, required int radiusKm}); toMap(); static ServiceArea? fromMap(Object?); ==; }`.
  - `abstract class PhotographerContactRepository { Stream<ContactChannels?> watchChannels(String photographerId); Stream<ContactNumbers?> watchNumbers(String photographerId); Stream<ServiceArea?> watchServiceArea(String photographerId); Future<void> completeContactSetup(String uid, {required ServiceArea area, required ContactChannels channels, required ContactNumbers numbers}); }`. `watchNumbers` only works for the owner (rules).
  - `FirestorePhotographerContactRepository({FirebaseFirestore? db})`, `FakePhotographerContactRepository({bool failSave = false})` with `seed(uid, {channels, numbers, area})`, `channelsOf/numbersOf/areaOf(uid)`, `completed` (`Set<String>` of uids with `onboardingComplete`).
  - `photographerContactRepositoryProvider`, `photographerChannelsProvider` (`StreamProvider.autoDispose.family<ContactChannels?, String>`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/contact_channel_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

void main() {
  test('codes match the data model', () {
    expect(
      {for (final c in ContactChannel.values) c.code},
      {'in_app', 'call', 'zalo', 'whatsapp'},
    );
    expect(ContactChannel.fromCode('zalo'), ContactChannel.zalo);
    expect(ContactChannel.fromCode('sms'), isNull);
    expect(ContactChannel.fromCode(null), isNull);
  });

  test('only the in-app channel is not external', () {
    expect(ContactChannel.inApp.isExternal, isFalse);
    for (final c in [ContactChannel.call, ContactChannel.zalo, ContactChannel.whatsapp]) {
      expect(c.isExternal, isTrue);
    }
  });
}
```

```dart
// test/data/photographer/photographer_contact_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';

void main() {
  group('ContactChannels', () {
    test('public flags only, with the documented defaults', () {
      const c = ContactChannels(zalo: true);
      expect(c.toMap(), {
        'call': false,
        'zalo': true,
        'whatsapp': false,
        'acceptInquiries': true,
      });
      expect(c.toMap().keys, isNot(contains('phone')));
    });

    test('fromMap reads flags, tolerates junk and missing maps', () {
      expect(
        ContactChannels.fromMap({'call': true, 'whatsapp': true, 'acceptInquiries': false}),
        const ContactChannels(call: true, whatsapp: true, acceptInquiries: false),
      );
      expect(ContactChannels.fromMap(null), isNull);
      expect(ContactChannels.fromMap('x'), isNull);
      expect(ContactChannels.fromMap(<String, dynamic>{}), const ContactChannels());
    });

    test('external lists switched-on channels in dial order', () {
      expect(
        const ContactChannels(call: true, zalo: true, whatsapp: true).external,
        [ContactChannel.call, ContactChannel.zalo, ContactChannel.whatsapp],
      );
      expect(const ContactChannels(whatsapp: true, call: true).external, [
        ContactChannel.call,
        ContactChannel.whatsapp,
      ]);
      expect(const ContactChannels().hasExternal, isFalse);
    });
  });

  group('ContactNumbers', () {
    test('numberFor falls back to the main number', () {
      const n = ContactNumbers(phone: '+84903123456');
      expect(n.numberFor(ContactChannel.call), '+84903123456');
      expect(n.numberFor(ContactChannel.zalo), '+84903123456');
      expect(n.numberFor(ContactChannel.whatsapp), '+84903123456');
      expect(n.numberFor(ContactChannel.inApp), isNull);
    });

    test('own numbers win for Zalo and WhatsApp', () {
      const n = ContactNumbers(
        phone: '+84903123456',
        zaloPhone: '+84912345678',
        whatsappPhone: '+14155552671',
      );
      expect(n.numberFor(ContactChannel.call), '+84903123456');
      expect(n.numberFor(ContactChannel.zalo), '+84912345678');
      expect(n.numberFor(ContactChannel.whatsapp), '+14155552671');
    });

    test('toMap omits unset numbers and never carries flags', () {
      expect(const ContactNumbers(phone: '+84903123456').toMap(), {
        'phone': '+84903123456',
      });
      expect(
        const ContactNumbers(phone: '+84903123456', whatsappPhone: '+14155552671').toMap(),
        {'phone': '+84903123456', 'whatsappPhone': '+14155552671'},
      );
    });

    test('fromMap needs a phone', () {
      expect(ContactNumbers.fromMap(null), isNull);
      expect(ContactNumbers.fromMap({'zaloPhone': '+84912345678'}), isNull);
      expect(
        ContactNumbers.fromMap({'phone': '+84903123456', 'zaloPhone': '+84912345678'}),
        const ContactNumbers(phone: '+84903123456', zaloPhone: '+84912345678'),
      );
    });
  });

  test('ServiceArea round-trips and refuses junk', () {
    const a = ServiceArea(city: 'Hà Nội', radiusKm: 20);
    expect(a.toMap(), {'city': 'Hà Nội', 'radiusKm': 20});
    expect(ServiceArea.fromMap(a.toMap()), a);
    expect(ServiceArea.fromMap({'city': 'Hà Nội'}), isNull);
    expect(ServiceArea.fromMap(null), isNull);
  });

  group('FakePhotographerContactRepository', () {
    const area = ServiceArea(city: 'Hà Nội', radiusKm: 30);
    const channels = ContactChannels(call: true, zalo: true);
    const numbers = ContactNumbers(phone: '+84903123456');

    test('completeContactSetup stores all three parts and marks onboarding done', () async {
      final repo = FakePhotographerContactRepository();
      await repo.completeContactSetup('p1', area: area, channels: channels, numbers: numbers);
      expect(repo.areaOf('p1'), area);
      expect(repo.channelsOf('p1'), channels);
      expect(repo.numbersOf('p1'), numbers);
      expect(repo.completed, {'p1'});
      expect(repo.channelsOf('p2'), isNull);
    });

    test('watchers emit the current value, then every change for that user only', () async {
      final repo = FakePhotographerContactRepository();
      expect(await repo.watchChannels('p1').first, isNull);
      final seen = repo.watchChannels('p1').skip(1).take(1).toList();
      await repo.completeContactSetup('p2', area: area, channels: const ContactChannels(), numbers: numbers);
      await repo.completeContactSetup('p1', area: area, channels: channels, numbers: numbers);
      expect(await seen, [channels]);
      expect(await repo.watchNumbers('p1').first, numbers);
      expect(await repo.watchServiceArea('p1').first, area);
    });

    test('a failing save throws and stores nothing', () async {
      final repo = FakePhotographerContactRepository(failSave: true);
      await expectLater(
        repo.completeContactSetup('p1', area: area, channels: channels, numbers: numbers),
        throwsStateError,
      );
      expect(repo.numbersOf('p1'), isNull);
      expect(repo.completed, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/contact_channel_test.dart test/data/photographer`
Expected: FAIL, `ContactChannel` and the `photographer_contact*.dart` files do not exist.

- [ ] **Step 3: Implement**

```dart
// lib/core/contact_channel.dart
/// A way to reach someone. `inApp` is the in-app chat; the other three leave
/// the app (phone dialer, Zalo, WhatsApp) and only open after booking.
enum ContactChannel {
  inApp('in_app'),
  call('call'),
  zalo('zalo'),
  whatsapp('whatsapp');

  const ContactChannel(this.code);

  /// Stable code used in the data model, callable payloads and analytics.
  final String code;

  bool get isExternal => this != inApp;

  static ContactChannel? fromCode(String? code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return null;
  }
}

/// Whether the outside channels may be used yet: `locked` before the customer
/// has booked (only the in-app inquiry chat), `unlocked` after.
enum ContactAccess { locked, unlocked }
```

In `lib/core/core.dart` add, keeping alphabetical order, after the `l10n_ext.dart` export:

```dart
export 'package:photobooking/core/contact_channel.dart';
```

```dart
// lib/data/photographer/photographer_contact.dart
import 'package:photobooking/core/core.dart';

/// Which outside channels a photographer accepts. Public flags only: the
/// numbers live in [ContactNumbers], which only the owner can read.
class ContactChannels {
  const ContactChannels({
    this.call = false,
    this.zalo = false,
    this.whatsapp = false,
    this.acceptInquiries = true,
  });

  final bool call;
  final bool zalo;
  final bool whatsapp;

  /// Whether customers may start an in-app "Nhắn tin hỏi trước" chat.
  final bool acceptInquiries;

  Map<String, dynamic> toMap() => {
    'call': call,
    'zalo': zalo,
    'whatsapp': whatsapp,
    'acceptInquiries': acceptInquiries,
  };

  static ContactChannels? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return ContactChannels(
      call: raw['call'] == true,
      zalo: raw['zalo'] == true,
      whatsapp: raw['whatsapp'] == true,
      acceptInquiries: raw['acceptInquiries'] != false,
    );
  }

  /// Switched-on outside channels in the order the dial shows them.
  List<ContactChannel> get external => [
    if (call) ContactChannel.call,
    if (zalo) ContactChannel.zalo,
    if (whatsapp) ContactChannel.whatsapp,
  ];

  bool get hasExternal => call || zalo || whatsapp;

  ContactChannels copyWith({
    bool? call,
    bool? zalo,
    bool? whatsapp,
    bool? acceptInquiries,
  }) => ContactChannels(
    call: call ?? this.call,
    zalo: zalo ?? this.zalo,
    whatsapp: whatsapp ?? this.whatsapp,
    acceptInquiries: acceptInquiries ?? this.acceptInquiries,
  );

  @override
  bool operator ==(Object other) =>
      other is ContactChannels &&
      other.call == call &&
      other.zalo == zalo &&
      other.whatsapp == whatsapp &&
      other.acceptInquiries == acceptInquiries;

  @override
  int get hashCode => Object.hash(call, zalo, whatsapp, acceptInquiries);
}

/// A photographer's private numbers (E.164). Stored in
/// `photographers/{uid}/private/contact`, readable only by the owner; a
/// customer never receives them, only a server-built link.
class ContactNumbers {
  const ContactNumbers({
    required this.phone,
    this.zaloPhone,
    this.whatsappPhone,
  });

  final String phone;

  /// Own Zalo number (Vietnamese); null means "use [phone]".
  final String? zaloPhone;

  /// Own WhatsApp number in international form; null means "use [phone]".
  final String? whatsappPhone;

  Map<String, dynamic> toMap() => {
    'phone': phone,
    if (zaloPhone != null) 'zaloPhone': zaloPhone,
    if (whatsappPhone != null) 'whatsappPhone': whatsappPhone,
  };

  static ContactNumbers? fromMap(Map<String, dynamic>? m) {
    final phone = m?['phone'];
    if (phone is! String) return null;
    return ContactNumbers(
      phone: phone,
      zaloPhone: m!['zaloPhone'] as String?,
      whatsappPhone: m['whatsappPhone'] as String?,
    );
  }

  /// The number a channel dials, or null for the in-app chat.
  String? numberFor(ContactChannel channel) => switch (channel) {
    ContactChannel.call => phone,
    ContactChannel.zalo => zaloPhone ?? phone,
    ContactChannel.whatsapp => whatsappPhone ?? phone,
    ContactChannel.inApp => null,
  };

  @override
  bool operator ==(Object other) =>
      other is ContactNumbers &&
      other.phone == phone &&
      other.zaloPhone == zaloPhone &&
      other.whatsappPhone == whatsappPhone;

  @override
  int get hashCode => Object.hash(phone, zaloPhone, whatsappPhone);
}

/// Where a photographer takes jobs: a city and a radius in km.
class ServiceArea {
  const ServiceArea({required this.city, required this.radiusKm});

  final String city;
  final int radiusKm;

  Map<String, dynamic> toMap() => {'city': city, 'radiusKm': radiusKm};

  static ServiceArea? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final city = raw['city'];
    final radius = raw['radiusKm'];
    if (city is! String || radius is! num) return null;
    return ServiceArea(city: city, radiusKm: radius.toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is ServiceArea && other.city == city && other.radiusKm == radiusKm;

  @override
  int get hashCode => Object.hash(city, radiusKm);
}
```

```dart
// lib/data/photographer/photographer_contact_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/photographer/photographer_contact.dart';

abstract class PhotographerContactRepository {
  /// Public flags of any photographer (null until set up).
  Stream<ContactChannels?> watchChannels(String photographerId);

  /// The owner's private numbers; other users are refused by the rules.
  Stream<ContactNumbers?> watchNumbers(String photographerId);

  Stream<ServiceArea?> watchServiceArea(String photographerId);

  /// S34 "Hoàn tất": writes the service area and public flags to
  /// `photographers/{uid}`, the numbers to `photographers/{uid}/private/contact`
  /// (one batch, so a channel is never public without a number) and sets
  /// `onboardingComplete`.
  Future<void> completeContactSetup(
    String uid, {
    required ServiceArea area,
    required ContactChannels channels,
    required ContactNumbers numbers,
  });
}

class FirestorePhotographerContactRepository
    implements PhotographerContactRepository {
  FirestorePhotographerContactRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('photographers').doc(uid);

  DocumentReference<Map<String, dynamic>> _private(String uid) =>
      _doc(uid).collection('private').doc('contact');

  @override
  Stream<ContactChannels?> watchChannels(String photographerId) => _doc(
    photographerId,
  ).snapshots().map((s) => ContactChannels.fromMap(s.data()?['contactChannels']));

  @override
  Stream<ContactNumbers?> watchNumbers(String photographerId) =>
      _private(photographerId).snapshots().map((s) => ContactNumbers.fromMap(s.data()));

  @override
  Stream<ServiceArea?> watchServiceArea(String photographerId) => _doc(
    photographerId,
  ).snapshots().map((s) => ServiceArea.fromMap(s.data()?['serviceArea']));

  @override
  Future<void> completeContactSetup(
    String uid, {
    required ServiceArea area,
    required ContactChannels channels,
    required ContactNumbers numbers,
  }) {
    final batch = _db.batch();
    // Replaces the whole private doc so a cleared own number really goes away.
    batch.set(_private(uid), {
      ...numbers.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_doc(uid), {
      'serviceArea': area.toMap(),
      'contactChannels': channels.toMap(),
      'onboardingComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return batch.commit();
  }
}

class FakePhotographerContactRepository
    implements PhotographerContactRepository {
  FakePhotographerContactRepository({this.failSave = false});
  final bool failSave;

  final _channels = <String, ContactChannels>{};
  final _numbers = <String, ContactNumbers>{};
  final _areas = <String, ServiceArea>{};

  /// Uids whose onboarding was completed through [completeContactSetup].
  final completed = <String>{};
  final _changes = StreamController<String>.broadcast();

  ContactChannels? channelsOf(String uid) => _channels[uid];
  ContactNumbers? numbersOf(String uid) => _numbers[uid];
  ServiceArea? areaOf(String uid) => _areas[uid];

  /// Test setup without going through [completeContactSetup].
  void seed(
    String uid, {
    ContactChannels? channels,
    ContactNumbers? numbers,
    ServiceArea? area,
  }) {
    if (channels != null) _channels[uid] = channels;
    if (numbers != null) _numbers[uid] = numbers;
    if (area != null) _areas[uid] = area;
  }

  Stream<T> _watch<T>(String uid, T Function() read) async* {
    yield read();
    yield* _changes.stream.where((u) => u == uid).map((_) => read());
  }

  @override
  Stream<ContactChannels?> watchChannels(String photographerId) =>
      _watch(photographerId, () => _channels[photographerId]);

  @override
  Stream<ContactNumbers?> watchNumbers(String photographerId) =>
      _watch(photographerId, () => _numbers[photographerId]);

  @override
  Stream<ServiceArea?> watchServiceArea(String photographerId) =>
      _watch(photographerId, () => _areas[photographerId]);

  @override
  Future<void> completeContactSetup(
    String uid, {
    required ServiceArea area,
    required ContactChannels channels,
    required ContactNumbers numbers,
  }) async {
    if (failSave) throw StateError('unavailable');
    _areas[uid] = area;
    _channels[uid] = channels;
    _numbers[uid] = numbers;
    completed.add(uid);
    _changes.add(uid);
  }
}
```

```dart
// lib/data/photographer/photographer_contact_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';

final photographerContactRepositoryProvider =
    Provider<PhotographerContactRepository>(
      (ref) => FirestorePhotographerContactRepository(),
    );

/// Public contact flags of one photographer (what S32 shows).
final photographerChannelsProvider = StreamProvider.autoDispose
    .family<ContactChannels?, String>(
      (ref, photographerId) => ref
          .watch(photographerContactRepositoryProvider)
          .watchChannels(photographerId),
    );
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/contact_channel_test.dart test/data/photographer && flutter analyze`
Expected: PASS (2 + 11 tests); analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/data/photographer test/core/contact_channel_test.dart test/data/photographer
git commit -m "feat(data): contact channels, private numbers and service area with fake and Firestore adapter

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Firestore rules for photographer contact data

**Files:**
- Modify: `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs`

**Interfaces:**
- Consumes: the existing `isOwner`, `hasPhotographerRole`, `onlyKeys`, `photographerClientFields` in `firebase/firestore.rules`; the test helper `asPhotographer(uid)` and imports (`doc, setDoc, getDoc, updateDoc, writeBatch`) already in `rules.test.mjs`.
- Produces: `photographers/{uid}` accepts `contactChannels` (only `call/zalo/whatsapp/acceptInquiries` booleans; a channel can be on only if the private contact doc exists after the same write) and `serviceArea` (`city` 2–80 chars, `radiusKm` int 1–200, optional `center` latlng); `photographers/{uid}/private/contact` is owner-only (read and write), only `phone` (Vietnamese E.164), optional `zaloPhone` (Vietnamese), optional `whatsappPhone` (`+` and 8–15 digits), `updatedAt`; no other `private/*` doc; no `phone`/`contact` key on the public doc.

- [ ] **Step 1: Write the failing tests** (append to `firebase/rules-test/rules.test.mjs`)

```js
const privateContact = (uid) => `photographers/${uid}/private/contact`;
const goodNumbers = { phone: '+84903123456', zaloPhone: '+84912345678', whatsappPhone: '+14155552671' };
const allChannels = { call: true, zalo: true, whatsapp: true, acceptInquiries: true };

test('photographer saves numbers, public flags and service area in one batch', async () => {
  await asPhotographer('ph1');
  const db = env.authenticatedContext('ph1').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, privateContact('ph1')), goodNumbers);
  batch.set(doc(db, 'photographers/ph1'), {
    serviceArea: { city: 'Hà Nội', radiusKm: 20 },
    contactChannels: allChannels,
    onboardingComplete: true,
  }, { merge: true });
  await assertSucceeds(batch.commit());
  // Later edits: drop an own number by replacing the doc, flip one flag.
  await assertSucceeds(setDoc(doc(db, privateContact('ph1')), { phone: '+84903123456' }));
  await assertSucceeds(updateDoc(doc(db, 'photographers/ph1'), { 'contactChannels': { ...allChannels, zalo: false } }));
});

test('numbers are readable by their owner only, flags by every signed-in user', async () => {
  await asPhotographer('ph2'); await asPhotographer('ph3');
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), privateContact('ph2')), goodNumbers);
    await setDoc(doc(c.firestore(), 'photographers/ph2'), { contactChannels: allChannels, onboardingComplete: true });
  });
  await assertSucceeds(getDoc(doc(env.authenticatedContext('ph2').firestore(), privateContact('ph2'))));
  await assertFails(getDoc(doc(env.authenticatedContext('ph3').firestore(), privateContact('ph2')))); // another photographer
  await assertFails(getDoc(doc(env.authenticatedContext('some-customer').firestore(), privateContact('ph2'))));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), privateContact('ph2'))));
  const publicDoc = await assertSucceeds(getDoc(doc(env.authenticatedContext('some-customer').firestore(), 'photographers/ph2')));
  assert.equal(publicDoc.data().contactChannels.call, true);
  assert.ok(!JSON.stringify(publicDoc.data()).includes('+84'), 'the public photographer doc must hold no number');
  // Nobody else may write them either.
  await assertFails(setDoc(doc(env.authenticatedContext('ph3').firestore(), privateContact('ph2')), { phone: '+84903123456' }));
});

test('numbers never go onto the public photographer doc', async () => {
  await asPhotographer('ph4');
  const db = env.authenticatedContext('ph4').firestore();
  await assertFails(setDoc(doc(db, 'photographers/ph4'), { contact: { phone: '+84903123456' } }));
  await assertFails(setDoc(doc(db, 'photographers/ph4'), { phone: '+84903123456' }));
  await assertFails(setDoc(doc(db, 'photographers/ph4'), { contactChannels: { call: false, phone: '+84903123456' } }));
});

test('private contact validates every number and rejects extras', async () => {
  await asPhotographer('ph5');
  const db = env.authenticatedContext('ph5').firestore();
  const bad = [
    { phone: '0903123456' }, { phone: '+84123456789' }, { phone: '+8490312345' }, { phone: 5 }, {},
    { phone: '+84903123456', zaloPhone: '+14155552671' },      // Zalo must be Vietnamese
    { phone: '+84903123456', whatsappPhone: '0903123456' },    // WhatsApp needs a +country code
    { phone: '+84903123456', whatsappPhone: '+123' },
    { phone: '+84903123456', note: 'x' },
  ];
  for (const data of bad) await assertFails(setDoc(doc(db, privateContact('ph5')), data));
  await assertFails(setDoc(doc(db, 'photographers/ph5/private/other'), { phone: '+84903123456' }));
  await assertSucceeds(setDoc(doc(db, privateContact('ph5')), { phone: '+84903123456', whatsappPhone: '+14155552671' }));
});

test('only a photographer-role account may write private contact', async () => {
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'users/cust-1'), { displayName: 'C', role: 'customer' }));
  await assertFails(setDoc(doc(env.authenticatedContext('cust-1').firestore(), privateContact('cust-1')), { phone: '+84903123456' }));
});

test('a channel cannot be public without a stored number, and flags are validated', async () => {
  await asPhotographer('ph6');
  const db = env.authenticatedContext('ph6').firestore();
  // No private doc yet: turning a channel on fails, all-off passes.
  await assertFails(setDoc(doc(db, 'photographers/ph6'), { contactChannels: { call: true } }, { merge: true }));
  await assertSucceeds(setDoc(doc(db, 'photographers/ph6'), { contactChannels: { call: false, zalo: false, whatsapp: false, acceptInquiries: true } }, { merge: true }));
  // Wrong shapes.
  await assertFails(setDoc(doc(db, 'photographers/ph6'), { contactChannels: { call: 'yes' } }, { merge: true }));
  await assertFails(setDoc(doc(db, 'photographers/ph6'), { contactChannels: { sms: true } }, { merge: true }));
  await assertFails(setDoc(doc(db, 'photographers/ph6'), { contactChannels: true }, { merge: true }));
  // Once the number exists in the same batch it works.
  const batch = writeBatch(db);
  batch.set(doc(db, privateContact('ph6')), { phone: '+84903123456' });
  batch.set(doc(db, 'photographers/ph6'), { contactChannels: { call: true } }, { merge: true });
  await assertSucceeds(batch.commit());
});

test('service area has a city and an integer radius', async () => {
  await asPhotographer('ph7');
  const db = env.authenticatedContext('ph7').firestore();
  await assertSucceeds(setDoc(doc(db, 'photographers/ph7'), { serviceArea: { city: 'Đà Nẵng', radiusKm: 50 } }));
  for (const serviceArea of [
    { city: 'Đ', radiusKm: 50 }, { city: 'Đà Nẵng', radiusKm: 0 }, { city: 'Đà Nẵng', radiusKm: 201 },
    { city: 'Đà Nẵng', radiusKm: 12.5 }, { city: 'Đà Nẵng' }, { city: 'Đà Nẵng', radiusKm: 5, extra: 1 }, 'Đà Nẵng',
  ]) {
    await assertFails(setDoc(doc(db, 'photographers/ph7'), { serviceArea }));
  }
});
```


- [ ] **Step 2: Run and see it fail**

Run (from `firebase/rules-test`; needs Node, Java and the Firestore emulator, as in CI): `npm ci && npm test`
Expected: the new tests FAIL (`contactChannels` is not an allowed key yet and no rule matches `photographers/*/private/*`; the very first test fails). If the emulator cannot run in this sandbox, say so in the report and rely on the CI job "Firestore rules tests (emulator)".

- [ ] **Step 3: Implement**

In `firebase/firestore.rules`, replace `photographerClientFields()` with (adds `contactChannels`):

```
    function photographerClientFields() {
      return ['bio', 'specialties', 'styles', 'equipment', 'yearsExperience', 'serviceArea',
              'contactChannels', 'portfolio', 'onboardingComplete', 'verified', 'createdAt', 'updatedAt'];
    }

    // serviceArea: a city and a whole-number radius in km (centre point added with the location work).
    function validServiceArea() {
      let d = request.resource.data;
      return !('serviceArea' in d)
        || (d.serviceArea is map
            && d.serviceArea.keys().hasOnly(['city', 'radiusKm', 'center'])
            && d.serviceArea.city is string
            && d.serviceArea.city.size() >= 2 && d.serviceArea.city.size() <= 80
            && d.serviceArea.radiusKm is int
            && d.serviceArea.radiusKm >= 1 && d.serviceArea.radiusKm <= 200
            && (!('center' in d.serviceArea) || d.serviceArea.center is latlng));
    }

    // contactChannels: public on/off flags only, never a number. A channel can be on only if the
    // private contact doc exists once this write (or batch) is applied.
    function validContactChannels(uid) {
      let d = request.resource.data;
      return !('contactChannels' in d)
        || (d.contactChannels is map
            && d.contactChannels.keys().hasOnly(['call', 'zalo', 'whatsapp', 'acceptInquiries'])
            && d.contactChannels.get('call', false) is bool
            && d.contactChannels.get('zalo', false) is bool
            && d.contactChannels.get('whatsapp', false) is bool
            && d.contactChannels.get('acceptInquiries', true) is bool
            && (!(d.contactChannels.get('call', false)
                  || d.contactChannels.get('zalo', false)
                  || d.contactChannels.get('whatsapp', false))
                || existsAfter(/databases/$(database)/documents/photographers/$(uid)/private/contact)));
    }

    // photographers/{uid}/private/contact: the photographer's real numbers. Owner-only; a customer
    // only ever gets a server-built link (callable getContactLink). Vietnamese E.164 for phone and
    // Zalo, "+country digits" for WhatsApp.
    function validPhotographerNumbers() {
      let d = request.resource.data;
      return d.keys().hasOnly(['phone', 'zaloPhone', 'whatsappPhone', 'updatedAt'])
        && d.phone is string
        && d.phone.matches('^\\+84[35789][0-9]{8}$')
        && (!('zaloPhone' in d)
            || (d.zaloPhone is string && d.zaloPhone.matches('^\\+84[35789][0-9]{8}$')))
        && (!('whatsappPhone' in d)
            || (d.whatsappPhone is string && d.whatsappPhone.matches('^\\+[0-9]{8,15}$')));
    }
```

and replace the `match /photographers/{uid}` block with:

```
    match /photographers/{uid} {
      allow read: if signedIn();
      allow create, update: if isOwner(uid)
        && hasPhotographerRole(uid)
        && verifiedUntouched()
        && onlyKeys(photographerClientFields())
        && validServiceArea()
        && validContactChannels(uid);
      allow delete: if false;

      match /services/{serviceId} {
        allow read: if signedIn();
        allow write: if isOwner(uid) && hasPhotographerRole(uid);
      }

      match /private/{docId} {
        allow read: if isOwner(uid);
        allow create, update: if isOwner(uid)
          && hasPhotographerRole(uid)
          && docId == 'contact'
          && validPhotographerNumbers();
        allow delete: if false;
      }
    }
```

- [ ] **Step 4: Run and see it pass**

Run (from `firebase/rules-test`): `npm test`
Expected: all rules tests pass, old and new. If the update in the first test (`updateDoc` with a whole `contactChannels` map) is refused, print the emulator rule trace and fix the expression, not the test. If `let` bindings are rejected inside a function, inline `request.resource.data` instead.

- [ ] **Step 5: Commit**

```bash
git add firebase/firestore.rules firebase/rules-test/rules.test.mjs
git commit -m "feat(rules): owner-only photographer numbers, validated contact flags and service area

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `ContactLinkRepository` port, URL rules, fake and `cloud_functions` adapter

**Files:**
- Create: `lib/data/contact/contact_link_repository.dart`, `lib/data/contact/functions_contact_link_repository.dart`, `test/data/contact/contact_link_repository_test.dart`
- Modify: `pubspec.yaml`, `pubspec.lock`

**Interfaces:**
- Consumes: `ContactChannel` (core), `ContactChannels`, `ContactNumbers` (Task 2).
- Produces:
  - `enum ContactSubjectType { booking, registration }`; `class ContactSubject { const ContactSubject.booking(String id); const ContactSubject.registration(String id); final String id; final ContactSubjectType type; ==; }`.
  - `enum ContactLinkError { locked, unavailable }`; `class ContactLinkException implements Exception { const ContactLinkException(ContactLinkError error); final ContactLinkError error; }` (its text never contains a number).
  - `abstract class ContactLinkRepository { Future<Uri> link({required ContactSubject subject, required ContactChannel channel}); }`.
  - Pure functions: `Map<String, Object> callableData(ContactSubject, ContactChannel)` (`{bookingId|registrationId, channel}`), `Uri contactUriFor(ContactChannel, ContactNumbers)` (the exact URL formats; also the reference for the later server function), `bool isAllowedContactUri(Uri, ContactChannel)`, `Uri parseLinkResponse(Object? data)`, `ContactLinkError linkErrorFromCode(String? code)`.
  - `FakeContactLinkRepository` with `add(subject, {numbers, channels, unlocked = true})`, `setUnlocked(subject, bool)`, `requests` (`List<ContactLinkRequest>`).
  - `FunctionsContactLinkRepository({FirebaseFunctions? functions})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/contact/contact_link_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';

void main() {
  const vn = ContactNumbers(phone: '+84903123456');
  const own = ContactNumbers(
    phone: '+84903123456',
    zaloPhone: '+84912345678',
    whatsappPhone: '+14155552671',
  );

  group('contactUriFor: the exact URL formats', () {
    test('call is tel: with the plus', () {
      expect(contactUriFor(ContactChannel.call, vn).toString(), 'tel:+84903123456');
    });
    test('zalo is https://zalo.me/ with digits only', () {
      expect(contactUriFor(ContactChannel.zalo, vn).toString(), 'https://zalo.me/84903123456');
    });
    test('whatsapp is https://wa.me/ without the plus', () {
      expect(contactUriFor(ContactChannel.whatsapp, vn).toString(), 'https://wa.me/84903123456');
    });
    test('own Zalo and WhatsApp numbers are used, call keeps the main one', () {
      expect(contactUriFor(ContactChannel.call, own).toString(), 'tel:+84903123456');
      expect(contactUriFor(ContactChannel.zalo, own).toString(), 'https://zalo.me/84912345678');
      expect(contactUriFor(ContactChannel.whatsapp, own).toString(), 'https://wa.me/14155552671');
    });
    test('the in-app chat has no URL', () {
      expect(() => contactUriFor(ContactChannel.inApp, vn), throwsArgumentError);
    });
    test('every URL it builds passes the allow-list for its own channel', () {
      for (final c in [ContactChannel.call, ContactChannel.zalo, ContactChannel.whatsapp]) {
        expect(isAllowedContactUri(contactUriFor(c, own), c), isTrue, reason: c.code);
      }
    });
  });

  group('isAllowedContactUri', () {
    bool ok(String url, ContactChannel c) => isAllowedContactUri(Uri.parse(url), c);

    test('accepts only the three shapes', () {
      expect(ok('tel:+84903123456', ContactChannel.call), isTrue);
      expect(ok('https://zalo.me/84903123456', ContactChannel.zalo), isTrue);
      expect(ok('https://wa.me/14155552671', ContactChannel.whatsapp), isTrue);
    });

    test('refuses other schemes, hosts, queries and look-alikes', () {
      expect(ok('tel:0903123456', ContactChannel.call), isFalse); // not E.164
      expect(ok('sms:+84903123456', ContactChannel.call), isFalse);
      expect(ok('http://zalo.me/84903123456', ContactChannel.zalo), isFalse);
      expect(ok('https://zalo.me.evil.com/84903123456', ContactChannel.zalo), isFalse);
      expect(ok('https://evil.com/84903123456', ContactChannel.zalo), isFalse);
      expect(ok('https://zalo.me/84903123456?text=hi', ContactChannel.zalo), isFalse);
      expect(ok('https://zalo.me/84903123456#x', ContactChannel.zalo), isFalse);
      expect(ok('https://user@zalo.me/84903123456', ContactChannel.zalo), isFalse);
      expect(ok('https://zalo.me:444/84903123456', ContactChannel.zalo), isFalse);
      expect(ok('https://wa.me/84903123456', ContactChannel.zalo), isFalse); // wrong channel
      expect(ok('https://zalo.me/84903123456', ContactChannel.whatsapp), isFalse);
      expect(ok('https://wa.me/abc', ContactChannel.whatsapp), isFalse);
      expect(ok('https://wa.me/84903123456', ContactChannel.inApp), isFalse);
    });
  });

  group('callable payload and response', () {
    test('booking and registration use different keys, channel is its code', () {
      expect(callableData(const ContactSubject.booking('b1'), ContactChannel.zalo), {
        'bookingId': 'b1',
        'channel': 'zalo',
      });
      expect(
        callableData(const ContactSubject.registration('r9'), ContactChannel.whatsapp),
        {'registrationId': 'r9', 'channel': 'whatsapp'},
      );
    });

    test('parseLinkResponse reads {url} and refuses anything else', () {
      expect(parseLinkResponse({'url': 'tel:+84903123456'}), Uri.parse('tel:+84903123456'));
      for (final bad in [null, 'x', {'url': 5}, <String, dynamic>{}, {'link': 'tel:+84903123456'}]) {
        expect(
          () => parseLinkResponse(bad),
          throwsA(
            isA<ContactLinkException>().having((e) => e.error, 'error', ContactLinkError.unavailable),
          ),
          reason: '$bad',
        );
      }
    });

    test('only contact_locked is "locked"; every other code is "unavailable"', () {
      expect(linkErrorFromCode('contact_locked'), ContactLinkError.locked);
      expect(linkErrorFromCode('permission_denied'), ContactLinkError.unavailable);
      expect(linkErrorFromCode('not_found'), ContactLinkError.unavailable);
      expect(linkErrorFromCode(null), ContactLinkError.unavailable);
    });

    test('an exception never prints a number', () {
      expect(const ContactLinkException(ContactLinkError.locked).toString(), isNot(contains('+84')));
    });
  });

  group('FakeContactLinkRepository mirrors the server rules', () {
    const booking = ContactSubject.booking('b1');
    const channels = ContactChannels(call: true, zalo: true, whatsapp: true);

    FakeContactLinkRepository fake({bool unlocked = true, ContactChannels c = channels}) =>
        FakeContactLinkRepository()..add(booking, numbers: own, channels: c, unlocked: unlocked);

    test('unlocked subject gets the URL for each switched-on channel', () async {
      final repo = fake();
      expect(
        (await repo.link(subject: booking, channel: ContactChannel.zalo)).toString(),
        'https://zalo.me/84912345678',
      );
      expect(
        (await repo.link(subject: booking, channel: ContactChannel.call)).toString(),
        'tel:+84903123456',
      );
      expect(repo.requests.length, 2);
      expect(repo.requests.first.channel, ContactChannel.zalo);
    });

    test('locked subject is refused with contact_locked and nothing is built', () async {
      final repo = fake(unlocked: false);
      await expectLater(
        repo.link(subject: booking, channel: ContactChannel.call),
        throwsA(isA<ContactLinkException>().having((e) => e.error, 'error', ContactLinkError.locked)),
      );
    });

    test('setUnlocked flips the answer', () async {
      final repo = fake(unlocked: false)..setUnlocked(booking, true);
      expect(await repo.link(subject: booking, channel: ContactChannel.call), isA<Uri>());
    });

    test('a channel the photographer switched off is unavailable', () async {
      final repo = fake(c: const ContactChannels(zalo: true));
      await expectLater(
        repo.link(subject: booking, channel: ContactChannel.call),
        throwsA(isA<ContactLinkException>().having((e) => e.error, 'error', ContactLinkError.unavailable)),
      );
    });

    test('unknown subject and the in-app channel are unavailable', () async {
      final repo = fake();
      await expectLater(
        repo.link(subject: const ContactSubject.booking('nope'), channel: ContactChannel.call),
        throwsA(isA<ContactLinkException>()),
      );
      await expectLater(
        repo.link(subject: booking, channel: ContactChannel.inApp),
        throwsA(isA<ContactLinkException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/contact/contact_link_repository_test.dart`
Expected: FAIL, `contact_link_repository.dart` not found.

- [ ] **Step 3: Implement**

Add the dependency (resolves the version that matches the project's `firebase_core`) and check `pubspec.yaml` lists `cloud_functions`:

```bash
flutter pub add cloud_functions
grep -n "cloud_functions" pubspec.yaml
```

```dart
// lib/data/contact/contact_link_repository.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';

enum ContactSubjectType { booking, registration }

/// What a contact link is for: a booking, or an event registration (ticket).
/// The server derives the photographer, number and unlock state from it.
class ContactSubject {
  const ContactSubject.booking(this.id) : type = ContactSubjectType.booking;
  const ContactSubject.registration(this.id)
    : type = ContactSubjectType.registration;

  final String id;
  final ContactSubjectType type;

  @override
  bool operator ==(Object other) =>
      other is ContactSubject && other.id == id && other.type == type;

  @override
  int get hashCode => Object.hash(id, type);
}

enum ContactLinkError {
  /// Contact is not unlocked yet (server code `contact_locked`).
  locked,

  /// Anything else: no permission, not found, channel off, network.
  unavailable,
}

class ContactLinkException implements Exception {
  const ContactLinkException(this.error);
  final ContactLinkError error;

  // Deliberately says nothing but the kind: no number can leak through logs.
  @override
  String toString() => 'ContactLinkException(${error.name})';
}

/// Port: asks the server for the one URL that opens [channel] for [subject].
/// The client never receives or stores the photographer's number itself.
abstract class ContactLinkRepository {
  /// Throws [ContactLinkException].
  Future<Uri> link({
    required ContactSubject subject,
    required ContactChannel channel,
  });
}

/// Payload of the callable `getContactLink`.
Map<String, Object> callableData(ContactSubject subject, ContactChannel channel) =>
    {
      switch (subject.type) {
        ContactSubjectType.booking => 'bookingId',
        ContactSubjectType.registration => 'registrationId',
      }: subject.id,
      'channel': channel.code,
    };

/// The URL a channel opens, from the photographer's numbers. This is the
/// reference for the server function and what the fake returns:
/// `tel:+84…`, `https://zalo.me/84…`, `https://wa.me/84…` (no plus).
Uri contactUriFor(ContactChannel channel, ContactNumbers numbers) {
  final number = numbers.numberFor(channel);
  if (number == null) {
    throw ArgumentError.value(channel, 'channel', 'has no external URL');
  }
  final digits = number.startsWith('+') ? number.substring(1) : number;
  return switch (channel) {
    ContactChannel.call => Uri(scheme: 'tel', path: number),
    ContactChannel.zalo => Uri.https('zalo.me', '/$digits'),
    ContactChannel.whatsapp => Uri.https('wa.me', '/$digits'),
    ContactChannel.inApp => throw ArgumentError.value(channel, 'channel'),
  };
}

final _e164 = RegExp(r'^\+\d{8,15}$');
final _digitsPath = RegExp(r'^/\d{8,15}$');

bool _https(Uri uri, String host) =>
    uri.scheme == 'https' &&
    uri.host == host &&
    !uri.hasPort &&
    uri.userInfo.isEmpty &&
    _digitsPath.hasMatch(uri.path);

/// The app opens a server-provided URL only when it has exactly the shape
/// built by [contactUriFor] for that channel.
bool isAllowedContactUri(Uri uri, ContactChannel channel) {
  if (uri.hasQuery || uri.hasFragment) return false;
  return switch (channel) {
    ContactChannel.call => uri.scheme == 'tel' && _e164.hasMatch(uri.path),
    ContactChannel.zalo => _https(uri, 'zalo.me'),
    ContactChannel.whatsapp => _https(uri, 'wa.me'),
    ContactChannel.inApp => false,
  };
}

/// Reads the callable's `{url: "..."}` response.
Uri parseLinkResponse(Object? data) {
  final url = data is Map ? data['url'] : null;
  final uri = url is String ? Uri.tryParse(url) : null;
  if (uri == null) {
    throw const ContactLinkException(ContactLinkError.unavailable);
  }
  return uri;
}

/// Maps the server error code (`details.code`) to what the UI needs.
ContactLinkError linkErrorFromCode(String? code) =>
    code == 'contact_locked'
    ? ContactLinkError.locked
    : ContactLinkError.unavailable;

typedef ContactLinkRequest = ({ContactSubject subject, ContactChannel channel});

/// In-memory stand-in with the server's rules: refuses locked subjects and
/// switched-off channels, otherwise returns [contactUriFor].
class FakeContactLinkRepository implements ContactLinkRepository {
  final _subjects =
      <ContactSubject, ({ContactNumbers numbers, ContactChannels channels, bool unlocked})>{};

  /// Every call made, in order (channel and subject only: never a number).
  final requests = <ContactLinkRequest>[];

  void add(
    ContactSubject subject, {
    required ContactNumbers numbers,
    required ContactChannels channels,
    bool unlocked = true,
  }) => _subjects[subject] = (
    numbers: numbers,
    channels: channels,
    unlocked: unlocked,
  );

  void setUnlocked(ContactSubject subject, bool unlocked) {
    final s = _subjects[subject]!;
    _subjects[subject] = (
      numbers: s.numbers,
      channels: s.channels,
      unlocked: unlocked,
    );
  }

  @override
  Future<Uri> link({
    required ContactSubject subject,
    required ContactChannel channel,
  }) async {
    requests.add((subject: subject, channel: channel));
    final s = _subjects[subject];
    if (s == null || !channel.isExternal) {
      throw const ContactLinkException(ContactLinkError.unavailable);
    }
    if (!s.unlocked) {
      throw const ContactLinkException(ContactLinkError.locked);
    }
    if (!s.channels.external.contains(channel)) {
      throw const ContactLinkException(ContactLinkError.unavailable);
    }
    return contactUriFor(channel, s.numbers);
  }
}
```

```dart
// lib/data/contact/functions_contact_link_repository.dart
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';

/// Calls the callable `getContactLink` (server side: a later plan). Thin on
/// purpose: all rules are in the pure functions of contact_link_repository.dart.
class FunctionsContactLinkRepository implements ContactLinkRepository {
  FunctionsContactLinkRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;
  final FirebaseFunctions _functions;

  @override
  Future<Uri> link({
    required ContactSubject subject,
    required ContactChannel channel,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('getContactLink')
          .call<Object?>(callableData(subject, channel));
      return parseLinkResponse(result.data);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final code = details is Map && details['code'] is String
          ? details['code'] as String
          : e.message;
      throw ContactLinkException(linkErrorFromCode(code));
    }
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/contact/contact_link_repository_test.dart && flutter analyze`
Expected: PASS (17 tests); analyze clean (the adapter compiles against `cloud_functions`).

- [ ] **Step 5: Commit**

```bash
git add lib/data/contact test/data/contact pubspec.yaml pubspec.lock
git commit -m "feat(data): ContactLinkRepository port, URL allow-list, fake and callable adapter

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `ContactLauncher`, `url_launcher` and package visibility

**Files:**
- Create: `lib/data/contact/external_launcher.dart`, `lib/data/contact/contact_launcher.dart`, `lib/data/contact/contact_providers.dart`, `test/data/contact/contact_launcher_test.dart`, `test/platform_config_test.dart`
- Modify: `pubspec.yaml`, `pubspec.lock`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`

**Interfaces:**
- Consumes: Task 4's `ContactLinkRepository`, `ContactSubject`, `ContactLinkException`, `isAllowedContactUri`, `FakeContactLinkRepository`.
- Produces:
  - `abstract class ExternalLauncher { Future<bool> canOpen(Uri uri); Future<bool> open(Uri uri); }`, `UrlLauncherExternalLauncher` (uses `canLaunchUrl` / `launchUrl(mode: LaunchMode.externalApplication)`), `FakeExternalLauncher({Set<String> unsupportedSchemes = const {}, bool failOpen = false})` with `opened` (`List<Uri>`).
  - `enum ContactOpenResult { opened, locked, unavailable, cannotLaunch }`.
  - `class ContactLauncher { const ContactLauncher({required ContactLinkRepository links, required ExternalLauncher launcher}); Future<bool> canOpen(ContactChannel); Future<ContactOpenResult> open(ContactChannel, {required ContactSubject subject}); }`. It never logs, stores or returns the URL.
  - Providers: `contactLinkRepositoryProvider`, `externalLauncherProvider`, `contactLauncherProvider`.
  - Android 11+ `<queries>` for `VIEW tel` and `VIEW https`; iOS `LSApplicationQueriesSchemes` = `tel`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/contact/contact_launcher_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_launcher.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';

class _StubLinks implements ContactLinkRepository {
  _StubLinks(this.uri);
  final Uri uri;
  @override
  Future<Uri> link({required ContactSubject subject, required ContactChannel channel}) async => uri;
}

void main() {
  const subject = ContactSubject.booking('b1');
  const numbers = ContactNumbers(phone: '+84903123456', whatsappPhone: '+14155552671');
  const channels = ContactChannels(call: true, zalo: true, whatsapp: true);

  ({ContactLauncher launcher, FakeContactLinkRepository links, FakeExternalLauncher external}) build({
    bool unlocked = true,
    Set<String> unsupported = const {},
    bool failOpen = false,
  }) {
    final links = FakeContactLinkRepository()
      ..add(subject, numbers: numbers, channels: channels, unlocked: unlocked);
    final external = FakeExternalLauncher(unsupportedSchemes: unsupported, failOpen: failOpen);
    return (launcher: ContactLauncher(links: links, launcher: external), links: links, external: external);
  }

  test('opens the dialer, Zalo and WhatsApp with the server-built URLs', () async {
    final t = build();
    expect(await t.launcher.open(ContactChannel.call, subject: subject), ContactOpenResult.opened);
    expect(await t.launcher.open(ContactChannel.zalo, subject: subject), ContactOpenResult.opened);
    expect(await t.launcher.open(ContactChannel.whatsapp, subject: subject), ContactOpenResult.opened);
    expect(t.external.opened.map((u) => u.toString()), [
      'tel:+84903123456',
      'https://zalo.me/84903123456',
      'https://wa.me/14155552671',
    ]);
  });

  test('maps contact_locked and opens nothing', () async {
    final t = build(unlocked: false);
    expect(await t.launcher.open(ContactChannel.zalo, subject: subject), ContactOpenResult.locked);
    expect(t.external.opened, isEmpty);
  });

  test('other server failures are "unavailable"', () async {
    final t = build();
    expect(
      await t.launcher.open(ContactChannel.zalo, subject: const ContactSubject.booking('missing')),
      ContactOpenResult.unavailable,
    );
    expect(t.external.opened, isEmpty);
  });

  test('a URL the server should not send is refused, not opened', () async {
    for (final url in [
      'https://evil.com/84903123456',
      'https://zalo.me/84903123456?text=x',
      'http://zalo.me/84903123456',
      'tel:0903123456',
    ]) {
      final external = FakeExternalLauncher();
      final launcher = ContactLauncher(links: _StubLinks(Uri.parse(url)), launcher: external);
      final channel = url.startsWith('tel') ? ContactChannel.call : ContactChannel.zalo;
      expect(await launcher.open(channel, subject: subject), ContactOpenResult.unavailable, reason: url);
      expect(external.opened, isEmpty, reason: url);
    }
  });

  test('the OS refusing to open is "cannotLaunch"', () async {
    final t = build(failOpen: true);
    expect(await t.launcher.open(ContactChannel.zalo, subject: subject), ContactOpenResult.cannotLaunch);
  });

  test('canOpen hides the dialer on a device without a phone, keeps the web links', () async {
    final t = build(unsupported: {'tel'});
    expect(await t.launcher.canOpen(ContactChannel.call), isFalse);
    expect(await t.launcher.canOpen(ContactChannel.zalo), isTrue);
    expect(await t.launcher.canOpen(ContactChannel.whatsapp), isTrue);
    expect(await t.launcher.canOpen(ContactChannel.inApp), isFalse);
  });

  test('the in-app channel is not opened here', () async {
    final t = build();
    expect(() => t.launcher.open(ContactChannel.inApp, subject: subject), throwsArgumentError);
  });

  test('canOpen probes with a placeholder, never a real number', () async {
    final t = build();
    await t.launcher.canOpen(ContactChannel.call);
    expect(t.links.requests, isEmpty);
    expect(t.external.opened, isEmpty);
  });
}
```

```dart
// test/platform_config_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 11+ can see a dialer and a browser (url_launcher canLaunchUrl)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final queries = RegExp(r'<queries>[\s\S]*?</queries>').firstMatch(manifest)?.group(0) ?? '';
    for (final scheme in ['tel', 'https']) {
      expect(
        RegExp('<action android:name="android.intent.action.VIEW"\\s*/>\\s*<data android:scheme="$scheme"\\s*/>')
            .hasMatch(queries),
        isTrue,
        reason: '<queries> needs a VIEW intent for $scheme',
      );
    }
  });

  test('iOS lists tel so canLaunchUrl can tell a phone from a tablet', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      RegExp(r'<key>LSApplicationQueriesSchemes</key>\s*<array>\s*<string>tel</string>\s*</array>')
          .hasMatch(plist),
      isTrue,
    );
  });

  test('url_launcher is a dependency', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('url_launcher:'));
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/contact/contact_launcher_test.dart test/platform_config_test.dart`
Expected: FAIL: `contact_launcher.dart` / `external_launcher.dart` not found; the config tests fail on the missing queries and dependency.

- [ ] **Step 3: Implement**

```bash
flutter pub add url_launcher
grep -n "url_launcher" pubspec.yaml
```

In `android/app/src/main/AndroidManifest.xml` replace the existing `<queries>` block

```xml
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
```

with

```xml
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <!-- url_launcher canLaunchUrl on Android 11+: a dialer and a browser. -->
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="tel"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
    </queries>
```

In `ios/Runner/Info.plist` insert, directly before `<key>UIApplicationSupportsIndirectInputEvents</key>`:

```xml
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>tel</string>
	</array>
```

```dart
// lib/data/contact/external_launcher.dart
import 'package:url_launcher/url_launcher.dart';

/// Port over "open this URL in another app", so tests never touch the OS.
abstract class ExternalLauncher {
  Future<bool> canOpen(Uri uri);
  Future<bool> open(Uri uri);
}

class UrlLauncherExternalLauncher implements ExternalLauncher {
  const UrlLauncherExternalLauncher();

  @override
  Future<bool> canOpen(Uri uri) => canLaunchUrl(uri);

  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

class FakeExternalLauncher implements ExternalLauncher {
  FakeExternalLauncher({this.unsupportedSchemes = const {}, this.failOpen = false});

  /// Schemes this "device" cannot handle (e.g. `tel` on a tablet).
  final Set<String> unsupportedSchemes;
  final bool failOpen;

  /// URLs that were opened, in order.
  final opened = <Uri>[];

  @override
  Future<bool> canOpen(Uri uri) async => !unsupportedSchemes.contains(uri.scheme);

  @override
  Future<bool> open(Uri uri) async {
    if (failOpen || unsupportedSchemes.contains(uri.scheme)) return false;
    opened.add(uri);
    return true;
  }
}
```

```dart
// lib/data/contact/contact_launcher.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/external_launcher.dart';

enum ContactOpenResult {
  opened,

  /// Contact is not unlocked (`contact_locked`).
  locked,

  /// Server refused or failed, or sent a URL the app does not accept.
  unavailable,

  /// The OS found nothing to open the link with.
  cannotLaunch,
}

/// Opens a contact channel: asks the server for the URL, checks its shape,
/// hands it to the OS. It does not log, keep or return the URL, so the number
/// exists in the app only for the instant of the call.
class ContactLauncher {
  const ContactLauncher({
    required ContactLinkRepository links,
    required ExternalLauncher launcher,
  }) : _links = links,
       _launcher = launcher;

  final ContactLinkRepository _links;
  final ExternalLauncher _launcher;

  // Probes only ask "is there an app for this kind of link"; they hold no real number.
  static final _probes = {
    ContactChannel.call: Uri(scheme: 'tel', path: '+84900000000'),
    ContactChannel.zalo: Uri.https('zalo.me', '/84900000000'),
    ContactChannel.whatsapp: Uri.https('wa.me', '/84900000000'),
  };

  /// False for the in-app chat and for channels this device cannot open
  /// (a tablet without a dialer): hide those.
  Future<bool> canOpen(ContactChannel channel) async {
    final probe = _probes[channel];
    return probe != null && _launcher.canOpen(probe);
  }

  Future<ContactOpenResult> open(
    ContactChannel channel, {
    required ContactSubject subject,
  }) async {
    if (!channel.isExternal) {
      throw ArgumentError.value(channel, 'channel', 'is not an external channel');
    }
    final Uri uri;
    try {
      uri = await _links.link(subject: subject, channel: channel);
    } on ContactLinkException catch (e) {
      return e.error == ContactLinkError.locked
          ? ContactOpenResult.locked
          : ContactOpenResult.unavailable;
    }
    if (!isAllowedContactUri(uri, channel)) return ContactOpenResult.unavailable;
    try {
      return await _launcher.open(uri)
          ? ContactOpenResult.opened
          : ContactOpenResult.cannotLaunch;
    } on Exception {
      return ContactOpenResult.cannotLaunch;
    }
  }
}
```

```dart
// lib/data/contact/contact_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/contact/contact_launcher.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/contact/functions_contact_link_repository.dart';

final contactLinkRepositoryProvider = Provider<ContactLinkRepository>(
  (ref) => FunctionsContactLinkRepository(),
);

final externalLauncherProvider = Provider<ExternalLauncher>(
  (ref) => const UrlLauncherExternalLauncher(),
);

final contactLauncherProvider = Provider<ContactLauncher>(
  (ref) => ContactLauncher(
    links: ref.watch(contactLinkRepositoryProvider),
    launcher: ref.watch(externalLauncherProvider),
  ),
);
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/contact test/platform_config_test.dart && flutter analyze`
Expected: PASS (launcher 8 + config 3 + Task 4's 17); analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/contact test/data/contact test/platform_config_test.dart android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist pubspec.yaml pubspec.lock
git commit -m "feat(contact): ContactLauncher with URL allow-list, url_launcher and package visibility

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `ContactDial` widget

**Files:**
- Create: `lib/core/widgets/contact_dial.dart`, `test/core/widgets/contact_dial_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `ContactChannel`, `ContactAccess` (Task 2); `hostWidget` (plan 2a / core-display-widgets Task 1); `AppColors`, `AppColorsDark`, `AppSpace`, `AppRadius`.
- Produces:
  - `enum ContactDialStyle { icon, labeled }`.
  - `const ContactDial({super.key, required ContactAccess access, required List<ContactChannel> channels, required ValueChanged<ContactChannel> onSelected, ContactDialStyle style = ContactDialStyle.icon, bool busy = false})`.
    - `locked`: a chat button "Nhắn tin hỏi trước"; tap calls `onSelected(ContactChannel.inApp)`; never expands.
    - `unlocked`: considers only external channels in `channels` (`inApp` is ignored; the screen has its own "Nhắn tin" button), in the fixed order Gọi, Zalo, WhatsApp. None: renders nothing. One: tap calls `onSelected(that channel)`. Two or more: tap opens the tray.
    - `busy`: the button shows a spinner and ignores taps (a link is being fetched).
  - Widget keys for tests: `contact-dial-button`, `contact-tray`, `contact-tray-fade` (the tray's `Opacity`), `contact-call`, `contact-zalo`, `contact-whatsapp`, and `contact-item-fade-<code>` (each entry's `Opacity`).
  - Focus nodes are labelled `ContactDial button` and `ContactDial item 0..2` (read by the tests).
  - l10n: `contactLabel` "Liên hệ", `contactCall` "Gọi điện", `contactZalo` "Zalo", `contactWhatsApp` "WhatsApp", `contactInquiry` "Nhắn tin hỏi trước", `contactLockedHint` "Liên hệ qua điện thoại mở sau khi bạn đặt lịch".
  - The widget never opens a URL and takes no `source`: the screen's `onSelected` calls `ContactLauncher` and logs the analytics event (Task 7).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/contact_dial_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

const _all = [ContactChannel.call, ContactChannel.zalo, ContactChannel.whatsapp];
const _button = Key('contact-dial-button');
const _tray = Key('contact-tray');

/// Puts the dial near the right edge and low on the screen, so the tray has
/// room above it.
Future<void> _pump(
  WidgetTester tester, {
  ContactAccess access = ContactAccess.unlocked,
  List<ContactChannel> channels = _all,
  ValueChanged<ContactChannel>? onSelected,
  ContactDialStyle style = ContactDialStyle.icon,
  bool busy = false,
  bool reduced = false,
  double width = 390,
  double textScale = 1.0,
  double top = 300,
  Brightness brightness = Brightness.dark,
  Widget? sibling,
}) async {
  Widget dial = ContactDial(
    access: access,
    channels: channels,
    onSelected: onSelected ?? (_) {},
    style: style,
    busy: busy,
  );
  if (reduced) {
    final inner = dial;
    dial = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  await tester.pumpWidget(
    hostWidget(
      Padding(
        padding: EdgeInsets.only(top: top, left: width - 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [dial, if (sibling != null) sibling],
        ),
      ),
      width: width,
      textScale: textScale,
      brightness: brightness,
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_button));
  await tester.pumpAndSettle();
}

double _opacityOf(WidgetTester tester, Key key) =>
    tester.widget<Opacity>(find.byKey(key)).opacity;

List<double> _itemOpacities(WidgetTester tester) => [
  for (final c in ['call', 'zalo', 'whatsapp'])
    _opacityOf(tester, Key('contact-item-fade-$c')),
];

void main() {
  group('resting state', () {
    testWidgets('only the small button is visible, no channel names', (tester) async {
      await _pump(tester);
      expect(find.byKey(_button), findsOneWidget);
      expect(find.byKey(_tray), findsNothing);
      expect(find.text('Zalo'), findsNothing);
      expect(tester.getSize(find.byKey(_button)), const Size(48, 48));
    });

    testWidgets('labeled style is a 44dp hit area showing "Liên hệ"', (tester) async {
      await _pump(tester, style: ContactDialStyle.labeled);
      expect(find.text('Liên hệ'), findsOneWidget);
      expect(tester.getSize(find.byKey(_button)).height, greaterThanOrEqualTo(44));
    });

    testWidgets('no outside channel at all: nothing is drawn', (tester) async {
      await _pump(tester, channels: const []);
      expect(find.byKey(_button), findsNothing);
      await _pump(tester, channels: const [ContactChannel.inApp]);
      expect(find.byKey(_button), findsNothing);
    });
  });

  group('locked: only the inquiry chat', () {
    testWidgets('tap opens the inquiry directly and never expands', (tester) async {
      final picked = <ContactChannel>[];
      await _pump(tester, access: ContactAccess.locked, onSelected: picked.add);
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(picked, [ContactChannel.inApp]);
      expect(find.byKey(_tray), findsNothing);
      expect(find.text('Zalo'), findsNothing);
    });

    testWidgets('it is labelled "Nhắn tin hỏi trước" with the unlock hint', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, access: ContactAccess.locked, channels: const [ContactChannel.call]);
      expect(find.bySemanticsLabel('Nhắn tin hỏi trước'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(_button)).hint,
        'Liên hệ qua điện thoại mở sau khi bạn đặt lịch',
      );
      handle.dispose();
    });

    testWidgets('labeled style shows the inquiry text', (tester) async {
      await _pump(tester, access: ContactAccess.locked, style: ContactDialStyle.labeled);
      expect(find.text('Nhắn tin hỏi trước'), findsOneWidget);
    });
  });

  group('single channel', () {
    testWidgets('tap goes straight to that channel, no tray', (tester) async {
      final picked = <ContactChannel>[];
      await _pump(tester, channels: const [ContactChannel.zalo], onSelected: picked.add);
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(picked, [ContactChannel.zalo]);
      expect(find.byKey(_tray), findsNothing);
    });

    testWidgets('in-app in the list is ignored once unlocked', (tester) async {
      final picked = <ContactChannel>[];
      await _pump(
        tester,
        channels: const [ContactChannel.inApp, ContactChannel.call],
        onSelected: picked.add,
      );
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(picked, [ContactChannel.call]);
    });
  });

  group('expanding', () {
    testWidgets('tap shows Gọi điện, Zalo, WhatsApp left to right with text labels', (tester) async {
      await _pump(tester);
      await _open(tester);
      expect(find.byKey(_tray), findsOneWidget);
      final xs = [
        for (final k in ['contact-call', 'contact-zalo', 'contact-whatsapp'])
          tester.getCenter(find.byKey(Key(k))).dx,
      ];
      expect(xs[0], lessThan(xs[1]));
      expect(xs[1], lessThan(xs[2]));
      for (final t in ['Gọi điện', 'Zalo', 'WhatsApp']) {
        expect(find.text(t), findsOneWidget);
      }
    });

    testWidgets('only the switched-on channels are listed', (tester) async {
      await _pump(tester, channels: const [ContactChannel.call, ContactChannel.whatsapp]);
      await _open(tester);
      expect(find.byKey(const Key('contact-zalo')), findsNothing);
      expect(find.byKey(const Key('contact-whatsapp')), findsOneWidget);
    });

    testWidgets('it opens upward, right-aligned, without moving or covering anything', (tester) async {
      await _pump(tester, sibling: const SizedBox(key: Key('below'), width: 100, height: 52));
      final button = tester.getRect(find.byKey(_button));
      final below = tester.getRect(find.byKey(const Key('below')));
      await _open(tester);
      final tray = tester.getRect(find.byKey(_tray));
      expect(tray.bottom, lessThanOrEqualTo(button.top));
      expect(tray.right, closeTo(button.right, 1));
      expect(tester.getRect(find.byKey(_button)), button);
      expect(tester.getRect(find.byKey(const Key('below'))), below);
    });

    testWidgets('with no room above it opens downward', (tester) async {
      await _pump(tester, top: 0);
      await _open(tester);
      final button = tester.getRect(find.byKey(_button));
      final tray = tester.getRect(find.byKey(_tray));
      expect(tray.top, greaterThanOrEqualTo(button.bottom));
    });

    testWidgets('the button turns primary while open', (tester) async {
      await _pump(tester);
      Color? border() {
        final box = tester.widget<Container>(
          find.descendant(of: find.byKey(_button), matching: find.byType(Container)).first,
        );
        return ((box.decoration! as BoxDecoration).border! as Border).top.color;
      }

      final resting = border();
      await _open(tester);
      expect(border(), isNot(resting));
      expect(border(), Theme.of(tester.element(find.byKey(_button))).colorScheme.primary);
    });

    testWidgets('picking an entry reports it and closes', (tester) async {
      final picked = <ContactChannel>[];
      await _pump(tester, onSelected: picked.add);
      await _open(tester);
      await tester.tap(find.byKey(const Key('contact-whatsapp')));
      await tester.pumpAndSettle();
      expect(picked, [ContactChannel.whatsapp]);
      expect(find.byKey(_tray), findsNothing);
    });

    testWidgets('a light tap on opening gives selection haptic feedback', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pump(tester);
      await _open(tester);
      expect(
        calls.where((c) => c.method == 'HapticFeedback.vibrate').map((c) => c.arguments),
        contains('HapticFeedbackType.selectionClick'),
      );
    });
  });

  group('animation', () {
    testWidgets('fades in over 240ms with the right-most entry first', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(_button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final trayOpacity = _opacityOf(tester, const Key('contact-tray-fade'));
      expect(trayOpacity, greaterThan(0));
      final o = _itemOpacities(tester); // left to right: call, zalo, whatsapp
      expect(o[2], greaterThan(o[1]));
      expect(o[1], greaterThan(o[0]));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, const Key('contact-tray-fade')), 1.0);
    });

    testWidgets('closing is faster than opening (done within 150ms) and has no stagger', (tester) async {
      await _pump(tester);
      await _open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.byKey(_tray), findsNothing);
    });

    testWidgets('reduced motion shows and hides instantly', (tester) async {
      await _pump(tester, reduced: true);
      await tester.tap(find.byKey(_button));
      await tester.pump(); // one frame, no settling
      expect(find.byKey(_tray), findsOneWidget);
      expect(_opacityOf(tester, const Key('contact-tray-fade')), 1.0);
      expect(_itemOpacities(tester), [1.0, 1.0, 1.0]);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(find.byKey(_tray), findsNothing);
    });
  });

  group('closing', () {
    testWidgets('tap outside', (tester) async {
      await _pump(tester);
      await _open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(_tray), findsNothing);
    });

    testWidgets('tapping the button again', (tester) async {
      await _pump(tester);
      await _open(tester);
      await tester.tap(find.byKey(_button), warnIfMissed: false); // the scrim takes the tap
      await tester.pumpAndSettle();
      expect(find.byKey(_tray), findsNothing);
    });

    testWidgets('system Back closes the tray and keeps the screen', (tester) async {
      await _pump(tester);
      await _open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(_tray), findsNothing);
      expect(find.byKey(_button), findsOneWidget);
    });

    testWidgets('Esc closes it and returns focus to the button', (tester) async {
      await _pump(tester);
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(_tray), findsNothing);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'ContactDial button');
    });
  });

  group('keyboard and accessibility', () {
    testWidgets('focus lands on the first entry, Tab walks in display order', (tester) async {
      await _pump(tester);
      await _open(tester);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'ContactDial item 0');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'ContactDial item 1');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'ContactDial item 2');
    });

    testWidgets('Enter on the focused entry selects it', (tester) async {
      final picked = <ContactChannel>[];
      await _pump(tester, onSelected: picked.add);
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(picked, [ContactChannel.zalo]);
    });

    testWidgets('the button is a labelled button that reports expanded', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(find.bySemanticsLabel('Liên hệ'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(_button)),
        isSemantics(label: 'Liên hệ', isButton: true, hasExpandedState: true, isExpanded: false),
      );
      await _open(tester);
      expect(
        tester.getSemantics(find.byKey(_button)),
        isSemantics(label: 'Liên hệ', isButton: true, hasExpandedState: true, isExpanded: true),
      );
      handle.dispose();
    });

    testWidgets('every entry is at least 44dp and 8dp from its neighbour', (tester) async {
      await _pump(tester);
      await _open(tester);
      final rects = [
        for (final k in ['contact-call', 'contact-zalo', 'contact-whatsapp'])
          tester.getRect(find.byKey(Key(k))),
      ];
      for (final r in rects) {
        expect(r.width, greaterThanOrEqualTo(44));
        expect(r.height, greaterThanOrEqualTo(44));
      }
      expect(rects[1].left - rects[0].right, greaterThanOrEqualTo(8));
      expect(rects[2].left - rects[1].right, greaterThanOrEqualTo(8));
    });

    testWidgets('Zalo and WhatsApp use the brand glyph files, labelled by text', (tester) async {
      await _pump(tester);
      await _open(tester);
      expect(find.byType(SvgPicture), findsNWidgets(2));
    });
  });

  group('busy', () {
    testWidgets('shows a spinner and ignores taps while a link is fetched', (tester) async {
      final picked = <ContactChannel>[];
      await _pump(tester, busy: true, onSelected: picked.add);
      expect(
        find.descendant(of: find.byKey(_button), matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
      expect(find.byKey(_tray), findsNothing);
    });
  });

  group('layout limits', () {
    for (final brightness in Brightness.values) {
      testWidgets('320dp at 1.3x text, ${brightness.name}: tray stays on screen, no overflow', (tester) async {
        await _pump(tester, width: 320, textScale: 1.3, brightness: brightness);
        await _open(tester);
        expect(tester.takeException(), isNull);
        final tray = tester.getRect(find.byKey(_tray));
        expect(tray.left, greaterThanOrEqualTo(0));
        expect(tray.right, lessThanOrEqualTo(320));
        for (final k in ['contact-call', 'contact-zalo', 'contact-whatsapp']) {
          expect(tester.getSize(find.byKey(Key(k))).height, greaterThanOrEqualTo(44));
        }
      });
    }
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/contact_dial_test.dart`
Expected: FAIL to compile, `ContactDial` / `ContactDialStyle` undefined.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`, then run `flutter gen-l10n`:

```json
  "contactLabel": "Liên hệ",
  "contactCall": "Gọi điện",
  "contactZalo": "Zalo",
  "contactWhatsApp": "WhatsApp",
  "contactInquiry": "Nhắn tin hỏi trước",
  "contactLockedHint": "Liên hệ qua điện thoại mở sau khi bạn đặt lịch",
```

```dart
// lib/core/widgets/contact_dial.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:photobooking/core/contact_channel.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/l10n/app_localizations.dart';

enum ContactDialStyle {
  /// Square 48dp button with a phone icon.
  icon,

  /// Low 38dp pill reading "Liên hệ", for a row of buttons (hit area is 44dp).
  labeled,
}

const _openDuration = Duration(milliseconds: 240);
const _closeDuration = Duration(milliseconds: 140);
const _stagger = Duration(milliseconds: 40);

// Sizes fixed by the spec (3b.5); the tray radius has no token (like GlassCard).
const double _trayRadius = 28;
const double _circle = 44;
const double _itemWidth = 62;
const double _gap = 8;
const double _labelSize = 10.5;
const double _lift = 10;
const double _minTarget = 44;

extension ContactChannelUi on ContactChannel {
  String label(AppLocalizations l) => switch (this) {
    ContactChannel.call => l.contactCall,
    ContactChannel.zalo => l.contactZalo,
    ContactChannel.whatsapp => l.contactWhatsApp,
    ContactChannel.inApp => l.contactInquiry,
  };
}

/// Compact contact button. Resting, it is one small button; the outside
/// channels appear in a tray only when it is tapped (spec 3b.5).
///
/// It never opens a URL: [onSelected] is the screen's cue to call
/// `ContactLauncher.open` (or to open the inquiry chat for `inApp`).
class ContactDial extends StatefulWidget {
  const ContactDial({
    super.key,
    required this.access,
    required this.channels,
    required this.onSelected,
    this.style = ContactDialStyle.icon,
    this.busy = false,
  });

  final ContactAccess access;

  /// Channels the photographer accepts. When unlocked only the external ones
  /// count, shown in the fixed order Gọi, Zalo, WhatsApp.
  final List<ContactChannel> channels;
  final ValueChanged<ContactChannel> onSelected;
  final ContactDialStyle style;

  /// A link is being fetched: spinner on the button, taps ignored.
  final bool busy;

  @override
  State<ContactDial> createState() => _ContactDialState();
}

class _ContactDialState extends State<ContactDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: _openDuration,
    reverseDuration: _closeDuration,
  );
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _buttonFocus = FocusNode(debugLabel: 'ContactDial button');
  final _itemFocus = List.generate(
    3,
    (i) => FocusNode(debugLabel: 'ContactDial item $i'),
  );
  bool _open = false;
  bool _below = false;

  @override
  void initState() {
    super.initState();
    _anim.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !_open && _portal.isShowing) {
        _portal.hide();
      }
    });
  }

  @override
  void didUpdateWidget(ContactDial old) {
    super.didUpdateWidget(old);
    final changed =
        old.access != widget.access ||
        !listEquals(old.channels, widget.channels);
    if (_open && changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close(refocus: false);
      });
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _buttonFocus.dispose();
    for (final n in _itemFocus) {
      n.dispose();
    }
    super.dispose();
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  List<ContactChannel> get _external => [
    for (final c in ContactChannel.values)
      if (c.isExternal && widget.channels.contains(c)) c,
  ];

  /// Height the tray needs above or below the button, with a text-scale margin.
  double _trayExtent() =>
      _circle +
      4 +
      MediaQuery.textScalerOf(context).scale(_labelSize * 1.4) +
      AppSpace.s3 * 2 +
      _gap;

  void _onButton(List<ContactChannel> external) {
    if (widget.busy) return;
    if (widget.access == ContactAccess.locked) {
      widget.onSelected(ContactChannel.inApp);
    } else if (external.length == 1) {
      widget.onSelected(external.single);
    } else if (_open) {
      _close();
    } else {
      _openTray();
    }
  }

  void _openTray() {
    final box = context.findRenderObject() as RenderBox?;
    final top = box == null ? double.infinity : box.localToGlobal(Offset.zero).dy;
    _below = top < _trayExtent() + MediaQuery.paddingOf(context).top;
    setState(() => _open = true);
    _portal.show();
    // Not awaited; a missing haptic engine must never break the tap.
    unawaited(HapticFeedback.selectionClick().catchError((_) {}));
    if (_reduced) {
      _anim.value = 1;
    } else {
      _anim.forward();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _itemFocus.first.requestFocus();
    });
  }

  void _close({bool refocus = true}) {
    if (!_open) return;
    setState(() => _open = false);
    if (_reduced) {
      _anim.value = 0;
      if (_portal.isShowing) _portal.hide();
    } else {
      _anim.reverse();
    }
    if (refocus) _buttonFocus.requestFocus();
  }

  void _select(ContactChannel channel) {
    _close();
    widget.onSelected(channel);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locked = widget.access == ContactAccess.locked;
    final external = _external;
    if (!locked && external.isEmpty) return const SizedBox.shrink();

    final single = !locked && external.length == 1;
    final expandable = !locked && !single;
    final label = locked
        ? l.contactInquiry
        : single
        ? external.single.label(l)
        : l.contactLabel;
    final color = _open ? scheme.primary : scheme.onSurface;
    final borderColor = _open ? scheme.primary : scheme.outlineVariant;

    Widget glyph(double size) => widget.busy
        ? SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
        : locked
        ? Icon(Icons.chat_bubble_outline_rounded, size: size, color: color)
        : single
        ? _ChannelGlyph(external.single, size: size, color: color)
        : Icon(Icons.phone_outlined, size: size, color: color);

    final visual = widget.style == ContactDialStyle.icon
        ? Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.secondary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: borderColor),
            ),
            child: glyph(22),
          )
        : Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
            decoration: BoxDecoration(
              color: scheme.secondary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                glyph(18),
                const SizedBox(width: AppSpace.s2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          );

    final button = CompositedTransformTarget(
      link: _link,
      child: Semantics(
        button: true,
        label: label,
        hint: locked ? l.contactLockedHint : null,
        expanded: expandable ? _open : null,
        child: InkWell(
          key: const Key('contact-dial-button'),
          focusNode: _buttonFocus,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: widget.busy ? null : () => _onButton(external),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTarget,
              minHeight: _minTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: ExcludeSemantics(child: visual),
            ),
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => _close()},
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) => _buildOverlay(context, external),
          child: button,
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, List<ContactChannel> external) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => _close()},
      child: Stack(
        children: [
          // Catches taps outside the tray (and on the button itself).
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: _below ? Alignment.bottomRight : Alignment.topRight,
            followerAnchor: _below ? Alignment.topRight : Alignment.bottomRight,
            offset: Offset(0, _below ? _gap : -_gap),
            child: Align(
              alignment: _below ? Alignment.topRight : Alignment.bottomRight,
              child: _Tray(
                channels: external,
                animation: _anim,
                reduced: _reduced,
                below: _below,
                focusNodes: _itemFocus,
                onSelect: _select,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({
    required this.channels,
    required this.animation,
    required this.reduced,
    required this.below,
    required this.focusNodes,
    required this.onSelect,
  });

  final List<ContactChannel> channels;
  final Animation<double> animation;
  final bool reduced;
  final bool below;
  final List<FocusNode> focusNodes;
  final ValueChanged<ContactChannel> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final reversing = animation.status == AnimationStatus.reverse;
          // Out: ease with a slight overshoot. In: plain ease-in, no stagger.
          final eased = reduced
              ? 1.0
              : (reversing ? Curves.easeIn : Curves.easeOutBack).transform(
                  animation.value,
                );
          return Opacity(
            key: const Key('contact-tray-fade'),
            opacity: eased.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (below ? -_lift : _lift) * (1 - eased)),
              child: Transform.scale(
                scale: 0.92 + 0.08 * eased,
                alignment: below ? Alignment.topRight : Alignment.bottomRight,
                child: Container(
                  key: const Key('contact-tray'),
                  padding: const EdgeInsets.all(AppSpace.s3),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(_trayRadius),
                    border: Border.all(color: scheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Color(dark ? 0x66000000 : 0x26000000),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FocusScope(
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < channels.length; i++) ...[
                            if (i > 0) const SizedBox(width: _gap),
                            FocusTraversalOrder(
                              order: NumericFocusOrder(i.toDouble()),
                              child: _itemFrame(context, i, reversing),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Entries enter right to left, 40ms apart; on the way out all fade together.
  Widget _itemFrame(BuildContext context, int index, bool reversing) {
    final fromRight = channels.length - 1 - index;
    double t;
    if (reduced) {
      t = 1;
    } else if (reversing) {
      t = Curves.easeIn.transform(animation.value);
    } else {
      final begin = _stagger.inMilliseconds * fromRight;
      final total = _openDuration.inMilliseconds;
      t = Interval(
        begin / total,
        ((begin + 160) / total).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      ).transform(animation.value);
    }
    return Opacity(
      key: Key('contact-item-fade-${channels[index].code}'),
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.8 + 0.2 * t,
        child: _TrayItem(
          channel: channels[index],
          focusNode: focusNodes[index],
          onTap: () => onSelect(channels[index]),
        ),
      ),
    );
  }
}

class _TrayItem extends StatefulWidget {
  const _TrayItem({
    required this.channel,
    required this.focusNode,
    required this.onTap,
  });

  final ContactChannel channel;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<_TrayItem> createState() => _TrayItemState();
}

class _TrayItemState extends State<_TrayItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ring = theme.brightness == Brightness.dark
        ? AppColorsDark.focusRing
        : AppColors.focusRing;
    return InkWell(
      key: Key('contact-${widget.channel.code}'),
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        width: _itemWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _circle,
                height: _circle,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.secondary,
                  border: Border.all(
                    color: _focused ? ring : scheme.outlineVariant,
                    width: _focused ? 2 : 1,
                  ),
                ),
                child: _ChannelGlyph(
                  widget.channel,
                  size: 22,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.channel.label(context.l10n),
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: _labelSize,
                    color: scheme.onSurface,
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

/// Phone glyph for Gọi, the brand files for Zalo and WhatsApp, drawn in one
/// colour. Decorative: every use sits next to a text label.
class _ChannelGlyph extends StatelessWidget {
  const _ChannelGlyph(this.channel, {required this.size, required this.color});

  final ContactChannel channel;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget svg(String asset) => SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
    return ExcludeSemantics(
      child: switch (channel) {
        ContactChannel.call => Icon(Icons.call_outlined, size: size, color: color),
        ContactChannel.zalo => svg('assets/social/zalo.svg'),
        ContactChannel.whatsapp => svg('assets/social/whatsapp.svg'),
        ContactChannel.inApp => Icon(
          Icons.chat_bubble_outline_rounded,
          size: size,
          color: color,
        ),
      },
    );
  }
}
```

Export both new core files from `lib/core/core.dart`, in alphabetical position:

```dart
export 'package:photobooking/core/widgets/contact_dial.dart';
```

(`contact_channel.dart` was exported in Task 2.)

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/contact_dial_test.dart && flutter analyze`
Expected: PASS (about 28 tests, 2 of them looped over light and dark); analyze clean. Known sharp edges, fix the code, not the test: (a) if `isSemantics` is not available in the installed Flutter, replace those two matchers by `expect(tester.getSemantics(find.byKey(_button)).label, 'Liên hệ')` and read the expanded state from `tester.getSemantics(...).getSemanticsData()`; (b) if `find.bySemanticsLabel('Liên hệ')` finds two nodes, the `ExcludeSemantics` around `visual` is missing a level; (c) if the `handlePopRoute` test leaves the tray open, check `PopScope.canPop` flips to false in the same frame as `_open = true`.

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/l10n test/core/widgets/contact_dial_test.dart
git commit -m "feat(core): ContactDial tray with locked, single-channel and reduced-motion modes

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: `ContactAction` and `PhotographerContactAction` (S32 behaviour)

**Files:**
- Create: `lib/data/booking/contact_access.dart`, `lib/features/contact/contact_action.dart`, `test/data/booking/contact_access_test.dart`, `test/features/contact/contact_action_test.dart`
- Modify: `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `ContactDial`, `ContactDialStyle`, `ContactChannel`, `ContactAccess` (core); `ContactLauncher`, `ContactOpenResult`, `contactLauncherProvider`, `contactLinkRepositoryProvider`, `externalLauncherProvider` (Task 5); `ContactSubject`, `FakeContactLinkRepository` (Task 4); `photographerChannelsProvider`, `photographerContactRepositoryProvider`, `FakePhotographerContactRepository` (Task 2); `BookingStatus` from `lib/data/booking/booking_status.dart`.
- Produces:
  - `ContactAccess contactAccessForBooking(BookingStatus status, {DateTime? completedAt, required DateTime now})`: `requested`, `accepted`, `upcoming` unlocked; `completed`/`reviewed` unlocked for 30 days after `completedAt` (locked when unknown); `draft`, `declined`, `expired`, `cancelled` locked. A UI hint only; the server decides.
  - `typedef ContactEventLogger = void Function(String name, Map<String, Object?> params)`.
  - `const ContactAction({super.key, required ContactAccess access, required List<ContactChannel> channels, required String source, ContactSubject? subject, ContactDialStyle style = ContactDialStyle.icon, VoidCallback? onInquiry, ContactEventLogger? onEvent})`: renders `ContactDial`, hides channels this device cannot open, on selection calls `ContactLauncher`, shows `busy` while the link is fetched, reports failures in a snackbar, logs `contact_tapped{channel, source}` and `contact_locked{source}` (never a number). `subject` is required when unlocked.
  - `const PhotographerContactAction({super.key, required String photographerId, required ContactAccess access, required String source, ContactSubject? subject, ContactDialStyle style, VoidCallback? onInquiry, ContactEventLogger? onEvent})`: takes the channels from `photographerChannelsProvider(photographerId)`; locked → the inquiry button unless the photographer turned inquiries off.
  - l10n: `contactOpenError` = "Không mở được liên hệ. Thử lại nhé.".

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/booking/contact_access_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/booking/contact_access.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1, 12);

  test('open from the deposit until the booking is over', () {
    for (final s in [BookingStatus.requested, BookingStatus.accepted, BookingStatus.upcoming]) {
      expect(contactAccessForBooking(s, now: now), ContactAccess.unlocked, reason: s.name);
    }
  });

  test('closed for drafts and for bookings that fell through', () {
    for (final s in [
      BookingStatus.draft,
      BookingStatus.declined,
      BookingStatus.expired,
      BookingStatus.cancelled,
    ]) {
      expect(contactAccessForBooking(s, now: now), ContactAccess.locked, reason: s.name);
    }
  });

  test('completed and reviewed bookings stay open for 30 days', () {
    for (final s in [BookingStatus.completed, BookingStatus.reviewed]) {
      expect(
        contactAccessForBooking(s, completedAt: now.subtract(const Duration(days: 29)), now: now),
        ContactAccess.unlocked,
      );
      expect(
        contactAccessForBooking(s, completedAt: now.subtract(const Duration(days: 30)), now: now),
        ContactAccess.unlocked,
      );
      expect(
        contactAccessForBooking(
          s,
          completedAt: now.subtract(const Duration(days: 30, seconds: 1)),
          now: now,
        ),
        ContactAccess.locked,
      );
      expect(contactAccessForBooking(s, now: now), ContactAccess.locked); // unknown date: stay closed
    }
  });

  test('time zones do not matter', () {
    final local = DateTime.parse('2026-09-30T20:00:00+07:00'); // = 13:00 UTC on the 30th, within 30 days
    expect(
      contactAccessForBooking(BookingStatus.completed, completedAt: local, now: now),
      ContactAccess.unlocked,
    );
  });
}
```

```dart
// test/features/contact/contact_action_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/features/contact/contact_action.dart';

import '../../core/widgets/widget_host.dart';

const _subject = ContactSubject.booking('b1');
const _numbers = ContactNumbers(phone: '+84903123456');
const _all = ContactChannels(call: true, zalo: true, whatsapp: true);
const _channelList = [ContactChannel.call, ContactChannel.zalo, ContactChannel.whatsapp];
const _button = Key('contact-dial-button');

class _SlowLinks implements ContactLinkRepository {
  final completer = Completer<Uri>();
  @override
  Future<Uri> link({required ContactSubject subject, required ContactChannel channel}) =>
      completer.future;
}

class _Harness {
  _Harness({bool unlocked = true, Set<String> unsupported = const {}, bool failOpen = false})
    : links = FakeContactLinkRepository()
        ..add(_subject, numbers: _numbers, channels: _all, unlocked: unlocked),
      external = FakeExternalLauncher(unsupportedSchemes: unsupported, failOpen: failOpen);
  final FakeContactLinkRepository links;
  final FakeExternalLauncher external;
  final events = <Map<String, Object?>>[];
  int inquiries = 0;

  void log(String name, Map<String, Object?> params) => events.add({'name': name, ...params});
}

Future<void> _pump(
  WidgetTester tester,
  _Harness h, {
  ContactAccess access = ContactAccess.unlocked,
  List<ContactChannel> channels = _channelList,
  ContactLinkRepository? links,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contactLinkRepositoryProvider.overrideWithValue(links ?? h.links),
        externalLauncherProvider.overrideWithValue(h.external),
      ],
      child: hostWidget(
        Padding(
          padding: const EdgeInsets.only(top: 300, left: 290),
          child: ContactAction(
            access: access,
            channels: channels,
            subject: access == ContactAccess.unlocked ? _subject : null,
            source: 'S09',
            onInquiry: () => h.inquiries++,
            onEvent: h.log,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(_button));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Zalo opens the server-built link and logs the tap without a number', (tester) async {
    final h = _Harness();
    await _pump(tester, h);
    await _pick(tester, 'contact-zalo');
    expect(h.external.opened.map((u) => u.toString()), ['https://zalo.me/84903123456']);
    expect(h.links.requests.single.channel, ContactChannel.zalo);
    expect(h.events, [
      {'name': 'contact_tapped', 'channel': 'zalo', 'source': 'S09'},
    ]);
    expect(h.events.toString(), isNot(contains('903')));
  });

  testWidgets('the dialer entry opens tel: with the plus', (tester) async {
    final h = _Harness();
    await _pump(tester, h);
    await _pick(tester, 'contact-call');
    expect(h.external.opened.single.toString(), 'tel:+84903123456');
  });

  testWidgets('one channel: the first tap goes straight through', (tester) async {
    final h = _Harness();
    await _pump(tester, h, channels: const [ContactChannel.whatsapp]);
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();
    expect(h.external.opened.single.toString(), 'https://wa.me/84903123456');
    expect(find.byKey(const Key('contact-tray')), findsNothing);
  });

  testWidgets('a locked answer from the server shows the unlock hint and logs contact_locked', (tester) async {
    final h = _Harness(unlocked: false);
    await _pump(tester, h);
    await _pick(tester, 'contact-zalo');
    expect(h.external.opened, isEmpty);
    expect(find.text('Liên hệ qua điện thoại mở sau khi bạn đặt lịch'), findsOneWidget);
    expect(h.events.map((e) => e['name']), ['contact_tapped', 'contact_locked']);
    expect(h.events.last['source'], 'S09');
  });

  testWidgets('a link the OS cannot open shows a retry message', (tester) async {
    final h = _Harness(failOpen: true);
    await _pump(tester, h);
    await _pick(tester, 'contact-zalo');
    expect(find.text('Không mở được liên hệ. Thử lại nhé.'), findsOneWidget);
  });

  testWidgets('the dialer is hidden on a device that cannot place calls', (tester) async {
    final h = _Harness(unsupported: {'tel'});
    await _pump(tester, h);
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-call')), findsNothing);
    expect(find.byKey(const Key('contact-zalo')), findsOneWidget);
    expect(find.byKey(const Key('contact-whatsapp')), findsOneWidget);
  });

  testWidgets('only the dialer on such a device leaves nothing to show', (tester) async {
    final h = _Harness(unsupported: {'tel'});
    await _pump(tester, h, channels: const [ContactChannel.call]);
    expect(find.byKey(_button), findsNothing);
  });

  testWidgets('before booking: the inquiry button opens the chat and asks the server for nothing', (tester) async {
    final h = _Harness();
    await _pump(tester, h, access: ContactAccess.locked);
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();
    expect(h.inquiries, 1);
    expect(h.links.requests, isEmpty);
    expect(h.external.opened, isEmpty);
    expect(h.events, [
      {'name': 'contact_tapped', 'channel': 'in_app', 'source': 'S09'},
    ]);
  });

  testWidgets('shows a spinner while the link is being fetched, then opens it', (tester) async {
    final h = _Harness();
    final slow = _SlowLinks();
    await _pump(tester, h, links: slow);
    await _pick(tester, 'contact-whatsapp');
    expect(
      find.descendant(of: find.byKey(_button), matching: find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
    slow.completer.complete(Uri.parse('https://wa.me/84903123456'));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(h.external.opened.single.toString(), 'https://wa.me/84903123456');
  });

  testWidgets('no phone number is ever on screen', (tester) async {
    final h = _Harness();
    await _pump(tester, h);
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();
    expect(find.textContaining('903'), findsNothing);
    expect(find.textContaining('+84'), findsNothing);
  });

  group('PhotographerContactAction', () {
    Future<void> pumpFor(
      WidgetTester tester,
      FakePhotographerContactRepository repo, {
      required ContactAccess access,
    }) async {
      final h = _Harness();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            photographerContactRepositoryProvider.overrideWithValue(repo),
            contactLinkRepositoryProvider.overrideWithValue(h.links),
            externalLauncherProvider.overrideWithValue(h.external),
          ],
          child: hostWidget(
            Padding(
              padding: const EdgeInsets.only(top: 300, left: 290),
              child: PhotographerContactAction(
                photographerId: 'p1',
                access: access,
                subject: access == ContactAccess.unlocked ? _subject : null,
                source: 'S09',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('unlocked: the tray lists exactly the channels the photographer switched on', (tester) async {
      final repo = FakePhotographerContactRepository()
        ..seed('p1', channels: const ContactChannels(call: true, whatsapp: true));
      await pumpFor(tester, repo, access: ContactAccess.unlocked);
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contact-call')), findsOneWidget);
      expect(find.byKey(const Key('contact-zalo')), findsNothing);
      expect(find.byKey(const Key('contact-whatsapp')), findsOneWidget);
    });

    testWidgets('unlocked but nothing switched on (or flags missing): no button', (tester) async {
      await pumpFor(
        tester,
        FakePhotographerContactRepository()..seed('p1', channels: const ContactChannels()),
        access: ContactAccess.unlocked,
      );
      expect(find.byKey(_button), findsNothing);
      await pumpFor(tester, FakePhotographerContactRepository(), access: ContactAccess.unlocked);
      expect(find.byKey(_button), findsNothing);
    });

    testWidgets('locked: inquiry button, unless the photographer turned inquiries off', (tester) async {
      await pumpFor(tester, FakePhotographerContactRepository(), access: ContactAccess.locked);
      expect(find.byKey(_button), findsOneWidget);
      await pumpFor(
        tester,
        FakePhotographerContactRepository()
          ..seed('p1', channels: const ContactChannels(call: true, acceptInquiries: false)),
        access: ContactAccess.locked,
      );
      expect(find.byKey(_button), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/booking/contact_access_test.dart test/features/contact/contact_action_test.dart`
Expected: FAIL to compile: `contact_access.dart` and `contact_action.dart` do not exist.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`, then run `flutter gen-l10n`:

```json
  "contactOpenError": "Không mở được liên hệ. Thử lại nhé.",
```

```dart
// lib/data/booking/contact_access.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_status.dart';

/// Client-side mirror of the server's `contact_unlocked` for bookings
/// (domain-model.md): from the deposit (`requested`) on, and for 30 days after
/// `completed`. It only decides which button to draw; `getContactLink` checks
/// again on the server. Event tickets (`paid`, until 7 days after the event)
/// get their own mapping when the registration model exists.
ContactAccess contactAccessForBooking(
  BookingStatus status, {
  DateTime? completedAt,
  required DateTime now,
}) {
  switch (status) {
    case BookingStatus.requested:
    case BookingStatus.accepted:
    case BookingStatus.upcoming:
      return ContactAccess.unlocked;
    case BookingStatus.completed:
    case BookingStatus.reviewed:
      if (completedAt == null) return ContactAccess.locked;
      final age = now.toUtc().difference(completedAt.toUtc());
      return age <= const Duration(days: 30)
          ? ContactAccess.unlocked
          : ContactAccess.locked;
    case BookingStatus.draft:
    case BookingStatus.declined:
    case BookingStatus.expired:
    case BookingStatus.cancelled:
      return ContactAccess.locked;
  }
}
```

```dart
// lib/features/contact/contact_action.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_launcher.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';

/// Hook for analytics. There is no analytics layer yet, so screens pass
/// their own; params never contain a phone number.
typedef ContactEventLogger = void Function(String name, Map<String, Object?> params);

/// S32 behaviour around [ContactDial]: hides channels the device cannot open,
/// asks [ContactLauncher] for the link and opens it, shows a spinner while
/// waiting and a message when it fails.
class ContactAction extends ConsumerStatefulWidget {
  const ContactAction({
    super.key,
    required this.access,
    required this.channels,
    required this.source,
    this.subject,
    this.style = ContactDialStyle.icon,
    this.onInquiry,
    this.onEvent,
  }) : assert(
         access == ContactAccess.locked || subject != null,
         'an unlocked dial needs the booking or registration it belongs to',
       );

  final ContactAccess access;
  final List<ContactChannel> channels;

  /// Screen code that hosts the button (`S03`, `S09`, `S16`, ...), for analytics.
  final String source;

  /// The booking or registration that unlocked contact.
  final ContactSubject? subject;
  final ContactDialStyle style;

  /// Opens the in-app inquiry chat (locked mode).
  final VoidCallback? onInquiry;
  final ContactEventLogger? onEvent;

  @override
  ConsumerState<ContactAction> createState() => _ContactActionState();
}

class _ContactActionState extends ConsumerState<ContactAction> {
  Set<ContactChannel> _blocked = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  @override
  void didUpdateWidget(ContactAction old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.channels, widget.channels)) _probe();
  }

  Future<void> _probe() async {
    final launcher = ref.read(contactLauncherProvider);
    final blocked = <ContactChannel>{};
    for (final c in widget.channels.where((c) => c.isExternal)) {
      if (!await launcher.canOpen(c)) blocked.add(c);
    }
    if (mounted) setState(() => _blocked = blocked);
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _select(ContactChannel channel) async {
    widget.onEvent?.call('contact_tapped', {
      'channel': channel.code,
      'source': widget.source,
    });
    if (channel == ContactChannel.inApp) {
      widget.onInquiry?.call();
      return;
    }
    final subject = widget.subject;
    if (subject == null) return;
    setState(() => _busy = true);
    final result = await ref
        .read(contactLauncherProvider)
        .open(channel, subject: subject);
    if (!mounted) return;
    setState(() => _busy = false);
    final l = context.l10n;
    switch (result) {
      case ContactOpenResult.opened:
        break;
      case ContactOpenResult.locked:
        widget.onEvent?.call('contact_locked', {'source': widget.source});
        _say(l.contactLockedHint);
      case ContactOpenResult.unavailable:
      case ContactOpenResult.cannotLaunch:
        _say(l.contactOpenError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContactDial(
      access: widget.access,
      channels: [
        for (final c in widget.channels)
          if (!_blocked.contains(c)) c,
      ],
      busy: _busy,
      style: widget.style,
      onSelected: _select,
    );
  }
}

/// [ContactAction] fed from a photographer's public contact flags.
class PhotographerContactAction extends ConsumerWidget {
  const PhotographerContactAction({
    super.key,
    required this.photographerId,
    required this.access,
    required this.source,
    this.subject,
    this.style = ContactDialStyle.icon,
    this.onInquiry,
    this.onEvent,
  });

  final String photographerId;
  final ContactAccess access;
  final String source;
  final ContactSubject? subject;
  final ContactDialStyle style;
  final VoidCallback? onInquiry;
  final ContactEventLogger? onEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(photographerChannelsProvider(photographerId)).value;
    final List<ContactChannel> channels;
    if (access == ContactAccess.unlocked) {
      channels = flags?.external ?? const [];
    } else {
      channels = (flags?.acceptInquiries ?? true)
          ? const [ContactChannel.inApp]
          : const [];
    }
    if (channels.isEmpty) return const SizedBox.shrink();
    return ContactAction(
      access: access,
      channels: channels,
      subject: subject,
      source: source,
      style: style,
      onInquiry: onInquiry,
      onEvent: onEvent,
    );
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/booking/contact_access_test.dart test/features/contact/contact_action_test.dart && flutter analyze`
Expected: PASS (4 + 13 tests); analyze clean. If the "first tap goes straight through" test fails because the probe has not finished, the `pumpAndSettle` in `_pump` should have covered it; otherwise add one `await tester.pump()` after the probe.

- [ ] **Step 5: Commit**

```bash
git add lib/data/booking lib/features/contact lib/l10n test/data/booking test/features/contact
git commit -m "feat(contact): S32 ContactAction wiring dial, launcher, access rule and events

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 8: S34 "Khu vực và liên hệ" (setup step 4/4), route and spec alignment

**Files:**
- Create: `lib/features/photographer_setup/contact_setup_logic.dart`, `lib/features/photographer_setup/contact_setup_controller.dart`, `lib/features/photographer_setup/contact_setup_screen.dart`, `test/features/photographer_setup/contact_setup_logic_test.dart`, `test/features/photographer_setup/contact_setup_screen_test.dart`
- Modify: `lib/app/router.dart`, `lib/l10n/app_vi.arb`, `docs/superpowers/specs/screens/photographer.md`, `docs/superpowers/specs/screens/booking.md`, `docs/superpowers/specs/components/shared-components.md`

**Interfaces:**
- Consumes: `PhoneField`, `phoneFromField`, `nationalFromE164` (plan 2a + Task 1); `StepProgress`; `ScreenCode`, `ScreenCodes.setupContact`; `GlassCard`, `AuroraBackground`, `AppButton`; `AppTab` from `lib/app/tabs.dart`; `ServiceArea`, `ContactChannels`, `ContactNumbers`, `photographerContactRepositoryProvider`, `FakePhotographerContactRepository` (Task 2); `authRepositoryProvider`, `FakeAuthRepository`.
- Produces:
  - `const radiusOptionsKm = [5, 10, 20, 30, 50, 100]`, `const defaultRadiusKm = 20`.
  - `enum ContactSetupField { city, phone, zalo, whatsapp, channels }`, `enum ContactSetupError { cityRequired, phoneRequired, phoneInvalid, zaloInvalid, whatsappInvalid, whatsappNeedsNumber, noChannel }`.
  - `class ContactSetupInput` (`city`, `radiusKm`, `phone`, `call`, `zalo`, `zaloOwn`, `whatsapp`, `whatsappOwn`, `inAppOnly`, `acceptInquiries`), `class ContactSetupResult` (`errors`, `ok`, `area?`, `channels?`, `numbers?`), `ContactSetupResult validateContactSetup(ContactSetupInput)`.
  - `setupContactControllerProvider` (`AsyncNotifierProvider.autoDispose<SetupContactController, bool>`) with `.save({area, channels, numbers})`; `ContactSetupDraft({area, channels, numbers})` and `contactSetupPrefillProvider` (`FutureProvider.autoDispose<ContactSetupDraft>`).
  - `ContactSetupScreen`, route `/setup/4` (outside the tab shell; reached from step 3 / S38 and the profile once plan 2d and 2c wire it).
  - Widget keys: `setup-city`, `radius-<km>`, `setup-phone`, `channel-call`, `channel-zalo`, `zalo-own`, `channel-whatsapp`, `whatsapp-own`, `channel-inapp`, `setup-back`, `setup-finish`.
  - l10n keys listed in Step 3.

Validation rules (spec S34, restated): a valid main number is required; at least one channel on **or** "Chỉ nhận tin nhắn trong app"; Zalo's own number must be a valid Vietnamese number; WhatsApp's own number must be valid international; WhatsApp on and empty means "use the main number" (always valid international when the main number is valid), and is an error under the field only when the main number is missing too.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/photographer_setup/contact_setup_logic_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/features/photographer_setup/contact_setup_logic.dart';

ContactSetupInput _in({
  String city = 'Hà Nội',
  int radiusKm = 20,
  String phone = '903 123 456',
  bool call = false,
  bool zalo = false,
  String zaloOwn = '',
  bool whatsapp = false,
  String whatsappOwn = '',
  bool inAppOnly = false,
  bool acceptInquiries = true,
}) => ContactSetupInput(
  city: city,
  radiusKm: radiusKm,
  phone: phone,
  call: call,
  zalo: zalo,
  zaloOwn: zaloOwn,
  whatsapp: whatsapp,
  whatsappOwn: whatsappOwn,
  inAppOnly: inAppOnly,
  acceptInquiries: acceptInquiries,
);

void main() {
  test('an empty form needs city, number and a channel decision', () {
    final r = validateContactSetup(const ContactSetupInput());
    expect(r.ok, isFalse);
    expect(r.errors, {
      ContactSetupField.city: ContactSetupError.cityRequired,
      ContactSetupField.phone: ContactSetupError.phoneRequired,
      ContactSetupField.channels: ContactSetupError.noChannel,
    });
  });

  test('minimum valid form: number plus one channel', () {
    final r = validateContactSetup(_in(zalo: true));
    expect(r.ok, isTrue);
    expect(r.area, const ServiceArea(city: 'Hà Nội', radiusKm: 20));
    expect(r.channels, const ContactChannels(zalo: true));
    expect(r.numbers, const ContactNumbers(phone: '+84903123456'));
  });

  test('city is trimmed and needs two characters', () {
    expect(validateContactSetup(_in(city: '  Đà Nẵng  ', call: true)).area!.city, 'Đà Nẵng');
    expect(
      validateContactSetup(_in(city: ' Đ ', call: true)).errors[ContactSetupField.city],
      ContactSetupError.cityRequired,
    );
  });

  test('main number: empty and malformed are different errors', () {
    expect(
      validateContactSetup(_in(phone: '', call: true)).errors[ContactSetupField.phone],
      ContactSetupError.phoneRequired,
    );
    expect(
      validateContactSetup(_in(phone: '90312345', call: true)).errors[ContactSetupField.phone],
      ContactSetupError.phoneInvalid,
    );
  });

  group('Zalo', () {
    test('empty own number means the main number', () {
      final r = validateContactSetup(_in(zalo: true));
      expect(r.numbers!.zaloPhone, isNull);
    });
    test('a different own number is kept, the same one is dropped', () {
      expect(
        validateContactSetup(_in(zalo: true, zaloOwn: '0912345678')).numbers!.zaloPhone,
        '+84912345678',
      );
      expect(
        validateContactSetup(_in(zalo: true, zaloOwn: '0903 123 456')).numbers!.zaloPhone,
        isNull,
      );
    });
    test('an invalid own number is an error under the Zalo field', () {
      final r = validateContactSetup(_in(zalo: true, zaloOwn: '12345'));
      expect(r.errors, {ContactSetupField.zalo: ContactSetupError.zaloInvalid});
    });
    test('text left in a switched-off Zalo field is ignored', () {
      final r = validateContactSetup(_in(call: true, zalo: false, zaloOwn: 'garbage'));
      expect(r.ok, isTrue);
      expect(r.numbers!.zaloPhone, isNull);
    });
  });

  group('WhatsApp', () {
    test('on and empty: use the main number, which is valid international', () {
      final r = validateContactSetup(_in(whatsapp: true));
      expect(r.ok, isTrue);
      expect(r.channels!.whatsapp, isTrue);
      expect(r.numbers!.whatsappPhone, isNull);
    });
    test('on, empty, and no usable main number: error under the WhatsApp field too', () {
      final r = validateContactSetup(_in(phone: '', whatsapp: true));
      expect(r.errors[ContactSetupField.whatsapp], ContactSetupError.whatsappNeedsNumber);
      expect(r.errors[ContactSetupField.phone], ContactSetupError.phoneRequired);
    });
    test('an international own number is kept', () {
      expect(
        validateContactSetup(_in(whatsapp: true, whatsappOwn: '+1 415 555 2671')).numbers!.whatsappPhone,
        '+14155552671',
      );
    });
    test('a number without a country code is refused', () {
      final r = validateContactSetup(_in(whatsapp: true, whatsappOwn: '4155552671'));
      expect(r.errors, {ContactSetupField.whatsapp: ContactSetupError.whatsappInvalid});
    });
    test('a Vietnamese 0… number is read as +84…; the same as main is dropped', () {
      expect(
        validateContactSetup(_in(whatsapp: true, whatsappOwn: '0912345678')).numbers!.whatsappPhone,
        '+84912345678',
      );
      expect(
        validateContactSetup(_in(whatsapp: true, whatsappOwn: '+84903123456')).numbers!.whatsappPhone,
        isNull,
      );
    });
  });

  group('in-app only', () {
    test('counts as a decision, switches the outside channels off', () {
      final r = validateContactSetup(_in(inAppOnly: true, call: true, zalo: true, whatsapp: true));
      expect(r.ok, isTrue);
      expect(r.channels, const ContactChannels());
      expect(r.numbers, const ContactNumbers(phone: '+84903123456'));
    });
    test('still needs a valid number', () {
      final r = validateContactSetup(_in(inAppOnly: true, phone: ''));
      expect(r.errors, {ContactSetupField.phone: ContactSetupError.phoneRequired});
    });
    test('without it and without a channel there is an error on the channels', () {
      expect(
        validateContactSetup(_in()).errors,
        {ContactSetupField.channels: ContactSetupError.noChannel},
      );
    });
  });

  test('acceptInquiries is carried through', () {
    expect(validateContactSetup(_in(call: true, acceptInquiries: false)).channels!.acceptInquiries, isFalse);
  });
}
```

```dart
// test/features/photographer_setup/contact_setup_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/features/photographer_setup/contact_setup_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class _H {
  _H(this.auth, this.repo, this.widget);
  final FakeAuthRepository auth;
  final FakePhotographerContactRepository repo;
  final Widget widget;
  String get uid => auth.currentUser!.uid;
}

Future<_H> _harness({bool failSave = false}) async {
  final auth = FakeAuthRepository();
  await auth.registerWithEmail('p@b.vn', 'password1', 'Thư');
  final repo = FakePhotographerContactRepository(failSave: failSave);
  final router = GoRouter(
    initialLocation: '/setup/4',
    routes: [
      GoRoute(path: '/setup/4', builder: (_, _) => const ContactSetupScreen()),
      GoRoute(path: '/bookings', builder: (_, _) => const Text('work')),
      GoRoute(path: '/profile', builder: (_, _) => const Text('profile')),
    ],
  );
  return _H(
    auth,
    repo,
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        photographerContactRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
}

Future<_H> _open(WidgetTester tester, {bool failSave = false}) async {
  tester.view.physicalSize = const Size(390, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await _harness(failSave: failSave);
  await tester.pumpWidget(h.widget);
  await tester.pumpAndSettle();
  return h;
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

bool _switchOn(WidgetTester tester, String key) =>
    tester.widget<SwitchListTile>(find.byKey(Key(key))).value;

void main() {
  testWidgets('step 4 of 4, with the title in the app bar', (tester) async {
    await _open(tester);
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('Khu vực và liên hệ'), findsOneWidget);
    expect(find.text('Chọn kênh khách được dùng để liên hệ bạn.'), findsOneWidget);
  });

  testWidgets('"Hoàn tất" on an empty form shows the three problems and saves nothing', (tester) async {
    final h = await _open(tester);
    await _tap(tester, 'setup-finish');
    expect(find.text('Nhập thành phố bạn nhận việc'), findsOneWidget);
    expect(find.text('Nhập số điện thoại'), findsOneWidget);
    expect(
      find.text('Bật ít nhất một kênh, hoặc chọn "Chỉ nhận tin nhắn trong app".'),
      findsOneWidget,
    );
    expect(h.repo.completed, isEmpty);
    expect(find.text('work'), findsNothing);
  });

  testWidgets('errors clear as the fields are fixed', (tester) async {
    await _open(tester);
    await _tap(tester, 'setup-finish');
    await _type(tester, 'setup-city', 'Hà Nội');
    expect(find.text('Nhập thành phố bạn nhận việc'), findsNothing);
    await _tap(tester, 'channel-call');
    expect(
      find.text('Bật ít nhất một kênh, hoặc chọn "Chỉ nhận tin nhắn trong app".'),
      findsNothing,
    );
  });

  testWidgets('a complete form is saved in one go and the photographer lands on Công việc', (tester) async {
    final h = await _open(tester);
    await _type(tester, 'setup-city', 'Hà Nội');
    await _tap(tester, 'radius-30');
    await _type(tester, 'setup-phone', '0903123456');
    await _tap(tester, 'channel-zalo');
    await _tap(tester, 'setup-finish');
    expect(h.repo.areaOf(h.uid), const ServiceArea(city: 'Hà Nội', radiusKm: 30));
    expect(h.repo.channelsOf(h.uid), const ContactChannels(zalo: true));
    expect(h.repo.numbersOf(h.uid), const ContactNumbers(phone: '+84903123456'));
    expect(h.repo.completed, {h.uid});
    expect(find.text('work'), findsOneWidget);
  });

  testWidgets('own Zalo and WhatsApp numbers are saved when given', (tester) async {
    final h = await _open(tester);
    await _type(tester, 'setup-city', 'Đà Nẵng');
    await _type(tester, 'setup-phone', '0903123456');
    await _tap(tester, 'channel-zalo');
    await _tap(tester, 'channel-whatsapp');
    await _type(tester, 'zalo-own', '0912345678');
    await _type(tester, 'whatsapp-own', '+1 415 555 2671');
    await _tap(tester, 'setup-finish');
    expect(
      h.repo.numbersOf(h.uid),
      const ContactNumbers(
        phone: '+84903123456',
        zaloPhone: '+84912345678',
        whatsappPhone: '+14155552671',
      ),
    );
    expect(h.repo.channelsOf(h.uid), const ContactChannels(zalo: true, whatsapp: true));
  });

  testWidgets('WhatsApp on and left empty uses the main number', (tester) async {
    final h = await _open(tester);
    await _type(tester, 'setup-city', 'Hà Nội');
    await _type(tester, 'setup-phone', '0903123456');
    await _tap(tester, 'channel-whatsapp');
    await _tap(tester, 'setup-finish');
    expect(h.repo.channelsOf(h.uid)!.whatsapp, isTrue);
    expect(h.repo.numbersOf(h.uid)!.whatsappPhone, isNull);
  });

  testWidgets('a WhatsApp number without a country code is refused under its field', (tester) async {
    final h = await _open(tester);
    await _type(tester, 'setup-city', 'Hà Nội');
    await _type(tester, 'setup-phone', '0903123456');
    await _tap(tester, 'channel-whatsapp');
    await _type(tester, 'whatsapp-own', '4155552671');
    await _tap(tester, 'setup-finish');
    expect(find.text('Nhập số có mã quốc gia, ví dụ: +1 415 555 2671'), findsOneWidget);
    expect(h.repo.completed, isEmpty);
  });

  testWidgets('"Chỉ nhận tin nhắn trong app" is a valid choice and switches the other three off', (tester) async {
    final h = await _open(tester);
    await _type(tester, 'setup-city', 'Hà Nội');
    await _type(tester, 'setup-phone', '0903123456');
    await _tap(tester, 'channel-call');
    await _tap(tester, 'channel-inapp');
    expect(_switchOn(tester, 'channel-inapp'), isTrue);
    expect(_switchOn(tester, 'channel-call'), isFalse);
    await _tap(tester, 'setup-finish');
    expect(h.repo.channelsOf(h.uid), const ContactChannels());
    expect(h.repo.numbersOf(h.uid), const ContactNumbers(phone: '+84903123456'));
    expect(h.repo.completed, {h.uid});
  });

  testWidgets('switching an outside channel on turns "only in-app" off', (tester) async {
    await _open(tester);
    await _tap(tester, 'channel-inapp');
    await _tap(tester, 'channel-zalo');
    expect(_switchOn(tester, 'channel-zalo'), isTrue);
    expect(_switchOn(tester, 'channel-inapp'), isFalse);
  });

  testWidgets('an earlier setup is shown again for editing', (tester) async {
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await _harness();
    h.repo.seed(
      h.uid,
      area: const ServiceArea(city: 'Huế', radiusKm: 50),
      channels: const ContactChannels(zalo: true),
      numbers: const ContactNumbers(phone: '+84903123456', zaloPhone: '+84912345678'),
    );
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    expect(find.text('Huế'), findsOneWidget);
    expect(find.text('903 123 456'), findsOneWidget);
    expect(find.text('912 345 678'), findsOneWidget);
    expect(_switchOn(tester, 'channel-zalo'), isTrue);
    expect(_switchOn(tester, 'channel-call'), isFalse);
    expect(tester.widget<ChoiceChip>(find.byKey(const Key('radius-50'))).selected, isTrue);
  });

  testWidgets('a failed save shows a message and keeps the form', (tester) async {
    final h = await _open(tester, failSave: true);
    await _type(tester, 'setup-city', 'Hà Nội');
    await _type(tester, 'setup-phone', '0903123456');
    await _tap(tester, 'channel-call');
    await _tap(tester, 'setup-finish');
    expect(find.text('Không lưu được thiết lập. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
    expect(h.repo.completed, isEmpty);
    expect(find.text('work'), findsNothing);
  });

  testWidgets('"Quay lại" leaves for the profile when there is nothing to pop', (tester) async {
    await _open(tester);
    await _tap(tester, 'setup-back');
    expect(find.text('profile'), findsOneWidget);
  });

  testWidgets('fits 320dp at 1.3x with every channel open', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await _harness();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
        child: h.widget,
      ),
    );
    await tester.pumpAndSettle();
    for (final k in ['channel-call', 'channel-zalo', 'channel-whatsapp']) {
      await tester.ensureVisible(find.byKey(Key(k)));
      await tester.tap(find.byKey(Key(k)));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/photographer_setup`
Expected: FAIL, the `photographer_setup/` files do not exist.

- [ ] **Step 3: Implement**

Strings to add to `lib/l10n/app_vi.arb` (then `flutter gen-l10n`):

```json
  "setupContactTitle": "Khu vực và liên hệ",
  "setupContactArea": "Khu vực phục vụ",
  "setupContactCity": "Thành phố",
  "setupContactRadius": "Bán kính phục vụ",
  "setupRadiusValue": "{km} km",
  "@setupRadiusValue": {
    "placeholders": {
      "km": {"type": "int"}
    }
  },
  "setupContactPhone": "Số điện thoại · bắt buộc",
  "setupContactChannels": "Chọn kênh khách được dùng để liên hệ bạn.",
  "setupChannelCall": "Gọi điện",
  "setupChannelCallHint": "Dùng số điện thoại ở trên",
  "setupChannelZalo": "Zalo",
  "setupChannelZaloHint": "Dùng số ở trên hoặc nhập số riêng",
  "setupZaloOwn": "Số Zalo riêng (để trống nếu dùng số trên)",
  "setupChannelWhatsApp": "WhatsApp",
  "setupChannelWhatsAppHint": "Nhập số quốc tế riêng, hoặc dùng số ở trên",
  "setupWhatsAppOwn": "Số WhatsApp có mã quốc gia (để trống nếu dùng số trên)",
  "setupInAppOnly": "Chỉ nhận tin nhắn trong app",
  "setupInAppOnlyHint": "Khách chỉ nhắn được trong ứng dụng. Bạn có thể bật gọi, Zalo hay WhatsApp sau.",
  "setupContactPrivacy": "Số của bạn không hiện công khai. Khách chỉ dùng được các kênh này sau khi đã đặt lịch.",
  "setupContactBack": "Quay lại",
  "setupContactFinish": "Hoàn tất",
  "setupCityRequired": "Nhập thành phố bạn nhận việc",
  "setupNoChannel": "Bật ít nhất một kênh, hoặc chọn \"Chỉ nhận tin nhắn trong app\".",
  "setupWhatsAppNeedsNumber": "Nhập số WhatsApp có mã quốc gia, ví dụ +1 415 555 2671",
  "setupSaveError": "Không lưu được thiết lập. Kiểm tra mạng rồi thử lại.",
```

```dart
// lib/features/photographer_setup/contact_setup_logic.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';

const radiusOptionsKm = [5, 10, 20, 30, 50, 100];
const defaultRadiusKm = 20;

enum ContactSetupField { city, phone, zalo, whatsapp, channels }

enum ContactSetupError {
  cityRequired,
  phoneRequired,
  phoneInvalid,
  zaloInvalid,
  whatsappInvalid,
  whatsappNeedsNumber,
  noChannel,
}

/// The raw state of the S34 form.
class ContactSetupInput {
  const ContactSetupInput({
    this.city = '',
    this.radiusKm = defaultRadiusKm,
    this.phone = '',
    this.call = false,
    this.zalo = false,
    this.zaloOwn = '',
    this.whatsapp = false,
    this.whatsappOwn = '',
    this.inAppOnly = false,
    this.acceptInquiries = true,
  });

  final String city;
  final int radiusKm;

  /// Text of the main `PhoneField` (national form).
  final String phone;
  final bool call;
  final bool zalo;

  /// Text of the optional own-Zalo `PhoneField` (national form).
  final String zaloOwn;
  final bool whatsapp;

  /// Text of the optional own-WhatsApp `PhoneField` (international form).
  final String whatsappOwn;

  /// "Chỉ nhận tin nhắn trong app": no outside channel, on purpose.
  final bool inAppOnly;

  /// Kept from the existing profile; S34 does not change it.
  final bool acceptInquiries;
}

class ContactSetupResult {
  const ContactSetupResult.invalid(this.errors)
    : area = null,
      channels = null,
      numbers = null;

  const ContactSetupResult.valid({
    required ServiceArea this.area,
    required ContactChannels this.channels,
    required ContactNumbers this.numbers,
  }) : errors = const {};

  final Map<ContactSetupField, ContactSetupError> errors;
  final ServiceArea? area;
  final ContactChannels? channels;
  final ContactNumbers? numbers;

  bool get ok => errors.isEmpty;
}

/// Validates S34 and builds what gets saved. Pure, so every rule is tested
/// without a widget.
ContactSetupResult validateContactSetup(ContactSetupInput i) {
  final errors = <ContactSetupField, ContactSetupError>{};

  final city = i.city.trim();
  if (city.length < 2) errors[ContactSetupField.city] = ContactSetupError.cityRequired;

  final phoneText = i.phone.trim();
  final phone = phoneFromField(phoneText);
  if (phoneText.isEmpty) {
    errors[ContactSetupField.phone] = ContactSetupError.phoneRequired;
  } else if (phone == null) {
    errors[ContactSetupField.phone] = ContactSetupError.phoneInvalid;
  }

  // "Only in-app" wins over any outside toggle left on.
  final call = !i.inAppOnly && i.call;
  final zalo = !i.inAppOnly && i.zalo;
  final whatsapp = !i.inAppOnly && i.whatsapp;

  String? zaloPhone;
  if (zalo) {
    final t = i.zaloOwn.trim();
    if (t.isNotEmpty) {
      final own = phoneFromField(t);
      if (own == null) {
        errors[ContactSetupField.zalo] = ContactSetupError.zaloInvalid;
      } else if (own != phone) {
        zaloPhone = own;
      }
    }
  }

  String? whatsappPhone;
  if (whatsapp) {
    final t = i.whatsappOwn.trim();
    if (t.isEmpty) {
      // Falls back to the main number. A valid Vietnamese number is always a
      // valid international one (+84…), so only a missing main number is a problem.
      if (phone == null) {
        errors[ContactSetupField.whatsapp] = ContactSetupError.whatsappNeedsNumber;
      }
    } else {
      final own = phoneFromField(t, international: true);
      if (own == null) {
        errors[ContactSetupField.whatsapp] = ContactSetupError.whatsappInvalid;
      } else if (own != phone) {
        whatsappPhone = own;
      }
    }
  }

  if (!i.inAppOnly && !call && !zalo && !whatsapp) {
    errors[ContactSetupField.channels] = ContactSetupError.noChannel;
  }

  if (errors.isNotEmpty || phone == null) return ContactSetupResult.invalid(errors);
  return ContactSetupResult.valid(
    area: ServiceArea(city: city, radiusKm: i.radiusKm),
    channels: ContactChannels(
      call: call,
      zalo: zalo,
      whatsapp: whatsapp,
      acceptInquiries: i.acceptInquiries,
    ),
    numbers: ContactNumbers(
      phone: phone,
      zaloPhone: zaloPhone,
      whatsappPhone: whatsappPhone,
    ),
  );
}
```

```dart
// lib/features/photographer_setup/contact_setup_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';

/// Saves S34. Its value turns true once the save went through.
class SetupContactController extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> save({
    required ServiceArea area,
    required ContactChannels channels,
    required ContactNumbers numbers,
  }) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(photographerContactRepositoryProvider)
          .completeContactSetup(uid, area: area, channels: channels, numbers: numbers);
      return true;
    });
  }
}

final setupContactControllerProvider =
    AsyncNotifierProvider.autoDispose<SetupContactController, bool>(
      SetupContactController.new,
    );

/// What the photographer saved before, to prefill the form when editing.
class ContactSetupDraft {
  const ContactSetupDraft({this.area, this.channels, this.numbers});
  final ServiceArea? area;
  final ContactChannels? channels;
  final ContactNumbers? numbers;
}

final contactSetupPrefillProvider =
    FutureProvider.autoDispose<ContactSetupDraft>((ref) async {
      final uid = ref.read(authRepositoryProvider).currentUser?.uid;
      if (uid == null) return const ContactSetupDraft();
      final repo = ref.read(photographerContactRepositoryProvider);
      return ContactSetupDraft(
        area: await repo.watchServiceArea(uid).first,
        channels: await repo.watchChannels(uid).first,
        numbers: await repo.watchNumbers(uid).first,
      );
    });
```

```dart
// lib/features/photographer_setup/contact_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/photographer_setup/contact_setup_controller.dart';
import 'package:photobooking/features/photographer_setup/contact_setup_logic.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S34: setup step 4/4. Service area, main number, and which outside
/// channels customers may use after they have booked.
class ContactSetupScreen extends ConsumerWidget {
  const ContactSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final prefill = ref.watch(contactSetupPrefillProvider);
    return ScreenCode(
      ScreenCodes.setupContact,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.setupContactTitle)),
          body: SafeArea(
            top: false,
            child: prefill.when(
              data: (draft) => _ContactSetupForm(draft: draft),
              loading: () => const Center(child: CircularProgressIndicator()),
              // A failed prefill must not block a first-time setup.
              error: (_, _) => const _ContactSetupForm(draft: ContactSetupDraft()),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactSetupForm extends ConsumerStatefulWidget {
  const _ContactSetupForm({required this.draft});
  final ContactSetupDraft draft;

  @override
  ConsumerState<_ContactSetupForm> createState() => _ContactSetupFormState();
}

class _ContactSetupFormState extends ConsumerState<_ContactSetupForm> {
  late final _city = TextEditingController(text: widget.draft.area?.city ?? '');
  late final _phone = TextEditingController(
    text: widget.draft.numbers == null ? '' : nationalFromE164(widget.draft.numbers!.phone),
  );
  late final _zaloOwn = TextEditingController(
    text: widget.draft.numbers?.zaloPhone == null
        ? ''
        : nationalFromE164(widget.draft.numbers!.zaloPhone!),
  );
  late final _whatsappOwn = TextEditingController(
    text: widget.draft.numbers?.whatsappPhone ?? '',
  );
  late int _radius = radiusOptionsKm.contains(widget.draft.area?.radiusKm)
      ? widget.draft.area!.radiusKm
      : defaultRadiusKm;
  late bool _call = widget.draft.channels?.call ?? false;
  late bool _zalo = widget.draft.channels?.zalo ?? false;
  late bool _whatsapp = widget.draft.channels?.whatsapp ?? false;
  // A saved profile with a number but no outside channel means "only in-app".
  late bool _inAppOnly =
      widget.draft.numbers != null && !(widget.draft.channels?.hasExternal ?? false);
  bool _submitted = false;

  @override
  void dispose() {
    _city.dispose();
    _phone.dispose();
    _zaloOwn.dispose();
    _whatsappOwn.dispose();
    super.dispose();
  }

  ContactSetupInput get _input => ContactSetupInput(
    city: _city.text,
    radiusKm: _radius,
    phone: _phone.text,
    call: _call,
    zalo: _zalo,
    zaloOwn: _zaloOwn.text,
    whatsapp: _whatsapp,
    whatsappOwn: _whatsappOwn.text,
    inAppOnly: _inAppOnly,
    acceptInquiries: widget.draft.channels?.acceptInquiries ?? true,
  );

  String? _errorText(AppLocalizations l, ContactSetupError? e) => switch (e) {
    null => null,
    ContactSetupError.cityRequired => l.setupCityRequired,
    ContactSetupError.phoneRequired => l.phoneRequired,
    ContactSetupError.phoneInvalid => l.phoneInvalid,
    ContactSetupError.zaloInvalid => l.phoneInvalid,
    ContactSetupError.whatsappInvalid => l.phoneInvalidInternational,
    ContactSetupError.whatsappNeedsNumber => l.setupWhatsAppNeedsNumber,
    ContactSetupError.noChannel => l.setupNoChannel,
  };

  void _finish() {
    final r = validateContactSetup(_input);
    final area = r.area;
    final channels = r.channels;
    final numbers = r.numbers;
    if (!r.ok || area == null || channels == null || numbers == null) {
      setState(() => _submitted = true);
      return;
    }
    ref
        .read(setupContactControllerProvider.notifier)
        .save(area: area, channels: channels, numbers: numbers);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppTab.profile.path);
    }
  }

  Widget _channel({
    required Key key,
    required IconData icon,
    required String title,
    required String hint,
    required bool value,
    required ValueChanged<bool>? onChanged,
    Widget? extra,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          SwitchListTile(
            key: key,
            secondary: Icon(icon),
            title: Text(title),
            subtitle: Text(hint),
            value: value,
            onChanged: onChanged,
          ),
          if (value && extra != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.s4, 0, AppSpace.s4, AppSpace.s4),
              child: extra,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final saving = ref.watch(setupContactControllerProvider).isLoading;
    ref.listen(setupContactControllerProvider, (prev, next) {
      if (next.isLoading || !(prev?.isLoading ?? false)) return;
      if (next.hasError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.setupSaveError)));
      } else if (next.value ?? false) {
        context.go(AppTab.bookings.path);
      }
    });

    final errors = _submitted
        ? validateContactSetup(_input).errors
        : const <ContactSetupField, ContactSetupError>{};
    String? err(ContactSetupField f) => _errorText(l, errors[f]);
    final channelsError = err(ContactSetupField.channels);
    void changed() => setState(() {});

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.s5),
      child: GlassCard(
        highlight: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepProgress(current: 4, total: 4),
              const SizedBox(height: AppSpace.s5),
              Text(l.setupContactArea, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpace.s2),
              TextFormField(
                key: const Key('setup-city'),
                controller: _city,
                enabled: !saving,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.addressCity],
                onChanged: (_) => changed(),
                decoration: InputDecoration(
                  labelText: l.setupContactCity,
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  errorText: err(ContactSetupField.city),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              Text(l.setupContactRadius, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpace.s2),
              Wrap(
                spacing: AppSpace.s2,
                runSpacing: AppSpace.s2,
                children: [
                  for (final km in radiusOptionsKm)
                    ChoiceChip(
                      key: Key('radius-$km'),
                      label: Text(l.setupRadiusValue(km)),
                      selected: _radius == km,
                      onSelected: saving ? null : (_) => setState(() => _radius = km),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.s5),
              PhoneField(
                key: const Key('setup-phone'),
                controller: _phone,
                label: l.setupContactPhone,
                enabled: !saving,
                errorText: err(ContactSetupField.phone),
                onChanged: (_) => changed(),
              ),
              const SizedBox(height: AppSpace.s5),
              Text(l.setupContactChannels, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpace.s3),
              _channel(
                key: const Key('channel-call'),
                icon: Icons.call_outlined,
                title: l.setupChannelCall,
                hint: l.setupChannelCallHint,
                value: _call,
                onChanged: saving
                    ? null
                    : (v) => setState(() {
                        _call = v;
                        if (v) _inAppOnly = false;
                      }),
              ),
              const SizedBox(height: AppSpace.s3),
              _channel(
                key: const Key('channel-zalo'),
                icon: Icons.chat_outlined,
                title: l.setupChannelZalo,
                hint: l.setupChannelZaloHint,
                value: _zalo,
                onChanged: saving
                    ? null
                    : (v) => setState(() {
                        _zalo = v;
                        if (v) _inAppOnly = false;
                      }),
                extra: PhoneField(
                  key: const Key('zalo-own'),
                  controller: _zaloOwn,
                  label: l.setupZaloOwn,
                  enabled: !saving,
                  errorText: err(ContactSetupField.zalo),
                  validator: (_) => null,
                  onChanged: (_) => changed(),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              _channel(
                key: const Key('channel-whatsapp'),
                icon: Icons.forum_outlined,
                title: l.setupChannelWhatsApp,
                hint: l.setupChannelWhatsAppHint,
                value: _whatsapp,
                onChanged: saving
                    ? null
                    : (v) => setState(() {
                        _whatsapp = v;
                        if (v) _inAppOnly = false;
                      }),
                extra: PhoneField(
                  key: const Key('whatsapp-own'),
                  controller: _whatsappOwn,
                  label: l.setupWhatsAppOwn,
                  international: true,
                  enabled: !saving,
                  errorText: err(ContactSetupField.whatsapp),
                  validator: (_) => null,
                  onChanged: (_) => changed(),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              _channel(
                key: const Key('channel-inapp'),
                icon: Icons.mark_chat_unread_outlined,
                title: l.setupInAppOnly,
                hint: l.setupInAppOnlyHint,
                value: _inAppOnly,
                onChanged: saving
                    ? null
                    : (v) => setState(() {
                        _inAppOnly = v;
                        if (v) _call = _zalo = _whatsapp = false;
                      }),
              ),
              if (channelsError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s2),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      channelsError,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.s4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 16),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Text(l.setupContactPrivacy, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s5),
              Row(
                children: [
                  Expanded(
                    child: AppButton.outline(
                      l.setupContactBack,
                      key: const Key('setup-back'),
                      onPressed: saving ? null : _back,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: AppButton.primary(
                      l.setupContactFinish,
                      key: const Key('setup-finish'),
                      loading: saving,
                      onPressed: _finish,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Route: in `lib/app/router.dart` add `import 'package:photobooking/features/photographer_setup/contact_setup_screen.dart';` (alphabetical among the feature imports) and, in the top-level `routes` list just before `StatefulShellRoute.indexedStack(`:

```dart
      GoRoute(path: '/setup/4', builder: (_, _) => const ContactSetupScreen()),
```

Align the specs (exact edits):

1. `docs/superpowers/specs/screens/photographer.md`, S34 **Dữ liệu**: replace
   `- **Dữ liệu**: ghi \`photographers/{uid}.serviceArea\` và \`.contact\`, đặt \`onboardingComplete = true\`.`
   with
   `- **Dữ liệu**: một batch ghi \`photographers/{uid}.serviceArea\` (\`city\`, \`radiusKm\`) và \`.contactChannels\` (cờ công khai \`call/zalo/whatsapp/acceptInquiries\`, không có số), \`photographers/{uid}/private/contact\` (số, chỉ chủ đọc), và đặt \`onboardingComplete = true\`. Kênh chỉ bật được khi đã có số (rules kiểm bằng \`existsAfter\`).`
   In S34 **Trạng thái**, append: `Công tắc "Chỉ nhận tin nhắn trong app" thay cho việc bật kênh ngoài: bật nó thì ba công tắc kia tắt, bật một kênh ngoài thì nó tắt. Lỗi hiện sau lần bấm "Hoàn tất" đầu tiên rồi cập nhật theo từng thay đổi.` In **Chuỗi**, append: `Khoá arb: \`setupContact*\`, \`setupChannel*\`, \`setupInAppOnly*\` (camelCase, \`lib/l10n/app_vi.arb\`).`
2. `docs/superpowers/specs/components/shared-components.md`, ContactDial: in the signature replace `ContactDialStyle style = icon, String? source})` with `ContactDialStyle style = icon, bool busy = false})` and add the line `- \`busy\`: đang lấy liên kết thì nút hiện vòng chờ và bỏ qua chạm. Sự kiện \`contact_tapped{channel, source}\` do \`ContactAction\` (lớp màn) ghi; widget không biết \`source\`. Khi mở khoá, \`inApp\` trong \`channels\` bị bỏ qua và không có kênh ngoài thì không vẽ gì.` ContactLauncher: replace `\`ContactLauncher.open(ContactChannel, {required String bookingOrRegistrationId})\`` with `\`ContactLauncher.open(ContactChannel, {required ContactSubject subject})\` (trả \`ContactOpenResult\`: \`opened | locked | unavailable | cannotLaunch\`)` and add `Chỉ mở URL đúng dạng \`tel:+…\`, \`https://zalo.me/<số>\`, \`https://wa.me/<số>\` (không query, cổng, user info); URL khác bị từ chối.`
3. `docs/superpowers/specs/screens/booking.md`, S32 **Trạng thái**: replace `đang lấy liên kết → viên được chọn hiện vòng chờ` with `đang lấy liên kết → nút Liên hệ hiện vòng chờ (khay đã đóng)`; in **Chuỗi** append `, \`s32_inquiry\` "Nhắn tin hỏi trước", \`s32_openError\` "Không mở được liên hệ. Thử lại nhé."`.

Then read the three diffs once (`git diff --stat docs/`).

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/features/photographer_setup && flutter test && flutter analyze`
Expected: S34 logic 17 tests and screen 13 tests PASS; the whole suite passes (including `test/app` and `responsive_test.dart`); analyze clean. If a `SwitchListTile` tap is swallowed by an overlapping `ListTile` in the 320dp test, scroll with `ensureVisible` as written; do not weaken the assertion.

- [ ] **Step 5: Commit**

```bash
git add lib test docs/superpowers/specs
git commit -m "feat(setup): S34 service area and contact channels, route /setup/4

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Battery and performance check

**Files:**
- Create: `test/support/idle.dart` if missing
- Modify: `test/core/widgets/contact_dial_test.dart`, `test/features/photographer_setup/contact_setup_screen_test.dart`

**Interfaces:**
- Consumes: `expectIdle`; in `contact_dial_test.dart` the helpers `_pump`, `_open`, `_button`, `_tray` (Task 6); in `contact_setup_screen_test.dart` the helper `_open` (Task 8).

- [ ] **Step 1: Write the tests**

If `test/support/idle.dart` is missing, create it:

```dart
// test/support/idle.dart
import 'package:flutter_test/flutter_test.dart';

/// Fails when something keeps scheduling frames at rest (a running
/// animation, ticker or repeating timer drains battery).
Future<void> expectIdle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));
  expect(tester.binding.transientCallbackCount, 0,
      reason: 'an animation or ticker keeps running at rest');
  expect(tester.binding.hasScheduledFrame, isFalse,
      reason: 'a frame is scheduled while nothing changes');
}
```

Append to `main()` in `test/core/widgets/contact_dial_test.dart` (add `import '../../support/idle.dart';`):

```dart
  testWidgets('the dial costs no frames closed, open, or after closing', (tester) async {
    await _pump(tester);
    await expectIdle(tester);
    await _open(tester);
    expect(find.byKey(_tray), findsOneWidget);
    await expectIdle(tester);
    await tester.tap(find.byKey(_button));
    await expectIdle(tester);
    expect(find.byKey(_tray), findsNothing);
  });

  testWidgets('locked and reduced-motion dials are idle too', (tester) async {
    await _pump(tester, access: ContactAccess.locked);
    await expectIdle(tester);
    await _pump(tester, reduced: true);
    await tester.tap(find.byKey(_button));
    await tester.pump();
    // Reduced motion: the tray is there after one frame and nothing runs on.
    expect(find.byKey(_tray), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('the closed dial adds no blur and no overlay entry', (tester) async {
    await _pump(tester);
    expect(find.byKey(_tray), findsNothing);
    expect(
      find.descendant(of: find.byType(ContactDial), matching: find.byType(BackdropFilter)),
      findsNothing,
    );
  });
```

Append to `main()` in `test/features/photographer_setup/contact_setup_screen_test.dart` (add `import '../../support/idle.dart';`):

```dart
  testWidgets('S34 is idle at rest and keeps blur passes within budget', (tester) async {
    await _open(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await expectIdle(tester);
    expect(find.byType(BackdropFilter).evaluate().length, lessThanOrEqualTo(4));
  });
```

- [ ] **Step 2: Run them**

Run: `flutter test test/core/widgets/contact_dial_test.dart test/features/photographer_setup/contact_setup_screen_test.dart`
Expected: PASS. If an idle test fails, the usual causes are an `AnimationController` left repeating, a `Timer` for the stagger that is not cancelled on close, or a spinner rendered while `busy` is false; fix the widget (dispose/stop the controller, cancel timers in `dispose` and on close). If the blur count is over 4, replace inner `GlassCard`s of the channel cards with translucent `DecoratedBox`es (the outer card already blurs).

- [ ] **Step 3: Check that `canOpen` is not called per build**

`ContactLauncher.canOpen` asks the platform (`canLaunchUrl`) and must run once per screen, not on every rebuild. Append to `test/features/contact/contact_action_test.dart` a test using the fake launcher of Task 7: pump the screen-level widget, trigger three rebuilds with `tester.pumpWidget` of the same tree with a different unrelated `Key` on an ancestor, and assert the fake's `canOpen` call count did not grow after the first build. If Task 7's fake launcher has no counter, add `int canOpenCalls = 0;` to it, incremented in its `canOpen`. If the count grows, cache the result in the action's state (`initState`/`didUpdateWidget` when the channel list changes) instead of calling it in `build`.

- [ ] **Step 4: Run the whole suite**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests pass.

- [ ] **Step 5: Manual profiling on a real Android device**

Follow `docs/testing/battery-and-performance.md` for the screens listed below (Genymotion is fine for the frame checks, but battery numbers need a real phone). Record the filled-in result table from that document in the PR description. Any value over a threshold blocks the merge: fix it in this plan's code, add a test that would have caught it, and re-measure.

Screens: S32 (open and close the tray 20 times on a test booking screen or the Task 7 widget hosted in a debug page you do not commit) and S34. Scenario for the battery step: fill and save S34, open/close the tray repeatedly, then idle. In `battery.txt`, the app must hold no wake lock after the external app (dialer, Zalo, WhatsApp) has been opened and closed.

- [ ] **Step 6: Commit**

```bash
git add test lib
git commit -m "perf(contact): idle and blur-budget guards for ContactDial and S34

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:**
  - 3b.1: outside channels only after booking (`ContactAccess`, locked dial = inquiry only, `contactAccessForBooking` 30 days, server checks again); inquiries switch `acceptInquiries` (Tasks 2, 6, 7).
  - 3b.2: `photographers/{uid}.contactChannels` flags public, `photographers/{uid}/private/contact` owner-only, `getContactLink` callable with `contact_locked`, client keeps no number (Tasks 2–5); rules and rules tests (Task 3); the server function is explicitly left to a later plan with its contract written down above.
  - 3b.3: `PhoneField(international: true)` with `^\+\d{8,15}$`, Zalo own number Vietnamese (Tasks 1, 3, 8).
  - 3b.4: `url_launcher`, `LaunchMode.externalApplication`, `canLaunchUrl` hides the dialer, Android `<queries>` for `tel` and `https`, iOS `LSApplicationQueriesSchemes` (Task 5); URL formats `tel:+84…`, `https://zalo.me/84…`, `https://wa.me/84…` without plus (Task 4 tests).
  - 3b.5 / S32: tray radius 28, 44dp circles, 62dp entries, labels 10.5, 240/140ms, 40ms stagger right-to-left, interruptible reverse, dismiss by outside tap / button / Back / Esc / choice, `OverlayPortal` + `CompositedTransformFollower` with flip, no layout change, reduced motion, focus to first entry, Tab order, Esc returns focus, `Semantics(button, expanded)`, haptic, single channel direct, locked inquiry only (Task 6); spinner, error messages, `contact_tapped`/`contact_locked` events without numbers (Task 7).
  - 3b.6: existing `zalo.svg`/`whatsapp.svg` through `flutter_svg`, monochrome `onSurface` in a `secondary` (surfaceMuted) circle, text labels and `Semantics` (Task 6).
  - S34: `StepProgress` 4/4, city + radius, required `PhoneField`, three channel cards, "Chỉ nhận tin nhắn trong app", validation per spec incl. WhatsApp fallback, batch write, `onboardingComplete`, route (Task 8). §7 tests: URL building, phone table (plan 2a + Task 1), `ContactDial` expand/close/single channel/reduced motion, rules for private numbers and flags.
- **Deviations from the spec text (also recorded in the spec edits of Task 8):**
  - Spec ids `s32_*`/`s34_*` become camelCase arb keys; new strings `contactInquiry`, `contactOpenError`, and the `setup*` strings.
  - `ContactLauncher.open` takes a `ContactSubject` (booking or registration) and returns a `ContactOpenResult` instead of a bare id and exceptions.
  - `ContactDial` has `busy` instead of `source`; while a link is fetched the **button** shows the spinner (the tray has already closed on selection) instead of the chosen circle. `ContactChannel` carries no `label`/`icon`/`enabled` fields: label is an extension in the widget file, icon is chosen by the widget, "enabled" is expressed by whether the channel is in `channels`.
  - Unlocked dial ignores `inApp` and draws nothing when no outside channel remains (spec text in shared-components says "chỉ `inApp`", S32 says hide the button; S32 wins since the screen has its own "Nhắn tin" button).
  - S34 writes `contactChannels` (the 3b.2 name) rather than the `.contact` that the S34 text mentioned.
  - No analytics layer exists, so events go through an `onEvent` callback on `ContactAction`; S34's `setup_complete{channels}` is not logged yet.
  - The explicit "Chỉ nhận tin nhắn trong app" confirmation of S34 is a switch card, not a separate dialog.
- **Placeholders:** none. The one thing intentionally missing is the Cloud Function `getContactLink` (specified under "Out of scope"); the app builds and tests against the fake.
- **Type consistency:** `ContactChannel`/`ContactAccess` (core), `ContactChannels`, `ContactNumbers`, `ServiceArea`, `PhotographerContactRepository.completeContactSetup(uid, {area, channels, numbers})`, `ContactSubject`, `ContactLinkRepository.link`, `ContactLauncher.open/canOpen`, `ContactOpenResult`, `ContactDial(access, channels, onSelected, style, busy)`, `ContactAction`/`PhotographerContactAction`, `validateContactSetup`/`ContactSetupResult`, `phoneFromField(…, {international})` and the widget keys are spelled identically in tests and code. `ContactDial` focus labels and keys used by Task 7's tests (`contact-dial-button`, `contact-zalo`, …) are defined in Task 6.
- **Risks to watch:**
  1. Task 6 is the largest: `OverlayPortal` + follower flip, `PopScope` for system Back, and `isSemantics` depend on the installed Flutter; Step 4 names the fallback for each. Interrupting the animation mid-way (reverse on open, forward on close) comes from `AnimationController` and has no dedicated test.
  2. Task 3's `existsAfter` and nested `get()` expressions are the part most likely to need an emulator-driven tweak; the tests are the contract.
  3. `getContactLink` does not exist: a release build can show the Liên hệ tray but every tap ends in "Không mở được liên hệ" until the Functions plan ships. The callable region is not chosen (`FirebaseFunctions.instance` default).
  4. S34 has no entry yet (`/setup/4` is only reachable by route); plan 2c (S38 "Tiếp tục") and 2d (S24/profile) must push it. Nothing sets `ContactChannels` for customers (S19/S27 use `customerContact`; a later plan maps `allowZalo/allowWhatsApp` into `channels` for `ContactAction`).
  5. iOS `canLaunchUrl('tel')` returns true on iPad without a dialer in some versions; the `tel` probe is the best signal available, and an actual failed launch is still handled (`cannotLaunch`).
- **Battery and performance:** Task 9 adds idle tests for the dial (closed, open, after close, locked, reduced motion), a blur budget for S34, and a check that `canOpen` is not called on every build.
