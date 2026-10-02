import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/phone.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

const double _codeBoxWidth = 72;
const String _dialCode = '+84';

/// Phone number input. By default two boxes (mock S33): a read-only "Mã +84"
/// box, then the number. In [international] mode the code box is hidden (the
/// number carries its own `+` code). The text is the national form
/// `903 123 456`; typing or pasting `0903…` or `+84…` is normalised. With [international] (WhatsApp) the field
/// holds the whole number, `+` and digits, e.g. `+14155552671`.
/// Read the number with [phoneFromField] (pass the same [international]).
///
/// Note: only a paste (or a whole-text edit) can carry a "+84" into a national
/// field; typing "+" digit by digit is read as national digits.

class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.validator,
    this.autofocus = false,
    this.international = false,
    this.label,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// Defaults to [validatePhone] (required and well-formed).
  final FormFieldValidator<String>? validator;
  final bool autofocus;

  /// Accept any country's number (`+` and 8–15 digits), for WhatsApp.
  final bool international;

  /// Replaces the default "Số điện thoại".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final number = TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: [
        international
            ? AutofillHints.telephoneNumber
            : AutofillHints.telephoneNumberNational,
      ],
      inputFormatters: [
        international
            ? _InternationalPhoneFormatter()
            : _NationalPhoneFormatter(),
      ],
      onChanged: onChanged,
      validator:
          validator ?? (v) => validatePhone(v, l, international: international),
      decoration: InputDecoration(
        labelText: label ?? l.phoneLabel,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: international ? '+1 415 555 2671' : '903 123 456',
        errorText: errorText,
      ),
    );
    if (international) return number;
    // Mock S33/S34/S42: a fixed "Mã +84" box (72dp), then the number.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeFocus(
          child: Semantics(
            label: l.phoneCodeSemantics,
            excludeSemantics: true,
            child: SizedBox(
              key: const Key('phone-code-box'),
              width: _codeBoxWidth,
              child: InputDecorator(
                isEmpty: false,
                decoration: InputDecoration(
                  labelText: l.phoneCodeLabel,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  enabled: enabled,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s3,
                    vertical: AppSpace.s4,
                  ),
                ),
                child: Text(
                  _dialCode,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        Expanded(child: number),
      ],
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

class _InternationalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    final text = internationalInput(next.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
