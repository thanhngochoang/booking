// S06.01's studio cards: a studio's accepted bookings (S06.01-studio) and
// the shoots a studio gave the signed-in photographer (S06.01-member).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/studio/studio_common.dart';

/// A studio's accepted booking before its start (mock `#S06.01-studio`): the
/// deadline to name who shoots ("Quá hạn giao thợ" in red once it passed),
/// or "Thợ: {name}"; a customer's pending change request with the small
/// outline "Từ chối đổi"; and the outline "Giao thợ" (S26.04), which is also
/// how the studio agrees to a change. No gradient button.
class StudioJobCard extends ConsumerWidget {
  const StudioJobCard({
    super.key,
    required this.booking,
    required this.customerName,
    required this.thumbUrl,
    required this.now,
    required this.onAssign,
    required this.onDeclineChange,
  });

  final Booking booking;
  final String customerName;
  final String? thumbUrl;
  final DateTime now;
  final VoidCallback onAssign;
  final VoidCallback onDeclineChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final s = booking.studio!;
    final assigneeId = s.assigneeId;
    final assignee = assigneeId == null
        ? null
        : ref.watch(partyProfileProvider(assigneeId)).value?.displayName;
    final overdue =
        assigneeId == null &&
        (s.assignOverdue || !now.isBefore(s.assignDeadline));
    final change = s.changeRequest?.status == ChangeRequestStatus.pending
        ? s.changeRequest
        : null;
    final red = dark ? AppColorsDark.destructive : AppColors.destructive;
    return _JobCard(
      booking: booking,
      customerName: customerName,
      thumbUrl: thumbUrl,
      badge: StatusBadge(booking.status),
      lines: [
        if (assigneeId == null)
          overdue
              ? _Line(
                  l.workAssignOverdue,
                  key: const Key('work-assign-overdue'),
                  color: red,
                )
              : _Line(
                  l.workAssignDeadline(studioDeadlineText(s.assignDeadline)),
                  key: const Key('work-assign-deadline'),
                )
        else if (assignee != null && assignee.isNotEmpty)
          _Line(l.workAssignedTo(assignee), key: const Key('work-assignee')),
      ],
      below: [
        if (change != null)
          Row(
            key: const Key('work-change-request'),
            children: [
              Expanded(
                child: Text(
                  l.workChangeRequested(_hm(change.respondBy)),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              AppButton.outline(
                l.workChangeDecline,
                key: Key('work-change-decline-${booking.id}'),
                size: AppButtonSize.xsmall,
                onPressed: onDeclineChange,
              ),
            ],
          ),
        AppButton.outline(
          l.workAssignAction,
          key: Key('work-assign-${booking.id}'),
          size: AppButtonSize.small,
          onPressed: onAssign,
        ),
      ],
    );
  }
}

/// A studio shoot given to the signed-in photographer (mock
/// `#S06.01-member`): the "Giao bởi {Studio}" tag, the "Đã giao" badge and
/// the red text "Trả việc" ([onReturn]); once handed back it reads "Đã trả
/// việc · chờ studio giao lại" with no button. Its money is the studio's.
class AssignedJobCard extends StatelessWidget {
  const AssignedJobCard({
    super.key,
    required this.booking,
    required this.customerName,
    required this.thumbUrl,
    required this.studioName,
    required this.onReturn,
  });

  final Booking booking;
  final String customerName;
  final String? thumbUrl;

  /// '' while it loads or when the studio has no name: no tag then.
  final String studioName;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final returned = booking.studio!.isReturned;
    return _JobCard(
      booking: booking,
      customerName: customerName,
      thumbUrl: thumbUrl,
      badge: returned
          ? null
          : StatusBadge.custom(
              label: l.myStudioAssignedBadge,
              color: AppColors.bookingAccepted,
              onColor: AppColors.foregroundInverse,
            ),
      lines: [
        if (returned) _Line(l.workReturned, key: const Key('work-returned')),
        if (studioName.isNotEmpty) _StudioTag(l.workAssignedBy(studioName)),
      ],
      below: [
        if (!returned)
          AppButton.text(
            l.workReturnJob,
            key: Key('work-return-${booking.id}'),
            size: AppButtonSize.small,
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(
                dark ? AppColorsDark.destructive : AppColors.destructive,
              ),
            ),
            onPressed: onReturn,
          ),
      ],
    );
  }
}

/// `HH:mm` on the Vietnam clock.
String _hm(DateTime at) {
  final vn = toVn(at);
  return '${vn.hour.toString().padLeft(2, '0')}:'
      '${vn.minute.toString().padLeft(2, '0')}';
}

/// Mock `.card` of S06.01-studio/-member: a 44dp thumbnail, "{customer} ·
/// {package}", the day and hours, [lines] under them, an optional [badge] at
/// the end, and [below] stacked under the row. Opens S05.02.
class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.booking,
    required this.customerName,
    required this.thumbUrl,
    required this.badge,
    required this.lines,
    required this.below,
  });

  final Booking booking;
  final String customerName;
  final String? thumbUrl;
  final Widget? badge;
  final List<Widget> lines;
  final List<Widget> below;

  /// Mock `.th`: 44px.
  static const double _thumb = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final b = booking;
    final day = parseDayKey(b.day);
    final when =
        '${day == null ? b.day : formatDay(day)} · ${b.start}–${b.end}';
    final title = customerName.isEmpty
        ? b.serviceSnapshot.name
        : '$customerName · ${b.serviceSnapshot.name}';
    final radius = BorderRadius.circular(AppRadius.card);
    final url = thumbUrl;
    return DecoratedBox(
      key: Key('work-job-${b.id}'),
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: radius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        child: InkWell(
          onTap: () => context.push('/b/${b.id}'),
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: SizedBox.square(
                          dimension: _thumb,
                          child: ColoredBox(
                            color: dark
                                ? AppColorsDark.surfaceMuted
                                : AppColors.surfaceMuted,
                            child: url == null || url.isEmpty
                                ? AppIcon(AppIcons.camera, color: secondary)
                                : NetworkPhoto(url: url, retry: false),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            when,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: secondary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          ...lines,
                        ],
                      ),
                    ),
                    if (badge case final badge?) ...[
                      const SizedBox(width: AppSpace.s2),
                      badge,
                    ],
                  ],
                ),
                for (final w in below) ...[
                  const SizedBox(height: AppSpace.s2),
                  w,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One meta line under the day ([color] defaults to secondary ink).
class _Line extends StatelessWidget {
  const _Line(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(color: color ?? secondary),
    );
  }
}

/// Mock `.ptag` with the storefront icon: "Giao bởi {Studio}".
class _StudioTag extends StatelessWidget {
  const _StudioTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s1),
      child: DecoratedBox(
        key: const Key('work-assigned-by'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          // Mock `.ptag`: 2px 8px 2px 6px, 11px icon, 10px text.
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s1 * 1.5,
            AppSpace.s1 / 2,
            AppSpace.s2,
            AppSpace.s1 / 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppIcons.store, size: AppText.xs2, color: secondary),
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
                    color: secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
