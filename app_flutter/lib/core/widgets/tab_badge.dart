import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';

/// Count bubble on a bottom-bar icon; hidden at zero, "9+" above nine.
class TabBadge extends StatelessWidget {
  const TabBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      value: context.l10n.tabBadgeCount(count),
      child: Badge(
        label: Text(count > 9 ? '9+' : '$count'),
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        child: child,
      ),
    );
  }
}
