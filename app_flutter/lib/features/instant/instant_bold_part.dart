// A sentence with one part bold in tabular figures (mock `<b class="tn">`):
// a time or an amount inside Chụp ngay copy.
import 'package:flutter/material.dart';

class InstantBoldPart extends StatelessWidget {
  const InstantBoldPart(
    this.text, {
    super.key,
    required this.part,
    this.style,
    this.textAlign,
  });

  final String text;

  /// Drawn bold where it first occurs in [text]; absent → plain [text].
  final String part;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final at = part.isEmpty ? -1 : text.indexOf(part);
    if (at < 0) return Text(text, style: style, textAlign: textAlign);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: part,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(text: text.substring(at + part.length)),
        ],
      ),
      style: style,
      textAlign: textAlign,
    );
  }
}
