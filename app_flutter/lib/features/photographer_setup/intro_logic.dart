import 'package:flutter/foundation.dart';

import 'package:photobooking/l10n/app_localizations.dart';

const kBioMaxLength = 300;
const kEquipmentMax = 8;
const kEquipmentItemMax = 40;

enum IntroField { name, bio }

enum IntroError { nameRequired, bioRequired, bioTooLong }

@immutable
class IntroInput {
  const IntroInput({
    required this.displayName,
    required this.bio,
    this.equipment = const [],
  });

  final String displayName;
  final String bio;
  final List<String> equipment;
}

/// Cleaned values and the problems found; save only when [ok].
@immutable
class IntroResult {
  const IntroResult({
    required this.errors,
    required this.displayName,
    required this.bio,
    this.equipment = const [],
  });

  final Map<IntroField, IntroError> errors;
  final String displayName;
  final String bio;
  final List<String> equipment;

  bool get ok => errors.isEmpty;
}

/// Trims, drops empty and duplicate (ignoring case) names, cuts each to
/// [kEquipmentItemMax] characters and keeps the first [kEquipmentMax].
List<String> cleanEquipment(Iterable<String> raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final e in raw) {
    var t = e.trim();
    if (t.isEmpty) {
      continue;
    }
    if (t.length > kEquipmentItemMax) {
      t = t.substring(0, kEquipmentItemMax).trim();
    }
    if (seen.add(t.toLowerCase())) {
      out.add(t);
    }
    if (out.length == kEquipmentMax) {
      break;
    }
  }
  return out;
}

IntroResult validateIntro(IntroInput input) {
  final errors = <IntroField, IntroError>{};
  final name = input.displayName.trim();
  final bio = input.bio.trim();
  if (name.isEmpty) {
    errors[IntroField.name] = IntroError.nameRequired;
  }
  if (bio.isEmpty) {
    errors[IntroField.bio] = IntroError.bioRequired;
  } else if (bio.length > kBioMaxLength) {
    errors[IntroField.bio] = IntroError.bioTooLong;
  }
  return IntroResult(
    errors: errors,
    displayName: name,
    bio: bio,
    equipment: cleanEquipment(input.equipment),
  );
}

String introErrorText(IntroError e, AppLocalizations l) => switch (e) {
  IntroError.nameRequired => l.errorNameEmpty,
  IntroError.bioRequired => l.introBioRequired,
  IntroError.bioTooLong => l.introBioTooLong,
};
