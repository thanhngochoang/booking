// lib/features/skills/evidence_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/skills/own_posts_controller.dart';

/// S40: pick 1–3 of your own posts as evidence for one genre. Returns the
/// ids in pick order after "Xong", or null when dismissed (nothing changes).
Future<List<String>?> showEvidenceSheet(
  BuildContext context, {
  required String specialtyName,
  required List<String> initial,
  required bool requiresOne,
  required VoidCallback onCreatePost,
}) => showAppSheet<List<String>>(
  context,
  builder: (_) => EvidenceSheet(
    specialtyName: specialtyName,
    initial: initial,
    requiresOne: requiresOne,
    onCreatePost: onCreatePost,
  ),
);

class EvidenceSheet extends ConsumerStatefulWidget {
  const EvidenceSheet({
    super.key,
    required this.specialtyName,
    required this.initial,
    required this.requiresOne,
    required this.onCreatePost,
  });

  final String specialtyName;
  final List<String> initial;

  /// The genre is "Chuyên sâu": "Xong" needs at least one photo.
  final bool requiresOne;

  /// Called after the sheet closes from the empty state ("Đăng bài").
  final VoidCallback onCreatePost;

  @override
  ConsumerState<EvidenceSheet> createState() => _EvidenceSheetState();
}

class _EvidenceSheetState extends ConsumerState<EvidenceSheet> {
  late Set<String> _selected = {...widget.initial};
  bool _maxed = false;

  void _createPost() {
    Navigator.of(context).pop();
    widget.onCreatePost();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final posts = ref.watch(ownPostsProvider);
    final hasPosts = posts.value?.posts.isNotEmpty ?? false;
    final blocked = widget.requiresOne && _selected.isEmpty;
    return ScreenCode(
      ScreenCodes.skillEvidence,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s5,
          0,
          AppSpace.s5,
          AppSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.skillEvidenceTitle(widget.specialtyName),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Text(
                  l.skillsCount(_selected.length, 3),
                  key: const Key('evidence-count'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            Text(l.skillEvidenceBody, style: theme.textTheme.bodySmall),
            if (_maxed) ...[
              const SizedBox(height: AppSpace.s2),
              Semantics(
                liveRegion: true,
                child: Text(
                  l.skillEvidenceMax,
                  key: const Key('evidence-max'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.s3),
            Flexible(
              child: posts.when(
                loading: () => const _GridSkeleton(),
                error: (_, _) => ErrorState(
                  message: l.skillEvidenceLoadError,
                  onRetry: () => ref.invalidate(ownPostsProvider),
                ),
                data: (s) => s.posts.isEmpty && !s.hasMore
                    ? EmptyState(
                        title: l.skillEvidenceEmpty,
                        body: l.skillEvidenceEmptyBody,
                        actionLabel: l.skillEvidenceEmptyAction,
                        onAction: _createPost,
                      )
                    : EvidencePicker(
                        posts: s.posts,
                        selected: _selected,
                        onChanged: (v) => setState(() {
                          _selected = v;
                          _maxed = false;
                        }),
                        onMaxReached: () => setState(() => _maxed = true),
                        onEndReached: s.hasMore && !s.loadMoreFailed
                            ? () =>
                                  ref.read(ownPostsProvider.notifier).loadMore()
                            : null,
                      ),
              ),
            ),
            if (posts.value?.loadMoreFailed ?? false)
              SizedBox(
                height: controlHeight,
                child: TextButton.icon(
                  key: const Key('evidence-retry'),
                  onPressed: () =>
                      ref.read(ownPostsProvider.notifier).retryLoadMore(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l.skillEvidenceLoadMoreRetry),
                ),
              ),
            if (hasPosts) ...[
              const SizedBox(height: AppSpace.s3),
              if (blocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s2),
                  child: Text(
                    l.skillEvidenceNeedOne,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              SizedBox(
                height: controlHeight,
                child: AppButton.primary(
                  l.skillEvidenceDone,
                  key: const Key('evidence-done'),
                  onPressed: blocked
                      ? null
                      : () => Navigator.of(context).pop(_selected.toList()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 3,
    mainAxisSpacing: AppSpace.s2,
    crossAxisSpacing: AppSpace.s2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: [for (var i = 0; i < 6; i++) const AppSkeleton.box(height: 100)],
  );
}
