// lib/core/widgets/status_timeline.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';

enum TimelineStepState { done, current, upcoming, stopped }

@immutable
class TimelineStep {
  const TimelineStep({required this.title, this.subtitle, required this.state});

  final String title;
  final String? subtitle;
  final TimelineStepState state;
}

/// Booking progress timeline (spec #statustimeline, S05.02):
/// vertical milestone sequence (done, current, upcoming, stopped)
/// with connecting lines and screen reader progress announcements.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.steps});

  final List<TimelineStep> steps;

  static Widget skeleton({int steps = 3}) =>
      _StatusTimelineSkeleton(stepsCount: steps);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          _buildStep(
            i,
            steps[i],
            total: steps.length,
            isLast: i == steps.length - 1,
            fg: fg,
            fgSec: fgSec,
            dark: dark,
          ),
      ],
    );
  }

  Widget _buildStep(
    int index,
    TimelineStep step, {
    required int total,
    required bool isLast,
    required Color fg,
    required Color fgSec,
    required bool dark,
  }) {
    final stateLabel = switch (step.state) {
      TimelineStepState.done => 'đã xong',
      TimelineStepState.current => 'đang diễn ra',
      TimelineStepState.upcoming => 'sắp tới',
      TimelineStepState.stopped => 'đã dừng',
    };

    final semanticsLabel =
        'Bước ${index + 1} trong $total, ${step.title}, $stateLabel'
        '${step.subtitle != null ? ', ${step.subtitle}' : ''}';

    return Semantics(
      label: semanticsLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left track: dot + vertical line
              SizedBox(
                width: 18,
                child: Column(
                  children: [
                    const SizedBox(height: 2),
                    _buildDot(index, step.state, dark: dark),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: dark
                              ? AppColorsDark.divider
                              : AppColors.divider,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Right content: title + subtitle
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: step.state == TimelineStepState.current
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: fg,
                          height: 1.25,
                        ),
                      ),
                      if (step.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          step.subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            color: fgSec,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index, TimelineStepState state, {required bool dark}) {
    final key = ValueKey('timeline_dot_$index');
    final success = dark ? AppColorsDark.success : AppColors.success;
    final primary = dark ? AppColorsDark.primary : AppColors.primary;
    final primarySubtle = dark
        ? AppColorsDark.primarySubtle
        : AppColors.primarySubtle;
    final destructive = dark
        ? AppColorsDark.destructive
        : AppColors.destructive;
    final border = dark ? AppColorsDark.border : AppColors.border;
    final surface = dark ? AppColorsDark.surface : AppColors.surface;

    switch (state) {
      case TimelineStepState.done:
        return DecoratedBox(
          key: key,
          decoration: BoxDecoration(
            color: success,
            shape: BoxShape.circle,
            border: Border.all(color: success, width: 2),
          ),
          child: const SizedBox(width: 14, height: 14),
        );
      case TimelineStepState.current:
        return DecoratedBox(
          key: key,
          decoration: BoxDecoration(
            color: primarySubtle,
            shape: BoxShape.circle,
            border: Border.all(color: primary, width: 2),
            boxShadow: [BoxShadow(color: primarySubtle, spreadRadius: 2)],
          ),
          child: const SizedBox(width: 14, height: 14),
        );
      case TimelineStepState.upcoming:
        return DecoratedBox(
          key: key,
          decoration: BoxDecoration(
            color: surface,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2),
          ),
          child: const SizedBox(width: 14, height: 14),
        );
      case TimelineStepState.stopped:
        return DecoratedBox(
          key: key,
          decoration: BoxDecoration(
            color: destructive,
            shape: BoxShape.circle,
            border: Border.all(color: destructive, width: 2),
          ),
          child: const SizedBox(width: 14, height: 14),
        );
    }
  }
}

class _StatusTimelineSkeleton extends StatelessWidget {
  const _StatusTimelineSkeleton({required this.stepsCount})
    : super(key: const ValueKey('status_timeline_skeleton'));

  final int stepsCount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final divider = dark ? AppColorsDark.divider : AppColors.divider;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < stepsCount; i++) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    child: Column(
                      children: [
                        const SizedBox(height: 2),
                        const AppSkeleton.box(
                          width: 14,
                          height: 14,
                          radius: AppRadius.full,
                        ),
                        if (i < stepsCount - 1)
                          Expanded(child: Container(width: 2, color: divider)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i < stepsCount - 1 ? 12 : 0,
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.55,
                            child: AppSkeleton.line(height: 14),
                          ),
                          SizedBox(height: 6),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.35,
                            child: AppSkeleton.line(height: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
