// lib/core/widgets/free_tag.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

({Color fill, Color text}) _freeColors(Brightness b) => b == Brightness.dark
    ? (fill: AppColorsDark.freeBg, text: AppColorsDark.freeInk)
    : (fill: AppColors.freeBg, text: AppColors.freeInk);

/// Where a free event would show "0₫" it shows this tag instead.
class FreeTag extends StatelessWidget {
  const FreeTag({super.key});

  @override
  Widget build(BuildContext context) {
    final c = _freeColors(Theme.of(context).brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(AppRadius.full),
        // Mock .tag has a 1px (transparent here) border.
        border: Border.all(color: Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: 3,
        ),
        // A tag is one line; it never wraps into a two-line stadium.
        child: Text(
          context.l10n.freeTag,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppText.xs,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4, // mock .tag: .04em of 10px
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
