// lib/core/widgets/swipe_deck.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

/// A stack of cards to choose from like a "match" (mock S13.02 `.swipe`,
/// `.sacts`): up to three cards show, the ones behind smaller and fainter.
/// Drag the top card right past 30% of the width (or fling it) or tap ♥ to
/// like it, left or ✕ to skip it; "Hoàn tác" brings the last card back. The
/// buttons are always there, so nothing depends on the gesture. With reduced
/// motion the card changes at once instead of flying away.
///
/// Give the deck a new key when [items] is a new set (e.g. a new round): it
/// keeps its own position and history.
class SwipeDeck<T> extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.items,
    required this.cardBuilder,
    required this.onLike,
    required this.onSkip,
    this.onUndo,
    this.onEmpty,
    required this.likeStampLabel,
    required this.likeLabel,
    required this.skipLabel,
    required this.undoLabel,
    this.initialIndex = 0,
    this.belowCards,
  });

  final List<T> items;
  final Widget Function(BuildContext, T) cardBuilder;
  final ValueChanged<T> onLike;
  final ValueChanged<T> onSkip;
  final VoidCallback? onUndo;

  /// After the last card was liked or skipped.
  final VoidCallback? onEmpty;

  /// The stamp that fades in on a card dragged right ("CHỌN").
  final String likeStampLabel;

  /// Screen-reader labels of ♥, ✕ and the undo button.
  final String likeLabel, skipLabel, undoLabel;

  /// Where the deck starts (cards before it were already answered); there is
  /// no history to undo before it.
  final int initialIndex;

  /// Between the cards and the buttons (S13.02: who was chosen, "Xong").
  final Widget? belowCards;

  @override
  State<SwipeDeck<T>> createState() => _SwipeDeckState<T>();
}

/// The cards behind the top one (mock `.sc.b2`, `.sc.b3`).
const _behind = [
  (dy: 12.0, scale: 0.94, opacity: 0.55),
  (dy: 24.0, scale: 0.88, opacity: 0.3),
];

/// A drag past this share of the width decides.
const _threshold = 0.3;

/// A fling faster than this decides (logical px per second).
const _flingVelocity = 800.0;

/// Tilt per width dragged (radians).
const _tilt = 0.12;

const _flyDuration = Duration(milliseconds: 220);
const _snapDuration = Duration(milliseconds: 180);

/// Mock `.sacts .ra` (56) and `.ra.sm` (44, inside a 48dp tap box).
const _bigButton = 56.0;
const _smallButton = 44.0;
const _tapBox = 48.0;

/// Mock `.swipe .stamp` green (the stamp sits on a photo, so the dark
/// theme's light green in both themes).
const _stampColor = AppColorsDark.freeInk;

