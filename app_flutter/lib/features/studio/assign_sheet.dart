import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/features/collab/collab_controller.dart';
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
///
/// A studio with active collaborators (S27, mock `#S26.04-collab`) sees two
/// groups, "Thành viên" and "Cộng tác viên". Picking a collaborator shows the
/// required "Thù lao" (the suggested fee filled in), the 6-hour note, and the
/// primary "Gửi việc cho {name}" sends an offer with the fee (never stored
/// on the booking, so the customer never sees it). The collaborator's own
/// day is checked by the server when the offer is sent and accepted.
class AssignSheet extends ConsumerStatefulWidget {
  const AssignSheet({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<AssignSheet> {
  /// The member picked by hand; null keeps the first free one.
  String? _picked;

  /// The collaborator picked by hand (S27); wins over [_picked].
  Collaboration? _collaborator;
  final _fee = TextEditingController();
  String? _feeError;
  bool _sending = false;

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  AssignmentOption? _choice(List<AssignmentOption> options) {
    final free = [
      for (final o in options)
        if (o.selectable) o,
    ];
    if (free.isEmpty) return null;
    return free.firstWhere((o) => o.uid == _picked, orElse: () => free.first);
  }

  void _pickMember(String uid) => setState(() {
    _picked = uid;
    _collaborator = null;
    _feeError = null;
  });

  void _pickCollaborator(Collaboration c) => setState(() {
    _collaborator = c;
    _feeError = null;
    _fee.text = switch (c.defaultFee) {
      final fee? => groupVnd(fee),
      null => '',
    };
  });

  Future<void> _offer(Collaboration c) async {
    final l = context.l10n;
    final text = _fee.text.trim();
    final fee = parseVnd(text);
    if (!isValidCollabFee(fee)) {
      setState(
        () =>
            _feeError = text.isEmpty ? l.assignFeeRequired : l.collabFeeInvalid,
      );
      return;
    }
    await _send(
      () => ref
          .read(bookingRepositoryProvider)
          .assign(
            widget.bookingId,
            c.collaboratorId,
            collaborator: true,
            agreedFee: fee,
          ),
    );
  }

  Future<void> _assign(AssignmentOption o) => _send(
    () => ref.read(bookingRepositoryProvider).assign(widget.bookingId, o.uid),
  );

  Future<void> _send(Future<void> Function() action) async {
    setState(() {
      _sending = true;
      _feeError = null;
    });
    final navigator = Navigator.of(context);
    final ok = await runStudioAction(context, action);
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
    // Read alongside the options, not after them (S27 collaborators). A
    // failing listener leaves the members-only sheet of S26 working.
    final watched = ref.watch(studioCollaborationsProvider);
    final collaborations = watched.hasError && !watched.hasValue
        ? const AsyncValue<List<Collaboration>>.data([])
        : watched;
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
                      data: (context, o) => AsyncView<List<Collaboration>>(
                        value: collaborations,
                        loaderSize: LoaderSize.inline,
                        skeleton: (_) => _skeleton(),
                        onRetry: () =>
                            ref.invalidate(studioCollaborationsProvider),
                        data: (context, collabs) => _body(
                          context,
                          b,
                          o.deadline,
                          [...o.options],
                          [
                            for (final c in collabs)
                              if (c.status == CollabStatus.active) c,
                          ],
                        ),
                      ),
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
    List<Collaboration> collaborators,
  ) {
    final l = context.l10n;
    final now = ref.read(clockProvider)();
    final collaborator = collaborators
        .where((c) => c.collaboratorId == _collaborator?.collaboratorId)
        .firstOrNull;
    final choice = collaborator == null ? _choice(options) : null;
    final name = collaborator?.collaboratorName ?? choice?.name ?? '';
    // A pending collaborator offer is not an assignee to replace (S27).
    final reassign = b.studio?.confirmedAssigneeId != null;
    final late = reassign && !now.isBefore(deadline);
    final grouped = collaborators.isNotEmpty;
    Widget memberTile(AssignmentOption o) => AppOptionTile(
      key: Key('assign-option-${o.uid}'),
      label: o.name,
      meta: _meta(l, o),
      leading: AppAvatar(
        url: o.avatarUrl,
        name: o.name,
        size: AppAvatarSize.sm,
        decorative: true,
      ),
      selected: collaborator == null && o.uid == choice?.uid,
      enabled: o.selectable && !_sending,
      onTap: () => _pickMember(o.uid),
    );
    Widget collaboratorTile(Collaboration c) => AppOptionTile(
      key: Key('assign-option-${c.collaboratorId}'),
      label: c.collaboratorName,
      meta: [
        if (ref
                .watch(photographerProfileProvider(c.collaboratorId))
                .value
                ?.summary
            case final summary? when summary.hasTomatoPct)
          MetaPart.tomato(summary.tomatoPct),
        if (c.defaultFee case final fee?)
          MetaPart.text(l.recruitFeePerShoot(formatMoney(fee))),
      ],
      leading: AppAvatar(
        url: c.collaboratorAvatarUrl,
        name: c.collaboratorName,
        size: AppAvatarSize.sm,
        decorative: true,
      ),
      selected: c.collaboratorId == collaborator?.collaboratorId,
      enabled: !_sending,
      onTap: () => _pickCollaborator(c),
    );
    final tiles = <Widget>[
      if (grouped)
        _GroupLabel(
          l.assignGroupMembers,
          key: const Key('assign-group-members'),
        ),
      if (options.isEmpty && grouped)
        StudioNote(l.assignNoMembers, key: const Key('assign-no-members')),
      for (final o in options) memberTile(o),
      if (grouped) ...[
        _GroupLabel(
          l.assignGroupCollaborators,
          key: const Key('assign-group-collaborators'),
        ),
        for (final c in collaborators) collaboratorTile(c),
      ],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Summary(booking: b, deadline: deadline, now: now),
        const SizedBox(height: AppSpace.s3),
        if (options.isEmpty && !grouped)
          StudioNote(l.assignNoMembers, key: const Key('assign-no-members'))
        else
          Flexible(
            child: Semantics(
              role: SemanticsRole.radioGroup,
              label: l.assignPickerA11y,
              explicitChildNodes: true,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: tiles.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s2),
                itemBuilder: (context, i) => tiles[i],
              ),
            ),
          ),
        if (collaborator != null) ...[
          const SizedBox(height: AppSpace.s3),
          TextField(
            key: const Key('assign-fee'),
            controller: _fee,
            enabled: !_sending,
            keyboardType: TextInputType.number,
            inputFormatters: const [VndInputFormatter()],
            onChanged: (_) {
              if (_feeError != null) setState(() => _feeError = null);
            },
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              labelText: l.assignFeeLabel,
              suffixText: l.recruitFeeAmountSuffix,
              errorText: _feeError,
            ),
          ),
        ],
        if (name.isNotEmpty)
          StudioNote(
            collaborator != null
                ? l.assignCollabNote(name)
                : l.assignNote(name),
          ),
        if (late)
          StudioNote(
            l.assignLateWarning,
            key: const Key('assign-late-warning'),
            icon: AppIcons.warning,
          ),
        const SizedBox(height: AppSpace.s2),
        AppButton.primary(
          name.isEmpty
              ? l.assignTitle
              : collaborator != null
              ? l.assignSendTo(name)
              : l.assignAction(name),
          key: const Key('assign-submit'),
          loading: _sending,
          onPressed: _sending
              ? null
              : collaborator != null
              ? () => _offer(collaborator)
              : choice == null
              ? null
              : () => _assign(choice),
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

/// "Thành viên" / "Cộng tác viên" above each group (mock `.sec`, small).
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.brightness == Brightness.dark
              ? AppColorsDark.foregroundSecondary
              : AppColors.foregroundSecondary,
        ),
      ),
    );
  }
}
