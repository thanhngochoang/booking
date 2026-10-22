// lib/core/widgets/match_overlay.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_avatar.dart';
import 'package:photobooking/core/widgets/app_button.dart';

/// S13.04: one continuous line draws a camera (1.8 s), the lens flashes, both
/// avatars land in the lens; continues by itself after ~3 s; "Tiếp tục"
/// always; tap skips to the last frame; reduced motion = last frame, no haptic.
///
/// [name] is the other person ("Đã match với {name}"), [body] the line under
/// it, written by the screen for its side (customer or photographer).
class MatchOverlay extends StatefulWidget {
  const MatchOverlay({
    super.key,
    required this.name,
    required this.body,
    this.myAvatarUrl,
    this.theirAvatarUrl,
    required this.onContinue,
    this.autoContinueAfter = const Duration(seconds: 3),
  });

  final String name;
  final String body;
  final String? myAvatarUrl;
  final String? theirAvatarUrl;
  final VoidCallback onContinue;
  final Duration autoContinueAfter;

  @override
  State<MatchOverlay> createState() => _MatchOverlayState();
}

/// Mock `.mcam` timeline, in ms of one 2,5 s run.
const _totalMs = 2500.0;
const _flashAtMs = 1750.0;

/// Progress of [v] (0..1 of the run) inside the window [fromMs, toMs].
double _window(
  double v,
  double fromMs,
  double toMs, [
  Curve curve = Curves.linear,
]) {
  final ms = v * _totalMs;
  if (ms <= fromMs) return 0;
  if (ms >= toMs) return 1;
  return curve.transform((ms - fromMs) / (toMs - fromMs));
}

/// Mock `cubic-bezier(.65,0,.35,1)` (draw), `(.2,.6,.3,1)` (flash) and
/// `(.34,1.56,.64,1)` (the light spring of the avatars).
const _draw = Cubic(0.65, 0, 0.35, 1);
const _flash = Cubic(0.2, 0.6, 0.3, 1);
const _spring = Cubic(0.34, 1.56, 0.64, 1);

