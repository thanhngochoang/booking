// S14.03: the assigned photographer's Chụp ngay job — on the way (map, meet
// point, "Đã đến"), arrived ("Bắt đầu chụp", no-show after 15 minutes),
// shooting (countdown, "Hoàn thành") and waiting for the customer; plus the
// closed states. Mock `#S14.03`, `-arrived`, `-shooting`, `-done`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';
import 'package:photobooking/features/instant_work/instant_job_controller.dart';
import 'package:photobooking/features/instant_work/provider_cancel_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Where the job screen goes when the request is no longer this photographer's.
const _liveShutterPath = '/work/instant';

/// "Về Công việc".
const _workPath = '/bookings';

/// Statuses before anyone is assigned: a request back there is no longer ours
/// (the photographer cancelled, Decision 8).
const _unassigned = {
  InstantStatus.choosing,
  InstantStatus.pendingPayment,
  InstantStatus.searching,
  InstantStatus.noMatch,
  InstantStatus.abandoned,
};

bool _notMine(InstantRequest? r) =>
    r == null || r.photographerId == null || _unassigned.contains(r.status);

class InstantJobScreen extends ConsumerStatefulWidget {
  const InstantJobScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<InstantJobScreen> createState() => _InstantJobScreenState();
}

class _InstantJobScreenState extends ConsumerState<InstantJobScreen>
    with WidgetsBindingObserver {
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<AsyncValue<InstantRequest?>>(
      instantRequestProvider(widget.requestId),
      (_, next) {
        if (next.hasValue && _notMine(next.value)) _leave();
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Foreground only (Decision 10/11): no fixes and no track in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = switch (state) {
      AppLifecycleState.resumed => true,
      AppLifecycleState.inactive => null,
      _ => false,
    };
    if (foreground != null) _controller.setForeground(foreground);
  }

  InstantJobController get _controller =>
      ref.read(instantJobControllerProvider(widget.requestId).notifier);

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) context.go(_liveShutterPath);
      })
      ..scheduleFrame();
  }

  Future<void> _call(Future<void> Function() call) async {
    final l = context.l10n;
    try {
      await call();
    } on Object catch (e) {
      if (mounted) _say(instantErrorText(l, e));
    }
  }

  Future<void> _arrive() async {
    final l = context.l10n;
    final ArrivalOutcome outcome;
    try {
      outcome = await _controller.arrive();
    } on Object catch (e) {
      if (mounted) _say(instantErrorText(l, e));
      return;
    }
    if (!mounted) return;
    switch (outcome) {
      case Arrived():
        break;
      case ArrivalNoFix():
        _say(l.jobLocationNeeded);
      case ArrivalTooFar(:final metres):
        _say(l.jobArriveFar(instantDistanceText(metres)));
      case ArrivalNeedsForce(:final fix):
        final ok = await showConfirmSheet(
          context,
          title: l.jobArriveForceTitle,
          body: l.jobArriveForceBody(fix.accuracyM.round()),
          confirmLabel: l.jobArriveForceConfirm,
          keepLabel: l.jobArriveForceKeep,
          danger: false,
        );
        if (ok && mounted) await _call(() => _controller.forceArrive(fix));
    }
  }

  Future<void> _noShow(InstantRequest r) async {
    final l = context.l10n;
    // Decision 9: 50/50 (#140 records zero money; the copy is the end state).
    final fee = r.amountVnd - r.amountVnd * 50 ~/ 100;
    final ok = await showConfirmSheet(
      context,
      title: l.jobNoShowTitle,
      body: l.jobNoShowBody(formatMoney(fee)),
      confirmLabel: l.jobNoShowConfirm,
      keepLabel: l.jobNoShowKeep,
    );
    if (ok && mounted) await _call(_controller.noShow);
  }

  Future<void> _cancel() async {
    final done = await showProviderCancelSheet(
      context,
      requestId: widget.requestId,
    );
    if (done && mounted) _leave();
  }

  Future<void> _directions(InstantRequest r) async {
    final l = context.l10n;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${r.meetPoint.lat},${r.meetPoint.lng}',
    );
    var opened = false;
    try {
      opened = await ref.read(externalLauncherProvider).open(uri);
    } on Object {
      opened = false;
    }
    if (!opened && mounted) _say(l.contactOpenError);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final value = ref.watch(instantRequestProvider(widget.requestId));
    final ui = ref.watch(instantJobControllerProvider(widget.requestId));
    final r = value.value;
    final status = _notMine(r) ? null : r!.status;
    final chatId = r?.chatId;
    return ScreenCode(
      ScreenCodes.instantJob,
      label: switch (status) {
        InstantStatus.arrived => 'arrived',
        InstantStatus.inProgress => 'shooting',
        InstantStatus.finished || InstantStatus.completed => 'done',
        _ => null,
      },
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: context.canPop()
                ? null
                : IconButton(
                    tooltip: l.back,
                    icon: const AppIcon(AppIcons.back),
                    onPressed: () => context.go(_workPath),
                  ),
            title: status == null
                ? null
                : _BarTitle(
                    title: _title(l, status),
                    subtitle: l.jobSubtitle(
                      r!.customerName,
                      instantGenreText(l, r.genre),
                      instantDurationText(l, r.durationMin),
                    ),
                  ),
            actions: [
              if (status != null)
                IconButton(
                  key: const Key('job-chat'),
                  tooltip: l.workMessage,
                  icon: const AppIcon(AppIcons.chat),
                  onPressed: chatId == null
                      ? null
                      : () => context.push('/chat/$chatId'),
                ),
            ],
          ),
          body: AsyncView<InstantRequest?>(
            value: value,
            skeleton: (_) => const _Skeleton(),
            onRetry: () =>
                ref.invalidate(instantRequestProvider(widget.requestId)),
            // Not ours (any more): the listener goes to Live Shutter.
            data: (context, r) => _notMine(r)
                ? const SizedBox.shrink()
                : _content(context, r!, ui),
          ),
        ),
      ),
    );
  }

  String _title(AppLocalizations l, InstantStatus s) => switch (s) {
    InstantStatus.arrived => l.jobTitleArrived,
    InstantStatus.inProgress => l.jobTitleShooting,
    InstantStatus.finished => l.jobTitleFinished,
    InstantStatus.completed => l.jobTitleCompleted,
    InstantStatus.cancelledByCustomer => l.jobCancelledTitle,
    InstantStatus.noShowCustomer => l.jobNoShow,
    _ => l.jobTitleEnRoute,
  };

  Widget _content(BuildContext context, InstantRequest r, InstantJobUi ui) {
    final (body, footer) = switch (r.status) {
      InstantStatus.assigned ||
      InstantStatus.enRoute => _enRoute(context, r, ui),
      InstantStatus.arrived => _arrived(context, r, ui),
      InstantStatus.inProgress => _shooting(context, r, ui),
      _ => _closed(context, r),
    };
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s2,
              AppSpace.s4,
              AppSpace.s6,
            ),
            children: body,
          ),
        ),
        AppFooterBar(child: footer),
      ],
    );
  }

  List<TimelineStep> _steps(AppLocalizations l, InstantRequest r) {
    final assignedAt = r.assignedAt;
    final arrivedAt = r.arrivedAt;
    return [
      TimelineStep(
        title: assignedAt == null
            ? l.instantStatusAssigned
            : l.jobStepAccepted(instantClock(assignedAt)),
        state: TimelineStepState.done,
      ),
      arrivedAt == null
          ? TimelineStep(
              title: l.jobStepArriveHint,
              state: TimelineStepState.current,
            )
          : TimelineStep(
              title: l.jobStepArrived(instantClock(arrivedAt)),
              state: TimelineStepState.done,
            ),
      TimelineStep(
        title: l.jobStepShoot,
        state: arrivedAt == null
            ? TimelineStepState.upcoming
            : TimelineStepState.current,
      ),
    ];
  }

  (List<Widget>, Widget) _enRoute(
    BuildContext context,
    InstantRequest r,
    InstantJobUi ui,
  ) {
    final l = context.l10n;
    final fix = ui.fix;
    final button = arriveButtonOf(r, fix);
    final busy = ui.busy != null;
    final km = fix == null ? null : metresToMeetPoint(r, fix) / 1000;
    final contact = ref.watch(instantCustomerContactProvider(r.id));
    final body = <Widget>[
      MapPreview(
        key: const Key('job-map'),
        height: 150,
        route: fix != null,
        pins: [
          MapPin(
            lat: r.meetPoint.lat,
            lng: r.meetPoint.lng,
            label: r.customerName,
          ),
          if (fix != null)
            MapPin(lat: fix.lat, lng: fix.lng, label: l.mapPinYou, self: true),
        ],
      ),
      const SizedBox(height: AppSpace.s3),
      _Card(
        title: r.meetPoint.name,
        meta: km == null
            ? r.areaLabel
            : l.jobDistanceLine(r.areaLabel, instantKmNumber(km)),
        trailing: Wrap(
          spacing: AppSpace.s1,
          runSpacing: AppSpace.s1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppButton.outline(
              l.jobDirections,
              key: const Key('job-directions'),
              size: AppButtonSize.xsmall,
              onPressed: () => _directions(r),
            ),
            // Locked while unpaid (every #140 job): no copy, nothing shown;
            // the chat in the bar stays (Decision 22).
            AsyncView<BookingContactSnapshot?>(
              value: contact,
              skeleton: (_) => const SizedBox.shrink(),
              error: (_, _, _) => const SizedBox.shrink(),
              data: (_, copy) => CustomerContactDial(copy: copy),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpace.s3),
      StatusTimeline(steps: _steps(l, r)),
      const SizedBox(height: AppSpace.s2),
      if (ui.locationDenied)
        _LocationNeeded(
          status: ui.permission!,
          onAsk: () => _controller.askLocation(),
        )
      else
        _Note(l.jobLocationNote),
      const SizedBox(height: AppSpace.s1),
      _RedText(
        l.jobCancel,
        key: const Key('job-cancel'),
        onPressed: busy ? null : _cancel,
      ),
    ];
    // Only a fix can make the button "far".
    final farFix = button == ArriveButton.far ? fix : null;
    final far = farFix != null;
    final footer = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (farFix != null) ...[
          Text(
            l.jobArriveFar(instantDistanceText(metresToMeetPoint(r, farFix))),
            key: const Key('job-arrive-far'),
            textAlign: TextAlign.center,
            style: _metaStyle(context),
          ),
          const SizedBox(height: AppSpace.s2),
        ],
        AppButton.primary(
          l.jobArrive,
          key: const Key('job-arrive'),
          loading: ui.busy == InstantJobAction.arrive,
          onPressed: far || busy ? null : _arrive,
        ),
      ],
    );
    return (body, footer);
  }

  (List<Widget>, Widget) _arrived(
    BuildContext context,
    InstantRequest r,
    InstantJobUi ui,
  ) {
    final l = context.l10n;
    final busy = ui.busy != null;
    final arrivedAt = r.arrivedAt;
    final body = <Widget>[
      _Card(title: r.meetPoint.name, meta: l.jobMeetPointLine(r.areaLabel)),
      const SizedBox(height: AppSpace.s3),
      StatusTimeline(steps: _steps(l, r)),
      if (arrivedAt != null) ...[
        const SizedBox(height: AppSpace.s2),
        _NoShowButton(
          openAt: arrivedAt.add(kNoShowWait),
          now: ref.read(clockProvider),
          onPressed: busy ? null : () => _noShow(r),
        ),
      ],
    ];
    final footer = AppButton.primary(
      l.jobStart,
      key: const Key('job-start'),
      loading: ui.busy == InstantJobAction.start,
      onPressed: busy ? null : () => _call(_controller.startShoot),
    );
    return (body, footer);
  }

  (List<Widget>, Widget) _shooting(
    BuildContext context,
    InstantRequest r,
    InstantJobUi ui,
  ) {
    final l = context.l10n;
    final busy = ui.busy != null;
    final startedAt = r.startedAt;
    final endsAt = r.shootEndsAt;
    final body = <Widget>[
      if (endsAt != null)
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CountdownRing(
                key: const Key('job-shoot-ring'),
                deadline: endsAt,
                total: Duration(minutes: r.durationMin),
                size: 132,
                now: ref.read(clockProvider),
                onExpired: () => unawaited(_controller.tick()),
              ),
              const SizedBox(height: AppSpace.s1),
              Text(l.jobShootLeft, style: _metaStyle(context)),
            ],
          ),
        ),
      const SizedBox(height: AppSpace.s3),
      _PartyCard(
        request: r,
        meta: startedAt == null
            ? r.meetPoint.name
            : l.jobStartedLine(instantClock(startedAt), r.meetPoint.name),
        badge: _Badge(l.instantStatusInProgress, waiting: false),
      ),
      const SizedBox(height: AppSpace.s2),
      _Note(l.jobShootNote),
    ];
    final footer = AppButton.primary(
      l.jobFinish,
      key: const Key('job-finish'),
      loading: ui.busy == InstantJobAction.finish,
      onPressed: busy ? null : () => _call(_controller.finish),
    );
    return (body, footer);
  }

  /// Finished (waiting for the customer), completed and the ends.
  (List<Widget>, Widget) _closed(BuildContext context, InstantRequest r) {
    final l = context.l10n;
    final doneAt = r.finishedAt ?? r.completedAt;
    final body = switch (r.status) {
      InstantStatus.finished || InstantStatus.completed => <Widget>[
        _PartyCard(
          request: r,
          meta: doneAt == null
              ? r.meetPoint.name
              : l.jobFinishedLine(instantClock(doneAt), r.meetPoint.name),
          badge: r.status == InstantStatus.finished
              ? _Badge(l.jobWaitingBadge, waiting: true)
              : null,
        ),
        if (r.status == InstantStatus.finished) ...[
          const SizedBox(height: AppSpace.s2),
          _Note(l.jobFinishedNote),
        ],
      ],
      InstantStatus.cancelledByCustomer => <Widget>[
        Text(
          (r.feeVnd ?? 0) > 0
              ? l.jobCancelledFee(formatMoney(r.feeVnd!))
              : l.jobCancelledNoFee,
          key: const Key('job-cancelled-line'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
      _ => const <Widget>[],
    };
    final footer = AppButton.outline(
      l.jobBackToWork,
      key: const Key('job-back-to-work'),
      onPressed: () => context.go(_workPath),
    );
    return (body, footer);
  }
}

TextStyle? _metaStyle(BuildContext context) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return theme.textTheme.bodySmall?.copyWith(
    color: dark ? AppColorsDark.foregroundMuted : AppColors.foregroundMuted,
  );
}

/// Mock `.bar .t` with `<small>`: the status and "Lan Anh · Chân dung 1 giờ".
class _BarTitle extends StatelessWidget {
  const _BarTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _metaStyle(context),
      ),
    ],
  );
}

