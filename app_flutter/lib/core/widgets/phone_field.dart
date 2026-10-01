import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/phone.dart';

/// Vietnamese phone number input with a fixed "+84" prefix. The text is the
/// national form `903 123 456`; typing or pasting `0903…` or `+84…` is
/// normalised. Read the number with [phoneFromField].
///
/// Note: only a paste (or a whole-text edit) can carry a "+84"; typing "+"
/// digit by digit is read as national digits.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.validator,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// Defaults to [validatePhone] (required and well-formed).
  final FormFieldValidator<String>? validator;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [_NationalPhoneFormatter()],
      onChanged: onChanged,
      validator: validator ?? (v) => validatePhone(v, l),
      decoration: InputDecoration(
        labelText: l.phoneLabel,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: '903 123 456',
        prefixText: '+84 ',
        prefixIcon: const Icon(Icons.phone_outlined),
        errorText: errorText,
      ),
    );
  }
}

class _NationalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    final text = formatNational(nationalDigits(next.text));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
