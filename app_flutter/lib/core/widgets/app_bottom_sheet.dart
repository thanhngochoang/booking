import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Opens [builder] in the app's glass bottom sheet and returns what it pops.
///
/// The sheet is at most 88% of the screen tall; content that can be long
/// scrolls itself. Dismissed by dragging down, tapping outside or Back.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  dynamic isDismissible = true,
  dynamic enableDrag = true,
  bool Function()? canDismiss,
}) {
  final dismissible =
      (isDismissible is bool Function()
          ? isDismissible()
          : (isDismissible is bool ? isDismissible : true)) &&
      (canDismiss == null || canDismiss());
  final drag =
      (enableDrag is bool Function()
          ? enableDrag()
          : (enableDrag is bool ? enableDrag : true)) &&
      (canDismiss == null || canDismiss());

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: AppColors.overlay,
    isDismissible: dismissible,
    enableDrag: drag,
    builder: (sheetContext) => _SheetFrame(child: builder(sheetContext)),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});
  final Widget child;

  static const _radius = BorderRadius.vertical(top: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
      child: ClipRRect(
        key: const Key('app-sheet'),
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.92),
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.s3,
                      ),
                      child: ExcludeSemantics(
                        key: const Key('app-sheet-handle'),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.outline,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: const SizedBox(width: 36, height: 4),
                        ),
                      ),
                    ),
                    Flexible(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