/// Mock `.card`: surface, card radius, hairline border.
BoxDecoration _cardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: dark ? AppColorsDark.surface : AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(color: theme.colorScheme.outlineVariant),
  );
}

/// Mock `.card` with the meet point: name bold, a meta line, actions right.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.meta, this.trailing});

  final String title;
  final String meta;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tail = trailing;
    return DecoratedBox(
      decoration: _cardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Row(
          children: [
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
                  Text(
                    meta,
                    key: const Key('job-meta'),
                    style: _metaStyle(context),
                  ),
                ],
              ),
            ),
            if (tail != null) ...[
              const SizedBox(width: AppSpace.s2),
              Flexible(child: tail),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mock S14.03-shooting/-done `.card`: the customer, the shoot, a badge.
class _PartyCard extends StatelessWidget {
  const _PartyCard({required this.request, required this.meta, this.badge});

  final InstantRequest request;
  final String meta;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final r = request;
    final b = badge;
    return DecoratedBox(
      decoration: _cardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Row(
          children: [
            AppAvatar(
              url: r.customerAvatarUrl,
              name: r.customerName,
              decorative: true,
            ),
            const SizedBox(width: AppSpace.s2h),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.jobSubtitle(
                      r.customerName,
                      instantGenreText(l, r.genre),
                      instantDurationText(l, r.durationMin),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    meta,
                    key: const Key('job-meta'),
                    style: _metaStyle(context),
                  ),
                ],
              ),
            ),
            if (b != null) ...[const SizedBox(width: AppSpace.s2), b],
          ],
        ),
      ),
    );
  }
}

