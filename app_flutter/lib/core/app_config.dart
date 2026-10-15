/// Build-time app settings shared by every feature.
library;

const String _supportEmailRaw = String.fromEnvironment('SUPPORT_EMAIL');

/// The support address shown on platform-hosted events (S11.02), on S21.02
/// final rejections and revocations, and in help, until the support inbox
/// (S23.06) exists (owner decision O2). Build config, set later by the owner:
/// `--dart-define=SUPPORT_EMAIL=...`. Unset (empty) hides the line.
const String? supportEmail = _supportEmailRaw == '' ? null : _supportEmailRaw;

/// `mailto:` for [email]; null while it is unset.
Uri? supportEmailUri([String? email = supportEmail]) =>
    email == null ? null : Uri(scheme: 'mailto', path: email);
