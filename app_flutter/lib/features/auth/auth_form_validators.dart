import '../../l10n/app_localizations.dart';

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? v, AppLocalizations l) =>
    (v == null || !_email.hasMatch(v.trim())) ? l.errorEmailInvalid : null;

String? validatePassword(String? v, AppLocalizations l) =>
    (v == null || v.length < 8) ? l.errorPasswordShort : null;

String? validateConfirm(String? v, String other, AppLocalizations l) =>
    v != other ? l.errorPasswordMismatch : null;

String? validateName(String? v, AppLocalizations l) =>
    (v == null || v.trim().isEmpty) ? l.errorNameEmpty : null;
