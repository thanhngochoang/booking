// lib/core/widgets/contact_dial.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:photobooking/core/contact_channel.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/screen_codes.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/screen_code.dart';
import 'package:photobooking/l10n/app_localizations.dart';

enum ContactDialStyle {
  /// Square 48dp button with a phone icon.
  icon,

  /// Low 38dp pill reading "Liên hệ", for a row of buttons (hit area is 44dp).
  labeled,
}

const _openDuration = Duration(milliseconds: 240);
const _closeDuration = Duration(milliseconds: 140);
const _stagger = Duration(milliseconds: 40);

// Sizes fixed by the spec (3b.5); the tray radius has no token (like GlassCard).
const double _trayRadius = 28;
const double _circle = 44;
const double _itemWidth = 62;
const double _gap = 8;
const double _labelSize = 10.5;
const double _lift = 10;
const double _minTarget = 44;

extension ContactChannelUi on ContactChannel {
  String label(AppLocalizations l) => switch (this) {
    ContactChannel.call => l.contactCall,
    ContactChannel.zalo => l.contactZalo,
    ContactChannel.whatsapp => l.contactWhatsApp,
    ContactChannel.inApp => l.contactInquiry,
  };

  /// Visible tray caption: "Gọi" for the call entry (mock); screen readers
  /// still get [label].
  String shortLabel(AppLocalizations l) =>
      this == ContactChannel.call ? l.contactCallShort : label(l);
}

/// Compact contact button. Resting, it is one small button; the outside
/// channels appear in a tray only when it is tapped (spec 3b.5).
///
/// It never opens a URL: [onSelected] is the screen's cue to call
/// `ContactLauncher.open` (or to open the inquiry chat for `inApp`).
class ContactDial extends StatefulWidget {
  const ContactDial({
    super.key,
    required this.access,
    required this.channels,
    required this.onSelected,
    this.style = ContactDialStyle.icon,
    this.busy = false,
  });

  final ContactAccess access;

  /// Channels the photographer accepts. When unlocked only the external ones
  /// count, shown in the fixed order Gọi, Zalo, WhatsApp.
  final List<ContactChannel> channels;
  final ValueChanged<ContactChannel> onSelected;
  final ContactDialStyle style;

  /// A link is being fetched: spinner on the button, taps ignored.
  final bool busy;

  @override
  State<ContactDial> createState() => _ContactDialState();
}

