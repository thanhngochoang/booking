// lib/features/photographer_profile/widgets/studio_members_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';
import 'package:photobooking/features/studio/studio_errors.dart';

/// S03.01-studio "Thành viên": the header with the outline "Xin gia nhập"
/// (only for an independent photographer, Decision 5) and the [MemberStrip]
/// of the first members by join date (Decision 2), each opening their
/// profile. Hidden for a studio with no members that the viewer cannot ask
/// to join.
class StudioMembersSection extends ConsumerWidget {
  const StudioMembersSection({super.key, required this.studio});

  final PhotographerSummary studio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final join = _joinState(ref, studio.id);
    if (studio.memberCount == 0 && join == _Join.hidden) {
      return const SizedBox.shrink();
    }
    final members = ref.watch(studioMembersProvider(studio.id));
    return Padding(
      key: const Key('profile-members'),
      padding: const EdgeInsets.only(top: AppSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.profileMembersTitle,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (join != _Join.hidden)
                _JoinButton(studio: studio, requested: join == _Join.requested),
            ],
          ),
          if (studio.memberCount > 0) ...[
            const SizedBox(height: AppSpace.s2),
            AsyncView<List<PhotographerSummary>>(
              value: members,
              skeleton: (_) => MemberStrip.skeleton(),
              onRetry: () => ref.invalidate(studioMembersProvider(studio.id)),
              data: (context, list) => MemberStrip(
                key: const Key('profile-member-strip'),
                label: l.profileMembersA11y(studio.displayName),
                total: studio.memberCount < list.length
                    ? list.length
                    : studio.memberCount,
                members: [
                  for (final m in list)
                    MemberStripItem(
                      id: m.id,
                      name: m.displayName,
                      avatarUrl: m.avatarUrl,
                      tomatoPct: m.hasTomatoPct ? m.tomatoPct : null,
                    ),
                ],
                onTap: (uid) => context.push('/u/$uid'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _Join { hidden, can, requested }

/// Whether the signed-in user may ask [studioId] to take them: an onboarded
/// individual or NAG photographer in no studio (Decision 5). Hidden while
/// their intro or relations load, so no request goes out on a guess.
_Join _joinState(WidgetRef ref, String studioId) {
  final me = ref.watch(authStateProvider).value?.uid;
  if (me == null || me == studioId) return _Join.hidden;
  final intro = ref.watch(myIntroProvider).value;
  if (intro == null ||
      !intro.onboardingComplete ||
      intro.providerType == ProviderType.studio ||
      intro.studioId != null) {
    return _Join.hidden;
  }
  final relations = ref.watch(myMemberRelationsProvider).value;
  if (relations == null) return _Join.hidden;
  if (relations.any((r) => r.status == RelationStatus.active)) {
    return _Join.hidden;
  }
  final asked = relations.any(
    (r) => r.studioId == studioId && r.status == RelationStatus.requested,
  );
  return asked ? _Join.requested : _Join.can;
}

/// Outline "Xin gia nhập" (a member daily action); once sent it reads
/// "Đã xin gia nhập", disabled, until S26.03 cancels it.
class _JoinButton extends ConsumerStatefulWidget {
  const _JoinButton({required this.studio, required this.requested});

  final PhotographerSummary studio;
  final bool requested;

  @override
  ConsumerState<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends ConsumerState<_JoinButton> {
  bool _sending = false;

  /// Sent here; the relation stream says so a moment later.
  bool _sent = false;

  Future<void> _join() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final cooldown = ref.read(myIntroProvider).value?.studioCooldownUntil;
    setState(() => _sending = true);
    String? text;
    try {
      await ref.read(studioRepositoryProvider).requestToJoin(widget.studio.id);
      _sent = true;
      text = l.profileJoinSent(widget.studio.displayName);
    } on StudioError catch (e) {
      text = e.code == 'cooldown' && cooldown != null
          ? l.profileJoinCooldown(formatDayMonth(toVn(cooldown)))
          : mounted
          ? studioErrorText(context, e.code)
          : null;
    } catch (e) {
      text = mounted ? studioFailureText(context, e) : null;
    }
    if (mounted) setState(() => _sending = false);
    if (text != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final requested = widget.requested || _sent;
    return AppButton.outline(
      requested ? l.profileJoinRequested : l.profileJoinStudio,
      key: const Key('profile-join-studio'),
      size: AppButtonSize.xsmall,
      loading: _sending,
      onPressed: requested || _sending ? null : _join,
    );
  }
}

/// S03.01-member: "Thành viên của {Studio}" under a member's name (from the
/// public `photographers.studioId`), opening the studio's profile. Nothing
/// while the studio's name loads, fails or is empty.
class MemberOfTag extends ConsumerWidget {
  const MemberOfTag({super.key, required this.studioId});

  final String studioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(profileStudioNameProvider(studioId));
    return AsyncView<String>(
      value: name,
      skeleton: (_) => AppSkeleton.line(width: 140),
      error: (_, _, _) => const SizedBox.shrink(),
      data: (context, studio) =>
          studio.isEmpty ? const SizedBox.shrink() : _tag(context, studio),
    );
  }

  Widget _tag(BuildContext context, String studio) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final label = context.l10n.profileMemberOf(studio);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        link: true,
        label: label,
        excludeSemantics: true,
        onTap: () => context.push('/u/$studioId'),
        child: InkWell(
          key: const Key('profile-member-of'),
          onTap: () => context.push('/u/$studioId'),
          borderRadius: BorderRadius.circular(AppRadius.full),
          // The pill is small; the tap area reaches 48dp high.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.s12),
            child: Align(
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  // Mock `.ptag`: 2px 8px 2px 6px, 11px icon, 10px text.
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s1 * 1.5,
                    AppSpace.s1 / 2,
                    AppSpace.s2,
                    AppSpace.s1 / 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        AppIcons.work,
                        size: AppText.xs2,
                        color: secondary,
                      ),
                      const SizedBox(width: AppSpace.s1),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppText.xs,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
