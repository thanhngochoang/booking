// lib/core/widgets/provider_mark.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/verified_mark.dart';
import 'package:photobooking/data/content/provider_type.dart';

/// Which mark follows a provider's name. Three shapes and colours, so the
/// kind never rests on colour alone: blue disc, gold disc, gold scalloped seal.
enum ProviderMarkKind { verified, artist, studio }

/// Picks the mark for a provider (plan A1, decision 5): an artist always gets
/// the gold tick; a studio gets the seal only once verified; an individual
/// gets the blue tick only once verified. `null` means no mark.
ProviderMarkKind? providerMarkOf({
  required ProviderType type,
  required bool verified,
}) => switch (type) {
  ProviderType.artist => ProviderMarkKind.artist,
  ProviderType.studio => verified ? ProviderMarkKind.studio : null,
  ProviderType.individual => verified ? ProviderMarkKind.verified : null,
};

/// The mark itself: [VerifiedMark] for [ProviderMarkKind.verified], a gold
/// gradient disc for artist, a 12-scallop gold seal for studio. Carries the
/// accessible name and a long-press tooltip.
class ProviderMark extends StatelessWidget {
  const ProviderMark(this.kind, {super.key, this.size});

  final ProviderMarkKind kind;

  /// Edge length; defaults to 14 (verified, artist) or 16 (studio).
  final double? size;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    switch (kind) {
      case ProviderMarkKind.verified:
        return VerifiedMark(size: size ?? 14);
      case ProviderMarkKind.artist:
        final d = size ?? 14;
        return _Labelled(
          label: l.providerArtistMark,
          child: SizedBox.square(
            dimension: d,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: _goldGradient,
              ),
              child: AppIcon(
                AppIcons.check,
                size: d * 0.72,
                color: AppColors.goldInk,
              ),
            ),
          ),
        );
      case ProviderMarkKind.studio:
        final d = size ?? 16;
        return _Labelled(
          label: l.providerStudioMark,
          child: CustomPaint(
            size: Size.square(d),
            painter: const ProviderSealPainter(),
          ),
        );
    }
  }
}

const _goldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.goldGradStart, AppColors.goldGradEnd],
);

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Tooltip(
      message: label,
      child: ExcludeSemantics(child: child),
    ),
  );
}

/// Paints the studio seal: the 12-scallop outline of the mock's `i-seal`
/// symbol (24x24 box) filled with the gold gradient, and a [AppColors.goldInk]
/// check on top.
class ProviderSealPainter extends CustomPainter {
  const ProviderSealPainter();

  static final Path _seal = _buildSeal();

  static Path _buildSeal() {
    // Quadratic segments of the mock path, as (control x, y, end x, y).
    const start = (12.0, 2.6);
    const segments = <List<double>>[
      [15.21, 0.02, 16.7, 3.86],
      [20.77, 3.23, 20.14, 7.3],
      [23.98, 8.79, 21.4, 12.0],
      [23.98, 15.21, 20.14, 16.7],
      [20.77, 20.77, 16.7, 20.14],
      [15.21, 23.98, 12.0, 21.4],
      [8.79, 23.98, 7.3, 20.14],
      [3.23, 20.77, 3.86, 16.7],
      [0.02, 15.21, 2.6, 12.0],
      [0.02, 8.79, 3.86, 7.3],
      [3.23, 3.23, 7.3, 3.86],
      [8.79, 0.02, 12.0, 2.6],
    ];
    final p = Path()..moveTo(start.$1, start.$2);
    for (final s in segments) {
      p.quadraticBezierTo(s[0], s[1], s[2], s[3]);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      _seal,
      Paint()
        ..shader = _goldGradient.createShader(
          const Rect.fromLTWH(0, 0, 24, 24),
        ),
    );
    final check = Path()
      ..moveTo(7.6, 12.2)
      ..relativeLineTo(3, 3)
      ..relativeLineTo(5.8, -6.4);
    canvas.drawPath(
      check,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.goldInk,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ProviderSealPainter oldDelegate) => false;
}

/// The pill under a name: "Nhiếp ảnh gia" (gold, with " · n giải" when
/// [awards] > 0 and [showAwards]) or "Studio" (with " · district" when given).
/// Empty for an individual. Always text, so the type never depends on colour.
class ProviderTag extends StatelessWidget {
  const ProviderTag({
    super.key,
    required this.type,
    this.awards = 0,
    this.district,
    this.showAwards = true,
  });

  final ProviderType type;
  final int awards;
  final String? district;
  final bool showAwards;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final artist = type == ProviderType.artist;
    final String text;
    switch (type) {
      case ProviderType.individual:
        return const SizedBox.shrink();
      case ProviderType.artist:
        text = showAwards && awards > 0
            ? l.providerArtistAwards(awards)
            : l.providerArtist;
      case ProviderType.studio:
        text = district == null || district!.isEmpty
            ? l.providerStudio
            : l.providerStudioDistrict(district!);
    }
    final gold = dark ? AppColorsDark.gold : AppColors.gold;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final border = artist
        ? (dark ? AppColorsDark.goldLine : AppColors.goldLine)
        : Theme.of(context).colorScheme.outlineVariant;
    final color = artist ? gold : secondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: artist
            ? (dark ? AppColorsDark.goldSoft : AppColors.goldSoft)
            : null,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: border),
      ),
      child: Padding(
        // Mock `.ptag`: padding 2px 8px 2px 6px, gap 4px, 11px icon, 10px text.
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s1 * 1.5,
          AppSpace.s1 / 2,
          AppSpace.s2,
          AppSpace.s1 / 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              // Studio: briefcase, as the mock's `#i-brief`.
              artist ? AppIcons.award : AppIcons.work,
              size: AppText.xs2,
              color: color,
            ),
            const SizedBox(width: AppSpace.s1),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppText.xs,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A name followed by [ProviderMark], raised about 3dp above the baseline so
/// it reads as a superscript to the name rather than sitting mid-line. With no
/// [mark] it is the plain name.
class ProviderName extends StatelessWidget {
  const ProviderName(
    this.name, {
    super.key,
    this.mark,
    this.style,
    this.maxLines,
  });

  final String name;

  /// Cuts a long name with an ellipsis after this many lines.
  final int? maxLines;
  final ProviderMarkKind? mark;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final kind = mark;
    return Text.rich(
      TextSpan(
        text: name,
        children: [
          if (kind != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.aboveBaseline,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Transform.translate(
                  offset: const Offset(0, -3),
                  child: ProviderMark(kind),
                ),
              ),
            ),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}
