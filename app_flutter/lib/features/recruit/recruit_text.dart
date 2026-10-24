import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/core.dart';

/// Length of [text] as the S27 server counts it: Unicode code points (the
/// server normalises to NFC first; the keyboards send composed Vietnamese,
/// so this never undercounts).
int recruitTextLength(String text) => text.runes.length;

/// Keeps a field at most [max] code points ([recruitTextLength]), cutting a
/// paste at a character boundary (an emoji is never split). Left alone
/// while the keyboard is composing, like `LengthLimitingTextInputFormatter`.
class RecruitTextLimit extends TextInputFormatter {
  const RecruitTextLimit(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid) return newValue;
    if (recruitTextLength(newValue.text) <= max) return newValue;
    final out = StringBuffer();
    var used = 0;
    for (final c in newValue.text.characters) {
      final n = recruitTextLength(c);
      if (used + n > max) break;
      out.write(c);
      used += n;
    }
    final text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// "{n}/{max}" under a field, in code points; rebuilds as [controller]
/// changes.
class RecruitTextCounter extends StatelessWidget {
  const RecruitTextCounter({
    super.key,
    required this.controller,
    required this.max,
  });

  final TextEditingController controller;
  final int max;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => Text(
          '${recruitTextLength(value.text)}/$max',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: AppText.xs2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
}
