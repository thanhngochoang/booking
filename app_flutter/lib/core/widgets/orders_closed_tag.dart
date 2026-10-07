// lib/core/widgets/orders_closed_tag.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_button.dart';

/// The dashed "Chưa nhận đơn" tag of S03.01 (mock `.ptag.off`): the same pill
/// as [ProviderTag] (sizes, secondary ink), with a lock icon and a dashed
/// outline in the mock's `--line-2` (the theme's `outline`).
class OrdersClosedTag extends StatelessWidget {
  const OrdersClosedTag({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.l10n.profileOrdersClosedTag;
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: CustomPaint(
          foregroundPainter: _DashedPillPainter(theme.colorScheme.outline),
          child: Padding(
            // Mock `.ptag`: padding 2px 8px 2px 6px, gap 4px, 11px icon,
            // 10px text; as [ProviderTag].
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s1 * 1.5,
              AppSpace.s1 / 2,
              AppSpace.s2,
              AppSpace.s1 / 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(AppIcons.lock, size: AppText.xs2, color: color),
                const SizedBox(width: AppSpace.s1),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppText.xs,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 1px dashed outline (dash 3, gap 2) along a fully rounded rect.
class _DashedPillPainter extends CustomPainter {
  const _DashedPillPainter(this.color);

  final Color color;

  static const _dash = 3.0;
  static const _gap = 2.0;
  static const _stroke = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final outline = Path()
      ..addRRect(
        // A pill: half the height, as AppRadius.full renders.
        RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide / 2)),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = color;
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Mock `.btn.out.dis`: the outline button of a provider not accepting orders
/// ("Chưa nhận đặt lịch", S03.01-new and photo detail), disabled, at 60% with
/// secondary ink. The outline button has no fill, so 60% on the label and the
/// `--line-2` border is the mock's `opacity:.6`. Pass as [AppButton.style].
ButtonStyle ordersClosedButtonStyle(BuildContext context) {
  final theme = Theme.of(context);
  final secondary = theme.brightness == Brightness.dark
      ? AppColorsDark.foregroundSecondary
      : AppColors.foregroundSecondary;
  return OutlinedButton.styleFrom(
    disabledForegroundColor: secondary.withValues(alpha: _lockedOpacity),
    side: BorderSide(
      color: theme.colorScheme.outline.withValues(alpha: _lockedOpacity),
    ),
  );
}

/// Mock `.btn.out.dis{opacity:.6}`.
const _lockedOpacity = 0.6;
