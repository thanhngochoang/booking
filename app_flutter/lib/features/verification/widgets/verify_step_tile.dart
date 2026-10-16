// lib/features/verification/widgets/verify_step_tile.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';

/// How a step row reads: done ("Xong"), the step being worked on ("Đang
/// làm"), not started ("Chưa làm"), or reopened by a rejection ("Cần sửa").
enum VerifyTileState { done, now, todo, fix }

/// One row of the S21.02 step list (mock `.vstep`): a numbered circle (a
/// check once done, or [icon] for a fix row), title, subtitle and the state
/// as text, so it never relies on colour alone. [onTap] opens the step.
class VerifyStepTile extends StatelessWidget {
  const VerifyStepTile({
    super.key,
    required this.index,
    this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    this.onTap,
  });

  /// 1-based position, shown in the circle while the step is not done.
  final int index;

  /// Replaces the number in the circle (fix rows: the item to change).
  final IconData? icon;
  final String title;
  final String subtitle;
  final VerifyTileState state;
  final VoidCallback? onTap;

  /// Mock `.vstep .no`.
  static const _circle = 26.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? AppColorsDark.accent : AppColors.accent;
    final accentSoft = dark ? AppColorsDark.accentSoft : AppColors.accentSoft;
    final success = dark ? AppColorsDark.success : AppColors.success;
    final freeInk = dark ? AppColorsDark.freeInk : AppColors.freeInk;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final line = dark ? AppColorsDark.border : AppColors.border;
    final lineStrong = dark
        ? AppColorsDark.borderStrong
        : AppColors.borderStrong;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final onSuccess = dark
        ? AppColorsDark.foregroundInverse
        : AppColors.foregroundInverse;

    final highlighted =
        state == VerifyTileState.now || state == VerifyTileState.fix;
    final stateText = switch (state) {
      VerifyTileState.done => l.verifyStateDone,
      VerifyTileState.now => l.verifyStateNow,
      VerifyTileState.todo => l.verifyStateTodo,
      VerifyTileState.fix => l.verifyStateFix,
    };
    final stateStyle = switch (state) {
      VerifyTileState.done => theme.textTheme.labelSmall?.copyWith(
        color: freeInk,
        fontWeight: FontWeight.w600,
      ),
      VerifyTileState.now ||
      VerifyTileState.fix => theme.textTheme.labelSmall?.copyWith(
        color: secondary,
        fontWeight: FontWeight.w600,
      ),
      VerifyTileState.todo => theme.textTheme.labelSmall?.copyWith(
        color: muted,
      ),
    };

    final circle = Container(
      width: _circle,
      height: _circle,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: state == VerifyTileState.done ? success : null,
        border: Border.all(
          width: 2,
          color: switch (state) {
            VerifyTileState.done => success,
            VerifyTileState.now || VerifyTileState.fix => accent,
            VerifyTileState.todo => lineStrong,
          },
        ),
      ),
      child: switch ((state, icon)) {
        (VerifyTileState.done, _) => AppIcon(
          AppIcons.check,
          size: AppText.base,
          color: onSuccess,
        ),
        (_, final IconData i?) => AppIcon(
          i,
          size: AppText.base,
          color: highlighted ? accent : muted,
        ),
        _ => Text(
          '$index',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: highlighted ? accent : muted,
          ),
        ),
      },
    );

    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        selected: highlighted,
        child: Material(
          color: highlighted ? accentSoft : glass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: highlighted ? accent : line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3,
                  vertical: AppSpace.s2,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(child: circle),
                    const SizedBox(width: AppSpace.s2h),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: secondary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Text(stateText, style: stateStyle),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
