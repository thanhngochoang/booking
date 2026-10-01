// lib/core/widgets/free_tag.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

({Color fill, Color text}) _freeColors(Brightness b) => b == Brightness.dark
    ? (
        // Green at 20% over the dark canvas, with a lightened green for text.
        fill: AppColors.success.withValues(alpha: 0.2),
        text: Color.alphaBlend(
          Colors.white.withValues(alpha: 0.45),
          AppColors.success,
        ),
      )
    : (
        fill: AppColors.successSubtle,
        // Success green darkened until it reads at 4.5:1 on the pale fill.
        text: Color.alphaBlend(
          Colors.black.withValues(alpha: 0.45),
          AppColors.success,
        ),
      );

/// Where a free event would show "0₫" it shows this tag instead.
class FreeTag extends StatelessWidget {
  const FreeTag({super.key});

  @override
  Widget build(BuildContext context) {
    final c = _freeColors(Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Text(
          context.l10n.freeTag,
          style: TextStyle(
            fontSize: AppText.sm,
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
        ),
      ),
    );
  }
}

/// Full-width strip under an event cover (S16) for events with `price == 0`.
class FreeBanner extends StatelessWidget {
  const FreeBanner({super.key, this.body});

  /// Second line; defaults to the standard "no payment needed" hint.
  final String? body;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = _freeColors(Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.fill),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s4,
          vertical: AppSpace.s3,
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: c.text),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.freeTag,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  Text(
                    body ?? l.freeBannerBody,
                    style: TextStyle(fontSize: AppText.sm, color: c.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