/// Mock `.badge.b-ok` ("Đang chụp") / `.b-warn` ("Chờ khách").
class _Badge extends StatelessWidget {
  const _Badge(this.label, {required this.waiting});

  final String label;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return StatusBadge.custom(
      label: label,
      color: waiting
          ? (dark ? AppColorsDark.warningSubtle : AppColors.warningSubtle)
          : (dark ? AppColorsDark.successSubtle : AppColors.successSubtle),
      onColor: waiting
          ? (dark ? AppColorsDark.warning : AppColors.warning)
          : (dark ? AppColorsDark.success : AppColors.success),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: _metaStyle(context));
}

/// Mock `.btn.txt` in `--bad`: "Huỷ việc", "Khách không có mặt".
class _RedText extends StatelessWidget {
  const _RedText(this.label, {super.key, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppButton.text(
      label,
      size: AppButtonSize.small,
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(
          dark ? AppColorsDark.destructive : AppColors.destructive,
        ),
      ),
      onPressed: onPressed,
    );
  }
}

/// `jobLocationNeeded` with the way to grant it (the OS dialog while it can
/// still ask, else Settings).
class _LocationNeeded extends StatelessWidget {
  const _LocationNeeded({required this.status, required this.onAsk});

  final LocationPermissionStatus status;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings =
        status == LocationPermissionStatus.deniedForever ||
        status == LocationPermissionStatus.serviceOff;
    return Column(
      key: const Key('job-location-needed'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Note(l.jobLocationNeeded),
        AppButton.text(
          settings ? l.liveShutterOpenSettings : l.jobLocationAllow,
          size: AppButtonSize.small,
          tapAlignment: Alignment.centerLeft,
          onPressed: onAsk,
        ),
      ],
    );
  }
}

