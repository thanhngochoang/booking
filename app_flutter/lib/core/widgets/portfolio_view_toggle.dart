// lib/core/widgets/portfolio_view_toggle.dart
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// The two ways to browse a portfolio (S03.01, S24.01).
enum PortfolioView { albums, timeline }

/// Pill toggle between [PortfolioView.albums] and [PortfolioView.timeline]
/// (mock `.vtg`): icon and label per segment, each a 48dp tab for screen
/// readers and touch.
class PortfolioViewToggle extends StatelessWidget {
  const PortfolioViewToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PortfolioView value;
  final ValueChanged<PortfolioView> onChanged;

  static const double _trackHeight = 36;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final track = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final l = context.l10n;
    final labels = {
      PortfolioView.albums: (Icons.grid_view_rounded, l.portfolioViewAlbums),
      PortfolioView.timeline: (Icons.schedule_rounded, l.portfolioViewTimeline),
    };
    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: SizedBox(
              height: _trackHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in PortfolioView.values)
              Flexible(
                child: _Segment(
                  icon: labels[v]!.$1,
                  label: labels[v]!.$2,
                  selected: v == value,
                  color: v == value ? theme.colorScheme.primary : secondary,
                  onTap: () => onChanged(v),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      role: SemanticsRole.tab,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpace.s12,
            minWidth: AppSpace.s12,
          ),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? scheme.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: selected ? Border.all(color: scheme.primary) : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3,
                  vertical: AppSpace.s2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: AppSpace.s1),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppText.xs2,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ),
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
