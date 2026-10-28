// S05.02 "Thợ chụp cho bạn": the customer's view of who a studio sent.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/booking/booking_view_rules.dart';
import 'package:photobooking/features/studio/studio_common.dart';
import 'package:photobooking/features/verification/widgets/verify_parts.dart'
    show VerifyAlert;

/// The block under the booking card of a studio booking (mocks
/// `#S05.02-studio`, `-late`, `-change`): the waiting line, the member card
/// ([AssigneeCard], "Xin đổi thợ (1 lần)" → [onChange]) or the overdue
/// warning, then the studio-fault warning and the red "Huỷ và hoàn 100%"
/// ([onCancel], shown when [canCancel]) per [studioBlockStateOf].
class StudioAssigneeBlock extends ConsumerWidget {
  const StudioAssigneeBlock({
    super.key,
    required this.booking,
    required this.studioName,
    required this.now,
    required this.canCancel,
    required this.busy,
    required this.onCancel,
    required this.onChange,
  });

  final Booking booking;

  /// The studio's display name; '' when unknown (no name is shown then).
  final String studioName;
  final DateTime now;
  final bool canCancel;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final red = dark ? AppColorsDark.destructive : AppColors.destructive;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final studio = booking.studio!;
    final state = studioBlockStateOf(booking, now)!;
    final deadline = studioDeadlineText(studio.assignDeadline);

    final String? sideLabel = switch (state) {
      StudioBlockState.waiting => null,
      StudioBlockState.overdue => l.assigneeOverdueLabel,
      _ => switch (studio.assignedAt) {
        final at? => l.assigneeAssignedOn(formatDayMonth(toVn(at))),
        null => null,
      },
    };

    // The overdue promise ("… huỷ và được hoàn 100%.") ends with the right
    // at the start; the title alone stays true after it.
    final rightLasts = studioFaultOf(booking, now) != null;
    final (String, String?)? alert = switch (state) {
      StudioBlockState.overdue => (
        l.assigneeOverdueTitle(deadline),
        rightLasts ? l.assigneeOverdueBody : null,
      ),
      StudioBlockState.changeDeclined => (
        l.assigneeChangeDeclinedTitle,
        l.assigneeChangeDeclinedBody(studio.changeRequest?.declineReason ?? ''),
      ),
      StudioBlockState.changeExpired => (
        l.assigneeChangeExpiredTitle,
        l.assigneeChangeExpiredBody,
      ),
      StudioBlockState.lateReassign => (
        l.assigneeLateReassignTitle,
        l.assigneeLateReassignBody,
      ),
      _ => null,
    };

    final assigneeId = studio.assigneeId;
    final showCard =
        state != StudioBlockState.waiting &&
        state != StudioBlockState.overdue &&
        assigneeId != null;
    // The two reminders go out 24 h and 2 h before the deadline; a booking
    // made later than the first one gets both at once, so the times would
    // be wrong: no line then.
    final firstReminder = studio.assignDeadline.subtract(
      const Duration(hours: 24),
    );
    final reminded =
        state == StudioBlockState.overdue &&
        studio.remindersSent.contains('h48') &&
        studio.remindersSent.contains('h26') &&
        !firstReminder.isBefore(booking.createdAt) &&
        studioName.isNotEmpty;

    return Column(
      key: const Key('studio-assignee-block'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          label: sideLabel == null
              ? l.assigneeSection
              : '${l.assigneeSection}, $sideLabel',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    l.assigneeSection,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (sideLabel != null)
                  Text(
                    sideLabel,
                    key: const Key('assignee-side-label'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: state == StudioBlockState.overdue
                          ? red
                          : (dark
                                ? AppColorsDark.foregroundMuted
                                : AppColors.foregroundMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (state == StudioBlockState.waiting)
          Text(
            l.assigneeWaiting(deadline),
            key: const Key('assignee-waiting'),
            style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
          ),
        if (showCard)
          AsyncView<PhotographerProfile?>(
            value: ref.watch(photographerProfileProvider(assigneeId)),
            loaderSize: LoaderSize.inline,
            skeleton: (_) => AssigneeCard.skeleton(),
            onRetry: () =>
                ref.invalidate(photographerProfileProvider(assigneeId)),
            data: (context, p) => AssigneeCard(
              summary: _summaryOf(assigneeId, p),
              studioName: studioName,
              collaborator: studio.assigneeKind == 'collaborator',
              onViewProfile: () => context.push('/u/$assigneeId'),
              changeLabel: state == StudioBlockState.changePending
                  ? l.assigneeChangePending
                  : (canRequestAssigneeChange(booking, now)
                        ? l.assigneeChange
                        : null),
              onChange:
                  state != StudioBlockState.changePending &&
                      canRequestAssigneeChange(booking, now) &&
                      !busy
                  ? onChange
                  : null,
            ),
          ),
        if (alert case (final title, final body)) ...[
          const SizedBox(height: AppSpace.s2),
          KeyedSubtree(
            key: const Key('assignee-alert'),
            child: body == null
                ? VerifyAlert(title)
                : VerifyAlert(body, title: title),
          ),
        ],
        if (canCancel)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.text(
              l.assigneeCancelFull,
              key: const Key('assignee-cancel-full'),
              size: AppButtonSize.small,
              style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(red)),
              onPressed: busy ? null : onCancel,
            ),
          ),
        if (reminded)
          Text(
            l.assigneeReminded(
              studioName,
              studioDeadlineText(firstReminder),
              studioDeadlineText(
                studio.assignDeadline.subtract(const Duration(hours: 2)),
              ),
            ),
            key: const Key('assignee-reminded'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: dark
                  ? AppColorsDark.foregroundMuted
                  : AppColors.foregroundMuted,
            ),
          ),
      ],
    );
  }

  static AssigneeSummary _summaryOf(String id, PhotographerProfile? p) {
    final s = p?.summary;
    return AssigneeSummary(
      id: id,
      name: s?.displayName ?? '',
      avatarUrl: s?.avatarUrl,
      verified: s?.verified ?? false,
      tomatoPct: s != null && s.hasTomatoPct ? s.tomatoPct : null,
      shoots: s?.completedCount ?? 0,
    );
  }
}