/// "Khách không có mặt (sau 12:40)": disabled until 15 minutes after the
/// arrival, counting down by the second, then "Khách không có mặt".
class _NoShowButton extends StatefulWidget {
  const _NoShowButton({
    required this.openAt,
    required this.now,
    required this.onPressed,
  });

  final DateTime openAt;
  final DateTime Function() now;
  final VoidCallback? onPressed;

  @override
  State<_NoShowButton> createState() => _NoShowButtonState();
}

class _NoShowButtonState extends State<_NoShowButton> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(_NoShowButton old) {
    super.didUpdateWidget(old);
    if (old.openAt != widget.openAt) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _left => widget.openAt.difference(widget.now());

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (_left <= Duration.zero) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_left <= Duration.zero) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final left = _left;
    if (left > Duration.zero) {
      // Rounded up, so it never reads 00:00 while still closed.
      final s = (left.inMilliseconds / 1000).ceil();
      String two(int n) => n.toString().padLeft(2, '0');
      return _RedText(
        l.jobNoShowIn('${two(s ~/ 60)}:${two(s % 60)}'),
        key: const Key('job-no-show'),
        onPressed: null,
      );
    }
    return _RedText(
      l.jobNoShow,
      key: const Key('job-no-show'),
      onPressed: widget.onPressed,
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => AppSkeleton.group(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        AppSpace.s6,
      ),
      children: [
        AppSkeleton.card(height: 150),
        const SizedBox(height: AppSpace.s3),
        AppSkeleton.card(height: 64),
        const SizedBox(height: AppSpace.s3),
        StatusTimeline.skeleton(),
      ],
    ),
  );
}
