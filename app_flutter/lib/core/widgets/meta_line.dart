// lib/core/widgets/meta_line.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/verdict_icon.dart';

/// One part of a [MetaLine]: plain text, or the tomato icon with a percent.
sealed class MetaPart {
  const factory MetaPart.text(String text) = _TextPart;

  /// Shown as the tomato icon and `97%`, or `97% (58)` with a [count] (the
  /// S02.01 photo cards). Callers add it only when the provider has enough
  /// reviews (`hasTomatoPct`).
  const factory MetaPart.tomato(int pct, {int? count}) = _TomatoPart;
}

String _tomatoText(int pct, int? count) =>
    count == null ? formatTomatoPct(pct) : '${formatTomatoPct(pct)} ($count)';

/// The text of [parts] as [MetaLine] reads it (` · ` between parts, the
/// tomato icon left out): for semantics labels and tests.
String metaPartsText(List<MetaPart> parts) => parts
    .map(
      (part) => switch (part) {
        _TextPart(:final text) => text,
        _TomatoPart(:final pct, :final count) => _tomatoText(pct, count),
      },
    )
    .join(' · ');

class _TextPart implements MetaPart {
  const _TextPart(this.text);
  final String text;
}

class _TomatoPart implements MetaPart {
  const _TomatoPart(this.pct, {this.count});
  final int pct;
  final int? count;
}

/// A one-line meta row of parts joined with ` · ` (mock `.meta`, `.tm`), e.g.
/// `Quận 3 · 🍅 97% · 112 buổi` with the tomato drawn as [VerdictIcon].
class MetaLine extends StatelessWidget {
  const MetaLine(this.parts, {super.key, this.style, this.maxLines = 1});

  final List<MetaPart> parts;

  /// Defaults to 12 pt in the secondary foreground colour.
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = TextStyle(
      fontSize: 12,
      color: dark
          ? AppColorsDark.foregroundSecondary
          : AppColors.foregroundSecondary,
    ).merge(style);
    final spans = <InlineSpan>[];
    for (final part in parts) {
      if (spans.isNotEmpty) spans.add(const TextSpan(text: ' · '));
      switch (part) {
        case _TextPart(:final text):
          spans.add(TextSpan(text: text));
        case _TomatoPart(:final pct, :final count):
          spans.add(
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: 2),
                child: VerdictIcon(VerdictKind.tomato, size: 12),
              ),
            ),
          );
          spans.add(TextSpan(text: _tomatoText(pct, count)));
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      style: base,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
