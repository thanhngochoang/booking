import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// "Tháng 10", or "Tháng 10/2025" for another year than [thisYear].
String monthLabel(AppLocalizations l, String monthKey, int thisYear) {
  final parts = monthKey.split('-');
  final y = int.tryParse(parts.first) ?? thisYear;
  final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
  return y == thisYear ? l.earningsMonth(m) : l.earningsMonthYear(m, y);
}

/// Month heading of the money lists (S06.05, S22.01), as the mock draws it.
/// The first month is the `.sec` row: [title] ("Các khoản") with the month on
/// the right. Later months are `.nsec`: small, upper-case, muted, alone.
class MonthHeader extends StatelessWidget {
  /// The first heading: [title] with [trailing] (the month) beside it.
  const MonthHeader.first({
    super.key,
    required String this.title,
    required String this.trailing,
  }) : month = null;

  /// A later month heading, e.g. "Tháng 9".
  const MonthHeader.month({super.key, required String this.month})
    : title = null,
      trailing = null;

  final String? title;
  final String? trailing;
  final String? month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    if (month != null) {
      // `.nsec`: 10.5px, upper-case, .08em tracking, muted ink.
      return Padding(
        padding: const EdgeInsets.only(top: AppSpace.s2, bottom: AppSpace.s1),
        child: Semantics(
          header: true,
          child: Text(
            month!.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: muted,
              letterSpacing: AppText.xs * 0.08,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Text(trailing!, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
