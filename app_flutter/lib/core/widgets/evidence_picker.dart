// lib/core/widgets/evidence_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/network_photo.dart';

/// A post offered as evidence: its id and the cover image.
class PostThumb {
  const PostThumb({required this.id, required this.imageUrl});
  final String id;
  final String imageUrl;
}

/// 3-column grid to pick up to [max] of the photographer's own posts (S08.04).
/// Lazy: only visible tiles are built, and each photo is decoded at tile
/// width by [NetworkPhoto]. No blur inside tiles.
class EvidencePicker extends StatelessWidget {
  const EvidencePicker({
    super.key,
    required this.posts,
    required this.selected,
    required this.onChanged,
    this.max = 3,
    this.onMaxReached,
    this.onEndReached,
  });

  final List<PostThumb> posts;

  /// Insertion-ordered (the order of picking).
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final int max;

  /// A pick beyond [max] was refused.
  final VoidCallback? onMaxReached;

  /// The grid was scrolled near its end; load the next page.
  final VoidCallback? onEndReached;

  void _toggle(String id) {
    if (selected.contains(id)) {
      onChanged({
        for (final x in selected)
          if (x != id) x,
      });
      return;
    }
    if (selected.length >= max) {
      SystemSound.play(SystemSoundType.alert);
      onMaxReached?.call();
      return;
    }
    onChanged({...selected, id});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.sm);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (onEndReached != null && n.metrics.extentAfter < 300) {
          onEndReached!();
        }
        return false;
      },
      child: GridView.builder(
        key: const Key('evidence-grid'),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpace.s1,
          crossAxisSpacing: AppSpace.s1,
        ),
        itemCount: posts.length,
        itemBuilder: (context, i) {
          final post = posts[i];
          final on = selected.contains(post.id);
          return Semantics(
            key: Key('evidence-${post.id}'),
            button: true,
            selected: on,
            label: l.skillEvidencePhoto(i + 1),
            onTap: () => _toggle(post.id),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: radius,
              onTap: () => _toggle(post.id),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkPhoto(url: post.imageUrl),
                    if (on)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(color: scheme.primary, width: 2),
                        ),
                      ),
                    if (on)
                      Positioned(
                        top: AppSpace.s1,
                        right: AppSpace.s1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(1),
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
