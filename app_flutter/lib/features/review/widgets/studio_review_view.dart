// S05.05 for a studio booking (mock `#S05.05-studio`): the form with the
// member and studio blocks, and both sent blocks read-only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_providers.dart';
import 'package:photobooking/features/review/review_controller.dart';
import 'package:photobooking/features/review/review_labels.dart';
import 'package:photobooking/features/review/widgets/review_block.dart';
import 'package:photobooking/features/review/widgets/review_form_parts.dart';

/// Who the two blocks of a studio booking's review are about.
typedef StudioReviewSubject = ({
  String assigneeName,
  String? assigneeAvatar,
  String studioName,
  String? studioAvatar,
  bool studioSealed,
});

Widget _assigneeHeader(BuildContext context, StudioReviewSubject subject) =>
    ReviewBlockHeader(
      title: context.l10n.reviewBlockAssignee(subject.assigneeName),
      note: context.l10n.reviewBlockAssigneeNote,
      avatarUrl: subject.assigneeAvatar,
    );

Widget _studioHeader(BuildContext context, StudioReviewSubject subject) =>
    ReviewBlockHeader(
      title: subject.studioName,
      note: context.l10n.reviewBlockStudioNote,
      avatarUrl: subject.studioAvatar,
      mark: subject.studioSealed ? ProviderMarkKind.studio : null,
    );

/// S05.05-studio: the member block, the studio block, the shared photos (one
/// section for both, spec §6) and "Gửi 2 đánh giá", enabled once both
/// blocks are complete; the line above it names the missing block.
class StudioReviewFormView extends StatelessWidget {
  const StudioReviewFormView({
    super.key,
    required this.summary,
    required this.subject,
    required this.state,
    required this.notifier,
    required this.textController,
    required this.studioTextController,
    required this.onSubmit,
  });

  final BookingSummary summary;
  final StudioReviewSubject subject;
  final ReviewState state;
  final ReviewController notifier;
  final TextEditingController textController;
  final TextEditingController studioTextController;
  final void Function(bool share) onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSubmitting = state.phase == ReviewPhase.submitting;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BookingCard(data: summary, size: BookingCardSize.compact),
                  const SizedBox(height: AppSpace.s4),
                  ReviewFormBlock(
                    key: const Key('review-block-assignee'),
                    label: l10n.reviewGroupAssigneeA11y(subject.assigneeName),
                    header: _assigneeHeader(context, subject),
                    subject: l10n.reviewWhoAssignee,
                    verdict: state.verdict,
                    hits: state.hits,
                    onVerdict: (kind, hits) =>
                        notifier.setVerdict(kind?.verdict, hits),
                    chips: [
                      for (final r in ReviewReason.values)
                        (
                          label: reviewReasonLabel(l10n, r),
                          selected: state.reasons.contains(r),
                          onTap: () => notifier.toggleReason(r),
                        ),
                    ],
                    controller: textController,
                    textLabel: l10n.reviewNoteForAssignee,
                    textKey: const Key('review_text_field'),
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: AppSpace.s3),
                  ReviewFormBlock(
                    key: const Key('review-block-studio'),
                    label: l10n.reviewGroupStudioA11y(subject.studioName),
                    header: _studioHeader(context, subject),
                    subject: l10n.reviewWhoStudio,
                    verdict: state.studioVerdict,
                    hits: state.studioHits,
                    onVerdict: (kind, hits) =>
                        notifier.setStudioVerdict(kind?.verdict, hits),
                    chips: [
                      for (final r in StudioReviewReason.values)
                        (
                          label: studioReviewReasonLabel(l10n, r),
                          selected: state.studioReasons.contains(r),
                          onTap: () => notifier.toggleStudioReason(r),
                        ),
                    ],
                    controller: studioTextController,
                    textLabel: l10n.reviewNoteForStudio,
                    textKey: const Key('review_studio_text_field'),
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: AppSpace.s6),
                  ReviewShareSection(
                    state: state,
                    notifier: notifier,
                    photographerName: subject.assigneeName,
                  ),
                ],
              ),
            ),
          ),
          ReviewFooter(
            state: state,
            missing: switch (state.missingSubject) {
              ReviewSubject.assignee => l10n.reviewMissingAssignee,
              ReviewSubject.studio => l10n.reviewMissingStudio,
              null => null,
            },
            submitLabel: l10n.reviewSubmitTwo,
            canReviewOnly: state.canSubmitTwo,
            canShare: state.canSubmitTwoWithShare,
            onSubmit: onSubmit,
          ),
        ],
      ),
    );
  }
}

/// Both sent blocks of a studio booking, read-only: the member review
/// ([review], `reviews/{bookingId}`) and the studio one
/// (`reviews/{bookingId}_studio`, read here).
class StudioReviewReadOnlyView extends ConsumerWidget {
  const StudioReviewReadOnlyView({
    super.key,
    required this.bookingId,
    required this.summary,
    required this.subject,
    required this.review,
  });

  final String bookingId;
  final BookingSummary summary;
  final StudioReviewSubject subject;
  final Review? review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final studioReviewId = studioReviewDocId(bookingId);
    final review = this.review;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingCard(data: summary, size: BookingCardSize.compact),
            const SizedBox(height: AppSpace.s4),
            if (review == null)
              Text(
                l10n.reviewAlreadyDone,
                key: const Key('review_already_done'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              )
            else ...[
              ReviewReadOnlyBlock(
                key: const Key('review-readonly-assignee'),
                label: l10n.reviewGroupAssigneeA11y(subject.assigneeName),
                header: _assigneeHeader(context, subject),
                verdict: review.verdict,
                hits: review.hits,
                reasons: [
                  for (final r in review.reasons) reviewReasonLabel(l10n, r),
                ],
                text: review.text,
              ),
              const SizedBox(height: AppSpace.s3),
              AsyncView<Review?>(
                value: ref.watch(bookingReviewProvider(studioReviewId)),
                skeleton: (_) => AppSkeleton.card(height: 140),
                onRetry: () =>
                    ref.invalidate(bookingReviewProvider(studioReviewId)),
                data: (context, studioReview) => studioReview == null
                    ? const SizedBox.shrink()
                    : ReviewReadOnlyBlock(
                        key: const Key('review-readonly-studio'),
                        label: l10n.reviewGroupStudioA11y(subject.studioName),
                        header: _studioHeader(context, subject),
                        verdict: studioReview.verdict,
                        hits: studioReview.hits,
                        reasons: [
                          for (final r in studioReview.studioReasons)
                            studioReviewReasonLabel(l10n, r),
                        ],
                        text: studioReview.text,
                      ),
              ),
              if (review.photoPostId case final postId?) ...[
                const SizedBox(height: AppSpace.s6),
                AppButton.outline(
                  l10n.reviewSharedLink,
                  onPressed: () => context.push('/p/$postId'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
