// lib/core/widgets/countdown.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// Progress ring with big number and unit for countdowns (spec .cd):
/// updates per second when < 1 hour, per minute when >= 1 hour.
/// Announces to assistive tech at 5m, 1m, 10s and 0s thresholds.
class CountdownRing extends StatefulWidget {
  const CountdownRing({
    super.key,
    required this.deadline,
    required this.total,
    this.size = 96,
    this.onExpired,
    this.now,
  });

  final DateTime deadline;
  final Duration total;
  final double size;
  final VoidCallback? onExpired;
  final DateTime Function()? now;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing> {
  Timer? _timer;
  late Duration _left;
  bool _expiredCalled = false;

  DateTime _currentTime() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _computeLeft();
    _scheduleNextTick();
  }

  @override
  void didUpdateWidget(CountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline ||
        oldWidget.total != widget.total) {
      _computeLeft();
      _scheduleNextTick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _computeLeft() {
    final now = _currentTime();
    final diff = widget.deadline.difference(now);
    if (diff <= Duration.zero) {
      _left = Duration.zero;
      _timer?.cancel();
      _timer = null;
      if (!_expiredCalled) {
        _expiredCalled = true;
        widget.onExpired?.call();
      }
    } else {
      _left = diff;
    }
  }

  void _scheduleNextTick() {
    _timer?.cancel();
    _timer = null;

    if (_left <= Duration.zero) return;

    final duration = _left.inHours >= 1
        ? const Duration(minutes: 1)
        : const Duration(seconds: 1);

    _timer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _computeLeft();
      });
      _scheduleNextTick();
    });
  }

  bool _isAnnounceThreshold(int seconds) {
    return seconds == 300 || seconds == 60 || seconds == 10 || seconds == 0;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgMuted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final primary = dark ? AppColorsDark.primary : AppColors.primary;
    final trackColor = dark
        ? AppColorsDark.surfaceMuted
        : AppColors.surfaceMuted;

    final totalSeconds = widget.total.inSeconds;
    final fraction = totalSeconds > 0
        ? (_left.inSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;

    final String numberStr;
    final String unitStr;
    final String semanticsLabel;

    if (_left <= Duration.zero) {
      numberStr = '0';
      unitStr = 'giây';
      semanticsLabel = 'Còn 0 giây';
    } else if (_left.inHours >= 1) {
      numberStr = _left.inHours.toString();
      unitStr = 'giờ';
      semanticsLabel = 'Còn ${_left.inHours} giờ';
    } else if (_left.inMinutes >= 1) {
      numberStr = _left.inMinutes.toString();
      unitStr = 'phút';
      semanticsLabel = 'Còn ${_left.inMinutes} phút';
    } else {
      numberStr = _left.inSeconds.toString();
      unitStr = 'giây';
      semanticsLabel = 'Còn ${_left.inSeconds} giây';
    }

    final isLiveRegion = _isAnnounceThreshold(_left.inSeconds);

    return Semantics(
      label: semanticsLabel,
      liveRegion: isLiveRegion,
      child: ExcludeSemantics(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingPainter(
                  fraction: fraction,
                  primaryColor: primary,
                  trackColor: trackColor,
                  strokeWidth: math.max(3.0, widget.size * 0.05),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    numberStr,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: widget.size * 0.29,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: fg,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    unitStr,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: widget.size * 0.11,
                      fontWeight: FontWeight.w500,
                      color: fgMuted,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.primaryColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double fraction;
  final Color primaryColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (fraction > 0) {
      final progressPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Dynamic countdown text builder (e.g. "Nhận · còn 22 giờ"):
/// ticks per minute when >= 1 hour, per second when < 1 hour.
class CountdownText extends StatefulWidget {
  const CountdownText({
    super.key,
    required this.deadline,
    required this.builder,
    this.onExpired,
    this.now,
  });

  final DateTime deadline;
  final Widget Function(BuildContext context, Duration left) builder;
  final VoidCallback? onExpired;
  final DateTime Function()? now;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  late Duration _left;
  bool _expiredCalled = false;

  DateTime _currentTime() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _computeLeft();
    _scheduleNextTick();
  }

  @override
  void didUpdateWidget(CountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _computeLeft();
      _scheduleNextTick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _computeLeft() {
    final now = _currentTime();
    final diff = widget.deadline.difference(now);
    if (diff <= Duration.zero) {
      _left = Duration.zero;
      _timer?.cancel();
      _timer = null;
      if (!_expiredCalled) {
        _expiredCalled = true;
        widget.onExpired?.call();
      }
    } else {
      _left = diff;
    }
  }

  void _scheduleNextTick() {
    _timer?.cancel();
    _timer = null;

    if (_left <= Duration.zero) return;

    final duration = _left.inHours >= 1
        ? const Duration(minutes: 1)
        : const Duration(seconds: 1);

    _timer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _computeLeft();
      });
      _scheduleNextTick();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _left);
  }
}

/// Determinate ring for uploads (S05.05 share grid, S10.01):
/// primary stroke on transparent. Replaces any determinate CircularProgressIndicator.
class UploadProgressRing extends StatelessWidget {
  const UploadProgressRing({super.key, required this.fraction, this.size = 28});

  final double fraction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.clamp(0.0, 1.0);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColorsDark.primary : AppColors.primary;
    final track = dark ? AppColorsDark.border : AppColors.border;

    return Semantics(
      value: '${(clamped * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: _RingPainter(
            fraction: clamped,
            primaryColor: primary,
            trackColor: track,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}