class _SwipeDeckState<T> extends State<SwipeDeck<T>>
    with SingleTickerProviderStateMixin {
  late int _index = widget.initialIndex.clamp(0, widget.items.length);
  final _history = <int>[];
  double _dx = 0;
  double _width = 1;

  late final AnimationController _anim = AnimationController(vsync: this)
    ..addListener(_onTick);
  Animation<double>? _motion;

  /// Set while a card flies away: +1 like, -1 skip.
  int? _flying;

  bool get _busy => _anim.isAnimating;
  bool get _hasCard => _index < widget.items.length;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onTick() {
    final m = _motion;
    if (m != null) setState(() => _dx = m.value);
  }

  bool _reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _onPanUpdate(DragUpdateDetails d) {
    if (_busy || !_hasCard) return;
    setState(() => _dx += d.delta.dx);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_busy || !_hasCard) return;
    final v = d.velocity.pixelsPerSecond.dx;
    if (_dx > _threshold * _width || v > _flingVelocity) {
      _fly(1);
    } else if (_dx < -_threshold * _width || v < -_flingVelocity) {
      _fly(-1);
    } else {
      _snapBack();
    }
  }

  Future<void> _animateTo(double target, Duration duration) async {
    _motion = Tween<double>(
      begin: _dx,
      end: target,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.duration = duration;
    await _anim.forward(from: 0).orCancel.catchError((Object _) {});
  }

  Future<void> _fly(int dir) async {
    if (_busy || !_hasCard) return;
    if (_reduced(context)) {
      _commit(dir);
      return;
    }
    _flying = dir;
    await _animateTo(dir * _width * 1.5, _flyDuration);
    if (!mounted) return;
    _flying = null;
    _commit(dir);
  }

  Future<void> _snapBack() async {
    if (_reduced(context)) {
      setState(() => _dx = 0);
      return;
    }
    await _animateTo(0, _snapDuration);
  }

  void _commit(int dir) {
    final item = widget.items[_index];
    setState(() {
      _history.add(_index);
      _index++;
      _dx = 0;
      _motion = null;
    });
    if (dir > 0) {
      widget.onLike(item);
    } else {
      widget.onSkip(item);
    }
    if (_index == widget.items.length) widget.onEmpty?.call();
  }

  void _undo() {
    if (_busy || _history.isEmpty) return;
    setState(() {
      _index = _history.removeLast();
      _dx = 0;
    });
    widget.onUndo?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _width = constraints.maxWidth > 0 ? constraints.maxWidth : 1;
              return _cards(context);
            },
          ),
        ),
        if (widget.belowCards case final below?) ...[
          const SizedBox(height: AppSpace.s3),
          below,
        ],
        const SizedBox(height: AppSpace.s3),
        _buttons(context),
      ],
    );
  }

  Widget _cards(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = [
      for (var i = _index; i < widget.items.length && i < _index + 3; i++) i,
    ];
    Widget frame(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: child,
      ),
    );
    final stampOpacity = (_dx / (_threshold * _width)).clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Farthest first, so the top card paints last.
        for (final i in shown.reversed)
          if (i == _index)
            GestureDetector(
              key: ValueKey('swipe-top-$i'),
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Transform.translate(
                offset: Offset(_dx, 0),
                child: Transform.rotate(
                  angle: _dx / _width * _tilt,
                  child: frame(
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.cardBuilder(context, widget.items[i]),
                        if (_dx > 0 && _flying != -1)
                          Positioned(
                            top: AppSpace.s6,
                            left: AppSpace.s3,
                            child: Opacity(
                              opacity: stampOpacity,
                              child: ExcludeSemantics(
                                child: _Stamp(widget.likeStampLabel),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            _BehindCard(
              key: ValueKey('swipe-behind-$i'),
              depth: i - _index - 1,
              child: frame(widget.cardBuilder(context, widget.items[i])),
            ),
      ],
    );
  }

  Widget _buttons(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final card = _hasCard && !_busy;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final line = theme.colorScheme.outline;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundButton(
          key: const Key('swipe-undo'),
          label: widget.undoLabel,
          icon: AppIcons.undo,
          visual: _smallButton,
          box: _tapBox,
          fill: glass,
          border: line,
          color: dark
              ? AppColorsDark.foregroundSecondary
              : AppColors.foregroundSecondary,
          onTap: _history.isEmpty || _busy ? null : _undo,
        ),
        const SizedBox(width: AppSpace.s4),
        _RoundButton(
          key: const Key('swipe-skip'),
          label: widget.skipLabel,
          icon: AppIcons.close,
          visual: _bigButton,
          box: _bigButton,
          fill: glass,
          border: line,
          color: theme.colorScheme.error,
          onTap: card ? () => _fly(-1) : null,
        ),
        const SizedBox(width: AppSpace.s4),
        _RoundButton(
          key: const Key('swipe-like'),
          label: widget.likeLabel,
          icon: AppIcons.favorite,
          visual: _bigButton,
          box: _bigButton,
          gradient: true,
          color: Colors.white,
          onTap: card ? () => _fly(1) : null,
        ),
      ],
    );
  }
}

/// A card behind the top one: lower, smaller, fainter; not interactive.
class _BehindCard extends StatelessWidget {
  const _BehindCard({super.key, required this.depth, required this.child});

  final int depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final b = _behind[depth.clamp(0, _behind.length - 1)];
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: b.opacity,
          child: Transform.translate(
            offset: Offset(0, b.dy),
            child: Transform.scale(scale: b.scale, child: child),
          ),
        ),
      ),
    );
  }
}

/// Mock `.swipe .stamp`: tilted outlined label.
class _Stamp extends StatelessWidget {
  const _Stamp(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.21,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.overlay,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: _stampColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _stampColor,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ),
    ),
  );
}

/// One round action (mock `.sacts .ra`): [visual] wide inside a [box] tap area.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.label,
    required this.icon,
    required this.visual,
    required this.box,
    required this.color,
    required this.onTap,
    this.fill,
    this.border,
    this.gradient = false,
  });

  final String label;
  final IconData icon;
  final double visual;
  final double box;
  final Color color;
  final VoidCallback? onTap;
  final Color? fill;
  final Color? border;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final radius = BorderRadius.circular(visual / 2);
    final iconSize = visual >= _bigButton ? AppIconSize.md : 19.0;
    final face = SizedBox.square(
      dimension: visual,
      child: Center(
        child: AppIcon(icon, size: iconSize, color: color),
      ),
    );
    final Widget surface = gradient
        ? CtaSurface(borderRadius: radius, child: face)
        : DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: border == null ? null : Border.all(color: border!),
            ),
            child: face,
          );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox.square(
        dimension: box,
        child: Center(
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: surface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
