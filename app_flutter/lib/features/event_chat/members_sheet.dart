// lib/features/event_chat/members_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_chat.dart';
import 'package:photobooking/data/events/event_social_providers.dart';
import 'package:photobooking/features/event_chat/event_chat_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// "Thành viên": names and avatars of everyone in the group chat (never a
/// phone). Moderators can mute a member for 24 hours or remove them, and see
/// the people they removed under "Đã mời ra" with "Cho vào lại" (O1/M8).
Future<void> showMembersSheet(
  BuildContext context, {
  required String eventId,
  required String myUid,
  required bool moderator,
}) => showAppSheet<void>(
  context,
  builder: (_) => ScreenCode(
    ScreenCodes.eventChat,
    label: 'members',
    child: MembersSheet(eventId: eventId, myUid: myUid, moderator: moderator),
  ),
);

enum _MemberAction { mute, unmute, remove, restore }

class MembersSheet extends ConsumerWidget {
  const MembersSheet({
    super.key,
    required this.eventId,
    required this.myUid,
    required this.moderator,
  });

  final String eventId;
  final String myUid;
  final bool moderator;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    GroupMember m,
    _MemberAction action,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ctl = ref.read(eventChatControllerProvider(eventId).notifier);
    ChatModeration? moderation;
    switch (action) {
      case _MemberAction.mute:
        moderation = MuteMember(m.uid);
      case _MemberAction.unmute:
        moderation = UnmuteMember(m.uid);
      case _MemberAction.remove:
        final yes = await showConfirmSheet(
          context,
          title: l.chatRemoveTitle(m.name),
          confirmLabel: l.chatRemove,
          keepLabel: l.actionCancel,
        );
        if (!yes) {
          return;
        }
        moderation = RemoveMember(m.uid);
      case _MemberAction.restore:
        moderation = RestoreMember(m.uid);
    }
    final ok = await ctl.moderate(moderation);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.chatActionFailed)));
    }
  }

  Widget _memberTile(
    BuildContext context,
    WidgetRef ref,
    GroupMember m,
    DateTime now,
    AppLocalizations l,
  ) {
    final muted = m.isMutedAt(now);
    final isMod = m.role == GroupRole.moderator;
    final canAct = moderator && !isMod && m.uid != myUid;
    return ListTile(
      key: Key('member-${m.uid}'),
      minTileHeight: AppSpace.s12 + AppSpace.s2,
      leading: AppAvatar(
        url: m.avatarUrl,
        name: m.name,
        size: AppAvatarSize.sm,
        decorative: true,
      ),
      title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: isMod
          ? Text(l.chatMemberModerator)
          : muted
          ? Text(l.chatMemberMuted)
          : null,
      trailing: canAct
          ? PopupMenuButton<_MemberAction>(
              key: Key('member-menu-${m.uid}'),
              tooltip: l.chatMemberList,
              icon: const AppIcon(AppIcons.more),
              onSelected: (a) => _act(context, ref, m, a),
              itemBuilder: (_) => [
                if (muted)
                  PopupMenuItem(
                    value: _MemberAction.unmute,
                    child: Text(l.chatUnmute),
                  )
                else
                  PopupMenuItem(
                    value: _MemberAction.mute,
                    child: Text(l.chatMute24h),
                  ),
                PopupMenuItem(
                  value: _MemberAction.remove,
                  child: Text(l.chatRemove),
                ),
              ],
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final members = ref.watch(groupMembersProvider(eventId));
    final now = ref.watch(clockProvider)();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s2,
                AppSpace.s4,
                AppSpace.s2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l.chatMemberList,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            Flexible(
              child: Material(
                type: MaterialType.transparency,
                child: AsyncView<List<GroupMember>>(
                  value: members,
                  loaderSize: LoaderSize.inline,
                  onRetry: () => ref.invalidate(groupMembersProvider(eventId)),
                  data: (context, all) {
                    final list = [
                      for (final m in all)
                        if (!m.removedByModerator) m,
                    ];
                    final removed = moderator
                        ? [
                            for (final m in all)
                              if (m.removedByModerator) m,
                          ]
                        : const <GroupMember>[];
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        for (final m in list)
                          _memberTile(context, ref, m, now, l),
                        if (removed.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpace.s4,
                              AppSpace.s4,
                              AppSpace.s4,
                              AppSpace.s1,
                            ),
                            child: Semantics(
                              header: true,
                              child: Text(
                                l.chatRemovedSection,
                                key: const Key('members-removed'),
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s4,
                            ),
                            child: Text(
                              l.chatRestoreHint,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          for (final m in removed)
                            ListTile(
                              key: Key('removed-${m.uid}'),
                              minTileHeight: AppSpace.s12 + AppSpace.s2,
                              leading: AppAvatar(
                                url: m.avatarUrl,
                                name: m.name,
                                size: AppAvatarSize.sm,
                                decorative: true,
                              ),
                              title: Text(
                                m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: TextButton(
                                key: Key('restore-${m.uid}'),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(
                                    AppSpace.s12,
                                    AppSpace.s12,
                                  ),
                                ),
                                onPressed: () => _act(
                                  context,
                                  ref,
                                  m,
                                  _MemberAction.restore,
                                ),
                                child: Text(l.chatRestore),
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
