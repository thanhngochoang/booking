// lib/core/widgets/verdict_pad.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/verdict_icon.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S05.05 review pad (mock `.vpad`): two buttons, tomato and brick. One side
/// at a time: a tap on the empty or other side selects it at ×1, each further
/// tap on the selected side adds one hit up to [kVerdictHitsMax] (the next
/// tap does nothing). [kind] is null exactly when [hits] is 0.
///
/// Each side is a slider for screen readers ("Ném cà chua, 3 trên 10") with
/// increase and decrease actions; decrease at 1 clears the side. Motion is a
/// single short bounce per change, never a loop. [compact] is the one-row
/// variant of the studio block (mock `.vpad.cp`).
class VerdictPad extends StatelessWidget {
  const VerdictPad({
    super.key,
    required this.kind,
    required this.hits,
    required this.onChanged,
    this.compact = false,
    this.enabled = true,
  });

  final VerdictKind? kind;
  final int hits;
  final void Function(VerdictKind? kind, int hits) onChanged;
  final bool compact;
  final bool enabled;

  void _tap(VerdictKind side) {
    if (!enabled) return;
    if (kind == side) {
      if (hits >= kVerdictHitsMax) return; // 11th tap: nothing
      final next = hits + 1;
      next == kVerdictHitsMax
          ? HapticFeedback.heavyImpact()
          : HapticFeedback.lightImpact();
      onChanged(side, next);
    } else {
      HapticFeedback.lightImpact();
      onChanged(side, 1); // switch side: back to 1, no confirm
    }
  }

  void _decrease(VerdictKind side) {
    if (!enabled || kind != side) return;
    onChanged(hits <= 1 ? null : side, hits <= 1 ? 0 : hits - 1);
  }

  @override
  Widget build(BuildContext context) {
    Widget button(VerdictKind side) => Expanded(
      child: _VerdictButton(
        key: Key('verdict-${side.name}'),
        side: side,
        hits: kind == side ? hits : 0,
        compact: compact,
        enabled: enabled,
        onTap: () => _tap(side),
        onDecrease: () => _decrease(side),
      ),
    );
    return Semantics(
      container: true,
      label: context.l10n.reviewPadLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          button(VerdictKind.tomato),
          SizedBox(width: compact ? 8 : AppSpace.s2h),
          button(VerdictKind.brick),
        ],
      ),
    );
  }
}

class _VerdictButton extends StatefulWidget {
  const _VerdictButton({
    super.key,
    required this.side,
    required this.hits,
    required this.compact,
    required this.enabled,
    required this.onTap,
    required this.onDecrease,
  });

  final VerdictKind side;

  /// 0 when this side is not the selected one.
  final int hits;
  final bool compact;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onDecrease;

  @override
  State<_VerdictButton> createState() => _VerdictButtonState();
}

class _VerdictButtonState extends State<_VerdictButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.16,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.16,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 60,
    ),
  ]).animate(_bounce);

  @override
  void didUpdateWidget(_VerdictButton old) {
    super.didUpdateWidget(old);
    // One run per change of this side's count; settles at 1. Not on a
    // decrease or a reset to 0.
    if (widget.hits > old.hits && !MediaQuery.disableAnimationsOf(context)) {
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final side = widget.side;
    final selected = widget.hits > 0;
    final tomato = side == VerdictKind.tomato;
    final sideColor = verdictColor(context, side);
    final ink = dark ? AppColorsDark.foreground : AppColors.foreground;
    final ink2 = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final compact = widget.compact;
    final radius = BorderRadius.circular(
      compact ? AppRadius.xl : AppRadius.card,
    );
    final fill = selected
        ? sideColor.withValues(alpha: tomato ? 0.14 : 0.16)
        : (dark ? AppColorsDark.glass : AppColors.glass);
    final border = selected
        ? sideColor
        : (dark ? AppColorsDark.borderStrong : AppColors.borderStrong);
    final labelText = tomato ? l.reviewTomato : l.reviewBrick;
    final label = Text(
      labelText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 11.5 : 12.5,
        fontWeight: FontWeight.w600,
        color: selected ? ink : ink2,
      ),
    );
    final hit = selected
        ? Text(
            l.reviewHits(widget.hits),
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: sideColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        : null;
    final icon = ScaleTransition(
      scale: _scale,
      child: VerdictIcon(
        side,
        size: compact ? 22 : 40,
        color: selected ? sideColor : ink2,
      ),
    );
    final Widget content = compact
        ? Row(
            children: [
              icon,
              const SizedBox(width: 5),
              Flexible(child: label),
              if (hit != null) ...[const Spacer(), hit],
            ],
          )
        : Stack(
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [icon, const SizedBox(height: 4), label],
                ),
              ),
              if (hit != null)
                PositionedDirectional(top: -6, end: -3, child: hit),
            ],
          );
    final enabled = widget.enabled;
    return Semantics(
      container: true,
      slider: true,
      enabled: enabled,
      label: tomato
          ? l.reviewA11yTomato(widget.hits)
          : l.reviewA11yBrick(widget.hits),
      onTap: enabled ? widget.onTap : null,
      onIncrease: enabled ? widget.onTap : null,
      onDecrease: enabled ? widget.onDecrease : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.s12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: radius,
                border: Border.all(color: border),
              ),
              child: Padding(
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 9, vertical: 8)
                    : const EdgeInsets.fromLTRB(8, 14, 8, 10),
                child: compact
                    ? Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: content,
                      )
                    : content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The level word for [hits] on [kind]: 1–2, 3–5, 6–9, 10 (mock S05.05).
String verdictLevelLabel(AppLocalizations l, VerdictKind kind, int hits) {
  final band = hits <= 2 ? 1 : (hits <= 5 ? 2 : (hits <= 9 ? 3 : 4));
  return switch ((kind, band)) {
    (VerdictKind.tomato, 1) => l.reviewTomatoLevel1,
    (VerdictKind.tomato, 2) => l.reviewTomatoLevel2,
    (VerdictKind.tomato, 3) => l.reviewTomatoLevel3,
    (VerdictKind.tomato, _) => l.reviewTomatoLevel4,
    (VerdictKind.brick, 1) => l.reviewBrickLevel1,
    (VerdictKind.brick, 2) => l.reviewBrickLevel2,
    (VerdictKind.brick, 3) => l.reviewBrickLevel3,
    (VerdictKind.brick, _) => l.reviewBrickLevel4,
  };
}

/// Under the pad once a side is picked (mock `.vlvl`): the level [label]
/// (see [verdictLevelLabel]), "Làm lại", a track as wide as the server
/// intensity of [hits] in the side colour, and the tap hint.
class VerdictLevel extends StatelessWidget {
  const VerdictLevel({
    super.key,
    required this.kind,
    required this.hits,
    required this.label,
    required this.onReset,
  });

  final VerdictKind kind;
  final int hits;
  final String label;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AppButton.text(
              l.reviewReset,
              onPressed: onReset,
              size: AppButtonSize.xsmall,
            ),
          ],
        ),
        const SizedBox(height: 5),
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: SizedBox(
              key: const Key('verdict-track'),
              height: 6,
              child: ColoredBox(
                color: dark ? AppColorsDark.border : AppColors.border,
                child: FractionallySizedBox(
                  key: const Key('verdict-track-fill'),
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: verdictIntensity(hits),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: verdictColor(context, kind),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(l.reviewTapMore, style: TextStyle(fontSize: 10.5, color: muted)),
      ],
    );
  }
}
