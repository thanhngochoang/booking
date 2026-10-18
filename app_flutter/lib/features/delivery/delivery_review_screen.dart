import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/delivery/report_delivery_sheet.dart';
import 'package:photobooking/features/delivery/revision_sheet.dart';
import 'package:photobooking/features/delivery/widgets/check_window_card.dart';
import 'package:photobooking/features/delivery/widgets/originals_card.dart';
import 'package:photobooking/features/delivery/widgets/sample_grid.dart';

class DeliveryReviewScreen extends ConsumerStatefulWidget {
  const DeliveryReviewScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<DeliveryReviewScreen> createState() => _DeliveryReviewScreenState();
}

class _DeliveryReviewScreenState extends ConsumerState<DeliveryReviewScreen> {
  static const _tick = Duration(minutes: 1);

  static String _twoD(int n) => n.toString().padLeft(2, '0');

  static String _formatDate(DateTime dt) => '${_twoD(dt.day)}/${_twoD(dt.month)}';

  static String _formatTime(DateTime dt) => '${_twoD(dt.hour)}:${_twoD(dt.minute)}';

  static String _formatAutoApproveTime(Duration left) {
    if (left <= Duration.zero) return '0 giây';
    final days = left.inDays;
    final hours = left.inHours % 24;
    final minutes = left.inMinutes % 60;
    if (days > 0) {
      return '$days ngày ${hours.toString().padLeft(2, '0')} giờ';
    }
    if (hours > 0) {
      return '$hours giờ ${minutes.toString().padLeft(2, '0')} phút';
    }
    return '$minutes phút';
  }

  Future<void> _approve(Booking booking) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmSheet(
      context,
      title: l10n.deliveryApproveConfirmTitle,
      body: l10n.deliveryApproveConfirmBody,
      confirmLabel: l10n.deliveryApprove,
      keepLabel: l10n.deliveryApproveConfirmReview,
      danger: false,
    );

    if (confirmed && mounted) {
      final repo = ref.read(deliveryRepositoryProvider);
      await repo.approve(booking.id);
      if (mounted) {
        final now = ref.read(clockProvider)();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.deliveryApprovedToast('${_formatTime(now)} ${_formatDate(now)}'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openRevision(
    Booking booking,
    DeliveryRound round,
    String providerName, {
    bool extra = false,
  }) async {
    await showRevisionSheet(
      context,
      booking: booking,
      round: round,
      providerName: providerName,
      extra: extra,
    );
  }

  Future<void> _report(Booking booking) async {
    final reported = await showReportDeliverySheet(context, booking: booking);
    if (reported == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.deliveryReportSuccess)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final textMuted = dark ? AppColorsDark.foregroundSecondary : AppColors.foregroundSecondary;

    final bookingAsync = ref.watch(bookingProvider(widget.bookingId));
    final auth = ref.watch(authStateProvider).value;
    final now = ref.watch(nowTickerProvider(_tick)).value ?? ref.read(clockProvider)();

    final booking = bookingAsync.value;
    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.deliveryReviewApprovedTitle)),
        body: const Center(child: DotRingLoader(size: LoaderSize.screen)),
      );
    }

    // Role check: Only customer and photographer can view
    final isCustomer = auth?.uid == booking.customerId;
    final isPhotographer = auth?.uid == booking.photographerId;
    if (!isCustomer && !isPhotographer) {
      return ScreenCode(
        ScreenCodes.deliveryReview,
        child: Scaffold(
          appBar: AppBar(),
          body: EmptyState(
            title: l10n.deliveryNotFound,
          ),
        ),
      );
    }

    final roundsAsync = ref.watch(deliveryRoundsProvider(widget.bookingId));
    final rounds = roundsAsync.value ?? const [];
    final currentRound = rounds.isNotEmpty ? rounds.last : null;

    final isApproved = booking.status == BookingStatus.approved ||
        booking.status == BookingStatus.completed;

    // Delivery Link: watchLink ONLY when approved/completed per Task 8 spec
    final DeliveryLink? link = isApproved
        ? ref.watch(deliveryLinkProvider(widget.bookingId)).value
        : null;

    final profile = ref.watch(photographerProfileProvider(booking.photographerId)).value;
    final providerName = profile?.summary.displayName ?? booking.serviceSnapshot.name;

    final title = isApproved
        ? l10n.deliveryReviewApprovedTitle
        : l10n.deliveryReviewTitle(currentRound?.round ?? booking.deliveryRound);

    final roundNum = currentRound?.round ?? (booking.deliveryRound > 0 ? booking.deliveryRound : 1);
    final totalRounds = booking.revisionsIncluded;
    final noRoundsLeft = roundNum >= totalRounds;
    final extraPending = booking.extraRound?.status == 'pending';

    // Auto-approve deadline
    final autoApproveAt = booking.deliveredAt?.add(const Duration(days: 3));

