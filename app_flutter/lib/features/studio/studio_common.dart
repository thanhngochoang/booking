import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Pieces S26.01–S26.03 share: relation clocks, open studio shoots and the
/// mock's `.sec`, `.lockn` and empty card.

/// Most members of a studio without and with a business record (Decision 3).
const kStudioMaxMembers = 3;
const kStudioMaxMembersVerified = 30;

/// Most open invites of one studio (Decision 3).
const kStudioMaxPendingInvites = 5;

int studioMaxMembers({required bool businessVerified}) =>
    businessVerified ? kStudioMaxMembersVerified : kStudioMaxMembers;

/// Whole Vietnam calendar days from [now] to [expiresAt]; 0 = it lapses
/// today.
int studioDaysLeft(DateTime expiresAt, DateTime now) {
  final a = toVn(now);
  final b = toVn(expiresAt);
  final days = DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  return days < 0 ? 0 : days;
}

/// "vừa xong", "{n} phút trước", "{n} giờ trước", "{n} ngày trước".
String studioAgo(AppLocalizations l, DateTime at, DateTime now) {
  final elapsed = now.difference(at);
  if (elapsed < const Duration(minutes: 1)) return l.studioAgoNow;
  if (elapsed < const Duration(hours: 1)) {
    return l.studioAgoMinutes(elapsed.inMinutes);
  }
  if (elapsed < const Duration(days: 1)) {
    return l.studioAgoHours(elapsed.inHours);
  }
  return l.studioAgoDays(elapsed.inDays);
}

/// `02/2026`: the Vietnam month of [at].
String studioMonth(DateTime at) {
  final vn = toVn(at);
  return '${vn.month.toString().padLeft(2, '0')}/${vn.year}';
}

/// A booking that still holds its assignee (Decision 6): not declined,
/// expired, cancelled, completed or reviewed.
bool isOpenStudioJob(Booking b) => switch (b.status) {
  BookingStatus.declined ||
  BookingStatus.expired ||
  BookingStatus.cancelled ||
  BookingStatus.completed ||
  BookingStatus.reviewed => false,
  _ => true,
};

/// Open shoots of [bookings] assigned to each member, by member uid.
Map<String, int> openJobsByAssignee(Iterable<Booking> bookings) {
  final counts = <String, int>{};
  for (final b in bookings) {
    final assignee = b.studio?.assigneeId;
    if (assignee == null || !isOpenStudioJob(b)) continue;
    counts[assignee] = (counts[assignee] ?? 0) + 1;
  }
  return counts;
}

/// Mock `.sec`: a bold title with a count on the right in tertiary ink, read
/// as one header ("Đang chờ, 2 · tối đa 5 lời mời").
class StudioSectionHeader extends StatelessWidget {
  const StudioSectionHeader({super.key, required this.title, this.count});

  final String title;
  final String? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tertiary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    return Semantics(
      header: true,
      label: count == null ? title : '$title, $count',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpace.s4, bottom: AppSpace.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (count case final c?)
              Flexible(
                child: Text(
                  c,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(color: tertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mock `.lockn`: an info icon and a short line in secondary ink.
class StudioNote extends StatelessWidget {
  const StudioNote(this.text, {super.key, this.icon = AppIcons.info});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: AppIcon(icon, size: 16, color: secondary)),
          const SizedBox(width: AppSpace.s2),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The empty card of S26.01 and S26.03-none: icon disc, title, one line.
class StudioEmptyCard extends StatelessWidget {
  const StudioEmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return GlassCard(
      highlight: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s3,
          vertical: AppSpace.s4,
        ),
        child: Column(
          children: [
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s3),
                  child: AppIcon(icon, color: secondary),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpace.s1),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A [GlassCard] holding rows (mock `.card` with `.irow2` lines), a hairline
/// between rows.
class StudioRowsCard extends StatelessWidget {
  const StudioRowsCard({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outlineVariant;
    return GlassCard(
      highlight: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s3,
          vertical: AppSpace.s1,
        ),
        child: Column(
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: line),
              row,
            ],
          ],
        ),
      ),
    );
  }
}
