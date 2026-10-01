# Step 2a: Phone Number and Customer Contact (S33, S42) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A customer can store a validated Vietnamese phone number (and Zalo/WhatsApp permissions) privately, from S33 "Thêm số điện thoại" and from S42 "Sửa hồ sơ", ready for the booking flow to require it later.

**Architecture:** Pure phone logic in `core/` (normalise, national digits, display format, validate) + a `PhoneField` widget on top of it. The number is stored in `users/{uid}/private/contact`, never in the public `users/{uid}` doc, behind a `UserContactRepository` port (Firestore adapter + in-memory fake) with matching Firestore rules and rules tests. S33 is a route `/profile/phone?returnTo=…` that saves and goes back; S42 gains a phone section.

**Tech Stack:** Flutter, Riverpod 3, go_router, `cloud_firestore` (adapter only), Firestore rules + `@firebase/rules-unit-testing` (Node), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3b.1–3b.3 and §7; `docs/superpowers/specs/screens/booking.md` (S33); `docs/superpowers/specs/screens/account.md` (S42); `docs/superpowers/specs/components/shared-components.md` (PhoneField); `docs/superpowers/specs/data-model/domain-model.md` (`UserContact`, `PhoneNumber`).

**Prerequisite:** `docs/superpowers/plans/2026-10-01-screen-codes.md` is done (this plan uses `ScreenCode` and `ScreenCodes.addPhone`).

## How step 2 is split

The spec's step 2 covers S03, S20, S24, S32, S33, S34, S38–S40, S42. It is four plans, in this order:

| Plan | Content | Screens |
|---|---|---|
| **2a (this)** | phone logic, `PhoneField`, `UserContact` + rules, S33, S42 phone section | S33, S42 |
| 2b | `ContactDial`, `ContactLauncher`, `getContactLink` port, photographer contact channels | S32, S34 |
| 2c | skills model, `SkillChip`, `LevelSelector`, `EvidencePicker`, `CompletenessMeter` | S38–S40 |
| 2d | photographer profile, setup steps 1–2, calendar (`AvailabilityCalendar`), "Số điện thoại" row on S30, avatar change on S42 | S03, S20, S24 |

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Imports are `package:photobooking/...` only; features import `package:photobooking/core/core.dart`; files inside `core/` import each other directly.
- `cloud_firestore` may appear only in `lib/data/**` adapters, `firebase_options.dart` and `main.dart`. Domain and features use the `UserContactRepository` interface.
- Data conventions (`data-model/README.md`): ids opaque strings, instants UTC, enum codes as strings, no Firebase types in the domain model.
- **Phone numbers never go into `users/{uid}`** (readable by every signed-in user). They live only in `users/{uid}/private/contact`, readable and writable only by the owner.
- Phone validity: Vietnamese `^(?:\+84|0)(3|5|7|8|9)\d{8}$`, stored as E.164 `+84` + 9 digits. Spaces, dots, dashes and brackets are ignored.
- Phone verification is out of scope: `phoneVerified` is always `false` and clients can never set it to `true`.
- Defaults: `allowZalo = true`, `allowWhatsApp = false`.
- The UI never shows another person's number; this plan only handles the user's own.
- All UI strings in `lib/l10n/app_vi.arb` (Vietnamese, full diacritics), regenerate with `flutter gen-l10n`. Colours, spacing from `AppColors`/`AppSpace`; main button is `AppButton.primary` (fixed 52dp, one per screen).
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/phone.dart` (create) | `normalizePhone`, `nationalDigits`, `formatNational`, `phoneFromField`, `nationalFromE164`, `validatePhone` |
| `lib/core/widgets/phone_field.dart` (create) | `PhoneField` |
| `lib/core/core.dart` (modify) | export both |
| `lib/data/user/user_contact_repository.dart` (create) | `UserContact`, `UserContactRepository`, Firestore adapter, fake, `contactToFirestore` |
| `lib/data/user/user_contact_providers.dart` (create) | `userContactRepositoryProvider`, `currentContactProvider` |
| `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs` (modify) | rules for `users/{uid}/private/contact` + tests |
| `lib/features/contact/return_to.dart` (create) | `safeReturnTo` |
| `lib/features/contact/save_contact_controller.dart` (create) | saves the contact for S33 |
| `lib/features/contact/add_phone_screen.dart` (create) | S33 |
| `lib/app/router.dart` (modify) | route `/profile/phone` |
| `lib/features/settings/edit_profile_controller.dart`, `edit_profile_screen.dart` (modify) | S42 phone section |
| `lib/l10n/app_vi.arb` (modify) | strings |
| `docs/superpowers/specs/screens/booking.md`, `components/shared-components.md` (modify) | align S33 error text and PhoneField behaviour |
| tests | listed per task |

---

### Task 1: Phone logic

**Files:**
- Create: `lib/core/phone.dart`, `test/core/phone_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Produces:
  - `String? normalizePhone(String input, {bool international = false})` → E.164 or `null`.
  - `String nationalDigits(String input)` → at most 9 digits; strips a leading `+84`, one leading `0`, and all non-digits.
  - `String formatNational(String digits)` → `903 123 456`.
  - `String? phoneFromField(String fieldText)` → `normalizePhone('+84' + nationalDigits(fieldText))`.
  - `String nationalFromE164(String e164)` → formatted national text for prefilling a field.
  - `String? validatePhone(String? fieldText, AppLocalizations l)`.
  - l10n: `phoneLabel` "Số điện thoại", `phoneRequired` "Nhập số điện thoại", `phoneInvalid` "Số điện thoại chưa đúng. Ví dụ: 903 123 456".

- [ ] **Step 1: Write the failing test**

