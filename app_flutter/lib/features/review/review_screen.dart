import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/booking/booking_summary.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_providers.dart';
import 'package:photobooking/features/review/review_controller.dart';
import 'package:photobooking/features/review/widgets/share_photo_grid.dart';
import 'package:photobooking/features/review/widgets/star_rating.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({
    super.key,
    required this.bookingId,
  });

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
    final notifier =
        ref.read(reviewControllerProvider(widget.bookingId).notifier);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.reviewThanks)),
      );
      context.go('/b/${widget.bookingId}');
    } else if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.detailErrorNetwork)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bookingAsync = ref.watch(bookingProvider(widget.bookingId));
    final reviewAsync = ref.watch(bookingReviewProvider(widget.bookingId));
    final controllerState =
        ref.watch(reviewControllerProvider(widget.bookingId));
    final notifier =
        ref.read(reviewControllerProvider(widget.bookingId).notifier);

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
                  title: l10n.reviewNotYet,
                  body: '',
                  actionLabel: l10n.back,
                  onAction: () => Navigator.of(context).maybePop(),
                ),
              );
            }

            final isEligible = booking.status == BookingStatus.completed ||
                booking.status == BookingStatus.reviewed;
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
                    booking.status == BookingStatus.reviewed ||
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
            BookingCard(
              data: summary,
              size: BookingCardSize.compact,
            ),
            const SizedBox(height: AppSpace.s6),
            if (review == null)
              Text(
                l10n.reviewAlreadyDone,
                key: const Key('review_already_done'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              )
            else ...[
              Center(
                child: StarRating(
                  value: review.rating,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpace.s4),
              Text(
                review.text,
                style: theme.textTheme.bodyLarge,
              ),
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
    final trimmedLength = state.text.trim().length;
    final showError = state.text.isNotEmpty && trimmedLength < 10;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BookingCard(
                    data: summary,
                    size: BookingCardSize.compact,
                  ),
                  const SizedBox(height: AppSpace.s6),
                  Center(
                    child: StarRating(
                      value: state.rating,
                      size: 40,
                      onChanged: isSubmitting ? null : notifier.setRating,
                    ),
                  ),
                  const SizedBox(height: AppSpace.s6),
                  TextField(
                    key: const Key('review_text_field'),
                    controller: _textController,
                    enabled: !isSubmitting,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l10n.reviewText,
                      hintText: l10n.reviewTextHint,
                      alignLabelWithHint: true,
                      errorText: showError ? l10n.reviewTextTooShort : null,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s2,
                          vertical: AppSpace.s1 / 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          borderRadius:
                              BorderRadius.circular(AppRadius.control),
                        ),
                        child: Text(
                          l10n.reviewOptional,
                          style: theme.textTheme.labelSmall,
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
            child: state.photos.isEmpty
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
                        child: AppButton.outline(
                          l10n.reviewOnly,
                          key: const Key('review_only_button'),
                          loading: isSubmitting,
                          onPressed: state.canSubmitReviewOnly
                              ? () => _submit(share: false)
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s3),
                      Expanded(
                        child: AppButton.primary(
                          l10n.reviewSubmitShare(state.photos.length),
                          key: const Key('submit_share_button'),
                          loading: isSubmitting,
                          onPressed: state.canSubmitWithShare
                              ? () => _submit(share: true)
                              : null,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
