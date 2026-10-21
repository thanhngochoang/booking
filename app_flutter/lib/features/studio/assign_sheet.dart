import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/features/studio/studio_common.dart';
import 'package:photobooking/features/studio/studio_errors.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The members the studio can pick for a booking and its deadline, from the
/// `assignmentOptions` callable (Decision 18).
final assignmentOptionsProvider = FutureProvider.autoDispose
    .family<({DateTime deadline, List<AssignmentOption> options}), String>(
      (ref, bookingId) =>
          ref.watch(studioRepositoryProvider).assignmentOptions(bookingId),
      retry: (_, _) => null,
    );

/// Opens S26.04 "Giao thợ" for [bookingId] over S06.01 or S05.02; true once
/// the server took the assignment.
Future<bool> showAssignSheet(BuildContext context, String bookingId) =>
    showAppSheet<bool>(
      context,
      builder: (_) => ScreenCode(
        ScreenCodes.assignPhotographer,
        child: AssignSheet(bookingId: bookingId),
      ),
    ).then((v) => v ?? false);

/// S26.04: the booking and its deadline, then the studio's members as a
/// radio list, each with their own day (Rảnh / Bận {giờ} / Bận cả ngày /
/// Chưa xác minh / Đang giao); only free members can be picked. The note
/// names the pick, and the one primary "Giao cho {name}" assigns and closes.
/// Changing the assignee after the deadline warns that the customer may
/// cancel with a full refund (Decision 10).
class AssignSheet extends ConsumerStatefulWidget {
  const AssignSheet({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<AssignSheet> {
  /// The member picked by hand; null keeps the first free one.
  String? _picked;
  bool _sending = false;

  AssignmentOption? _choice(List<AssignmentOption> options) {
    final free = [
      for (final o in options)
        if (o.selectable) o,
    ];
    if (free.isEmpty) return null;
    return free.firstWhere((o) => o.uid == _picked, orElse: () => free.first);
  }

  Future<void> _assign(AssignmentOption o) async {
    setState(() => _sending = true);
    final navigator = Navigator.of(context);
    final ok = await runStudioAction(
      context,
      () => ref.read(bookingRepositoryProvider).assign(widget.bookingId, o.uid),
    );
    if (!mounted) return;
    if (ok) {
      navigator.pop(true);
    } else {
      setState(() => _sending = false);
      // The members' days may have changed: read them again.
      ref.invalidate(assignmentOptionsProvider(widget.bookingId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final booking = ref.watch(bookingProvider(widget.bookingId));
    final options = ref.watch(assignmentOptionsProvider(widget.bookingId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.assignTitle, style: theme.textTheme.titleLarge),
                ),
              ),
              IconButton(
                key: const Key('assign-close'),
                tooltip: l.studioSheetClose,
                icon: const AppIcon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          Flexible(
            child: AsyncView<Booking?>(
              value: booking,
              loaderSize: LoaderSize.inline,
              skeleton: (_) => _skeleton(),
              onRetry: () => ref.invalidate(bookingProvider(widget.bookingId)),
              data: (context, b) => b == null
                  ? Text(l.studioErr_generic)
                  : AsyncView<
                      ({DateTime deadline, List<AssignmentOption> options})
                    >(
                      value: options,
                      loaderSize: LoaderSize.inline,
                      skeleton: (_) => _skeleton(),
                      onRetry: () => ref.invalidate(
                        assignmentOptionsProvider(widget.bookingId),
                      ),
                      data: (context, o) =>
                          _body(context, b, o.deadline, [...o.options]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeleton() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSkeleton.card(height: 56),
      const SizedBox(height: AppSpace.s2),
      for (var i = 0; i < 3; i++) ...[
        AppOptionTile.skeleton(withThumb: true),
        const SizedBox(height: AppSpace.s2),
      ],
    ],
  );

  Widget _body(
    BuildContext context,
    Booking b,
    DateTime deadline,
    List<AssignmentOption> options,
  ) {
    final l = context.l10n;
    final now = ref.read(clockProvider)();
    final choice = _choice(options);
    final name = choice?.name ?? '';
    final reassign = b.studio?.assigneeId != null;
    final late = reassign && !now.isBefore(deadline);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Summary(booking: b, deadline: deadline, now: now),
        const SizedBox(height: AppSpace.s3),
        if (options.isEmpty)
          StudioNote(l.assignNoMembers, key: const Key('assign-no-members'))
        else
          Flexible(
            child: Semantics(
              role: SemanticsRole.radioGroup,
              label: l.assignPickerA11y,
              explicitChildNodes: true,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s2),
                itemBuilder: (context, i) {
                  final o = options[i];
                  return AppOptionTile(
                    key: Key('assign-option-${o.uid}'),
                    label: o.name,
                    meta: _meta(l, o),
                    leading: AppAvatar(
                      url: o.avatarUrl,
                      name: o.name,
                      size: AppAvatarSize.sm,
                      decorative: true,
                    ),
                    selected: o.uid == choice?.uid,
                    enabled: o.selectable && !_sending,
                    onTap: () => setState(() => _picked = o.uid),
                  );
                },
              ),
            ),
          ),
        if (name.isNotEmpty) StudioNote(l.assignNote(name)),
        if (late)
          StudioNote(
            l.assignLateWarning,
            key: const Key('assign-late-warning'),
            icon: AppIcons.warning,
          ),
        const SizedBox(height: AppSpace.s2),
        AppButton.primary(
          name.isEmpty ? l.assignTitle : l.assignAction(name),
          key: const Key('assign-submit'),
          loading: _sending,
          onPressed: choice == null || _sending ? null : () => _assign(choice),
        ),
      ],
    );
  }

  /// The member's own day for this booking, with their % when free.
  List<MetaPart> _meta(AppLocalizations l, AssignmentOption o) {
    final pct = o.tomatoPct;
    final tomato = pct != null && o.reviewCount >= kTomatoPctMinReviews
        ? MetaPart.tomato(pct)
        : null;
    return switch (o.state) {
      AssignState.free => [MetaPart.text(l.assignFree), ?tomato],
      AssignState.current => [MetaPart.text(l.assignCurrent), ?tomato],
      AssignState.busy when o.busyStart != null && o.busyEnd != null => [
        MetaPart.text(l.assignBusy(o.busyStart!, o.busyEnd!)),
      ],
      AssignState.busy ||
      AssignState.off => [MetaPart.text(l.assignBusyAllDay)],
      AssignState.unverified => [MetaPart.text(l.assignUnverified)],
    };
  }
}

/// Mock: the booking card of the sheet, "Cưới 4 giờ · T7 12/10 ·
/// 15:30–19:30" over the deadline and the time left.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.booking,
    required this.deadline,
    required this.now,
  });

  final Booking booking;
  final DateTime deadline;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final b = booking;
    final day = parseDayKey(b.day);
    final left = deadline.difference(now);
    final when = studioDeadlineText(deadline);
    final passed = left <= Duration.zero;
    final deadlineLine = passed
        ? l.assignDeadlinePassed(when)
        : l.assignDeadline(
            when,
            left.inDays >= 1
                ? l.assignLeftDays(left.inDays)
                : l.assignLeftHours(left.inHours < 1 ? 1 : left.inHours),
          );
    return DecoratedBox(
      key: const Key('assign-summary'),
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2h,
          vertical: AppSpace.s2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.assignSummary(
                b.serviceSnapshot.name,
                day == null ? b.day : formatDay(day),
                b.start,
                b.end,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              deadlineLine,
              style: theme.textTheme.bodySmall?.copyWith(
                color: passed
                    ? (dark ? AppColorsDark.destructive : AppColors.destructive)
                    : (dark
                          ? AppColorsDark.foregroundSecondary
                          : AppColors.foregroundSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