class _ContactDialState extends State<ContactDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: _openDuration,
    reverseDuration: _closeDuration,
  );
  // Curves stay with the direction the motion started in until it completes,
  // so reversing mid-way continues smoothly instead of snapping.
  late final _trayAnim = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeIn,
  );
  // Index = position counted from the right: right-most enters first.
  late final _itemAnims = List.generate(3, (fromRight) {
    final begin = _stagger.inMilliseconds * fromRight;
    final total = _openDuration.inMilliseconds;
    return CurvedAnimation(
      parent: _anim,
      curve: Interval(
        begin / total,
        ((begin + 160) / total).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      ),
      reverseCurve: Curves.easeIn,
    );
  });
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _buttonFocus = FocusNode(debugLabel: 'ContactDial button');
  final _itemFocus = List.generate(
    3,
    (i) => FocusNode(debugLabel: 'ContactDial item $i'),
  );
  bool _open = false;
  bool _below = false;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _anim.addStatusListener((status) {
      if (status == AnimationStatus.dismissed &&
          !_open &&
          _portal.isShowing &&
          !_resetting) {
        _portal.hide();
      }
    });
  }

  @override
  void didUpdateWidget(ContactDial old) {
    super.didUpdateWidget(old);
    final changed =
        old.access != widget.access ||
        !listEquals(old.channels, widget.channels);
    if ((_open || _anim.value > 0) && changed) {
      // Synchronously: no tappable remnant of the old state may survive.
      _open = false;
      _resetting = true;
      _anim.value = 0;
      _resetting = false;
      if (_portal.isShowing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_open && _portal.isShowing) _portal.hide();
        });
      }
    }
  }

  @override
  void dispose() {
    _trayAnim.dispose();
    for (final a in _itemAnims) {
      a.dispose();
    }
    _anim.dispose();
    _buttonFocus.dispose();
    for (final n in _itemFocus) {
      n.dispose();
    }
    super.dispose();
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  List<ContactChannel> get _external => [
    for (final c in ContactChannel.values)
      if (c.isExternal && widget.channels.contains(c)) c,
  ];

  /// Height the tray needs above or below the button, with a text-scale margin.
  double _trayExtent() =>
      _circle +
      4 +
      MediaQuery.textScalerOf(context).scale(_labelSize * 1.4) +
      AppSpace.s3 * 2 +
      _gap;

  void _onButton(List<ContactChannel> external) {
    if (widget.busy) return;
    if (widget.access == ContactAccess.locked) {
      widget.onSelected(ContactChannel.inApp);
    } else if (external.length == 1) {
      widget.onSelected(external.single);
    } else if (_open) {
      _close();
    } else {
      _openTray();
    }
  }

  void _openTray() {
    final box = context.findRenderObject() as RenderBox?;
    final top = box == null
        ? double.infinity
        : box.localToGlobal(Offset.zero).dy;
    _below = top < _trayExtent() + MediaQuery.paddingOf(context).top;
    setState(() => _open = true);
    _portal.show();
    // Not awaited; a missing haptic engine must never break the tap.
    unawaited(HapticFeedback.selectionClick().catchError((_) {}));
    if (_reduced) {
      _anim.value = 1;
    } else {
      _anim.forward();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _itemFocus.first.requestFocus();
    });
  }

  void _close({bool refocus = true}) {
    if (!_open) return;
    setState(() => _open = false);
    if (_reduced) {
      _anim.value = 0;
      if (_portal.isShowing) _portal.hide();
    } else {
      _anim.reverse();
    }
    if (refocus) _buttonFocus.requestFocus();
  }

  void _select(ContactChannel channel) {
    if (!_open) return;
    _close();
    widget.onSelected(channel);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locked = widget.access == ContactAccess.locked;
    final external = _external;
    if (!locked && external.isEmpty) return const SizedBox.shrink();

    final single = !locked && external.length == 1;
    final expandable = !locked && !single;
    final label = locked
        ? l.contactInquiry
        : single
        ? external.single.label(l)
        : l.contactLabel;
    final color = _open ? scheme.primary : scheme.onSurface;
    final borderColor = _open ? scheme.primary : scheme.outlineVariant;

    Widget glyph(double size) => widget.busy
        ? (_reduced
              ? Icon(
                  Icons.phone_outlined,
                  size: size,
                  color: color.withValues(alpha: 0.38),
                )
              : SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ))
        : locked
        ? Icon(Icons.chat_bubble_outline_rounded, size: size, color: color)
        : single
        ? ChannelGlyph(external.single, size: size, color: color)
        : Icon(Icons.phone_outlined, size: size, color: color);

    final visual = widget.style == ContactDialStyle.icon
        ? Container(
            key: const Key('contact-dial-visual'),
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.secondary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: borderColor),
            ),
            child: glyph(22),
          )
        : Container(
            key: const Key('contact-dial-visual'),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
            decoration: BoxDecoration(
              color: scheme.secondary,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                glyph(18),
                const SizedBox(width: AppSpace.s2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          );

    final button = CompositedTransformTarget(
      link: _link,
      child: Semantics(
        button: true,
        label: widget.busy ? '$label, ${l.contactOpening}' : label,
        hint: locked ? l.contactLockedHint : null,
        expanded: expandable ? _open : null,
        child: InkWell(
          key: const Key('contact-dial-button'),
          focusNode: _buttonFocus,
          borderRadius: BorderRadius.circular(
            widget.style == ContactDialStyle.icon
                ? AppRadius.xl
                : AppRadius.control,
          ),
          onTap: widget.busy ? null : () => _onButton(external),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTarget,
              minHeight: _minTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: ExcludeSemantics(child: visual),
            ),
          ),
        ),
      ),
    );

    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => _close(),
        },
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) => _buildOverlay(context, external),
          child: button,
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, List<ContactChannel> external) {
    if (widget.access == ContactAccess.locked || external.length < 2) {
      return const SizedBox.shrink();
    }
    // The open tray is S32: its tag covers the host screen's while shown.
    return ScreenCode(
      ScreenCodes.contactAfterBooking,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => _close(),
        },
        child: Stack(
          children: [
            // Catches taps outside the tray (and on the button itself).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // While the tray is closing the scrim covers the button: a tap
                // there brings the tray back.
                onTap: () =>
                    !_open && _anim.isAnimating ? _openTray() : _close(),
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: _below ? Alignment.bottomRight : Alignment.topRight,
              followerAnchor: _below
                  ? Alignment.topRight
                  : Alignment.bottomRight,
              offset: Offset(0, _below ? _gap : -_gap),
              child: Align(
                alignment: _below ? Alignment.topRight : Alignment.bottomRight,
                child: _Tray(
                  channels: external,
                  animation: _trayAnim,
                  itemAnimations: _itemAnims,
                  reduced: _reduced,
                  below: _below,
                  focusNodes: _itemFocus,
                  onSelect: _select,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({
    required this.channels,
    required this.animation,
    required this.itemAnimations,
    required this.reduced,
    required this.below,
    required this.focusNodes,
    required this.onSelect,
  });

  final List<ContactChannel> channels;
  final Animation<double> animation;
  final List<Animation<double>> itemAnimations;
  final bool reduced;
  final bool below;
  final List<FocusNode> focusNodes;
  final ValueChanged<ContactChannel> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          // In: ease with a slight overshoot. Out: plain ease-in, no stagger.
          final eased = reduced ? 1.0 : animation.value;
          return Opacity(
            key: const Key('contact-tray-fade'),
            opacity: eased.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (below ? -_lift : _lift) * (1 - eased)),
              child: Transform.scale(
                scale: 0.92 + 0.08 * eased,
                alignment: below ? Alignment.topRight : Alignment.bottomRight,
                child: Container(
                  key: const Key('contact-tray'),
                  padding: const EdgeInsets.all(AppSpace.s3),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(_trayRadius),
                    border: Border.all(color: scheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Color(dark ? 0x66000000 : 0x26000000),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FocusScope(
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < channels.length; i++) ...[
                            if (i > 0) const SizedBox(width: _gap),
                            FocusTraversalOrder(
                              order: NumericFocusOrder(i.toDouble()),
                              child: _itemFrame(context, i),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Entries enter right to left, 40ms apart; on the way out all fade together.
  Widget _itemFrame(BuildContext context, int index) {
    final fromRight = channels.length - 1 - index;
    final t = reduced ? 1.0 : itemAnimations[fromRight].value;
    return Opacity(
      key: Key('contact-item-fade-${channels[index].code}'),
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.8 + 0.2 * t,
        child: _TrayItem(
          channel: channels[index],
          focusNode: focusNodes[index],
          onTap: () => onSelect(channels[index]),
        ),
      ),
    );
  }
}

class _TrayItem extends StatefulWidget {
  const _TrayItem({
    required this.channel,
    required this.focusNode,
    required this.onTap,
  });

  final ContactChannel channel;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<_TrayItem> createState() => _TrayItemState();
}

class _TrayItemState extends State<_TrayItem> {
  bool _focused = false;
  bool _keyboardMode =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode mode) {
    final keyboard = mode == FocusHighlightMode.traditional;
    if (keyboard != _keyboardMode && mounted) {
      setState(() => _keyboardMode = keyboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Focus is requested on every open; the ring is only for keyboard users.
    final showRing = _focused && _keyboardMode;
    final ring = theme.brightness == Brightness.dark
        ? AppColorsDark.focusRing
        : AppColors.focusRing;
    return Semantics(
      button: true,
      label: widget.channel.label(context.l10n),
      onTap: widget.onTap,
      excludeSemantics: true,
      child: InkWell(
        key: Key('contact-${widget.channel.code}'),
        focusNode: widget.focusNode,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SizedBox(
          width: _itemWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _circle,
                  height: _circle,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.secondary,
                    border: Border.all(
                      color: showRing ? ring : scheme.outlineVariant,
                      width: showRing ? 2 : 1,
                    ),
                  ),
                  child: ChannelGlyph(
                    widget.channel,
                    size: 22,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.channel.shortLabel(context.l10n),
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: _labelSize,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Phone glyph for Gọi, the brand files for Zalo and WhatsApp, drawn in one
/// colour. Decorative: every use sits next to a text label. Shared by the dial
/// and the photographer setup screen.
class ChannelGlyph extends StatelessWidget {
  const ChannelGlyph(
    this.channel, {
    super.key,
    required this.size,
    required this.color,
  });

  final ContactChannel channel;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget svg(String asset) => SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
    return ExcludeSemantics(
      child: switch (channel) {
        ContactChannel.call => Icon(
          Icons.call_outlined,
          size: size,
          color: color,
        ),
        ContactChannel.zalo => svg('assets/social/zalo.svg'),
        ContactChannel.whatsapp => svg('assets/social/whatsapp.svg'),
        ContactChannel.inApp => Icon(
          Icons.chat_bubble_outline_rounded,
          size: size,
          color: color,
        ),
      },
    );
  }
}
