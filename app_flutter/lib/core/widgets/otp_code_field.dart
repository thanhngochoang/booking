// lib/core/widgets/otp_code_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Number of digits in a one-time code.
const int otpCodeLength = 6;

/// One field for a 6-digit one-time code: digits only, number keyboard, the
/// SMS autofill hint, wide tabular digits. [onCompleted] fires when the 6th
/// digit is typed (or pasted); [errorText] shows under the field.
class OtpCodeField extends StatelessWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.errorText,
    this.onCompleted,
    this.labelText,
    this.enabled = true,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onCompleted;
  final String? labelText;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      enableSuggestions: false,
      autocorrect: false,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(otpCodeLength),
      ],
      style: theme.textTheme.titleLarge?.copyWith(
        letterSpacing: AppSpace.s2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      onChanged: (v) {
        if (v.length == otpCodeLength) onCompleted?.call(v);
      },
      decoration: InputDecoration(
        labelText: labelText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        errorText: errorText,
        errorMaxLines: 3,
      ),
    );
  }
}
