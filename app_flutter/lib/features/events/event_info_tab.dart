// lib/features/events/event_info_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/contact/contact_action.dart';
import 'package:photobooking/features/events/event_links.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S11.02/S11.03 entry-fee line of an event's venue (no S11.02-fee frame:
/// organizer.md copy): a paid place says whether the ticket includes the
/// gate fee; a managed spot's gate scans the event ticket, so it is
/// included; a public place has no gate. Null when there is nothing to say.
String? eventEntryFeeLine(AppLocalizations l, EventDetail e) {
  final v = e.venue;
  if (v == null || e.isEntry) {
    return null;
  }
  return switch (v.kind) {
    VenueKind.publicPlace => null,
    VenueKind.managedSpot => l.s1102_feeIncluded,
    VenueKind.paidPlace when v.entryFeeIncluded => l.s1102_feeIncluded,
    VenueKind.paidPlace => switch (v.entryFeeVnd) {
      final amount? when amount > 0 => l.s1102_feeNotIncluded(
        formatMoney(amount),
      ),
      _ => null,
    },
  };
}

/// "gồm phí quản lý địa điểm {y}" for [quantity] tickets: the venue fee the
/// manager accepted, inside the price (Decision 16); null without one.
String? eventVenueFeeLine(
  AppLocalizations l,
  EventDetail e, {
  int quantity = 1,
}) {
  final fee = e.venueFeePerGuest;
  if (fee <= 0 || e.summary.isFree || e.isEntry) {
    return null;
  }
  return l.s1102_venueFee(formatMoney(fee * quantity));
}

/// "Thông tin" of S11.02: host, when, where, seats, description and, for
/// platform-hosted events, the staff Q&A and the support line.
class EventInfoTab extends ConsumerWidget {
  const EventInfoTab({
    super.key,
    required this.event,
    required this.registration,
    required this.isManager,
  });

  final EventDetail event;
  final EventRegistration? registration;
  final bool isManager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = event.summary;
    final theme = Theme.of(context);
    final soldOut = s.status == EventStatus.full || s.seatsLeft == 0;
    final capacityLabel =
        '${l.capacityUsed(s.registeredCount, s.capacity)} · '
        '${soldOut ? l.eventSoldOut : l.eventCapacityLeft(s.seatsLeft)}';
    final meeting = event.meetingPoint;

    Future<void> open(Uri uri) => ref.read(externalLauncherProvider).open(uri);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HostRow(
          event: event,
          registration: registration,
          isManager: isManager,
        ),
        const SizedBox(height: AppSpace.s3),
        _InfoRow(
          key: const Key('event-when'),
          icon: AppIcons.calendar,
          title: eventWhenLabel(l, s.startsAt, event.endsAt),
          subtitle: l.ticketAddToCalendar,
          subtitleIsLink: true,
          onTap: () => open(
            eventCalendarUri(
              title: s.title,
              startsAt: s.startsAt,
              endsAt: event.endsAt,
              location: s.locationName,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        _InfoRow(
          key: const Key('event-where'),
          icon: AppIcons.place,
          title: s.locationName ?? '',
          subtitle: meeting == null || meeting.isEmpty
              ? null
              : l.eventMeetingPoint(meeting),
          trailing: AppButton.text(
            l.ticketDirections,
            key: const Key('event-directions'),
            size: AppButtonSize.xsmall,
            onPressed: () => open(
              eventDirectionsUri(
                lat: s.lat,
                lng: s.lng,
                placeName: s.locationName,
              ),
            ),
          ),
        ),
        if (_feeRow(l, event) case final row?) ...[
          const SizedBox(height: AppSpace.s3),
          row,
        ],
        const SizedBox(height: AppSpace.s3),
        CapacityBar(
          key: const Key('event-capacity'),
          used: s.registeredCount,
          total: s.capacity,
          label: capacityLabel,
        ),
        if (event.description.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s3),
          Text(event.description, style: theme.textTheme.bodyMedium),
        ],
        if (s.isPlatformHosted) ...[
          if (event.faq.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s4),
            Text(
              l.eventFaqTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final f in event.faq) ...[
              const SizedBox(height: AppSpace.s2),
              Text(
                f.question,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(f.answer, style: theme.textTheme.bodySmall),
            ],
          ],
          if ((supportEmail, supportEmailUri()) case (
            final email?,
            final mailto?,
          )) ...[
            const SizedBox(height: AppSpace.s4),
            InkWell(
              key: const Key('event-support'),
              onTap: () => open(mailto),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.eventSupportLine(email),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// The price with the venue fee inside it, and the entry-fee line.
Widget? _feeRow(AppLocalizations l, EventDetail e) {
  final entry = eventEntryFeeLine(l, e);
  final venueFee = eventVenueFeeLine(l, e);
  final price = venueFee == null
      ? null
      : l.s1102_priceWithVenueFee(formatMoney(e.summary.priceVnd), venueFee);
  if (entry == null && price == null) {
    return null;
  }
  return _InfoRow(
    key: const Key('event-fees'),
    icon: AppIcons.ticket,
    title: price ?? entry!,
    subtitle: price == null ? null : entry,
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleIsLink = false,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool subtitleIsLink;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: SizedBox.square(
            dimension: 40,
            child: Center(child: AppIcon(icon, size: AppIconSize.sm)),
          ),
        ),
        const SizedBox(width: AppSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtitleIsLink ? theme.colorScheme.primary : null,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
    return onTap == null
        ? row
        : InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: row,
            ),
          );
  }
}

/// Host line: a photographer (avatar, name, % cà chua, "Hồ sơ", ask first or the
/// unlocked contact) or the app itself, with no buttons (O2).
class _HostRow extends ConsumerWidget {
  const _HostRow({
    required this.event,
    required this.registration,
    required this.isManager,
  });

  final EventDetail event;
  final EventRegistration? registration;
  final bool isManager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = event.summary;
    if (s.isPlatformHosted) {
      return Row(
        key: const Key('event-host-platform'),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(
              dimension: 40,
              child: Center(
                child: AppIcon(AppIcons.store, size: AppIconSize.sm),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Text(
              l.eventHostPlatform,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    final hostId = s.hostId;
    final summary = hostId == null
        ? null
        : ref.watch(photographerProfileProvider(hostId)).value?.summary;
    // "Chủ sự kiện · 🍅 97%" (mock S11.02); under five reviews just the role.
    final hostMeta = [
      MetaPart.text(l.eventHostRole),
      if (summary != null && summary.hasTomatoPct)
        MetaPart.tomato(summary.tomatoPct),
    ];
    final unlocked =
        registration != null &&
        registration!.status == RegistrationStatus.paid &&
        registration!.contactEligible;

    Widget? contact;
    if (hostId != null && !isManager) {
      contact = unlocked
          ? PhotographerContactAction(
              key: const Key('event-contact'),
              photographerId: hostId,
              access: ContactAccess.unlocked,
              subject: ContactSubject.registration(registration!.id),
              source: ScreenCodes.eventDetail,
              style: ContactDialStyle.labeled,
            )
          : AppButton.outline(
              l.contactInquiry,
              key: const Key('event-inquiry'),
              size: AppButtonSize.small,
              icon: const AppIcon(AppIcons.chat, size: 18),
              onPressed: () => context.push(inquiryPath(hostId)),
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppAvatar(
              url: event.hostAvatarUrl ?? summary?.avatarUrl,
              name: s.hostName,
              size: AppAvatarSize.sm,
              decorative: true,
            ),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpace.s1,
                    children: [
                      Text(
                        s.hostName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (s.hostVerified) const VerifiedMark(),
                    ],
                  ),
                  MetaLine(hostMeta, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (hostId != null)
              AppButton.outline(
                l.eventProfile,
                key: const Key('event-host-profile'),
                size: AppButtonSize.xsmall,
                onPressed: () => context.push('/u/$hostId'),
              ),
          ],
        ),
        if (contact != null) ...[
          const SizedBox(height: AppSpace.s2),
          Align(alignment: Alignment.centerLeft, child: contact),
        ],
      ],
    );
  }
}