```dart
// test/core/phone_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/phone.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

void main() {
  group('normalizePhone', () {
    const valid = {
      '0903123456': '+84903123456',
      '+84 903 123 456': '+84903123456',
      '0903.123.456': '+84903123456',
      '(090) 312-3456': '+84903123456',
      '+84903123456': '+84903123456',
      '0321234567': '+84321234567',
    };
    valid.forEach((input, e164) {
      test('accepts $input', () => expect(normalizePhone(input), e164));
    });

    const invalid = [
      '', '090312345', '0123456789', '09031234567', '0203123456',
      '+84 023 123 456', '+14155552671', 'abc', '0903 123 45a',
    ];
    for (final input in invalid) {
      test('rejects "$input"', () => expect(normalizePhone(input), isNull));
    }

    test('international accepts other countries, still rejects malformed +84', () {
      expect(normalizePhone('+1 415 555 2671', international: true), '+14155552671');
      expect(normalizePhone('+84012345678', international: true), isNull);
      expect(normalizePhone('+123', international: true), isNull);
    });
  });

  group('field text', () {
    test('nationalDigits strips +84, one leading 0 and junk, caps at 9', () {
      expect(nationalDigits('0903123456'), '903123456');
      expect(nationalDigits('+84 903 123 456'), '903123456');
      expect(nationalDigits('903 123 456'), '903123456');
      expect(nationalDigits('0'), '');
      expect(nationalDigits('84312345678'), '843123456'); // no "+": 84 is part of the number
      expect(nationalDigits('9031234567890'), '903123456');
    });
    test('formatNational groups by three', () {
      expect(formatNational(''), '');
      expect(formatNational('90'), '90');
      expect(formatNational('9031'), '903 1');
      expect(formatNational('903123456'), '903 123 456');
    });
    test('phoneFromField accepts what a person types or pastes', () {
      expect(phoneFromField('903 123 456'), '+84903123456');
      expect(phoneFromField('0903123456'), '+84903123456');
      expect(phoneFromField('+84 903 123 456'), '+84903123456');
      expect(phoneFromField('90312345'), isNull);
      expect(phoneFromField('123456789'), isNull);
    });
    test('nationalFromE164 round-trips', () {
      expect(nationalFromE164('+84903123456'), '903 123 456');
    });
  });

  group('validatePhone', () {
    final l = AppLocalizationsVi();
    test('empty, wrong and right', () {
      expect(validatePhone('', l), l.phoneRequired);
      expect(validatePhone(null, l), l.phoneRequired);
      expect(validatePhone('90312345', l), l.phoneInvalid);
      expect(validatePhone('903 123 456', l), isNull);
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/phone_test.dart`
Expected: FAIL, `package:photobooking/core/phone.dart` not found.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`:

```json
  "phoneLabel": "Số điện thoại",
  "phoneRequired": "Nhập số điện thoại",
  "phoneInvalid": "Số điện thoại chưa đúng. Ví dụ: 903 123 456",
```

Run `flutter gen-l10n`.

```dart
// lib/core/phone.dart
import 'package:photobooking/l10n/app_localizations.dart';

/// Vietnamese numbers: 0 or +84, then a 3/5/7/8/9 prefix and 8 more digits.
final _vn = RegExp(r'^(?:\+84|0)([35789]\d{8})$');
final _international = RegExp(r'^\+\d{8,15}$');

String _compact(String s) => s.replaceAll(RegExp(r'[\s.\-()]'), '');

/// E.164 for a valid number, else null. Spaces, dots, dashes and brackets are
/// ignored. [international] also accepts other countries' numbers
/// (`+` and 8–15 digits), for WhatsApp.
String? normalizePhone(String input, {bool international = false}) {
  final s = _compact(input);
  final vn = _vn.firstMatch(s);
  if (vn != null) return '+84${vn.group(1)}';
  // A malformed +84 number must not slip through as "international".
  if (international && !s.startsWith('+84') && _international.hasMatch(s)) {
    return s;
  }
  return null;
}

/// What goes after the fixed "+84" in a field: digits only, no leading 0,
/// at most 9. A leading "+84" (pasted) is dropped; without "+", "84…" is part
/// of the number (08x numbers exist).
String nationalDigits(String input) {
  final s = _compact(input);
  var d = s.startsWith('+84') ? s.substring(3) : s;
  d = d.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('0')) d = d.substring(1);
  return d.length > 9 ? d.substring(0, 9) : d;
}

/// `903123456` → `903 123 456`.
String formatNational(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 3 == 0) b.write(' ');
    b.write(digits[i]);
  }
  return b.toString();
}

/// E.164 from the text of a `PhoneField`, or null while it is not valid.
String? phoneFromField(String fieldText) =>
    normalizePhone('+84${nationalDigits(fieldText)}');

/// Text to prefill a `PhoneField` from a stored E.164 number.
String nationalFromE164(String e164) => formatNational(nationalDigits(e164));

String? validatePhone(String? fieldText, AppLocalizations l) {
  final t = (fieldText ?? '').trim();
  if (t.isEmpty) return l.phoneRequired;
  return phoneFromField(t) == null ? l.phoneInvalid : null;
}
```

In `core.dart` add `export 'package:photobooking/core/phone.dart';` after `l10n_ext.dart`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/phone_test.dart && flutter analyze`
Expected: PASS; analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/core/phone.dart lib/core/core.dart lib/l10n test/core/phone_test.dart
git commit -m "feat(core): Vietnamese phone normalisation and validation

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `PhoneField`

**Files:**
- Create: `lib/core/widgets/phone_field.dart`, `test/core/widgets/phone_field_test.dart`
- Modify: `lib/core/core.dart`

**Interfaces:**
- Consumes: `formatNational`, `nationalDigits`, `validatePhone` (Task 1); `hostWidget` from `test/core/widgets/widget_host.dart` (created in `2026-10-01-core-display-widgets.md` Task 1; if that plan has not run, create the same file from that plan first).
- Produces: `const PhoneField({super.key, required TextEditingController controller, String? errorText, bool enabled = true, ValueChanged<String>? onChanged, FormFieldValidator<String>? validator, bool autofocus = false})`. The controller text is always the national form (`903 123 456`); read the number with `phoneFromField(controller.text)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/phone_field_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  Future<TextEditingController> pump(
    WidgetTester tester, {
    ValueChanged<String>? onChanged,
    GlobalKey<FormState>? form,
  }) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      hostWidget(
        Form(
          key: form,
          child: PhoneField(controller: c, onChanged: onChanged),
        ),
      ),
    );
    return c;
  }

  testWidgets('typing groups digits as 903 123 456', (tester) async {
    final c = await pump(tester);
    await tester.enterText(find.byType(TextFormField), '903123456');
    expect(c.text, '903 123 456');
  });

  testWidgets('a pasted 0903… or +84… number is turned into the national form', (
    tester,
  ) async {
    final c = await pump(tester);
    await tester.enterText(find.byType(TextFormField), '0903123456');
    expect(c.text, '903 123 456');
    await tester.enterText(find.byType(TextFormField), '+84 903 123 456');
    expect(c.text, '903 123 456');
  });

  testWidgets('letters are dropped and input stops at nine digits', (tester) async {
    final c = await pump(tester);
    await tester.enterText(find.byType(TextFormField), '90a31234567890');
    expect(c.text, '903 123 456');
  });

  testWidgets('uses the phone keyboard and shows the label', (tester) async {
    await pump(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.phone);
    expect(find.text('Số điện thoại'), findsOneWidget);
  });

  testWidgets('validation message is specific and sits under the field', (
    tester,
  ) async {
    final form = GlobalKey<FormState>();
    await pump(tester, form: form);
    await tester.enterText(find.byType(TextFormField), '90312345');
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Số điện thoại chưa đúng. Ví dụ: 903 123 456'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '903123456');
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets('onChanged receives the formatted text', (tester) async {
    String? last;
    await pump(tester, onChanged: (v) => last = v);
    await tester.enterText(find.byType(TextFormField), '0903123456');
    expect(last, '903 123 456');
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    final c = TextEditingController(text: '903 123 456');
    addTearDown(c.dispose);
    await tester.pumpWidget(
      hostWidget(PhoneField(controller: c), width: 320, textScale: 1.3),
    );
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/phone_field_test.dart`
Expected: FAIL, `PhoneField` undefined.

