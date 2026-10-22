// lib/core/widgets/map_preview.dart
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// One labelled place on a [MapPreview]; [self] is the viewer (blue dot).
@immutable
class MapPin {
  const MapPin({
    required this.lat,
    required this.lng,
    required this.label,
    this.self = false,
  });

  final double lat;
  final double lng;
  final String label;
  final bool self;
}

/// The area a [MapPreview] shows, in degrees.
typedef MapBounds = ({
  double minLat,
  double maxLat,
  double minLng,
  double maxLng,
});

/// Each side spans at least this many degrees (of latitude; longitude is
/// scaled by cos(latitude)), about 400 m, so pins a few metres apart are not
/// blown up to the edges.
const double kMapMinSpanDeg = 0.0036;

/// Padding around the pins, as a share of the span on each side.
const double kMapPadding = 0.2;

/// The pins' bounding box, expanded to [kMapMinSpanDeg] around its centre,
/// then padded by [kMapPadding] of the span on each side.
@visibleForTesting
MapBounds mapBoundsOf(List<MapPin> pins) {
  assert(pins.isNotEmpty);
  var minLat = pins.first.lat, maxLat = minLat;
  var minLng = pins.first.lng, maxLng = minLng;
  for (final p in pins.skip(1)) {
    minLat = math.min(minLat, p.lat);
    maxLat = math.max(maxLat, p.lat);
    minLng = math.min(minLng, p.lng);
    maxLng = math.max(maxLng, p.lng);
  }
  final cosLat = math.cos((minLat + maxLat) / 2 * math.pi / 180);
  ({double lo, double hi}) widen(double lo, double hi, double minSpan) {
    final span = math.max(hi - lo, minSpan);
    final mid = (lo + hi) / 2;
    final pad = span * kMapPadding;
    return (lo: mid - span / 2 - pad, hi: mid + span / 2 + pad);
  }

  final lat = widen(minLat, maxLat, kMapMinSpanDeg);
  final lng = widen(minLng, maxLng, kMapMinSpanDeg / cosLat);
  return (minLat: lat.lo, maxLat: lat.hi, minLng: lng.lo, maxLng: lng.hi);
}

/// Equirectangular projection of [p] into [box]: x is longitude scaled by
/// [cosLat], north is up, the bounds are fitted (not stretched) and centred.
@visibleForTesting
Offset projectMapPin(MapPin p, Rect box, MapBounds b, double cosLat) {
  final w = (b.maxLng - b.minLng) * cosLat, h = b.maxLat - b.minLat;
  final scale = math.min(box.width / w, box.height / h);
  final cx = box.center.dx, cy = box.center.dy;
  final mx = (b.minLng + b.maxLng) / 2, my = (b.minLat + b.maxLat) / 2;
  return Offset(cx + (p.lng - mx) * cosLat * scale, cy - (p.lat - my) * scale);
}

/// The decorative colours of the map (`map*` tokens, mock `.map`).
@immutable
class MapPalette {
  const MapPalette({
    required this.background,
    required this.block,
    required this.road,
    required this.water,
    required this.park,
  });

  factory MapPalette.of(Brightness brightness) => brightness == Brightness.dark
      ? const MapPalette(
          background: AppColorsDark.mapBg,
          block: AppColorsDark.mapBlock,
          road: AppColorsDark.mapRoad,
          water: AppColorsDark.mapWater,
          park: AppColorsDark.mapPark,
        )
      : const MapPalette(
          background: AppColors.mapBg,
          block: AppColors.mapBlock,
          road: AppColors.mapRoad,
          water: AppColors.mapWater,
          park: AppColors.mapPark,
        );

  final Color background;
  final Color block;
  final Color road;
  final Color water;
  final Color park;

  @override
  bool operator ==(Object other) =>
      other is MapPalette &&
      other.background == background &&
      other.block == block &&
      other.road == road &&
      other.water == water &&
      other.park == park;

  @override
  int get hashCode => Object.hash(background, block, road, water, park);
}

