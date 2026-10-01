/// Shared building blocks for every feature: theme, tokens and widgets.
///
/// Features import this one file; files inside `core/` import each other
/// directly to keep the barrel free of cycles.
library;

export 'package:photobooking/core/l10n_ext.dart';
export 'package:photobooking/core/screen_codes.dart';
export 'package:photobooking/core/theme/app_theme.dart';
export 'package:photobooking/core/theme/tokens.g.dart';
export 'package:photobooking/core/widgets/app_button.dart';
export 'package:photobooking/core/widgets/app_logo.dart';
export 'package:photobooking/core/widgets/aurora_background.dart';
export 'package:photobooking/core/widgets/aurora_hero.dart';
export 'package:photobooking/core/widgets/capacity_bar.dart';
export 'package:photobooking/core/widgets/cta_surface.dart';
export 'package:photobooking/core/widgets/empty_state.dart';
export 'package:photobooking/core/widgets/free_tag.dart';
export 'package:photobooking/core/widgets/glass_card.dart';
export 'package:photobooking/core/widgets/screen_code.dart';
export 'package:photobooking/core/widgets/stat_tile.dart';
export 'package:photobooking/core/widgets/status_badge.dart';
export 'package:photobooking/core/widgets/tab_badge.dart';
export 'package:photobooking/core/widgets/verified_mark.dart';
