import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

void main() {
  testWidgets('test_vi_locale_resolves_material_and_cupertino_strings', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(Localizations.localeOf(ctx).languageCode, 'vi');
    expect(MaterialLocalizations.of(ctx).cancelButtonLabel, isNot('CANCEL'));
    expect(
      Localizations.of<CupertinoLocalizations>(ctx, CupertinoLocalizations),
      isNotNull,
    );
    expect(AppLocalizations.of(ctx), isNotNull);
  });
}