/// Schematic map (mock `.map`): decorative blocks/roads/water/park, labelled
/// pins placed by an equirectangular projection of [pins] (padding 20%,
/// minimum span 400 m), a dotted route between the first two pins when
/// [route], and a "Về vị trí của tôi" button when [onRecenter] is set. No
/// tiles and no maps SDK (plan #140 Decision 30): the streets are decoration,
/// only the pins' relative places are real. Screen readers hear "Bản đồ:"
/// and the pin labels.
class MapPreview extends StatelessWidget {
  const MapPreview({
    super.key,
    required this.pins,
    this.height = 250,
    this.route = false,
    this.onRecenter,
    this.borderRadius,
  });

  final List<MapPin> pins;
  final double height;
  final bool route;
  final VoidCallback? onRecenter;

  /// Defaults to the mock's `--r2` (16); `BorderRadius.zero` for a full-bleed map.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final palette = MapPalette.of(theme.brightness);
    final dark = theme.brightness == Brightness.dark;
    final accent = dark ? AppColorsDark.accent : AppColors.accent;
    return ClipRRect(
      key: const Key('map-preview'),
      borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.xl),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                container: true,
                image: true,
                label: l.mapSemantics(pins.map((p) => p.label).join(', ')),
                child: ExcludeSemantics(
                  child: LayoutBuilder(
                    builder: (context, c) => _layers(
                      context,
                      Offset.zero & c.biggest,
                      palette,
                      accent,
                    ),
                  ),
                ),
              ),
            ),
            if (onRecenter != null)
              Positioned(
                right: AppSpace.s2,
                bottom: AppSpace.s2,
                child: _RecenterButton(
                  tooltip: l.mapRecenter,
                  onPressed: onRecenter!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _layers(
    BuildContext context,
    Rect box,
    MapPalette palette,
    Color accent,
  ) {
    final points = <Offset>[];
    if (pins.isNotEmpty) {
      final b = mapBoundsOf(pins);
      final cosLat = math.cos((b.minLat + b.maxLat) / 2 * math.pi / 180);
      for (final p in pins) {
        points.add(projectMapPin(p, box, b, cosLat));
      }
    }
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            key: const Key('map-preview-bg'),
            color: palette.background,
            child: CustomPaint(
              key: const Key('map-preview-base'),
              painter: MapBasePainter(palette),
            ),
          ),
        ),
        if (route && points.length >= 2)
          Positioned.fill(
            child: CustomPaint(
              painter: _RoutePainter(points[0], points[1], accent),
            ),
          ),
        for (var i = 0; i < pins.length; i++)
          Positioned(
            left: points[i].dx,
            top: points[i].dy - _PinView.dot / 2,
            child: FractionalTranslation(
              translation: const Offset(-0.5, 0),
              child: _PinView(index: i, pin: pins[i]),
            ),
          ),
      ],
    );
  }
}

/// Mock `.mpin`: a 14px dot with a white ring (blue for the viewer) and the
/// label in a small chip under it.
class _PinView extends StatelessWidget {
  const _PinView({required this.index, required this.pin});

  final int index;
  final MapPin pin;

