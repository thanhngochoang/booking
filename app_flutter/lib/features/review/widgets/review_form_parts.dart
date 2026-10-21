// Parts every S05.05 form shares: the shared-photo section and the bottom
// bar (individual booking and the studio booking's two blocks).
import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/review/review_controller.dart';
import 'package:photobooking/features/review/widgets/share_photo_grid.dart';

/// "Chia sẻ ảnh bạn thích · Tuỳ chọn" over the [SharePhotoGrid] of [state]'s
/// photos; [photographerName] is who the shared post tags.
class ReviewShareSection extends StatelessWidget {
  const ReviewShareSection({
    super.key,
    required this.state,
    required this.notifier,
    required this.photographerName,
  });

  final ReviewState state;
  final ReviewController notifier;
  final String photographerName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isSubmitting = state.phase == ReviewPhase.submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.reviewShare, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(width: AppSpace.s2),
            Text(
              l10n.reviewOptional,
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s3),
        SharePhotoGrid(
          photos: state.photos,
          photographerName: photographerName,
          enabled: !isSubmitting,
          onAdd: notifier.pickPhotos,
          onRemove: notifier.removePhoto,
          onRetry: notifier.retryPhoto,
        ),
      ],
    );
  }
}

/// The bottom bar of S05.05: the [missing] line (null hides it), then
/// [submitLabel] alone or, once photos are picked, "Chỉ đánh giá" beside
/// "Gửi & chia sẻ n ảnh". [onSubmit] gets whether to share.
class ReviewFooter extends StatelessWidget {
  const ReviewFooter({
    super.key,
    required this.state,
    required this.missing,
    required this.submitLabel,
    required this.canReviewOnly,
    required this.canShare,
    required this.onSubmit,
  });

  final ReviewState state;
  final String? missing;
  final String submitLabel;
  final bool canReviewOnly;
  final bool canShare;
  final void Function(bool share) onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isSubmitting = state.phase == ReviewPhase.submitting;
    final line = missing;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.brightness == Brightness.dark
                ? AppColorsDark.border
                : AppColors.border,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (line != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s2),
              child: Text(
                line,
                key: const Key('review_missing_hint'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.mutedForeground,
                ),
              ),
            ),
          state.photos.isEmpty
              ? AppButton.primary(
                  submitLabel,
                  key: const Key('submit_review_button'),
                  loading: isSubmitting,
                  onPressed: canReviewOnly ? () => onSubmit(false) : null,
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppButton.outline(
                        l10n.reviewOnly,
                        key: const Key('review_only_button'),
                        loading: isSubmitting && state.submittedShare == false,
                        onPressed: canReviewOnly ? () => onSubmit(false) : null,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      flex: 3,
                      child: AppButton.primary(
                        l10n.reviewSubmitShare(state.photos.length),
                        key: const Key('submit_share_button'),
                        loading: isSubmitting && state.submittedShare == true,
                        onPressed: canShare ? () => onSubmit(true) : null,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
