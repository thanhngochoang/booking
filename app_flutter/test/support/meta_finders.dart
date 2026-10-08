import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

/// The [MetaLine] whose text (parts joined by " · ", icon left out) is [text].
Finder findMeta(String text) => find.byWidgetPredicate(
  (w) => w is MetaLine && metaPartsText(w.parts) == text,
  description: 'MetaLine "$text"',
);

/// The tomato icon drawn inside [meta].
Finder tomatoIconIn(Finder meta) => find.descendant(
  of: meta,
  matching: find.byWidgetPredicate(
    (w) => w is VerdictIcon && w.kind == VerdictKind.tomato,
  ),
);
