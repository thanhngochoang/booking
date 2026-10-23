// S06.01 (`#S06.01-instant`): the Live Shutter entry at the top of Công việc
// and, under it, the active Chụp ngay job.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';

/// Hidden while Chụp ngay is off ([instantEnabledProvider], Decision 28):
/// nothing is listened to then.
class LiveShutterCard extends ConsumerWidget {
  const LiveShutterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(instantEnabledProvider)) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AsyncView<LiveShutterState?>(
          value: ref.watch(livePresenceProvider),
          skeleton: (_) => AppSkeleton.card(height: 64),
          // The entry still opens S14.01, which says what failed.
          error: (_, _, _) => const _EntryCard(line: null),
          data: (_, p) => _EntryCard(
            line: p?.online == true
                ? l.liveShutterCardOn
                : l.liveShutterCardOff,
          ),
        ),
        AsyncView<InstantRequest?>(
          value: ref.watch(myActiveInstantJobProvider),
          skeleton: (_) => const SizedBox.shrink(),
          error: (_, _, _) => const SizedBox.shrink(),
          data: (_, job) =>
              job == null ? const SizedBox.shrink() : _JobCard(job),
        ),
      ],
    );
  }
}

/// Mock `.card.hi`: bolt tile, "Live Shutter", the state line, chevron.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.line});

  final String? line;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final radius = BorderRadius.circular(AppRadius.card);
    final text = line;
    return Semantics(
      button: true,
      label: text == null ? l.liveShutterTitle : '${l.liveShutterTitle}. $text',
      excludeSemantics: true,
      child: DecoratedBox(
        key: const Key('live-shutter-card'),
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.surface : AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: dark ? AppColorsDark.borderStrong : AppColors.borderStrong,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: () => context.push('/work/instant'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s3),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Center(
                      child: AppIcon(
                        AppIcons.instant,
                        size: 20,
                        color: secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.liveShutterTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (text != null)
                          Text(
                            text,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  AppIcon(AppIcons.chevron, size: 20, color: secondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The active job: customer, "{genre} {duration} · {place}", status badge;
/// opens S14.03.
class _JobCard extends StatelessWidget {
  const _JobCard(this.job);

  final InstantRequest job;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final radius = BorderRadius.circular(AppRadius.xl);
    final service =
        '${instantGenreText(l, job.genre)} ${instantDurationText(l, job.durationMin)}';
    final status = instantStatusText(l, job.status);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s3),
      child: DecoratedBox(
        key: Key('instant-job-${job.id}'),
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.glass : AppColors.glass,
          borderRadius: radius,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: () => context.push('/work/instant/${job.id}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s2h),
              child: Row(
                children: [
                  AppAvatar(
                    url: job.customerAvatarUrl,
                    name: job.customerName,
                    size: AppAvatarSize.xs,
                    decorative: true,
                  ),
                  const SizedBox(width: AppSpace.s2h),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.liveShutterJobTitle(job.customerName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l.liveShutterJobMeta(service, job.meetPoint.name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: AppSpace.s2),
                    StatusBadge.custom(
                      label: status,
                      color: dark ? AppColorsDark.success : AppColors.success,
                      onColor: AppColors.foregroundInverse,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
