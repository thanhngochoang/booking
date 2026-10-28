// lib/core/widgets/meta_line.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/widgets/verdict_icon.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// One part of a [MetaLine]: plain text, or the tomato icon with a percent.
sealed class MetaPart {
  /// [bold], when it occurs in [text], is drawn bold in tabular figures
  /// (mock `<b class="tn">`, e.g. "đến trong khoảng **9 phút**").
  const factory MetaPart.text(String text, {String? bold}) = _TextPart;

  /// Shown as the tomato icon and `97%`, or `97% (58)` with a [count] (the
  /// S02.01 photo cards). Callers add it only when the provider has enough
  /// reviews (`hasTomatoPct`).
  const factory MetaPart.tomato(int pct, {int? count}) = _TomatoPart;
}

String _tomatoText(int pct, int? count) =>
    count == null ? formatTomatoPct(pct) : '${formatTomatoPct(pct)} ($count)';

/// What a screen reader hears for the tomato part: "97% cà chua", or
/// "97% cà chua, 58 đánh giá" with a count (the icon itself is decorative).
String _tomatoSpoken(AppLocalizations l, int pct, int? count) => count == null
    ? l.tomatoPctA11y(pct)
    : l.tomatoPctCountA11y(pct, count);

/// The text of [parts] as [MetaLine] shows it (` · ` between parts, the
/// tomato icon left out), e.g. `Quận 3 · 97% · 112 buổi`.
String metaPartsText(List<MetaPart> parts) => parts
    .map(
      (part) => switch (part) {
        _TextPart(:final text) => text,
        _TomatoPart(:final pct, :final count) => _tomatoText(pct, count),
      },
    )
    .join(' · ');

/// The spoken form of [parts] for a parent's semantics label: like
/// [metaPartsText], but the tomato part says what the percent is
/// (`Quận 3 · 97% cà chua · 112 buổi`).
String metaPartsSemantics(List<MetaPart> parts, AppLocalizations l) => parts
    .map(
      (part) => switch (part) {
        _TextPart(:final text) => text,
        _TomatoPart(:final pct, :final count) => _tomatoSpoken(l, pct, count),
      },
    )
    .join(' · ');

class _TextPart implements MetaPart {
  const _TextPart(this.text, {this.bold});
  final String text;
  final String? bold;
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
        case _TextPart(:final text, :final bold):
          final at = bold == null || bold.isEmpty ? -1 : text.indexOf(bold);
          if (at < 0) {
            spans.add(TextSpan(text: text));
          } else {
            spans
              ..add(TextSpan(text: text.substring(0, at)))
              ..add(
                TextSpan(
                  text: bold,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              )
              ..add(TextSpan(text: text.substring(at + bold!.length)));
          }
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
    // One label for the whole line, with the tomato part spoken as
    // "97% cà chua" (the icon is decorative and the span would split it).
    return Semantics(
      label: metaPartsSemantics(parts, context.l10n),
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(children: spans),
        style: base,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
