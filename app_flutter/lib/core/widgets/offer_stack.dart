// lib/core/widgets/offer_stack.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Up to three offer cards: the first full, the next two as edges peeking
/// above it (mock S14.02 `.ostk`). Only the first card is built; the others
/// are counted, never shown, so the screen says how many wait elsewhere.
class OfferStack extends StatelessWidget {
  const OfferStack({super.key, required this.offers});

  final List<Widget> offers;

  /// Mock `.ostk .under` / `.under.u2`: inset and lift of each edge.
  static const _edges = [
    (inset: AppSpace.s3, lift: 8.0, opacity: 1.0),
    (inset: AppSpace.s6, lift: 15.0, opacity: 0.6),
  ];

  /// Mock: each edge is 20 px tall, rounded on top only.
  static const _edgeHeight = AppSpace.s5;

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) return const SizedBox.shrink();
    final edges = (offers.length - 1).clamp(0, _edges.length);
    final top = edges == 0 ? 0.0 : _edges[edges - 1].lift;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Farthest first, so the nearer edge paints over it.
          for (var i = edges; i >= 1; i--)
            Positioned(
              left: _edges[i - 1].inset,
              right: _edges[i - 1].inset,
              top: -_edges[i - 1].lift,
              height: _edgeHeight,
              child: _Edge(
                key: Key('offer-edge-$i'),
                opacity: _edges[i - 1].opacity,
              ),
            ),
          offers.first,
        ],
      ),
    );
  }
}

class _Edge extends StatelessWidget {
  const _Edge({super.key, required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ExcludeSemantics(
      child: Opacity(
        opacity: opacity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark
                ? AppColorsDark.secondaryPressed
                : AppColors.secondaryPressed,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.card),
            ),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}
