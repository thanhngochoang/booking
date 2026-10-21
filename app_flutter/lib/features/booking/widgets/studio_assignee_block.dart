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

    final (String, String)? alert = switch (state) {
      StudioBlockState.overdue => (
        l.assigneeOverdueTitle(deadline),
        l.assigneeOverdueBody,
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
    final reminded =
        state == StudioBlockState.overdue &&
        studio.remindersSent.contains('h48') &&
        studio.remindersSent.contains('h26') &&
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
          _StudioAlert(title: title, body: body),
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
              studioDeadlineText(
                studio.assignDeadline.subtract(const Duration(hours: 24)),
              ),
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

/// Mock `.warnc` (role alert): a red-outlined card, bold [title] over
/// [body].
class _StudioAlert extends StatelessWidget {
  const _StudioAlert({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bad = dark ? AppColorsDark.destructive : AppColors.destructive;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        key: const Key('assignee-alert'),
        decoration: BoxDecoration(
          color: bad.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: bad.withValues(alpha: 0.55)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2h,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(AppIcons.info, size: AppIconSize.sm, color: bad),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: dark
                            ? AppColorsDark.foregroundSecondary
                            : AppColors.foregroundSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
