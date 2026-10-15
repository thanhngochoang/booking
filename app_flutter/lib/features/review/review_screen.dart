import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_summary.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_providers.dart';
import 'package:photobooking/data/review/review_repository.dart';
import 'package:photobooking/features/review/review_controller.dart';
import 'package:photobooking/features/review/review_labels.dart';
import 'package:photobooking/features/review/widgets/share_photo_grid.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    ref
        .read(reviewControllerProvider(widget.bookingId).notifier)
        .setText(_textController.text);
  }

  Future<void> _submit({required bool share}) async {
    final notifier = ref.read(
      reviewControllerProvider(widget.bookingId).notifier,
    );
    final success = await notifier.submit(share: share);
    if (!mounted) return;

    final state = ref.read(reviewControllerProvider(widget.bookingId));
    if (state.isConflict) {
      // Re-read review, stay and show read-only view
      ref.invalidate(bookingReviewProvider(widget.bookingId));
      ref.invalidate(bookingProvider(widget.bookingId));
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.reviewThanks)));
      context.go('/b/${widget.bookingId}');
    } else if (state.error != null) {
      final l10n = context.l10n;
      final error = state.error;
      final message = switch (error is ReviewException ? error.code : null) {
        ReviewErrorCode.notEligible => l10n.reviewNotYet,
        ReviewErrorCode.permissionDenied ||
        ReviewErrorCode.notFound => l10n.reviewErrorForbidden,
        _ => l10n.detailErrorNetwork,
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bookingAsync = ref.watch(bookingProvider(widget.bookingId));
    final reviewAsync = ref.watch(bookingReviewProvider(widget.bookingId));
    final controllerState = ref.watch(
      reviewControllerProvider(widget.bookingId),
    );
    final notifier = ref.read(
      reviewControllerProvider(widget.bookingId).notifier,
    );

    return ScreenCode(
      ScreenCodes.reviewAndShare,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.reviewTitle),
          leading: const BackButton(),
        ),
        body: AsyncView<Booking?>(
          value: bookingAsync,
          skeleton: _skeleton,
          onRetry: () => ref.invalidate(bookingProvider(widget.bookingId)),
          data: (context, booking) {
            if (booking == null) {
              return Center(
                child: EmptyState(
                  title: l10n.detailNotFound,
                  body: '',
                  actionLabel: l10n.back,
                  onAction: () => Navigator.of(context).maybePop(),
                ),
              );
            }

            final uid = ref.watch(authStateProvider).value?.uid;
            if (uid != null && uid != booking.customerId) {
              return Center(
                child: EmptyState(
                  title: l10n.reviewErrorForbidden,
                  body: '',
                  actionLabel: l10n.back,
                  onAction: () => Navigator.of(context).maybePop(),
                ),
              );
            }

            final isEligible =
                BookingRules.canReview(booking) ||
                BookingRules.isReviewed(booking);
            if (!isEligible) {
              return Center(
                child: EmptyState(
                  title: l10n.reviewNotYet,
                  body: '',
                  actionLabel: l10n.back,
                  onAction: () => Navigator.of(context).maybePop(),
                ),
              );
            }

            final profileAsync = ref.watch(
              photographerProfileProvider(booking.photographerId),
            );
            final photographerName =
                profileAsync.value?.summary.displayName ?? '';
            final thumbUrl = profileAsync.value?.summary.avatarUrl;

            final summary = bookingSummaryOf(
              booking,
              photographerName: photographerName,
              thumbUrl: thumbUrl,
            );

            // The form only shows once the existing review has loaded.
            return AsyncView<Review?>(
              value: reviewAsync,
              skeleton: _skeleton,
              onRetry: () =>
                  ref.invalidate(bookingReviewProvider(widget.bookingId)),
              data: (context, existingReview) {
                if (existingReview != null ||
                    BookingRules.isReviewed(booking) ||
                    controllerState.isConflict) {
                  return _buildReadOnlyView(
                    context: context,
                    summary: summary,
                    review: existingReview,
                  );
                }
                return _buildFormView(
                  context: context,
                  theme: theme,
                  summary: summary,
                  photographerName: photographerName,
                  state: controllerState,
                  notifier: notifier,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _skeleton(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpace.s4),
    child: BookingCard.skeleton(size: BookingCardSize.compact),
  );

  Widget _buildReadOnlyView({
    required BuildContext context,
    required BookingSummary summary,
    required Review? review,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BookingCard(data: summary, size: BookingCardSize.compact),
            const SizedBox(height: AppSpace.s6),
            if (review == null)
              Text(
                l10n.reviewAlreadyDone,
                key: const Key('review_already_done'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  VerdictBadge(kind: review.verdict.kind, hits: review.hits),
                  const SizedBox(width: AppSpace.s2),
                  Flexible(
                    child: Text(
                      review.verdict == Verdict.tomato
                          ? l10n.reviewTomato
                          : l10n.reviewBrick,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              if (review.verdict == Verdict.brick &&
                  review.reasons.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s3),
                Wrap(
                  key: const Key('review_reasons_readonly'),
                  alignment: WrapAlignment.center,
                  spacing: AppSpace.s1,
                  children: [
                    for (final r in review.reasons)
                      Semantics(
                        label: reviewReasonLabel(l10n, r),
                        child: ExcludeSemantics(
                          child: IgnorePointer(
                            child: AppChip(
                              label: reviewReasonLabel(l10n, r),
                              selected: true,
                              kind: AppChipKind.context,
                              onChanged: (_) {},
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.s4),
              Text(review.text, style: theme.textTheme.bodyLarge),
            ],
            if (review?.photoPostId != null) ...[
              const SizedBox(height: AppSpace.s6),
              AppButton.outline(
                l10n.reviewSharedLink,
                onPressed: () => context.push('/p/${review!.photoPostId}'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormView({
    required BuildContext context,
    required ThemeData theme,
    required BookingSummary summary,
    required String photographerName,
    required ReviewState state,
    required ReviewController notifier,
  }) {
    final l10n = context.l10n;
    final isSubmitting = state.phase == ReviewPhase.submitting;
    final verdict = state.verdict;
    final missing = state.missing;
    final muted = context.mutedForeground;

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
                  const SizedBox(height: AppSpace.s6),
                  VerdictPad(
                    kind: verdict?.kind,
                    hits: state.hits,
                    enabled: !isSubmitting,
                    onChanged: (kind, hits) =>
                        notifier.setVerdict(kind?.verdict, hits),
                  ),
                  if (verdict != null) ...[
                    const SizedBox(height: AppSpace.s3),
                    VerdictLevel(
                      kind: verdict.kind,
                      hits: state.hits,
                      label: verdictLevelLabel(l10n, verdict.kind, state.hits),
                      onReset: isSubmitting ? () {} : notifier.reset,
                      // The brick frame of the mock leaves the hint out.
                      showHint: verdict == Verdict.tomato,
                    ),
                  ],
                  if (verdict == Verdict.brick) ...[
                    const SizedBox(height: AppSpace.s4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.reviewReasonsTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s2),
                        Text(
                          l10n.reviewReasonsMin,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s1),
                    Wrap(
                      key: const Key('review_reasons'),
                      spacing: AppSpace.s1,
                      children: [
                        for (final r in ReviewReason.values)
                          AppChip(
                            label: reviewReasonLabel(l10n, r),
                            selected: state.reasons.contains(r),
                            kind: AppChipKind.context,
                            onChanged: isSubmitting
                                ? (_) {}
                                : (_) => notifier.toggleReason(r),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpace.s4),
                  TextField(
                    key: const Key('review_text_field'),
                    controller: _textController,
                    enabled: !isSubmitting,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: ReviewController.maxTextLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l10n.reviewText,
                      hintText: verdict == Verdict.brick
                          ? l10n.reviewTextHintBrick
                          : l10n.reviewTextHintTomato,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.reviewShare,
                          style: theme.textTheme.titleMedium,
                        ),
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
              ),
            ),
          ),
          Container(
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
                if (missing != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s2),
                    child: Text(
                      switch (missing) {
                        ReviewBlock.verdict => l10n.reviewNeedVerdict,
                        ReviewBlock.reason => l10n.reviewNeedReason,
                        ReviewBlock.text => l10n.reviewTextTooShort,
                      },
                      key: const Key('review_missing_hint'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                state.photos.isEmpty
                    ? AppButton.primary(
                        l10n.reviewSubmit,
                        key: const Key('submit_review_button'),
                        loading: isSubmitting,
                        onPressed: state.canSubmitReviewOnly
                            ? () => _submit(share: false)
                            : null,
                      )
                    : Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: AppButton.outline(
                              l10n.reviewOnly,
                              key: const Key('review_only_button'),
                              loading:
                                  isSubmitting && state.submittedShare == false,
                              onPressed: state.canSubmitReviewOnly
                                  ? () => _submit(share: false)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpace.s3),
                          Expanded(
                            flex: 3,
                            child: AppButton.primary(
                              l10n.reviewSubmitShare(state.photos.length),
                              key: const Key('submit_share_button'),
                              loading:
                                  isSubmitting && state.submittedShare == true,
                              onPressed: state.canSubmitWithShare
                                  ? () => _submit(share: true)
                                  : null,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