- [ ] **Step 3: Implement**

```dart
// lib/core/widgets/phone_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/phone.dart';

/// Vietnamese phone number input with a fixed "+84" prefix. The text is the
/// national form `903 123 456`; typing or pasting `0903…` or `+84…` is
/// normalised. Read the number with [phoneFromField].
///
/// Note: only a paste (or a whole-text edit) can carry a "+84"; typing "+"
/// digit by digit is read as national digits.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.validator,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// Defaults to [validatePhone] (required and well-formed).
  final FormFieldValidator<String>? validator;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [_NationalPhoneFormatter()],
      onChanged: onChanged,
      validator: validator ?? (v) => validatePhone(v, l),
      decoration: InputDecoration(
        labelText: l.phoneLabel,
        hintText: '903 123 456',
        prefixText: '+84 ',
        prefixIcon: const Icon(Icons.phone_outlined),
        errorText: errorText,
      ),
    );
  }
}

class _NationalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final text = formatNational(nationalDigits(next.text));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
```

Export from `core.dart`: `export 'package:photobooking/core/widgets/phone_field.dart';`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/phone_field_test.dart && flutter analyze`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core test/core/widgets/phone_field_test.dart
git commit -m "feat(core): PhoneField with +84 prefix and 903 123 456 format

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `UserContact`, repository port, fake and Firestore adapter

**Files:**
- Create: `lib/data/user/user_contact_repository.dart`, `lib/data/user/user_contact_providers.dart`, `test/data/user/user_contact_repository_test.dart`

**Interfaces:**
- Consumes: `authRepositoryProvider`, `authStateProvider` from `lib/data/auth/auth_providers.dart`.
- Produces:
  - `class UserContact { const UserContact({required String phone, bool phoneVerified = false, bool allowZalo = true, bool allowWhatsApp = false}); }` with value `==`/`hashCode`, `copyWith`.
  - `Map<String, dynamic> contactToFirestore(UserContact c)` → `{phone, allowZalo, allowWhatsApp}` only.
  - `abstract class UserContactRepository { Stream<UserContact?> watch(String uid); Future<void> save(String uid, {required String phone, required bool allowZalo, required bool allowWhatsApp}); }`
  - `FirestoreUserContactRepository({FirebaseFirestore? db})`, `FakeUserContactRepository({bool failSave = false})` with `UserContact? stored(String uid)`.
  - `userContactRepositoryProvider` (`Provider<UserContactRepository>`), `currentContactProvider` (`StreamProvider<UserContact?>`, `null` when signed out or no contact).

- [ ] **Step 1: Write the failing test**

```dart
// test/data/user/user_contact_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';

