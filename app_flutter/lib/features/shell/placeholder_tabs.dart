import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';

UserRole _role(WidgetRef ref) =>
    ref.watch(currentProfileProvider).value?.role ?? UserRole.customer;

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.tabHome)),
      body: EmptyState(title: l.emptyHomeTitle, body: l.emptyHomeBody),
    );
  }
}

class ExploreTab extends ConsumerWidget {
  const ExploreTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.tabExplore)),
      body: EmptyState(title: l.emptyExploreTitle, body: l.emptyExploreBody),
    );
  }
}

class ActionTab extends ConsumerWidget {
  const ActionTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final photographer = _role(ref) == UserRole.photographer;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(photographer ? l.tabCreate : l.tabFind)),
      body: EmptyState(
        title: photographer ? l.emptyCreateTitle : l.emptyFindTitle,
        body: photographer ? l.emptyCreateBody : l.emptyFindBody,
      ),
    );
  }
}

class BookingsTab extends ConsumerWidget {
  const BookingsTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final photographer = _role(ref) == UserRole.photographer;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(photographer ? l.tabWork : l.tabBookings)),
      body: EmptyState(
        title: photographer ? l.emptyWorkTitle : l.emptyBookingsTitle,
        body: photographer ? l.emptyWorkBody : l.emptyBookingsBody,
      ),
    );
  }
}

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(currentProfileProvider).value;
    final roleLabel = profile?.role == UserRole.photographer
        ? l.profileRolePhotographer
        : l.profileRoleCustomer;
    final avatar = profile?.avatarUrl;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.tabProfile)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundImage: avatar == null ? null : NetworkImage(avatar),
                child: avatar == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(height: AppSpace.s3),
              Text(
                profile?.displayName ?? '',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              Text(
                roleLabel,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton.outline(
                l.signOut,
                key: const Key('sign-out'),
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
