// lib/features/photographer_profile/photographer_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';
import 'package:photobooking/features/photographer_profile/widgets/profile_bottom_bar.dart';
import 'package:photobooking/features/photographer_profile/widgets/profile_header.dart';
import 'package:photobooking/features/photographer_profile/widgets/profile_sections.dart';

/// S03.01 "Hồ sơ nhiếp ảnh gia" at `/u/:uid`, for visitors and the owner.
class PhotographerProfileScreen extends ConsumerStatefulWidget {
  const PhotographerProfileScreen({
    super.key,
    required this.uid,
    this.initialSection = ProfileSection.portfolio,
  });

  final String uid;
  final ProfileSection initialSection;

  @override
  ConsumerState<PhotographerProfileScreen> createState() =>
      _PhotographerProfileScreenState();
}

class _PhotographerProfileScreenState
    extends ConsumerState<PhotographerProfileScreen> {
  late final ValueNotifier<ProfileSection> _section = ValueNotifier(
    widget.initialSection,
  );

  @override
  void initState() {
    super.initState();
    // After the first frame: providers must not change while building.
    Future.microtask(() {
      if (!mounted) {
        return;
      }
      final me = ref.read(authRepositoryProvider).currentUser?.uid;
      if (me != null && me != widget.uid) {
        ref.read(followProvider.notifier).load(widget.uid);
      }
    });
  }

  @override
  void dispose() {
    _section.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    final target = await showAppSheet<String>(
      context,
      builder: (_) => const _EditSheet(),
    );
    if (target == null || !mounted) {
      return;
    }
    await context.push(target);
    if (!mounted) {
      return;
    }
    ref
      ..invalidate(photographerProfileProvider(widget.uid))
      ..invalidate(profilePackagesProvider(widget.uid))
      ..invalidate(photographerSkillsSnapshotProvider(widget.uid));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profile = ref.watch(photographerProfileProvider(widget.uid));
    final owner =
        ref.read(authRepositoryProvider).currentUser?.uid == widget.uid;
    return ScreenCode(
      ScreenCodes.photographerProfile,
      child: AsyncView<PhotographerProfile?>(
        value: profile,
        onRetry: () =>
            ref.invalidate(photographerProfileProvider(widget.uid)),
        skeleton: (_) => const _ProfileSkeleton(),
        error: (context, _, _) => _Message(
          title: l.profileLoadError,
          onRetry: () =>
              ref.invalidate(photographerProfileProvider(widget.uid)),
        ),
        data: (context, value) {
          if (value == null) {
            return _Message(title: l.profileNotFound);
          }
          if (!value.published && !owner) {
            return _Message(
              title: l.profileNotReadyTitle,
              body: l.profileNotReadyBody,
            );
          }
          return _loaded(context, value, owner);
        },
      ),
    );
  }

  Widget _loaded(BuildContext context, PhotographerProfile p, bool owner) {
    final l = context.l10n;
    final hero = p.summary.heroUrl;
    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? Padding(
                padding: const EdgeInsets.all(AppSpace.s1),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.overlay,
                    shape: BoxShape.circle,
                  ),
                  child: BackButton(
                    color: Colors.white,
                    onPressed: () => context.pop(),
                  ),
                ),
              )
            : null,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ProfileHeader(profile: p, owner: owner),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: ValueListenableBuilder<ProfileSection>(
                valueListenable: _section,
                builder: (context, value, _) => SegmentedTabs<ProfileSection>(
                  key: const Key('profile-tabs'),
                  options: [
                    SegmentOption(
                      value: ProfileSection.portfolio,
                      label: l.profileTabPortfolio,
                    ),
                    SegmentOption(
                      value: ProfileSection.services,
                      label: l.profileTabServices,
                    ),
                    SegmentOption(
                      value: ProfileSection.calendar,
                      label: l.profileTabCalendar,
                    ),
                    SegmentOption(
                      value: ProfileSection.reviews,
                      label: l.profileTabReviews,
                    ),
                  ],
                  value: value,
                  onChanged: (s) => _section.value = s,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s3,
              AppSpace.s4,
              AppSpace.s6,
            ),
            sliver: ValueListenableBuilder<ProfileSection>(
              valueListenable: _section,
              builder: (context, value, _) => switch (value) {
                ProfileSection.portfolio => PortfolioSliver(
                  photographerId: widget.uid,
                ),
                ProfileSection.services => ServicesSliver(
                  photographerId: widget.uid,
                  owner: owner,
                ),
                ProfileSection.calendar => CalendarSliver(
                  photographerId: widget.uid,
                ),
                ProfileSection.reviews => const ReviewsSliver(),
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: ProfileBottomBar(
        photographerId: widget.uid,
        owner: owner,
        onEdit: _edit,
      ),
    );
    return hero == null
        ? AuroraBackground(child: scaffold)
        : ImageBackdrop(image: NetworkImage(hero), child: scaffold);
  }
}

class _EditSheet extends StatelessWidget {
  const _EditSheet();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final entries = [
      ('edit-intro', l.profileEditIntro, Icons.badge_outlined, '/setup/1'),
      ('edit-packages', l.profileEditPackages, Icons.sell_outlined, '/setup/2'),
      (
        'edit-skills',
        l.profileEditSkills,
        Icons.auto_awesome_outlined,
        '/profile/skills',
      ),
      (
        'edit-photo',
        l.profileEditPhoto,
        Icons.account_circle_outlined,
        '/settings/profile',
      ),
      ('edit-contact', l.profileEditContact, Icons.call_outlined, '/setup/4'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            AppSpace.s2,
            AppSpace.s5,
            AppSpace.s2,
          ),
          child: Text(
            l.profileEdit,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        for (final (key, label, icon, path) in entries)
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              key: Key(key),
              leading: Icon(icon),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).pop(path),
            ),
          ),
        const SizedBox(height: AppSpace.s3),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.body = '', this.onRetry});

  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AuroraBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(),
      body: onRetry != null
          ? ErrorState(message: title, onRetry: onRetry)
          : EmptyState(title: title, body: body),
    ),
  );
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) => AuroraBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          Center(child: AppAvatar.skeleton(size: AppAvatarSize.lg)),
          const SizedBox(height: AppSpace.s4),
          Center(child: AppSkeleton.line(width: 180)),
          const SizedBox(height: AppSpace.s2),
          Center(child: AppSkeleton.line(width: 240)),
          const SizedBox(height: AppSpace.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              StatTile.skeleton(),
              StatTile.skeleton(),
              StatTile.skeleton(),
              StatTile.skeleton(),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          AppSkeleton.card(height: 90),
        ],
      ),
    ),
  );
}
