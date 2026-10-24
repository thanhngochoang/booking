import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/features/collab/collab_controller.dart';
import 'package:photobooking/features/onboarding/role_controller.dart';
import 'package:photobooking/features/photographer_setup/stored_provider_type.dart';
import 'package:photobooking/features/settings/button_style_controller.dart';
import 'package:photobooking/features/settings/provider_type_sheet.dart';
import 'package:photobooking/features/settings/role_mode_card.dart';
import 'package:photobooking/features/settings/settings_links.dart';
import 'package:photobooking/features/settings/show_screen_codes_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

/// S09.02's groups, top to bottom. Each group's label carries the key
/// `settings-group-<name>`; a group whose screens do not exist yet is absent,
/// and later plans fill their slot without reordering the others.
const settingsGroupOrder = [
  'account',
  'mode',
  'appearance',
  'buttonStyle',
  'notifications',
  'paymentsData',
  'support',
  'debug',
  'signOut',
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final name = profile?.displayName;
    final hasAvatar = profile?.avatarUrl != null;
    // Without a photo the avatar style paints the gradient, so show that.
    final buttonStyle = hasAvatar
        ? ref.watch(buttonStyleProvider)
        : ButtonStyleMode.gradient;
    final showCodes = ref.watch(showScreenCodesProvider);
    final isPhotographer = profile?.role == UserRole.photographer;
    final type = isPhotographer
        ? ref.watch(liveProviderTypeProvider).value
        : null;
    final verifyReady = ref.watch(verifyStartReadyProvider);
    // S21.04 opens once the studio owner is verified (Decision 16).
    final ownerVerified =
        type == ProviderType.studio &&
        (ref.watch(myIntroProvider).value?.verified ?? false);
    final studioReady = ref.watch(studioRoutesReadyProvider);
    final isStaff = ref.watch(staffRoleProvider).value != null;
    // While the mode switches, only the mode card reacts.
    final switching = ref.watch(roleSwitchControllerProvider).isLoading;
    // Here, not in the card: the card can scroll out and be disposed.
    listenToRoleSwitch(context, ref);
    Widget guard(Widget child) =>
        AbsorbPointer(absorbing: switching, child: child);

    final accountRows = <Widget>[
      ListTile(
        key: const Key('settings-edit-profile'),
        leading: const AppIcon(AppIcons.profile),
        title: Text(l.settingsEditProfile),
        subtitle: Text(name ?? l.settingsEditProfileBody),
        trailing: const AppIcon(AppIcons.chevron),
        onTap: () => context.push('/settings/profile'),
      ),
      const _PhoneTile(),
      if (isPhotographer) ...[
        _SkillsTile(uid: profile!.uid),
        _ProviderTypeTile(uid: profile.uid),
        _LinkTile(
          key: const Key('settings-addons'),
          icon: AppIcons.addCircle,
          title: l.settingsAddons,
          path: '/me/addons',
        ),
        if (type == ProviderType.studio) _StudioAddressTile(uid: profile.uid),
        _LinkTile(
          key: const Key('profile-awards'),
          icon: AppIcons.award,
          title: l.settingsAwards,
          subtitle: l.settingsAwardsBody,
          path: '/me/awards',
        ),
        if (verifyReady) ...[
          const _VerifyTile(),
          if (ownerVerified) const _BusinessTile(),
        ],
        if (studioReady && type == ProviderType.studio)
          const _StudioMembersTile()
        else if (studioReady && type != null)
          const _MyStudioTile(),
        // S27 (#151): after the studio rows, before the public profile.
        if (type == ProviderType.studio) ...[
          const _CollabStudioTile(),
          const _RecruitTile(),
        ] else if (type != null)
          const _CollabMemberTile(),
        _LinkTile(
          key: const Key('profile-public'),
          icon: AppIcons.store,
          title: l.settingsPublicProfile,
          subtitle: l.settingsPublicProfileBody,
          path: '/u/${profile.uid}',
        ),
      ],
      _LinkTile(
        key: const Key('settings-blocked'),
        icon: AppIcons.block,
        title: l.settingsBlocked,
        subtitle: l.settingsBlockedBody,
        path: '/settings/blocked',
      ),
      if (isStaff)
        _LinkTile(
          key: const Key('settings-manage-events'),
          icon: AppIcons.celebration,
          title: l.settingsManageEvents,
          path: '/events/mine',
        ),
    ];

    // Mid-switch, Cài đặt cannot be left (system back or the AppBar arrow),
    // so the mode switch's SnackBar, error and redirect are never lost.
    final canGoBack = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    return ScreenCode(
      ScreenCodes.settings,
      child: AuroraBackground(
        child: PopScope(
          canPop: !switching,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              leading: switching && canGoBack
                  ? IconButton(
                      key: const Key('settings-back-disabled'),
                      onPressed: null,
                      icon: const BackButtonIcon(),
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                    )
                  : null,
              title: Text(l.settingsTitle),
            ),
            body: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.s5),
                children: [
                  _SectionLabel(
                    l.settingsAccount,
                    key: const Key('settings-group-account'),
                  ),
                  guard(
                    GlassCard(
                      highlight: false,
                      child: Column(
                        children: [
                          for (final (i, row) in accountRows.indexed) ...[
                            if (i > 0) const _RowDivider(),
                            row,
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s6),
                  _SectionLabel(
                    l.settingsMode,
                    key: const Key('settings-group-mode'),
                  ),
                  const RoleModeCard(),
                  const SizedBox(height: AppSpace.s6),
                  _SectionLabel(
                    l.settingsAppearance,
                    key: const Key('settings-group-appearance'),
                  ),
                  guard(
                    SegmentedTabs<ThemeMode>(
                      key: const Key('settings-theme'),
                      options: [
                        SegmentOption(
                          value: ThemeMode.dark,
                          label: l.themeDark,
                        ),
                        SegmentOption(
                          value: ThemeMode.light,
                          label: l.themeLight,
                        ),
                        SegmentOption(
                          value: ThemeMode.system,
                          label: l.themeSystem,
                        ),
                      ],
                      value: mode,
                      onChanged: (v) =>
                          ref.read(themeModeProvider.notifier).set(v),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s6),
                  _SectionLabel(
                    l.settingsButtonStyle,
                    key: const Key('settings-group-buttonStyle'),
                  ),
                  guard(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedTabs<ButtonStyleMode>(
                          key: const Key('settings-button-style'),
                          options: [
                            SegmentOption(
                              value: ButtonStyleMode.gradient,
                              label: l.settingsButtonGradientShort,
                            ),
                            SegmentOption(
                              value: ButtonStyleMode.avatar,
                              label: l.buttonStyleAvatar,
                              enabled: hasAvatar,
                            ),
                          ],
                          value: buttonStyle,
                          onChanged: (v) =>
                              ref.read(buttonStyleProvider.notifier).set(v),
                        ),
                        if (!hasAvatar) ...[
                          const SizedBox(height: AppSpace.s2),
                          Text(
                            l.buttonStyleAvatarNeedsPhoto,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: AppSpace.s4),
                        Semantics(
                          label: l.settingsButtonPreview,
                          child: ExcludeSemantics(
                            child: AppButton.primary(
                              l.settingsButtonPreview,
                              size: AppButtonSize.small,
                              onPressed: () {},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.s6),
                  _SectionLabel(
                    l.notificationTitle,
                    key: const Key('settings-group-notifications'),
                  ),
                  guard(
                    GlassCard(
                      highlight: false,
                      child: _LinkTile(
                        key: const Key('settings-notifications'),
                        icon: AppIcons.notifications,
                        title: l.notificationTitle,
                        subtitle: l.settingsNotificationsBody,
                        path: '/settings/notifications',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s6),
                  _SectionLabel(
                    l.settingsPaymentsData,
                    key: const Key('settings-group-paymentsData'),
                  ),
                  guard(
                    GlassCard(
                      highlight: false,
                      child: _LinkTile(
                        key: const Key('settings-privacy'),
                        icon: AppIcons.privacy,
                        title: l.settingsPrivacy,
                        subtitle: isPhotographer
                            ? l.settingsPrivacyBody
                            : l.settingsPrivacyBodyCustomer,
                        path: '/settings/privacy',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s6),
                  _SectionLabel(
                    l.settingsSupportSection,
                    key: const Key('settings-group-support'),
                  ),
                  guard(
                    GlassCard(
                      highlight: false,
                      child: _LinkTile(
                        key: const Key('settings-help'),
                        icon: AppIcons.help,
                        title: l.settingsHelp,
                        subtitle: l.settingsHelpBody,
                        path: '/help',
                      ),
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: AppSpace.s6),
                    _SectionLabel(
                      l.settingsDeveloper,
                      key: const Key('settings-group-debug'),
                    ),
                    guard(
                      GlassCard(
                        highlight: false,
                        child: SwitchListTile(
                          key: const Key('show-screen-codes'),
                          secondary: const AppIcon(AppIcons.pin),
                          title: Text(l.settingsShowScreenCodes),
                          subtitle: Text(l.settingsShowScreenCodesBody),
                          value: showCodes,
                          onChanged: (v) =>
                              ref.read(showScreenCodesProvider.notifier).set(v),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpace.s6),
                  KeyedSubtree(
                    key: const Key('settings-group-signOut'),
                    child: guard(
                      Center(
                        child: TextButton(
                          key: const Key('settings-sign-out'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            minimumSize: const Size.fromHeight(36),
                          ),
                          onPressed: () => _confirmSignOut(context, ref),
                          child: Text(
                            l.signOut,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    await showConfirmSheet(
      context,
      title: l.signOut,
      body: l.settingsSignOutConfirmBody,
      confirmLabel: l.signOut,
      keepLabel: l.settingsSignOutKeep,
      danger: true,
      onConfirm: () async {
        // Drops this device's push token first, then signs out.
        await ref.read(pushRegistrationProvider).signOut();
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Mock: 10.5px uppercase, .08em tracking, --ink-3. Read in sentence case.
    return Padding(
      padding: const EdgeInsets.only(left: AppSpace.s1, bottom: AppSpace.s2),
      child: Semantics(
        header: true,
        label: text,
        child: ExcludeSemantics(
          child: Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: AppText.xs2,
              fontWeight: FontWeight.w500,
              letterSpacing: AppText.xs2 * 0.08,
              color: dark
                  ? AppColorsDark.foregroundMuted
                  : AppColors.foregroundMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Phone row: the last 4 digits, or "Chưa thêm". The contact stream is
/// autoDispose and S09.02 is a pushed route, so no listener outlives it.
class _PhoneTile extends ConsumerWidget {
  const _PhoneTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final phone = ref.watch(currentContactProvider).value?.phone ?? '';
    // Under 5 digits there is nothing safe to show beyond "added".
    final tail = phone.length > 4 ? phone.substring(phone.length - 4) : '';
    return ListTile(
      key: const Key('profile-phone'),
      leading: const AppIcon(AppIcons.phone),
      title: Text(l.settingsPhone),
      subtitle: Text(
        phone.isEmpty
            ? l.settingsPhoneEmpty
            : tail.isEmpty
            ? l.settingsPhoneAdded
            : l.settingsPhoneMasked(tail),
      ),
      trailing: const AppIcon(AppIcons.chevron),
      onTap: () => context.push('/profile/phone'),
    );
  }
}

/// "Hình thức nhận việc": Cá nhân, Cá nhân · Nhiếp ảnh gia, or Studio. Opens
/// [ProviderTypeSheet]; after a switch to Studio the address form (S08.05)
/// opens, since the profile has none yet.
class _ProviderTypeTile extends ConsumerWidget {
  const _ProviderTypeTile({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(liveProviderTypeProvider);
    final type = async.value;
    return ListTile(
      key: const Key('profile-provider-type'),
      leading: const AppIcon(AppIcons.work),
      title: Text(l.settingsProviderType),
      subtitle: type == null
          ? null
          : Text(switch (type) {
              ProviderType.individual => l.setupTypeIndividual,
              ProviderType.artist => l.settingsProviderArtist,
              ProviderType.studio => l.setupTypeStudio,
            }),
      trailing: const AppIcon(AppIcons.chevron),
      onTap: () async {
        if (type == null) {
          // Not loaded (or failed): this tap is the retry.
          ref.invalidate(photographerProfileProvider(uid));
          return;
        }
        // Refresh the stored profile too, so what follows reads fresh.
        ref.invalidate(photographerProfileProvider(uid));
        final next = await showProviderTypeSheet(context, current: type);
        if (next == ProviderType.studio &&
            type != ProviderType.studio &&
            context.mounted) {
          await context.push('/setup/4?from=settings');
        }
      },
    );
  }
}

/// Skills row with the server's completeness score (never computed here).
class _SkillsTile extends ConsumerWidget {
  const _SkillsTile({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final snapshot = ref.watch(photographerSkillsSnapshotProvider(uid)).value;
    return ListTile(
      key: const Key('profile-skills'),
      leading: const AppIcon(AppIcons.autoAwesome),
      title: Text(l.settingsSkills),
      subtitle: snapshot == null
          ? Text(l.settingsSkillsBody)
          : Padding(
              padding: const EdgeInsets.only(top: AppSpace.s1),
              child: CompletenessMeter(percent: snapshot.server.completeness),
            ),
      trailing: const AppIcon(AppIcons.chevron),
      onTap: () async {
        await context.push('/profile/skills');
        if (context.mounted) {
          ref.invalidate(photographerSkillsSnapshotProvider(uid));
        }
      },
    );
  }
}

/// A row that opens [path].
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String path;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: AppIcon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const AppIcon(AppIcons.chevron),
    onTap: () => context.push(path),
  );
}

/// "Xác minh & nhận đơn" (S21.02) with where the provider stands: the intro
/// line until they start (or while it loads), then Còn {n} bước, Đang chờ
/// duyệt, Đã xác minh, Chưa được duyệt or Đã thu hồi.
class _VerifyTile extends ConsumerWidget {
  const _VerifyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(myVerificationProvider).value;
    final subtitle = switch (s?.status) {
      null || VerificationStatus.notStarted => l.settingsVerifyBody,
      // All done but not sent yet: sending is the step left.
      VerificationStatus.inProgress => l.settingsVerifyStepsLeft(
        s!.stepsLeft == 0 ? 1 : s.stepsLeft,
      ),
      VerificationStatus.submitted => l.settingsVerifyPending,
      VerificationStatus.approved => l.settingsVerifyApproved,
      VerificationStatus.rejected => l.settingsVerifyRejected,
      VerificationStatus.revoked => l.settingsVerifyRevoked,
    };
    return _LinkTile(
      key: const Key('settings-verify'),
      icon: AppIcons.verified,
      title: l.settingsVerify,
      subtitle: subtitle,
      path: '/verify/start',
    );
  }
}

/// "Thành viên studio" (S26.01) with "{n}/{max} thợ" once both the relations
/// and the own intro (the max is 30 with a business record, else 3) have
/// loaded; until then #148's line, so the max never jumps from 3 to 30.
class _StudioMembersTile extends ConsumerWidget {
  const _StudioMembersTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final relations = ref.watch(myStudioRelationsProvider).value;
    final intro = ref.watch(myIntroProvider).value;
    return _LinkTile(
      key: const Key('settings-studio-members'),
      icon: AppIcons.people,
      title: l.settingsStudioMembers,
      subtitle: relations == null || intro == null
          ? l.settingsStudioMembersBody
          : l.settingsStudioMembersQuota(
              relations.activeCount,
              studioMaxMembers(businessVerified: intro.businessVerified),
            ),
      path: '/studio/members',
    );
  }
}

/// "Cộng tác" (S27.06) for an individual or artist: "{n} studio · {m} việc
/// chờ nhận" once both listeners load.
class _CollabMemberTile extends ConsumerWidget {
  const _CollabMemberTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final collabs = ref.watch(myCollaborationsProvider).value;
    final jobs = ref.watch(myCollabJobsProvider).value;
    final now = ref.watch(clockProvider)();
    return _LinkTile(
      key: const Key('settings-collab'),
      icon: AppIcons.handshake,
      title: l.settingsCollab,
      subtitle: collabs == null || jobs == null
          ? null
          : l.settingsCollabProviderMeta(
              collabs.where((c) => c.status == CollabStatus.active).length,
              liveOffers(jobs, now).length,
            ),
      path: '/collab',
    );
  }
}

/// "Cộng tác" (S27.06) for a studio: "{n} cộng tác viên".
class _CollabStudioTile extends ConsumerWidget {
  const _CollabStudioTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final collabs = ref.watch(studioCollaborationsProvider).value;
    return _LinkTile(
      key: const Key('settings-collab'),
      icon: AppIcons.handshake,
      title: l.settingsCollab,
      subtitle: collabs == null
          ? null
          : l.settingsCollabStudioMeta(
              collabs.where((c) => c.status == CollabStatus.active).length,
            ),
      path: '/collab',
    );
  }
}

/// "Tin tuyển" (S27.05) for a studio: "{n}/3 tin mở".
class _RecruitTile extends ConsumerWidget {
  const _RecruitTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final counters = ref.watch(myRecruitCountersProvider).value;
    return _LinkTile(
      key: const Key('settings-recruit'),
      icon: AppIcons.campaign,
      title: l.settingsRecruit,
      subtitle: counters == null
          ? null
          : l.settingsRecruitMeta(counters.openPostCount),
      path: '/studio/recruit',
    );
  }
}

/// "Studio của tôi" (S26.03) with the studio's name, or "Chưa ở studio nào"
/// once the relations load.
class _MyStudioTile extends ConsumerWidget {
  const _MyStudioTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final relations = ref.watch(myMemberRelationsProvider).value;
    final active = relations
        ?.where((r) => r.status == RelationStatus.active)
        .firstOrNull;
    return _LinkTile(
      key: const Key('settings-my-studio'),
      icon: AppIcons.people,
      title: l.settingsMyStudio,
      subtitle: relations == null
          ? l.settingsMyStudioBody
          : active == null
          ? l.settingsMyStudioNone
          // A studio without a display name keeps the row's own line.
          : active.studioName.isEmpty
          ? l.settingsMyStudioBody
          : active.studioName,
      path: '/me/studio',
    );
  }
}

/// "Xác minh doanh nghiệp" (S21.04): a studio whose owner is verified
/// (Decision 16).
class _BusinessTile extends StatelessWidget {
  const _BusinessTile();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _LinkTile(
      key: const Key('settings-verify-business'),
      icon: AppIcons.businessVerify,
      title: l.settingsBusiness,
      subtitle: l.settingsBusinessTodo,
      path: '/verify/business',
    );
  }
}

/// "Địa chỉ studio" (studios only): the public district, else "Chưa có địa
/// chỉ". Opens the S08.05 address form, which pops back here when done; the
/// profile is read again on return.
class _StudioAddressTile extends ConsumerWidget {
  const _StudioAddressTile({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(photographerProfileProvider(uid));
    final district = async.value?.summary.studioDistrict?.trim() ?? '';
    return ListTile(
      key: const Key('settings-studio-address'),
      leading: const AppIcon(AppIcons.place),
      title: Text(l.settingsStudioAddress),
      subtitle: district.isNotEmpty
          ? Text(district)
          : async.hasValue
          ? Text(l.settingsStudioAddressEmpty)
          : null,
      trailing: const AppIcon(AppIcons.chevron),
      onTap: () async {
        await context.push('/setup/4?from=settings');
        if (context.mounted) {
          ref.invalidate(photographerProfileProvider(uid));
        }
      },
    );
  }
}

/// Hairline between rows of one settings card (mock S09.02).
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    indent: AppSpace.s4,
    endIndent: AppSpace.s4,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}
