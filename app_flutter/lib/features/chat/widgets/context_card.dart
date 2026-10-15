import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/booking/booking_summary.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class ChatContextCard extends ConsumerWidget {
  const ChatContextCard({super.key, required this.thread, this.serviceId});

  final ChatThread thread;
  final String? serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (thread.kind == ChatKind.booking && thread.bookingId != null) {
      return _BookingContextCard(
        bookingId: thread.bookingId!,
        photographerId: thread.photographerId,
      );
    }

    return _InquiryContextCard(
      photographerId: thread.photographerId,
      serviceId: serviceId,
    );
  }
}

class _BookingContextCard extends ConsumerWidget {
  const _BookingContextCard({
    required this.bookingId,
    required this.photographerId,
  });

  final String bookingId;
  final String photographerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingProvider(bookingId));
    final profileAsync = ref.watch(partyProfileProvider(photographerId));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s2,
      ),
      child: AsyncView<Booking?>(
        value: bookingAsync,
        skeleton: (_) => BookingCard.skeleton(size: BookingCardSize.compact),
        data: (context, booking) {
          if (booking == null) return const SizedBox.shrink();

          final l10n = AppLocalizations.of(context);
          final photographerName =
              profileAsync.value?.displayName ?? l10n.profileRolePhotographer;
          final thumbUrl = profileAsync.value?.avatarUrl;
          final statusLabel = booking.status.label(l10n);

          final summary = bookingSummaryOf(
            booking,
            photographerName: photographerName,
            thumbUrl: thumbUrl,
            statusLabel: statusLabel,
          );

          return BookingCard(
            data: summary,
            size: BookingCardSize.compact,
            onTap: () => context.push('/b/$bookingId'),
          );
        },
      ),
    );
  }
}

class _InquiryContextCard extends ConsumerWidget {
  const _InquiryContextCard({required this.photographerId, this.serviceId});

  final String photographerId;
  final String? serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(photographerProfileProvider(photographerId));
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bg = dark ? AppColorsDark.glass : AppColors.glass;
    final border = theme.colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s2,
      ),
      child: AsyncView<PhotographerProfile?>(
        value: profileAsync,
        skeleton: (_) => Container(
          height: 60,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        data: (context, profile) {
          if (profile == null) return const SizedBox.shrink();
          final summary = profile.summary;

          return Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => context.push('/u/$photographerId'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s2),
                  child: Row(
                    children: [
                      AppAvatar(
                        url: summary.avatarUrl,
                        name: summary.displayName,
                        size: AppAvatarSize.sm,
                      ),
                      const SizedBox(width: AppSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              summary.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((summary.areaLabel ?? '').isNotEmpty)
                              Text(
                                summary.areaLabel!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const AppIcon(AppIcons.chevron, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
