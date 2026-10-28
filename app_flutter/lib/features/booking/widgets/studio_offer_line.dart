// S05.02 / S06.01 studio side: a collaborator offer waiting or declined.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/booking/booking_view_rules.dart';
import 'package:photobooking/features/collab/collab_controller.dart';
import 'package:photobooking/features/studio/studio_common.dart';

/// The studio's line for [booking]'s collaborator offer ([studioOfferOf]):
/// "Chờ {name} nhận · còn {left}" (live, injected clock) or, in red, "{name}
/// đã từ chối. Giao người khác trước {deadline}."; nothing otherwise or
/// while the name loads.
class StudioOfferLine extends ConsumerWidget {
  const StudioOfferLine({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final clock = ref.watch(clockProvider);
    final offer = studioOfferOf(booking, clock());
    if (offer == null) return const SizedBox.shrink();
    final name =
        ref
            .watch(photographerProfileProvider(offer.collaboratorId))
            .value
            ?.summary
            .displayName ??
        '';
    if (name.isEmpty) return const SizedBox.shrink();
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final style = theme.textTheme.bodySmall;
    final expiresAt = offer.expiresAt;
    return KeyedSubtree(
      key: const Key('studio-offer-line'),
      child: switch (offer.state) {
        StudioOfferState.pending when expiresAt != null => CountdownText(
          deadline: expiresAt,
          now: clock,
          builder: (context, left) => Text(
            l.assignOfferPending(name, collabLeftText(left, l)),
            style: style?.copyWith(color: secondary),
          ),
        ),
        StudioOfferState.pending => const SizedBox.shrink(),
        StudioOfferState.declined => Text(
          l.assignOfferDeclined(
            name,
            studioDeadlineText(booking.studio!.assignDeadline),
          ),
          style: style?.copyWith(
            color: dark ? AppColorsDark.destructive : AppColors.destructive,
          ),
        ),
      },
    );
  }
}
