// lib/core/widgets/confirm_sheet.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_bottom_sheet.dart';
import 'package:photobooking/core/widgets/app_button.dart';

/// Shows a standard confirmation bottom sheet.
///
/// Features a safe button (outline) on the left ("keep"), and a confirmation button
/// on the right ("confirm", red if [danger] is true, primary otherwise).
///
/// While [onConfirm] executes:
/// - The confirm button shows a loading spinner.
/// - Both buttons are disabled.
/// - The sheet cannot be dismissed by back gesture, barrier tap, or dragging down.
/// - If [onConfirm] throws an error, the sheet remains open and displays a SnackBar.
///
/// Returns `true` if confirmed, `false` if kept, dismissed, or cancelled.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? body,
  Widget? content,
  required String confirmLabel,
  required String keepLabel,
  bool danger = true,
  Future<void> Function()? onConfirm,
  ValueListenable<bool>? confirmEnabled,
}) {
  return showAppSheet<bool>(
    context,
    builder: (sheetContext) => _ConfirmBody(
      title: title,
      body: body,
      content: content,
      confirmLabel: confirmLabel,
      keepLabel: keepLabel,
      danger: danger,
      onConfirm: onConfirm,
      confirmEnabled: confirmEnabled,
    ),
  ).then((v) => v ?? false);
}

class _ConfirmBody extends StatefulWidget {
  const _ConfirmBody({
    required this.title,
    this.body,
    this.content,
    required this.confirmLabel,
    required this.keepLabel,
    required this.danger,
    this.onConfirm,
    this.confirmEnabled,
  });

  final String title;
  final String? body;
  final Widget? content;
  final String confirmLabel;
  final String keepLabel;
  final bool danger;
  final Future<void> Function()? onConfirm;
  final ValueListenable<bool>? confirmEnabled;

  @override
  State<_ConfirmBody> createState() => _ConfirmBodyState();
}

class _ConfirmBodyState extends State<_ConfirmBody> {
  bool _running = false;

  Future<void> _handleConfirm() async {
    if (_running) return;

    if (widget.onConfirm == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _running = true);

    try {
      await widget.onConfirm!();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _running = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _handleKeep() {
    if (_running) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    Widget buildButtons(bool enabled) {
      final keepBtn = AppButton.outline(
        widget.keepLabel,
        onPressed: _running ? null : _handleKeep,
      );

      final confirmBtn = widget.danger
          ? AppButton.danger(
              widget.confirmLabel,
              loading: _running,
              onPressed: (!_running && enabled) ? _handleConfirm : null,
            )
          : AppButton.primary(
              widget.confirmLabel,
              loading: _running,
              onPressed: (!_running && enabled) ? _handleConfirm : null,
            );

      return Row(
        children: [
          Expanded(child: keepBtn),
          const SizedBox(width: AppSpace.s2),
          Expanded(child: confirmBtn),
        ],
      );
    }

    return PopScope(
      canPop: !_running,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: _running ? (_) {} : null,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              0,
              AppSpace.s4,
              AppSpace.s4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.body != null) ...[
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    widget.body!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
                if (widget.content != null) ...[
                  const SizedBox(height: AppSpace.s3),
                  widget.content!,
                ],
                const SizedBox(height: AppSpace.s4),
                if (widget.confirmEnabled != null)
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.confirmEnabled!,
                    builder: (context, enabled, _) => buildButtons(enabled),
                  )
                else
                  buildButtons(true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
