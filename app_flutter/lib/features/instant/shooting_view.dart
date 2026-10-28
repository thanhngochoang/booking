// S13.06 (`#S13.06`, `-confirm`): the shoot. `in_progress`: the clock to
// `shootEndsAt` (the flow screen ticks the server there, Decision 6), the
// photographer and the steps so far. `finished`: the photographer pressed
// "Hoàn thành"; it completes by itself 2 hours after `finishedAt`. In both
// the customer can confirm at once ("Xác nhận hoàn thành", companion
// Decision 9); a `conflict` means the clock already completed it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant/instant_bold_part.dart';
import 'package:photobooking/features/instant/instant_status_badge.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// A `finished` request completes by itself this long after `finishedAt`
/// (domain `INSTANT.AUTO_COMPLETE_H`).
const kInstantAutoComplete = Duration(hours: 2);

/// "1:52:10" (hours, minutes, seconds; "0:42:05" under an hour).
String instantHms(Duration left) {
  final s = left.isNegative ? 0 : left.inSeconds;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${s ~/ 3600}:${two(s ~/ 60 % 60)}:${two(s % 60)}';
}

class ShootingView extends ConsumerStatefulWidget {
  const ShootingView({super.key, required this.request});

  final InstantRequest request;

  @override
  ConsumerState<ShootingView> createState() => _ShootingViewState();
}

class _ShootingViewState extends ConsumerState<ShootingView> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    final l = context.l10n;
    final id = widget.request.id;
    setState(() => _busy = true);
    try {
      await ref.read(instantRepositoryProvider).confirmComplete(id);
    } on Object catch (e) {
      if (!mounted) return;
      if (InstantError(instantErrorCodeOf(e)).kind ==
          InstantErrorKind.conflict) {
        // Completed by the clock meanwhile: read the request again.
        ref.invalidate(instantRequestProvider(id));
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(instantErrorText(l, e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final r = widget.request;
    final finished = r.status == InstantStatus.finished;
    final name = r.photographer?.name ?? '';
    final chatId = r.chatId;
    final muted = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final endsAt = r.shootEndsAt;
    final finishedAt = r.finishedAt;
    final children = <Widget>[
      if (!finished && endsAt != null)
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CountdownRing(
                key: const Key('shooting-ring'),
                deadline: endsAt,
                total: Duration(minutes: r.durationMin),
                size: 132,
                now: ref.read(clockProvider),
              ),
              const SizedBox(height: AppSpace.s1),
              Text(
                l.jobShootLeft,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      if (!finished) const SizedBox(height: AppSpace.s3),
      _ShootCard(
        request: r,
        badge: finished ? null : l.instantStatusInProgress,
      ),
      const SizedBox(height: AppSpace.s3),
      if (finished && finishedAt != null) ...[
        CountdownText(
          key: const Key('shooting-auto-complete'),
          deadline: finishedAt.add(kInstantAutoComplete),
          now: ref.read(clockProvider),
          interval: const Duration(seconds: 1),
          builder: (context, left) {
            final time = instantHms(left);
            return InstantBoldPart(
              l.shootingFinishedBody(name, time),
              part: time,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            );
          },
        ),
        const SizedBox(height: AppSpace.s3),
      ],
      StatusTimeline(steps: _steps(l, r)),
      if (!finished) ...[
        const SizedBox(height: AppSpace.s2),
        Text(
          l.shootingNote(name),
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    ];
    return ScreenCode(
      ScreenCodes.instantInProgress,
      label: finished ? 'confirm' : null,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: Text(finished ? l.shootingFinishedTitle : l.shootingTitle),
            actions: [
              IconButton(
                key: const Key('shooting-chat'),
                tooltip: l.trackingMessage,
                icon: const AppIcon(AppIcons.chat),
                onPressed: chatId == null
                    ? null
                    : () => context.push('/chat/$chatId'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s2,
              AppSpace.s4,
              AppSpace.s6,
            ),
            children: children,
          ),
          bottomNavigationBar: AppFooterBar(
            child: AppButton.primary(
              l.shootingConfirm,
              key: const Key('shooting-confirm'),
              loading: _busy,
              onPressed: _busy ? null : _confirm,
            ),
          ),
        ),
      ),
    );
  }

  /// Accepted and arrived (done, Vietnam time), then "Hoàn thành và giao 30
  /// ảnh trong 48 giờ" (upcoming).
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
      TimelineStep(
        title: arrivedAt == null
            ? l.instantStatusArrived
            : l.jobStepArrived(instantClock(arrivedAt)),
        state: TimelineStepState.done,
      ),
      TimelineStep(
        title: l.shootingStepDeliver(r.photos),
        state: TimelineStepState.upcoming,
      ),
    ];
  }
}

/// Mock `.card`: the photographer, "Minh Trí · Chân dung 1 giờ", "Bắt đầu
/// 15:42 · {meet point}" and, while shooting, the "Đang chụp" badge.
class _ShootCard extends StatelessWidget {
  const _ShootCard({required this.request, this.badge});

  final InstantRequest request;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final r = request;
    final p = r.photographer;
    final name = p?.name ?? '';
    final startedAt = r.startedAt;
    final b = badge;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Row(
          children: [
            AppAvatar(url: p?.avatarUrl, name: name, decorative: true),
            const SizedBox(width: AppSpace.s2h),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.shootingCard(
                      name,
                      instantGenreText(l, r.genre),
                      instantDurationText(l, r.durationMin),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    startedAt == null
                        ? r.meetPoint.name
                        : l.shootingMeta(
                            instantClock(startedAt),
                            r.meetPoint.name,
                          ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: dark
                          ? AppColorsDark.foregroundMuted
                          : AppColors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (b != null) ...[
              const SizedBox(width: AppSpace.s2),
              InstantStatusBadge(b),
            ],
          ],
        ),
      ),
    );
  }
}
