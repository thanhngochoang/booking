// lib/core/widgets/season_tag.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// Tag showing season status ("Đang vào mùa" or "Đang vào mùa · tới cuối tháng {m}").
///
/// If [pill] is true, renders as a photo overlay pill (.pill in mock).
/// Otherwise renders as an inline tag (.ptag in mock).
class SeasonTag extends StatelessWidget {
  const SeasonTag({
    super.key,
    this.label,
    this.pill = false,
  });

  final String? label;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final text = label ?? context.l10n.spotInSeason;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    if (pill) {
      final bg = dark
          ? const Color(0xDE1B1A18)
          : const Color(0xF0FFFFFF);
      final fg = dark ? Colors.white : const Color(0xFF1B1A18);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(AppIcons.eco, size: 13, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bg = dark ? AppColorsDark.freeBg : AppColors.freeBg;
    final fg = dark ? AppColorsDark.freeInk : AppColors.freeInk;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: dark ? AppColorsDark.freeInk.withAlpha(60) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.eco, size: 11, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