    // 48h Check Until
    final checkUntil = booking.checkUntil ??
        booking.approvedAt?.add(const Duration(hours: 48));

    return ScreenCode(
      ScreenCodes.deliveryReview,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top sender row
              if (currentRound != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.secondary,
                      child: Text(
                        providerName.isNotEmpty ? providerName[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.deliverySenderInfo(
                              providerName,
                              currentRound.samples.length,
                              _formatDate(currentRound.submittedAt),
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (!isApproved) ...[
                            const SizedBox(height: AppSpace.s1),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: StatusBadge.custom(
                                label: l10n.deliveryWaitingApprovalBadge,
                                color: AppColors.warning.withValues(alpha: 0.15),
                                onColor: AppColors.warning,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s4),
              ],

              // Sample grid
              if (currentRound != null && currentRound.samples.isNotEmpty) ...[
                SampleGrid(samples: currentRound.samples),
                const SizedBox(height: AppSpace.s4),
              ] else if (booking.status == BookingStatus.completed &&
                  (currentRound == null || currentRound.samples.isEmpty)) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  decoration: BoxDecoration(
                    color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Center(
                    child: Text(
                      l10n.deliverySamplesPurged,
                      style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
              ],

              // Originals Card
              if (currentRound != null) ...[
                OriginalsCard(
                  photoCount: currentRound.photoCount,
                  isApproved: isApproved,
                  linkHost: currentRound.linkHost,
                  rawLink: link?.link,
                  providerName: providerName,
                  submittedDate: _formatDate(currentRound.submittedAt),
                  onOpenLink: isApproved && link?.link != null
                      ? () => ref.read(externalLauncherProvider).open(Uri.parse(link!.link))
                      : null,
                ),
                const SizedBox(height: AppSpace.s4),
              ],

              // Revision status line & Auto-approve notice (when delivered)
              if (!isApproved) ...[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpace.s2,
                  runSpacing: AppSpace.s1,
                  children: [
                    Text(
                      noRoundsLeft
                          ? l10n.deliveryRevisionsExhausted(totalRounds)
                          : l10n.deliveryRevisionsLeft(roundNum, totalRounds),
                      style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
                    ),
                    Text(
                      booking.serviceSnapshot.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (autoApproveAt != null) ...[
                  const SizedBox(height: AppSpace.s2),
                  CountdownText(
                    deadline: autoApproveAt,
                    now: () => now,
                    builder: (context, left) {
                      return Text(
                        l10n.deliveryAutoApproveHint(_formatAutoApproveTime(left)),
                        style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
                      );
                    },
                  ),
                ],
                const SizedBox(height: AppSpace.s4),
              ],

              // Check window card (when approved)
              if (isApproved && checkUntil != null) ...[
                CheckWindowCard(
                  checkUntil: checkUntil,
                  now: now,
                  onReport: now.isBefore(checkUntil) ? () => _report(booking) : null,
                ),
                const SizedBox(height: AppSpace.s4),
              ],
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s4,
              vertical: AppSpace.s3,
            ),
            child: _buildFooter(
              context,
              booking,
              currentRound,
              providerName,
              isApproved,
              noRoundsLeft,
              extraPending,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    Booking booking,
    DeliveryRound? currentRound,
    String providerName,
    bool isApproved,
    bool noRoundsLeft,
    bool extraPending,
  ) {
    final l10n = context.l10n;

    if (!isApproved) {
      if (currentRound == null) return const SizedBox.shrink();

      if (extraPending) {
        return Text(
          l10n.deliveryExtraRoundPending(providerName),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColorsDark.foregroundSecondary
                    : AppColors.foregroundSecondary,
              ),
        );
      }

      if (noRoundsLeft) {
        return Row(
          children: [
            Expanded(
              child: AppButton.outline(
                l10n.deliveryAskExtraRound,
                onPressed: () => _openRevision(
                  booking,
                  currentRound,
                  providerName,
                  extra: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: AppButton.primary(
                l10n.deliveryApprove,
                onPressed: () => _approve(booking),
              ),
            ),
          ],
        );
      }

      return Row(
        children: [
          Expanded(
            flex: 46,
            child: AppButton.outline(
              l10n.deliveryRequestRevision,
              onPressed: () => _openRevision(
                booking,
                currentRound,
                providerName,
                extra: false,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            flex: 54,
            child: AppButton.primary(
              l10n.deliveryApprove,
              onPressed: () => _approve(booking),
            ),
          ),
        ],
      );
    }

    // Approved footer
    final isReviewed = BookingRules.isReviewed(booking);
    if (isReviewed) {
      return AppButton.outline(
        l10n.deliveryViewReview,
        onPressed: () => context.push('/b/${booking.id}/review'),
      );
    }

    return AppButton.primary(
      l10n.deliveryRateShoot,
      onPressed: () => context.push('/b/${booking.id}/review'),
    );
  }
}
