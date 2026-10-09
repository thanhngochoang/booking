import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/booking/my_bookings_screen.dart';
import 'package:photobooking/features/create_post/create_post_screen.dart';
import 'package:photobooking/features/find/find_screen.dart';
import 'package:photobooking/features/home/home_controller.dart';
import 'package:photobooking/features/work/work_screen.dart';

UserRole _role(WidgetRef ref) =>
    ref.watch(currentProfileProvider).value?.role ?? UserRole.customer;

class ActionTab extends ConsumerWidget {
  const ActionTab({
    super.key,
    this.specialty,
    this.style,
    this.area,
    this.caption,
  });

  /// Filters carried by the link `/action?specialty=…&style=…&area=…`.
  final String? specialty;
  final String? style;
  final String? area;

  /// `/action?caption=%23Tag%20`: a photographer's post opens with this text
  /// (the timeline's "Đăng ảnh với #Tag").
  final String? caption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).value?.role;
    if (role == null) {
      return const SizedBox.shrink();
    }
    if (role == UserRole.customer) {
      return FindPhotographerScreen(
        initialSpecialty: specialty,
        initialStyle: style,
        initialArea: area,
      );
    }
    return CreatePostScreen(
      initialCaption: caption,
      onAddService: () => context.push('/setup/2'),
      onOpenEvents: () => context.push('/events/new'),
      onPublished: (postId) {
        ref.read(homeFeedProvider.notifier).pinToTop(postId);
        context.go(AppTab.home.path);
      },
    );
  }
}

class BookingsTab extends ConsumerWidget {
  const BookingsTab({super.key, this.tab, this.highlight});

  /// `events` opens the customer's "Vé sự kiện" (`/bookings?tab=events`).
  final String? tab;

  /// The ticket to emphasise (`&highlight=<registrationId>`).
  final String? highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing until the role is known, so neither side flashes the other's tab.
    if (!ref.watch(currentProfileProvider).hasValue) {
      return const SizedBox.shrink();
    }
    return _role(ref) == UserRole.customer
        ? MyBookingsScreen(
            showTickets: true,
            initialTab: tab,
            highlightTicketId: highlight,
          )
        : const WorkScreen(showEvents: true);
  }
}
