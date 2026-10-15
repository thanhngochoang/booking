import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Sticky action row at the bottom of a form screen (mock `.foot`): surface
/// background and a top hairline. Lives outside the scroll view.
class AppFooterBar extends StatelessWidget {
  const AppFooterBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s2h,
            AppSpace.s4,
            AppSpace.s3,
          ),
          child: child,
        ),
      ),
    );
  }
}
