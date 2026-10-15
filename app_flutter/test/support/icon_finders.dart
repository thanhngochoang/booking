import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// An [Icon] showing [icon] with the filled variant (FILL 1): selected,
/// saved, liked or active.
Finder filledIcon(IconData icon) => find.byWidgetPredicate(
  (w) => w is Icon && w.icon == icon && w.fill == 1,
  description: 'filled $icon',
);

/// An [Icon] showing [icon] as an outline (FILL 0).
Finder outlineIcon(IconData icon) => find.byWidgetPredicate(
  (w) => w is Icon && w.icon == icon && (w.fill ?? 0) == 0,
  description: 'outline $icon',
);