class _MatchOverlayState extends State<MatchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _totalMs.round()),
  );
  Timer? _auto;
  bool _started = false;
  bool _flashed = false;
  bool _continued = false;

  @override
  void initState() {
    super.initState();
    _run.addListener(_onTick);
    _auto = Timer(widget.autoContinueAfter, _continue);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduced motion: the last frame at once, no flash, no haptic.
      _flashed = true;
      _run.value = 1;
    } else {
      _run.forward();
    }
  }

  void _onTick() {
    if (_flashed || _run.value * _totalMs < _flashAtMs) return;
    _flashed = true;
    HapticFeedback.lightImpact();
  }

  /// A tap anywhere jumps to the last frame (no flash, no haptic).
  void _skip() {
    if (!_run.isAnimating) return;
    _flashed = true;
    _run
      ..stop()
      ..value = 1;
  }

  void _continue() {
    if (_continued || !mounted) return;
    _continued = true;
    _auto?.cancel();
    widget.onContinue();
  }

  @override
  void dispose() {
    _auto?.cancel();
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = dark ? AppColorsDark.primary : AppColors.primary;
    final muted = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final title = l.matchTitle(widget.name);
    // The name is the gradient word of the mock (`.gt`): accent here.
    final parts = widget.name.isEmpty ? [title] : title.split(widget.name);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4,
            vertical: AppSpace.s6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  final w = math.min(240.0, c.maxWidth * 0.78);
                  return SizedBox(
                    key: const Key('match-camera'),
                    width: w,
                    height: w * _box.height / _box.width,
                    child: ExcludeSemantics(
                      child: AnimatedBuilder(
                        animation: _run,
                        builder: (context, _) => _Camera(
                          progress: _run.value,
                          ink: theme.colorScheme.onSurface,
                          primary: primary,
                          myAvatar: _avatar(widget.myAvatarUrl, ''),
                          theirAvatar: _avatar(
                            widget.theirAvatarUrl,
                            widget.name,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpace.s3),
              AnimatedBuilder(
                animation: _run,
                builder: (context, child) {
                  final t = _window(_run.value, 2100, 2500, Curves.easeOut);
                  return Opacity(
                    key: const Key('match-text'),
                    opacity: t,
                    alwaysIncludeSemantics: true,
                    child: Transform.translate(
                      offset: Offset(0, 6 * (1 - t)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Semantics(
                      liveRegion: true,
                      label: title,
                      header: true,
                      excludeSemantics: true,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            for (var i = 0; i < parts.length; i++) ...[
                              if (i > 0)
                                TextSpan(
                                  text: widget.name,
                                  style: TextStyle(color: primary),
                                ),
                              TextSpan(text: parts[i]),
                            ],
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: AppText.xl,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s3),
                    ConstrainedBox(
                      // Mock `max-width: 30ch`.
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        widget.body,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              AppButton.primary(
                l.matchContinue,
                key: const Key('match-continue'),
                size: AppButtonSize.small,
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(String? url, String name) => url == null && name.isEmpty
      ? DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.secondary,
            border: Border.all(
              color: Theme.of(context).scaffoldBackgroundColor,
              width: 3,
            ),
          ),
        )
      : AppAvatar(
          url: url,
          name: name,
          size: AppAvatarSize.sm,
          decorative: true,
        );
}

/// The mock's `viewBox="40 80 420 250"`.
const _box = Rect.fromLTWH(40, 80, 420, 250);

/// Mock `.mcam`: the camera line, its two buttons, the wash behind the
/// lens, the flash ring and the two avatars in the lens.
class _Camera extends StatelessWidget {
  const _Camera({
    required this.progress,
    required this.ink,
    required this.primary,
    required this.myAvatar,
    required this.theirAvatar,
  });

  final double progress;
  final Color ink;
  final Color primary;
  final Widget myAvatar;
  final Widget theirAvatar;

  @override
  Widget build(BuildContext context) {
    // Mock `.av`: 40dp at 44% / 56% across, 56% down, 100 ms apart.
    Widget landing(Widget avatar, double x, double fromMs) {
      final t = _window(progress, fromMs, fromMs + 500, _spring);
      final shown = _window(progress, fromMs, fromMs + 500);
      return Align(
        alignment: Alignment(x * 2 - 1, 0.56 * 2 - 1),
        child: Opacity(
          opacity: shown.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.6 + 0.4 * t,
            child: SizedBox.square(dimension: 40, child: avatar),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _CameraPainter(
            progress: progress,
            ink: ink,
            primary: primary,
          ),
        ),
        landing(myAvatar, 0.44, 1850),
        landing(theirAvatar, 0.56, 1950),
      ],
    );
  }
}

class _CameraPainter extends CustomPainter {
  _CameraPainter({
    required this.progress,
    required this.ink,
    required this.primary,
  });

  final double progress;
  final Color ink;
  final Color primary;

  static final Path _body = _svgPath(
    'M90 310C70 310 60 290 60 270L60 180C60 160 75 150 95 150L140 150C150 150 155 140 160 130L170 115C175 105 185 100 200 100L300 100C315 100 325 105 330 115L340 130C345 140 350 150 360 150L405 150C425 150 440 160 440 180L440 270C440 290 425 310 400 310L100 310C140 310 170 305 190 285C170 270 160 245 160 220C160 170 200 130 250 130C300 130 340 170 340 220C340 270 300 310 250 310C220 310 195 295 180 270C195 240 215 220 250 220C270 220 285 235 285 255C285 275 270 290 250 290C220 290 200 260 210 220C220 180 250 160 280 175C310 190 315 230 295 260C320 230 310 175 260 165C220 155 180 185 180 220C180 250 200 275 225 282C290 295 360 280 380 240C390 220 385 190 370 175C360 165 345 165 335 170C345 140 330 120 300 120L200 120C180 120 170 130 165 145C130 160 100 160 85 180C75 195 75 240 85 270C95 295 130 305 170 305',
  );
  static final Path _buttons = _svgPath(
    'M120 150C120 135 135 135 135 150M365 150C365 130 390 130 390 150',
  );
  static final Path _wash = _svgPath(
    'M180 220C140 160 320 140 340 220C360 300 200 280 180 220Z',
  );
  static const _lens = Offset(250, 220);
  static const _flashRadius = 92.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _box.width;
    canvas
      ..save()
      ..scale(s)
      ..translate(-_box.left, -_box.top);

    // Wash behind the lens: primary 16%, grows from 85%.
    final wash = _window(progress, 1200, 2100, Curves.easeOut);
    if (wash > 0) {
      final c = _wash.getBounds().center;
      final k = 0.85 + 0.15 * wash;
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..scale(k)
        ..translate(-c.dx, -c.dy)
        ..drawPath(
          _wash,
          Paint()..color = primary.withValues(alpha: 0.16 * wash),
        )
        ..restore();
    }

    final line = Paint()
      ..color = ink.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_partial(_body, _window(progress, 0, 1800, _draw)), line);
    canvas.drawPath(
      _partial(_buttons, _window(progress, 1500, 1950, _draw)),
      line..strokeWidth = 3.5,
    );

    // The lens flashes once: a primary ring grows 0.55 → 1.35 and fades.
    final f = _window(progress, _flashAtMs, 2450, _flash);
    if (f > 0 && f < 1) {
      canvas.drawCircle(
        _lens,
        _flashRadius * (0.55 + 0.8 * f),
        Paint()
          ..color = primary.withValues(alpha: 0.9 * (1 - f))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CameraPainter old) =>
      old.progress != progress || old.ink != ink || old.primary != primary;
}

/// The first [t] (0..1) of [path]'s length, across its contours.
Path _partial(Path path, double t) {
  if (t >= 1) return path;
  final out = Path();
  if (t <= 0) return out;
  final metrics = path.computeMetrics().toList();
  var left = t * metrics.fold<double>(0, (a, PathMetric m) => a + m.length);
  for (final m in metrics) {
    if (left <= 0) break;
    out.addPath(m.extractPath(0, math.min(left, m.length)), Offset.zero);
    left -= m.length;
  }
  return out;
}

/// An SVG path of absolute `M`, `L`, `C` and `Z` commands (the mock's).
Path _svgPath(String d) {
  final tokens = RegExp(r'[MLCZ]|-?\d*\.?\d+')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  final path = Path();
  var i = 0;
  var cmd = 'M';
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (RegExp(r'^[MLCZ]$').hasMatch(tokens[i])) {
      cmd = tokens[i++];
      if (cmd == 'Z') {
        path.close();
        continue;
      }
    }
    switch (cmd) {
      case 'M':
        path.moveTo(next(), next());
        cmd = 'L';
      case 'L':
        path.lineTo(next(), next());
      case 'C':
        path.cubicTo(next(), next(), next(), next(), next(), next());
    }
  }
  return path;
}