  // Mock `.mpin` sizes (no token matches them).
  static const double dot = 14;
  static const double _ring = 3;
  static const double _labelGap = 2;
  static const double _chipRadius = 6;
  static const _chipPadding = EdgeInsets.symmetric(horizontal: 5, vertical: 1);
  static const _shadow = BoxShadow(
    color: AppColors.overlay,
    blurRadius: 6,
    offset: Offset(0, 2),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fill = pin.self
        ? (dark ? AppColorsDark.mapSelf : AppColors.mapSelf)
        : (dark
              ? AppColorsDark.foregroundSecondary
              : AppColors.foregroundSecondary);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: dot,
          child: DecoratedBox(
            key: Key('map-pin-dot-$index'),
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              // Mock `border:3px solid #fff` in both themes:
              // `foregroundInverse` is white in light and dark.
              border: Border.all(
                color: dark
                    ? AppColorsDark.foregroundInverse
                    : AppColors.foregroundInverse,
                width: _ring,
              ),
              boxShadow: const [_shadow],
            ),
          ),
        ),
        const SizedBox(height: _labelGap),
        DecoratedBox(
          decoration: BoxDecoration(
            // Mock `.mpin span`: surface, `--line` border, ink text.
            color: dark ? AppColorsDark.surface : AppColors.surface,
            borderRadius: BorderRadius.circular(_chipRadius),
            border: Border.all(
              color: dark ? AppColorsDark.border : AppColors.border,
            ),
          ),
          child: Padding(
            padding: _chipPadding,
            child: Text(
              pin.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: AppText.tab,
                fontWeight: FontWeight.w600,
                color: dark ? AppColorsDark.foreground : AppColors.foreground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mock `.mfab`: 34px round button, 48dp hit area.
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(34),
        minimumSize: const Size.square(34),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
        backgroundColor: dark ? AppColorsDark.surface : AppColors.surface,
        side: BorderSide(
          color: dark ? AppColorsDark.borderStrong : AppColors.borderStrong,
        ),
      ),
      icon: AppIcon(
        AppIcons.myLocation,
        size: 16,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

/// The mock's decorative streets (`svg.base`, viewBox 260×200), scaled to
/// cover the map like `preserveAspectRatio="xMidYMid slice"`.
class MapBasePainter extends CustomPainter {
  const MapBasePainter(this.palette);

  final MapPalette palette;

  static const _view = Size(260, 200);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.max(
      size.width / _view.width,
      size.height / _view.height,
    );
    canvas
      ..save()
      ..translate(
        (size.width - _view.width * scale) / 2,
        (size.height - _view.height * scale) / 2,
      )
      ..scale(scale);

    final water = Path()
      ..moveTo(0, 170)
      ..quadraticBezierTo(60, 150, 120, 175)
      // SVG `T260 160`: the control point mirrors (60,150) through (120,175).
      ..quadraticBezierTo(180, 200, 260, 160)
      ..lineTo(260, 200)
      ..lineTo(0, 200)
      ..close();
    canvas
      ..drawPath(water, Paint()..color = palette.water)
      ..drawRRect(
        RRect.fromLTRBR(150, 105, 220, 145, const Radius.circular(6)),
        Paint()..color = palette.park,
      );
    final block = Paint()..color = palette.block;
    for (final r in const [
      Rect.fromLTWH(12, 12, 60, 40),
      Rect.fromLTWH(88, 12, 70, 40),
      Rect.fromLTWH(174, 12, 74, 28),
      Rect.fromLTWH(12, 68, 60, 50),
      Rect.fromLTWH(88, 68, 48, 50),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        block,
      );
    }
    final road = Paint()
      ..color = palette.road
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(
        Path()
          ..moveTo(0, 60)
          ..lineTo(260, 60)
          ..moveTo(80, 0)
          ..lineTo(80, 160)
          ..moveTo(166, 0)
          ..lineTo(166, 100)
          ..lineTo(240, 150)
          ..moveTo(0, 128)
          ..quadraticBezierTo(90, 140, 150, 100),
        road,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(MapBasePainter old) => old.palette != palette;
}

/// Mock route: a dotted curve (dash 1, gap 7, 4px round caps) between two
/// pins, bowed a little to one side so it does not read as a measured line.
class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.from, this.to, this.color);

  final Offset from;
  final Offset to;
  final Color color;

  static const _dash = 1.0;
  static const _gap = 7.0;
  static const _bow = 0.15;

  @override
  void paint(Canvas canvas, Size size) {
    final d = to - from;
    if (d.distance < _gap) return;
    final mid = from + d / 2;
    final normal = Offset(-d.dy, d.dx) * _bow;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(mid.dx + normal.dx, mid.dy + normal.dy, to.dx, to.dy);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final PathMetric m in path.computeMetrics()) {
      for (var t = 0.0; t < m.length; t += _dash + _gap) {
        canvas.drawPath(m.extractPath(t, t + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.from != from || old.to != to || old.color != color;
}
