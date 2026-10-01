import 'package:flutter/material.dart';

enum _Kind { primary, outline, text }

class AppButton extends StatelessWidget {
  const AppButton.primary(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
  }) : _kind = _Kind.primary;
  const AppButton.outline(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
  }) : _kind = _Kind.outline;
  const AppButton.text(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
  }) : _kind = _Kind.text;

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
    final cb = loading ? null : onPressed;
    return switch (_kind) {
      _Kind.primary => FilledButton(onPressed: cb, child: child),
      _Kind.outline => OutlinedButton(onPressed: cb, child: child),
      _Kind.text => TextButton(onPressed: cb, child: child),
    };
  }
}
