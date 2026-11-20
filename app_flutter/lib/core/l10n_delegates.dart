import 'package:material_ui/material_ui.dart';

import 'package:photobooking/l10n/app_localizations.dart';

/// The app's single localization delegate list.
///
/// The list `flutter gen-l10n` emits on `AppLocalizations` carries the legacy
/// `flutter_localizations` delegates, not the `material_ui` / `cupertino_ui`
/// ones the widgets look up, so the app and tests use this list instead.
/// `GlobalMaterialLocalizations.delegates` covers the Material, Cupertino and
/// Widgets delegates.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ];