void main() {
  test('only phone and the two permissions are written by the client', () {
    const c = UserContact(phone: '+84903123456');
    expect(contactToFirestore(c), {
      'phone': '+84903123456',
      'allowZalo': true,
      'allowWhatsApp': false,
    });
  });

  test('defaults: not verified, Zalo on, WhatsApp off', () {
    const c = UserContact(phone: '+84903123456');
    expect(c.phoneVerified, isFalse);
    expect(c.allowZalo, isTrue);
    expect(c.allowWhatsApp, isFalse);
  });

  test('fake saves, streams updates and keeps users separate', () async {
    final repo = FakeUserContactRepository();
    expect(await repo.watch('u1').first, isNull);
    final updates = repo.watch('u1').skip(1).take(2).toList();
    await repo.save('u1', phone: '+84903123456', allowZalo: true, allowWhatsApp: false);
    await repo.save('u1', phone: '+84903123456', allowZalo: false, allowWhatsApp: true);
    final seen = await updates;
    expect(seen.last, const UserContact(phone: '+84903123456', allowZalo: false, allowWhatsApp: true));
    expect(repo.stored('u2'), isNull);
  });

  test('changing the number resets verification; changing only a toggle keeps it', () async {
    final repo = FakeUserContactRepository()
      ..seed('u1', const UserContact(phone: '+84903123456', phoneVerified: true));
    await repo.save('u1', phone: '+84903123456', allowZalo: false, allowWhatsApp: false);
    expect(repo.stored('u1')!.phoneVerified, isTrue);
    await repo.save('u1', phone: '+84912345678', allowZalo: false, allowWhatsApp: false);
    expect(repo.stored('u1')!.phoneVerified, isFalse);
  });

  test('a failing save throws and stores nothing', () async {
    final repo = FakeUserContactRepository(failSave: true);
    await expectLater(
      repo.save('u1', phone: '+84903123456', allowZalo: true, allowWhatsApp: false),
      throwsStateError,
    );
    expect(repo.stored('u1'), isNull);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/user/user_contact_repository_test.dart`
Expected: FAIL, file not found.

- [ ] **Step 3: Implement**

```dart
// lib/data/user/user_contact_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// The signed-in user's private contact details. Lives apart from the public
/// users/{uid} profile; only the owner can read or write it.
class UserContact {
  const UserContact({
    required this.phone,
    this.phoneVerified = false,
    this.allowZalo = true,
    this.allowWhatsApp = false,
  });

  /// E.164, e.g. `+84903123456`.
  final String phone;

  /// Always false until phone verification exists; the client never sets it.
  final bool phoneVerified;
  final bool allowZalo;
  final bool allowWhatsApp;

  UserContact copyWith({
    String? phone,
    bool? phoneVerified,
    bool? allowZalo,
    bool? allowWhatsApp,
  }) => UserContact(
    phone: phone ?? this.phone,
    phoneVerified: phoneVerified ?? this.phoneVerified,
    allowZalo: allowZalo ?? this.allowZalo,
    allowWhatsApp: allowWhatsApp ?? this.allowWhatsApp,
  );

  @override
  bool operator ==(Object other) =>
      other is UserContact &&
      other.phone == phone &&
      other.phoneVerified == phoneVerified &&
      other.allowZalo == allowZalo &&
      other.allowWhatsApp == allowWhatsApp;

  @override
  int get hashCode => Object.hash(phone, phoneVerified, allowZalo, allowWhatsApp);
}

/// Fields a client writes. `phoneVerified` is deliberately absent: only the
/// repository resets it (to false) and only a server process may set it true.
Map<String, dynamic> contactToFirestore(UserContact c) => {
  'phone': c.phone,
  'allowZalo': c.allowZalo,
  'allowWhatsApp': c.allowWhatsApp,
};

abstract class UserContactRepository {
  Stream<UserContact?> watch(String uid);

  /// Creates or updates the contact. A changed number is marked unverified.
  Future<void> save(
    String uid, {
    required String phone,
    required bool allowZalo,
    required bool allowWhatsApp,
  });
}

class FirestoreUserContactRepository implements UserContactRepository {
  FirestoreUserContactRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid).collection('private').doc('contact');

  @override
  Stream<UserContact?> watch(String uid) => _doc(uid).snapshots().map((s) {
    final d = s.data();
    if (d == null || d['phone'] is! String) return null;
    return UserContact(
      phone: d['phone'] as String,
      phoneVerified: d['phoneVerified'] == true,
      allowZalo: d['allowZalo'] != false,
      allowWhatsApp: d['allowWhatsApp'] == true,
    );
  });

  @override
  Future<void> save(
    String uid, {
    required String phone,
    required bool allowZalo,
    required bool allowWhatsApp,
  }) async {
    final ref = _doc(uid);
    final before = (await ref.get()).data();
    final changed = before == null || before['phone'] != phone;
    await ref.set({
      ...contactToFirestore(
        UserContact(phone: phone, allowZalo: allowZalo, allowWhatsApp: allowWhatsApp),
      ),
      if (changed) 'phoneVerified': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class FakeUserContactRepository implements UserContactRepository {
  FakeUserContactRepository({this.failSave = false});
  final bool failSave;
  final _contacts = <String, UserContact>{};
  final _controllers = <String, StreamController<UserContact?>>{};

  StreamController<UserContact?> _c(String uid) => _controllers.putIfAbsent(
    uid,
    () => StreamController<UserContact?>.broadcast(),
  );

  UserContact? stored(String uid) => _contacts[uid];

  /// Test setup without going through [save].
  void seed(String uid, UserContact contact) => _contacts[uid] = contact;

  @override
  Stream<UserContact?> watch(String uid) async* {
    yield _contacts[uid];
    yield* _c(uid).stream;
  }

  @override
  Future<void> save(
    String uid, {
    required String phone,
    required bool allowZalo,
    required bool allowWhatsApp,
  }) async {
    if (failSave) throw StateError('unavailable');
    final before = _contacts[uid];
    final next = UserContact(
      phone: phone,
      phoneVerified: before != null && before.phone == phone && before.phoneVerified,
      allowZalo: allowZalo,
      allowWhatsApp: allowWhatsApp,
    );
    _contacts[uid] = next;
    _c(uid).add(next);
  }
}
```

```dart
// lib/data/user/user_contact_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';

final userContactRepositoryProvider = Provider<UserContactRepository>(
  (ref) => FirestoreUserContactRepository(),
);

/// The signed-in user's private contact; null while signed out or when no
/// number has been saved yet.
final currentContactProvider = StreamProvider<UserContact?>((ref) async* {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    yield null;
    return;
  }
  yield* ref.watch(userContactRepositoryProvider).watch(user.uid);
});
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/user/user_contact_repository_test.dart && flutter analyze`
Expected: PASS, 5 tests; analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/user test/data/user/user_contact_repository_test.dart
git commit -m "feat(data): private UserContact repository with fake and Firestore adapter

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Firestore rules for `users/{uid}/private/contact`

**Files:**
- Modify: `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs`

**Interfaces:**
- Produces: owner-only read/write of `users/{uid}/private/contact`; no other `private/*` document; shape and E.164 validated; `phoneVerified` cannot be set to `true` or changed by a client.

- [ ] **Step 1: Write the failing tests** (append to `firebase/rules-test/rules.test.mjs`)

```js
const contactPath = (uid) => `users/${uid}/private/contact`;

test('owner can save a valid private contact; defaults work', async () => {
  const db = env.authenticatedContext('c1').firestore();
  await assertSucceeds(setDoc(doc(db, contactPath('c1')), {
    phone: '+84903123456', allowZalo: true, allowWhatsApp: false, phoneVerified: false,
  }));
  await assertSucceeds(setDoc(doc(db, contactPath('c1')), { phone: '+84321234567' }, { merge: true }));
  await assertSucceeds(getDoc(doc(db, contactPath('c1'))));
});

test('nobody else can read or write someone\'s private contact', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), contactPath('c2')), { phone: '+84903123456' }));
  const other = env.authenticatedContext('c3').firestore();
  await assertFails(getDoc(doc(other, contactPath('c2'))));
  await assertFails(setDoc(doc(other, contactPath('c2')), { phone: '+84912345678' }));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), contactPath('c2'))));
});

test('contact rejects malformed numbers, extra fields and other documents', async () => {
  const db = env.authenticatedContext('c4').firestore();
  for (const phone of ['0903123456', '+8490312345', '+84123456789', '903123456', 123]) {
    await assertFails(setDoc(doc(db, contactPath('c4')), { phone }));
  }
  await assertFails(setDoc(doc(db, contactPath('c4')), { phone: '+84903123456', note: 'x' }));
  await assertFails(setDoc(doc(db, contactPath('c4')), { phone: '+84903123456', allowZalo: 'yes' }));
  await assertFails(setDoc(doc(db, 'users/c4/private/other'), { phone: '+84903123456' }));
  await assertFails(setDoc(doc(db, contactPath('c4')), {}));
});

test('a client can never mark its phone verified', async () => {
  const db = env.authenticatedContext('c5').firestore();
  await assertFails(setDoc(doc(db, contactPath('c5')), { phone: '+84903123456', phoneVerified: true }));
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), contactPath('c5')), { phone: '+84903123456', phoneVerified: true }));
  // Toggling a permission keeps the server's flag untouched.
  await assertSucceeds(updateDoc(doc(db, contactPath('c5')), { allowZalo: false }));
  await assertFails(updateDoc(doc(db, contactPath('c5')), { phoneVerified: false }));
});

test('the public users doc still refuses a phone field', async () => {
  const db = env.authenticatedContext('c6').firestore();
  await assertFails(setDoc(doc(db, 'users/c6'), { displayName: 'X', phone: '+84903123456' }));
});
```

- [ ] **Step 2: Run and see it fail**

Run (from `firebase/rules-test`, needs Node, Java and the emulator, as in CI): `npm ci && npm test`
Expected: the new tests FAIL (no rule allows `users/{uid}/private/contact`, so the first test fails; the "owner can save" one proves it).
If the emulator cannot run in this sandbox, say so in the report and rely on the CI job "Firestore rules tests (emulator)".

- [ ] **Step 3: Implement**

In `firebase/firestore.rules`, inside `service cloud.firestore` / `match /databases/{database}/documents`, add this function next to the others:

```
    // users/{uid}/private/contact: owner-only; E.164 Vietnamese number; the
    // verified flag is never changed by a client (verification comes later).
    function validContact(uid) {
      let d = request.resource.data;
      let old = resource == null ? null : resource.data;
      return d.keys().hasOnly(['phone', 'phoneVerified', 'allowZalo', 'allowWhatsApp', 'updatedAt'])
        && d.phone is string
        && d.phone.matches('^\\+84[35789][0-9]{8}$')
        && d.get('phoneVerified', false) == (old == null ? false : old.get('phoneVerified', false))
        && d.get('allowZalo', true) is bool
        && d.get('allowWhatsApp', false) is bool;
    }
```

and replace the `match /users/{uid}` block with:

```
    match /users/{uid} {
      allow read: if signedIn();
      allow create, update: if isOwner(uid) && validRole() && onlyKeys(userClientFields());
      allow delete: if false;

      match /private/{docId} {
        allow read: if isOwner(uid);
        allow create, update: if isOwner(uid) && docId == 'contact' && validContact(uid);
        allow delete: if false;
      }
    }
```

- [ ] **Step 4: Run and see it pass**

Run (from `firebase/rules-test`): `npm test`
Expected: all rules tests pass, old and new. If `update` of `allowZalo` fails because merged data lacks `phone`, remember `request.resource.data` is the merged result, so `phone` is present; if it still fails, print the rule trace from the emulator and fix the expression, not the test.

- [ ] **Step 5: Commit**

```bash
git add firebase/firestore.rules firebase/rules-test/rules.test.mjs
git commit -m "feat(rules): owner-only validated users/{uid}/private/contact

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: S33 "Thêm số điện thoại" screen and route

**Files:**
- Create: `lib/features/contact/return_to.dart`, `lib/features/contact/save_contact_controller.dart`, `lib/features/contact/add_phone_screen.dart`, `test/features/contact/return_to_test.dart`, `test/features/contact/add_phone_screen_test.dart`
- Modify: `lib/app/router.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `PhoneField`, `phoneFromField` (Tasks 1–2); `userContactRepositoryProvider` (Task 3); `authRepositoryProvider`; `ScreenCode`/`ScreenCodes.addPhone`; `AppTab.home.path` from `lib/app/tabs.dart`.
- Produces:
  - `String? safeReturnTo(String? value)` — only in-app absolute paths.
  - `saveContactControllerProvider` (`AsyncNotifierProvider.autoDispose<SaveContactController, bool>`), `.save({required String phone, required bool allowZalo, required bool allowWhatsApp})`.
  - `AddPhoneScreen({super.key, String? returnTo})`, route `/profile/phone?returnTo=<path>`. Booking and event flows (later plans) open it with `context.push('/profile/phone?returnTo=${Uri.encodeComponent(here)}')`.
  - l10n: `addPhoneTitle`, `addPhoneBody`, `addPhoneExample`, `allowZaloLabel`, `allowWhatsAppLabel`, `phonePrivacy`, `addPhoneSave`, `phoneSaveError`.

S33 is a spec'd sheet. `AppBottomSheet` does not exist yet, so this plan builds the screen as a full-page route over `AuroraBackground`; the content widget is `_AddPhoneForm`-free and self-contained so a later task can move it into `showAppSheet` without touching logic.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/contact/return_to_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/contact/return_to.dart';

void main() {
  test('keeps in-app paths, with query', () {
    expect(safeReturnTo('/u/abc/book'), '/u/abc/book');
    expect(safeReturnTo('/e/1/join?qty=2'), '/e/1/join?qty=2');
  });
  test('refuses anything that could leave the app or is empty', () {
    for (final bad in [null, '', 'https://evil.com', '//evil.com', 'evil.com', r'/\evil.com', 'javascript:alert(1)']) {
      expect(safeReturnTo(bad), isNull, reason: '$bad');
    }
  });
}
```

```dart
// test/features/contact/add_phone_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/contact/add_phone_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class _Harness {
  _Harness(this.auth, this.contacts, this.widget);
  final FakeAuthRepository auth;
  final FakeUserContactRepository contacts;
  final Widget widget;
}

Future<_Harness> _harness({
  String location = '/profile/phone?returnTo=%2Fafter',
  bool failSave = false,
}) async {
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final contacts = FakeUserContactRepository(failSave: failSave);
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
  await users.ensureProfile(u);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/profile/phone',
        builder: (_, s) => AddPhoneScreen(returnTo: s.uri.queryParameters['returnTo']),
      ),
      GoRoute(path: '/after', builder: (_, _) => const Text('after')),
      GoRoute(path: '/home', builder: (_, _) => const Text('home')),
    ],
  );
  return _Harness(
    auth,
    contacts,
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        userContactRepositoryProvider.overrideWithValue(contacts),
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

void main() {
  testWidgets('save stays disabled until the number is valid', (tester) async {
    final h = await _harness();
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    bool enabled() => tester
            .widget<FilledButton>(find.descendant(of: find.byKey(const Key('phone-save')), matching: find.byType(FilledButton)))
            .onPressed !=
        null;
    expect(enabled(), isFalse);
    await tester.enterText(find.byType(TextFormField), '90312345');
    await tester.pump();
    expect(enabled(), isFalse);
    await tester.enterText(find.byType(TextFormField), '0903123456');
    await tester.pump();
    expect(enabled(), isTrue);
  });

  testWidgets('saves E.164 with the default toggles and returns to returnTo', (tester) async {
    final h = await _harness();
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '+84 903 123 456');
    await tester.pump();
    await tester.tap(find.byKey(const Key('phone-save')));
    await tester.pumpAndSettle();
    expect(
      h.contacts.stored(h.auth.currentUser!.uid),
      const UserContact(phone: '+84903123456', allowZalo: true, allowWhatsApp: false),
    );
    expect(find.text('after'), findsOneWidget);
  });

  testWidgets('toggles are saved as chosen', (tester) async {
    final h = await _harness();
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0903123456');
    await tester.tap(find.byKey(const Key('allow-zalo')));
    await tester.tap(find.byKey(const Key('allow-whatsapp')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('phone-save')));
    await tester.pumpAndSettle();
    final c = h.contacts.stored(h.auth.currentUser!.uid)!;
    expect((c.allowZalo, c.allowWhatsApp), (false, true));
  });

  testWidgets('an unsafe returnTo is ignored and the app goes home', (tester) async {
    final h = await _harness(location: '/profile/phone?returnTo=%2F%2Fevil.com');
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0903123456');
    await tester.pump();
    await tester.tap(find.byKey(const Key('phone-save')));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a failed save shows a message and keeps the screen', (tester) async {
    final h = await _harness(failSave: true);
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0903123456');
    await tester.pump();
    await tester.tap(find.byKey(const Key('phone-save')));
    await tester.pumpAndSettle();
    expect(find.text('Không lưu được số điện thoại. Thử lại nhé.'), findsOneWidget);
    expect(find.byType(AddPhoneScreen), findsOneWidget);
    expect(find.text('after'), findsNothing);
  });

  testWidgets('shows the privacy note and fits 320dp at 1.3x', (tester) async {
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
    expect(find.text('Số của bạn chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/contact`
Expected: FAIL, the `contact/` files do not exist.

- [ ] **Step 3: Implement**

Strings to add to `lib/l10n/app_vi.arb` (then `flutter gen-l10n`):

```json
  "addPhoneTitle": "Thêm số điện thoại để đặt lịch",
  "addPhoneBody": "Nhiếp ảnh gia sẽ gọi hoặc nhắn Zalo/WhatsApp cho bạn để chốt chi tiết.",
  "addPhoneExample": "Ví dụ: 0903 123 456. Chưa cần mã xác minh; bước xác minh sẽ bổ sung sau.",
  "allowZaloLabel": "Cho phép liên hệ qua Zalo",
  "allowWhatsAppLabel": "Cho phép liên hệ qua WhatsApp",
  "phonePrivacy": "Số của bạn chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc.",
  "addPhoneSave": "Lưu và tiếp tục",
  "phoneSaveError": "Không lưu được số điện thoại. Thử lại nhé.",
```

```dart
// lib/features/contact/return_to.dart
/// A `returnTo` query value is only followed when it is an absolute in-app
/// path; anything that could leave the app (a scheme, `//host`, backslashes)
/// is dropped so the screen cannot be used as an open redirect.
String? safeReturnTo(String? value) {
  if (value == null || value.isEmpty) return null;
  if (!value.startsWith('/') || value.startsWith('//')) return null;
  if (value.contains(r'\')) return null;
  return value;
}
```

```dart
// lib/features/contact/save_contact_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';

/// Saves the user's private contact. Its value turns true once a save went
/// through.
class SaveContactController extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> save({
    required String phone,
    required bool allowZalo,
    required bool allowWhatsApp,
  }) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(userContactRepositoryProvider)
          .save(uid, phone: phone, allowZalo: allowZalo, allowWhatsApp: allowWhatsApp);
      return true;
    });
  }
}

final saveContactControllerProvider =
    AsyncNotifierProvider.autoDispose<SaveContactController, bool>(
      SaveContactController.new,
    );
```

```dart
// lib/features/contact/add_phone_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/contact/return_to.dart';
import 'package:photobooking/features/contact/save_contact_controller.dart';

/// S33: add the phone number needed to book. Saves to the private contact and
/// goes back to [returnTo] (or the previous screen / home).
class AddPhoneScreen extends ConsumerStatefulWidget {
  const AddPhoneScreen({super.key, this.returnTo});

  final String? returnTo;

  @override
  ConsumerState<AddPhoneScreen> createState() => _AddPhoneScreenState();
}

class _AddPhoneScreenState extends ConsumerState<AddPhoneScreen> {
  final _phone = TextEditingController();
  bool _zalo = true;
  bool _whatsApp = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String? get _e164 => phoneFromField(_phone.text);

  void _done() {
    final to = safeReturnTo(widget.returnTo);
    if (to != null) {
      context.go(to);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppTab.home.path);
    }
  }

  void _save() {
    final phone = _e164;
    if (phone == null) return;
    ref
        .read(saveContactControllerProvider.notifier)
        .save(phone: phone, allowZalo: _zalo, allowWhatsApp: _whatsApp);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final saving = ref.watch(saveContactControllerProvider).isLoading;
    ref.listen(saveContactControllerProvider, (prev, next) {
      if (next.isLoading || !(prev?.isLoading ?? false)) return;
      if (next.hasError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.phoneSaveError)));
      } else if (next.value ?? false) {
        _done();
      }
    });
    return ScreenCode(
      ScreenCodes.addPhone,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.s5),
              child: GlassCard(
                highlight: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(l.addPhoneTitle, style: theme.textTheme.titleLarge),
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Text(l.addPhoneBody),
                      const SizedBox(height: AppSpace.s5),
                      PhoneField(
                        controller: _phone,
                        enabled: !saving,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Text(l.addPhoneExample, style: theme.textTheme.bodySmall),
                      const SizedBox(height: AppSpace.s3),
                      SwitchListTile(
                        key: const Key('allow-zalo'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.allowZaloLabel),
                        value: _zalo,
                        onChanged: saving ? null : (v) => setState(() => _zalo = v),
                      ),
                      SwitchListTile(
                        key: const Key('allow-whatsapp'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.allowWhatsAppLabel),
                        value: _whatsApp,
                        onChanged: saving ? null : (v) => setState(() => _whatsApp = v),
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 16),
                          const SizedBox(width: AppSpace.s2),
                          Expanded(child: Text(l.phonePrivacy, style: theme.textTheme.bodySmall)),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s5),
                      AppButton.primary(
                        l.addPhoneSave,
                        key: const Key('phone-save'),
                        loading: saving,
                        onPressed: _e164 == null ? null : _save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

`lib/app/router.dart`: add `import 'package:photobooking/features/contact/add_phone_screen.dart';` and, in the top-level `routes` list just before `StatefulShellRoute.indexedStack(`:

```dart
      GoRoute(
        path: '/profile/phone',
        builder: (_, state) =>
            AddPhoneScreen(returnTo: state.uri.queryParameters['returnTo']),
      ),
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/features/contact test/app && flutter analyze`
Expected: PASS; analyze clean. If `FilledButton` is not found under the `AppButton` key in the test, change the finder to `find.descendant(of: find.byKey(const Key('phone-save')), matching: find.byType(FilledButton))` as written; if the key lands on `AppButton` itself the descendant lookup still works.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(contact): S33 add phone number with safe returnTo

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: S42 phone section

**Files:**
- Modify: `lib/features/settings/edit_profile_controller.dart`, `lib/features/settings/edit_profile_screen.dart`, `test/features/settings/settings_test.dart`, and `test/features/screen_codes_applied_test.dart` (only if the screen-codes plan has been executed)

**Interfaces:**
- Consumes: `PhoneField`, `phoneFromField`, `nationalFromE164`, `validatePhone`; `currentContactProvider`, `userContactRepositoryProvider`; strings `phoneLabel`, `allowZaloLabel`, `allowWhatsAppLabel`, `phonePrivacy`.
- Produces: `EditProfileController.save({required String displayName, String? phone, bool? allowZalo, bool? allowWhatsApp})` — `phone` is E.164; the contact is saved only when a number is present (typed now, or already stored).
- Behaviour: empty phone field keeps whatever is stored (no number is deleted from here); a non-empty invalid number blocks saving with the `phoneInvalid` message; the number is never written to `users/{uid}`.

- [ ] **Step 1: Write the failing tests**

In `test/features/settings/settings_test.dart`:

1. Add imports `package:photobooking/data/user/user_contact_providers.dart` and `package:photobooking/data/user/user_contact_repository.dart`.
2. Give `_app` an optional `FakeUserContactRepository? contacts` parameter and add `userContactRepositoryProvider.overrideWithValue(contacts ?? FakeUserContactRepository())` to the `overrides` list. (Without this the S42 screen would build a real Firestore repository in tests.)
3. Append inside `main()`:

```dart
  testWidgets('editing the phone saves it to the private contact only', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    final contacts = FakeUserContactRepository();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs, contacts: contacts));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('edit-phone')), '0903123456');
    await tester.tap(find.byKey(const Key('edit-allow-whatsapp')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();

    final uid = auth.currentUser!.uid;
    expect(
      contacts.stored(uid),
      const UserContact(phone: '+84903123456', allowZalo: true, allowWhatsApp: true),
    );
    expect((await users.watch(uid).first)!.toJson().containsKey('phone'), isFalse);
  });

  testWidgets('an invalid phone blocks saving', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    final contacts = FakeUserContactRepository();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs, contacts: contacts));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit-phone')), '90312345');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    expect(find.text('Số điện thoại chưa đúng. Ví dụ: 903 123 456'), findsOneWidget);
    expect(contacts.stored(auth.currentUser!.uid), isNull);
    expect(find.byType(SettingsScreen), findsNothing); // still on the edit screen
  });

  testWidgets('a stored number prefills the field and an empty field keeps it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    final contacts = FakeUserContactRepository()
      ..seed(auth.currentUser!.uid, const UserContact(phone: '+84903123456', allowZalo: false));
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs, contacts: contacts));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '903 123 456'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('edit-allow-zalo'))).value, isFalse);

    await tester.enterText(find.byKey(const Key('edit-phone')), '');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    expect(contacts.stored(auth.currentUser!.uid)!.phone, '+84903123456');
  });
```

(The existing name-only tests keep passing: an empty phone with no stored contact writes nothing.)

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/settings/settings_test.dart`
Expected: FAIL, no widget with key `edit-phone`.

- [ ] **Step 3: Implement**

`edit_profile_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';

/// Saves the profile form. Its value turns true once a save has gone through.
class EditProfileController extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  /// [phone] is E.164. The contact is written only when there is a number;
  /// it goes to the private contact, never to the public profile.
  Future<void> save({
    required String displayName,
    String? phone,
    bool allowZalo = true,
    bool allowWhatsApp = false,
  }) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(userRepositoryProvider)
          .setDisplayName(uid, displayName.trim());
      if (phone != null) {
        await ref.read(userContactRepositoryProvider).save(
          uid,
          phone: phone,
          allowZalo: allowZalo,
          allowWhatsApp: allowWhatsApp,
        );
      }
      return true;
    });
  }
}

final editProfileControllerProvider =
    AsyncNotifierProvider.autoDispose<EditProfileController, bool>(
      EditProfileController.new,
    );
```

`edit_profile_screen.dart` (full file; keeps the `ScreenCode` wrapper from the screen-codes plan; if that plan has not run, drop the `ScreenCode(...)` wrapper and the `ScreenCodes` use):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/auth/auth_form_validators.dart';
import 'package:photobooking/features/settings/edit_profile_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: ref.read(currentProfileProvider).value?.displayName ?? '',
  );
  final _phone = TextEditingController();
  bool _zalo = true;
  bool _whatsApp = false;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    // Fill the phone section once, when the stored contact first arrives; a
    // later stream update must not overwrite what the person is typing.
    ref.listenManual(currentContactProvider, (_, next) {
      final c = next.value;
      if (_prefilled || c == null) return;
      _prefilled = true;
      setState(() {
        _phone.text = nationalFromE164(c.phone);
        _zalo = c.allowZalo;
        _whatsApp = c.allowWhatsApp;
      });
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final saving = ref.watch(editProfileControllerProvider).isLoading;
    ref.listen(editProfileControllerProvider, (prev, next) {
      if (next.isLoading || !(prev?.isLoading ?? false)) return;
      final messenger = ScaffoldMessenger.of(context);
      if (next.hasError) {
        messenger.showSnackBar(SnackBar(content: Text(l.editProfileError)));
      } else if (next.value ?? false) {
        messenger.showSnackBar(SnackBar(content: Text(l.editProfileSaved)));
        context.pop();
      }
    });
    void save() {
      if (!_form.currentState!.validate()) return;
      // Empty field: keep any stored number (saving the toggles with it).
      final phone =
          phoneFromField(_phone.text) ??
          ref.read(currentContactProvider).value?.phone;
      ref
          .read(editProfileControllerProvider.notifier)
          .save(
            displayName: _name.text,
            phone: phone,
            allowZalo: _zalo,
            allowWhatsApp: _whatsApp,
          );
    }

    return ScreenCode(
      ScreenCodes.editProfile,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.editProfileTitle)),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.s5),
              child: GlassCard(
                highlight: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s5),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: const Key('edit-name'),
                          controller: _name,
                          enabled: !saving,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: InputDecoration(
                            labelText: l.displayNameLabel,
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) => validateName(v, l),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        PhoneField(
                          key: const Key('edit-phone'),
                          controller: _phone,
                          enabled: !saving,
                          // Optional here: empty means "leave as is".
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? null
                              : validatePhone(v, l),
                        ),
                        SwitchListTile(
                          key: const Key('edit-allow-zalo'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.allowZaloLabel),
                          value: _zalo,
                          onChanged: saving ? null : (v) => setState(() => _zalo = v),
                        ),
                        SwitchListTile(
                          key: const Key('edit-allow-whatsapp'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.allowWhatsAppLabel),
                          value: _whatsApp,
                          onChanged: saving ? null : (v) => setState(() => _whatsApp = v),
                        ),
                        Text(l.phonePrivacy, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: AppSpace.s5),
                        AppButton.primary(
                          l.editProfileSave,
                          key: const Key('edit-save'),
                          loading: saving,
                          onPressed: save,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

If the screen-codes plan's `test/features/screen_codes_applied_test.dart` exists, add `userContactRepositoryProvider.overrideWithValue(FakeUserContactRepository())` to its `ProviderScope` overrides (the S42 case now reads the contact provider).

- [ ] **Step 4: Run the whole suite**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(settings): S42 phone number and Zalo/WhatsApp permissions

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Align the specs with what was built

**Files:**
- Modify: `docs/superpowers/specs/screens/booking.md` (S33), `docs/superpowers/specs/components/shared-components.md` (PhoneField), `docs/superpowers/specs/screens/account.md` (S42)

**Interfaces:** none (documentation).

- [ ] **Step 1: Edit**

1. `booking.md`, S33 **Chuỗi**: replace `s33_errorFormat` "Số cần 10 chữ số, bắt đầu bằng 0" with `s33_errorFormat` "Số điện thoại chưa đúng. Ví dụ: 903 123 456" (the field has a fixed +84 prefix and strips a leading 0, so "bắt đầu bằng 0" no longer applies). In **Thông tin**, change "(sheet)" to "(sheet; bản đầu là trang đầy đủ, chuyển vào `AppBottomSheet` khi widget đó có)".
2. `shared-components.md`, PhoneField: add "Văn bản trong ô luôn ở dạng quốc nội `903 123 456`; dán `0903…` hoặc `+84…` được chuẩn hoá; gõ từng ký tự `+` không được coi là mã nước. Đọc số bằng `phoneFromField`."
3. `account.md`, S42 **Thay đổi cần làm**: add "Ô số điện thoại để trống = giữ nguyên số đã lưu (không xoá số từ màn này). Đổi ảnh đại diện làm ở kế hoạch 2d."
4. Run `git diff --stat docs/` and read the three hunks once.

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs
git commit -m "docs: align S33, S42 and PhoneField specs with the implementation

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Battery and performance check

**Files:**
- Create: `test/features/contact/phone_screens_idle_test.dart`; `test/support/idle.dart` if missing
- Modify: `lib/data/user/user_contact_repository.dart` (fake counts its listeners), `lib/data/user/user_contact_providers.dart` (`autoDispose`), `test/features/settings/settings_test.dart`

**Interfaces:**
- Consumes: `expectIdle`; the S33 harness pattern of Task 5; `_app`/`_signedIn` of `settings_test.dart`.
- Produces: `FakeUserContactRepository.watchers` (`int`, open `watch` subscriptions across all users). `currentContactProvider` becomes `StreamProvider.autoDispose`: the private-contact listener lives only while a screen that needs it (S33, S42, later the booking gate) is open.

- [ ] **Step 1: Write the failing tests**

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

```dart
// test/features/contact/phone_screens_idle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/contact/add_phone_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/idle.dart';

void main() {
  testWidgets('S33 is idle at rest and after typing a number', (tester) async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await users.ensureProfile(u);
    final router = GoRouter(
      initialLocation: '/profile/phone',
      routes: [
        GoRoute(path: '/profile/phone', builder: (_, _) => const AddPhoneScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
          userContactRepositoryProvider.overrideWithValue(FakeUserContactRepository()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    // The field autofocuses; a blinking caret is the only allowed motion, so
    // drop focus before checking.
    FocusManager.instance.primaryFocus?.unfocus();
    await expectIdle(tester);
    await tester.enterText(find.byType(TextFormField), '0903123456');
    FocusManager.instance.primaryFocus?.unfocus();
    await expectIdle(tester);
  });

  test('the fake counts open listeners', () async {
    final repo = FakeUserContactRepository();
    final sub = repo.watch('u1').listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(repo.watchers, 1);
    await sub.cancel();
    expect(repo.watchers, 0);
  });
}
```

Append to `main()` in `test/features/settings/settings_test.dart` (add `import '../../support/idle.dart';`):

```dart
  testWidgets('S42 listens to the private contact only while open', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    final contacts = FakeUserContactRepository();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs, contacts: contacts));
    await tester.pumpAndSettle();
    expect(contacts.watchers, 0);

    await tester.tap(find.byKey(const Key('settings-edit-profile')));
    await tester.pumpAndSettle();
    expect(contacts.watchers, 1);
    await expectIdle(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(contacts.watchers, 0);
  });
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/contact/phone_screens_idle_test.dart test/features/settings/settings_test.dart`
Expected: FAIL to compile, `watchers` is not defined on `FakeUserContactRepository`. (After Step 3's fake change alone, the S42 test still fails on the last line with "Expected: <0> Actual: <1>" because the provider is not `autoDispose`.)

- [ ] **Step 3: Implement**

In `lib/data/user/user_contact_repository.dart`, `FakeUserContactRepository`: add the counter and replace `watch` so cancellation is observable:

```dart
  /// Open [watch] subscriptions, so tests can prove screens stop listening.
  int watchers = 0;

  @override
  Stream<UserContact?> watch(String uid) {
    late final StreamController<UserContact?> out;
    StreamSubscription<UserContact?>? inner;
    out = StreamController<UserContact?>(
      onListen: () {
        watchers++;
        out.add(_contacts[uid]);
        inner = _c(uid).stream.listen(out.add);
      },
      onCancel: () async {
        watchers--;
        await inner?.cancel();
      },
    );
    return out.stream;
  }
```

In `lib/data/user/user_contact_providers.dart` change `final currentContactProvider = StreamProvider<UserContact?>(` to `final currentContactProvider = StreamProvider.autoDispose<UserContact?>(` (body unchanged).

- [ ] **Step 4: Run the whole suite**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests pass (the Task 3 fake tests still pass: the first value is emitted on listen, then every change).

- [ ] **Step 5: Manual profiling on a real Android device**

Follow `docs/testing/battery-and-performance.md` for the screens listed below (Genymotion is fine for the frame checks, but battery numbers need a real phone). Record the filled-in result table from that document in the PR description. Any value over a threshold blocks the merge: fix it in this plan's code, add a test that would have caught it, and re-measure.

Screens: S33 and S42. Scenario for the battery step: open S42, type and save a number, open S33 from a debug deep link (`adb shell am start -a android.intent.action.VIEW -d "photobooking://app/profile/phone"` only if deep links are configured; otherwise reach it with a temporary button you do not commit), save, go back, leave the app idle on Settings. Check in Firebase console (Firestore usage) or with `adb logcat | grep -i firestore` that no listener stays open after leaving S42.

- [ ] **Step 6: Commit**

```bash
git add lib/data/user test/features/contact/phone_screens_idle_test.dart test/features/settings/settings_test.dart test/support
git commit -m "perf(contact): stop the private-contact listener when its screens close

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** 3b.3 normalisation and `PhoneField` (Tasks 1–2); `users/{uid}/private/contact` with `phone` E.164, `allowZalo`, `allowWhatsApp`, `phoneVerified:false` (Tasks 3–4); rules "chỉ chủ đọc/ghi" and no phone in public `users` (Task 4); S33 flow with `returnTo`, defaults Zalo on / WhatsApp off, privacy note, enable-only-when-valid, failed-save snackbar (Task 5); S42 phone section, number never in `users/{uid}` (Task 6); §7 test examples `0903123456`, `+84 903 123 456`, `090312345`, `0123456789` (Task 1). **Deferred on purpose:** the booking-side `phone_required` gate and "đóng không lưu → huỷ luồng đặt" (plan with step 4, which will call `/profile/phone?returnTo=…`); "Số điện thoại" row on S30 and avatar change on S42 (2d); server-side `phone_required` (Cloud Functions, step 4).
- **Placeholders:** none.
- **Type consistency:** `UserContact`, `UserContactRepository.save(uid, {phone, allowZalo, allowWhatsApp})`, `FakeUserContactRepository.seed/stored`, `phoneFromField`, `nationalFromE164`, `validatePhone`, `safeReturnTo`, `saveContactControllerProvider`, `AddPhoneScreen(returnTo)` and the widget keys (`phone-save`, `allow-zalo`, `allow-whatsapp`, `edit-phone`, `edit-allow-zalo`, `edit-allow-whatsapp`) are named identically in tests and code.
- **Risk to watch:** the rules expression using `let` and `get()` on possibly-null `resource` (Task 4 Step 4 says what to do if the emulator disagrees); `enterText` on a keyed `PhoneField` (it has exactly one `EditableText`, so the finder resolves).
- **Battery and performance:** Task 8 adds idle tests for S33/S42, a listener counter on the fake, and makes `currentContactProvider` `autoDispose` so the Firestore listener closes with the screen.
