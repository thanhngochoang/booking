// lib/core/widgets/screen_code.dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Whether [ScreenCode] tags are shown. Placed above the router by `MyApp`,
/// so `core/` does not depend on the settings feature.
class ScreenCodeScope extends InheritedWidget {
  const ScreenCodeScope({
    super.key,
    required this.visible,
    required super.child,
  });

  final bool visible;

  static bool visibleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScreenCodeScope>()?.visible ??
      false;

  @override
  bool updateShouldNotify(ScreenCodeScope old) => old.visible != visible;
}

/// Debug aid: draws the screen's code (`S09`, or `S09.timeline` with [label])
/// at the top-left so a change request can name the screen. In release builds,
/// or while the switch is off, it returns [child] untouched.
class ScreenCode extends StatelessWidget {
  const ScreenCode(this.code, {super.key, this.label, required this.child});

  final String code;

  /// Marks a part of a screen, shown as `code.label`.
  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || !ScreenCodeScope.visibleOf(context)) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpace.s2,
                top: AppSpace.s1,
              ),
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: _Tag(label == null ? code : '$code.$label'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  // Fixed by the mock (docs/design/ui-mock.html, .scode); not a theme colour.
  static const _background = Color(0xFFFF2D95);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
