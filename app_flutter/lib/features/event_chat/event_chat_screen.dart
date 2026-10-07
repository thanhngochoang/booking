// lib/features/event_chat/event_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_chat.dart';
import 'package:photobooking/data/events/event_social_providers.dart';
import 'package:photobooking/features/event_chat/event_chat_controller.dart';
import 'package:photobooking/features/event_chat/members_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S11.06: the group chat of an event, for the people holding a paid ticket
/// and the organisers. Everyone else sees the locked screen.
class EventChatScreen extends ConsumerStatefulWidget {
  const EventChatScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends ConsumerState<EventChatScreen> {
  final _scroll = ScrollController();
  final List<ChatMessage> _older = [];
  bool _loadingOlder = false;
  bool _pinOpen = false;
  String? _markedFor;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 40 &&
        !_loadingOlder) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    final stream = ref.read(groupMessagesProvider(widget.eventId)).value ?? [];
    final all = [..._older, ...stream];
    if (all.isEmpty) {
      return;
    }
    all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    setState(() => _loadingOlder = true);
    try {
      final older = await ref
          .read(eventChatRepositoryProvider)
          .olderMessages(widget.eventId, before: all.first.createdAt);
      if (mounted && older.isNotEmpty) {
        setState(() => _older.insertAll(0, older));
      }
    } catch (_) {
      // Pulling again later retries; nothing to tell the person.
    } finally {
      if (mounted) {
        setState(() => _loadingOlder = false);
      }
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/e/${widget.eventId}');
    }
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  String _errorText(AppLocalizations l, ChatErrorCode code) => switch (code) {
    ChatErrorCode.limitExceeded => l.chatRateLimited,
    ChatErrorCode.notEligible => l.chatMutedNote,
    ChatErrorCode.permissionDenied => l.chatModOnly,
    _ => l.chatActionFailed,
  };

  Future<void> _messageMenu(
    ChatMessage m,
    PinnedMessage? pin,
    EventChatController ctl,
  ) async {
    final l = context.l10n;
    if (m.type == MessageType.system || m.deletedAt != null) {
      return;
    }
    final pinned = pin?.messageId == m.id;
    final choice = await showAppSheet<String>(
      context,
      builder: (sheet) => SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('msg-pin'),
                minTileHeight: 48,
                leading: const AppIcon(AppIcons.pushPin),
                title: Text(pinned ? l.chatUnpin : l.chatPin),
                onTap: () => Navigator.of(sheet).pop(pinned ? 'unpin' : 'pin'),
              ),
              ListTile(
                key: const Key('msg-delete'),
                minTileHeight: 48,
                leading: AppIcon(
                  AppIcons.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l.chatDelete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.of(sheet).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) {
      return;
    }
    if (choice == 'delete') {
      final yes = await showConfirmSheet(
        context,
        title: l.chatDelete,
        body: l.chatDeleted,
        confirmLabel: l.chatDelete,
        keepLabel: l.actionCancel,
      );
      if (!yes || !mounted) {
        return;
      }
    }
    final ok = await ctl.moderate(switch (choice) {
      'pin' => PinMessage(m.id),
      'unpin' => UnpinMessage(m.id),
      _ => DeleteMessage(m.id),
    });
    if (!ok && mounted) {
      _say(l.chatActionFailed);
    }
  }

  ChatBubbleContent _content(
    WidgetRef ref,
    ChatMessage m,
    AppLocalizations l, {
    required bool pending,
  }) {
    if (m.deletedAt != null) {
      return TextContent(l.chatDeleted);
    }
    switch (m.type) {
      case MessageType.text:
        return TextContent(m.body ?? '');
      case MessageType.image:
        if (pending) {
          return ImageContent('', localPath: m.imagePath);
        }
        final url = m.imagePath == null
            ? ''
            : ref.watch(groupImageUrlProvider(m.imagePath!)).value ?? '';
        return ImageContent(url);
      case MessageType.location:
        final p = m.point;
        return LocationContent(
          label: l.chatLocationOf(m.senderName ?? ''),
          mapUrl: p == null
              ? ''
              : 'https://www.google.com/maps?q=${p.lat},${p.lng}',
        );
      case MessageType.system:
        final name = m.system?.name ?? m.senderName ?? '';
        return SystemContent(
          m.system?.kind == 'member_joined'
              ? l.chatJoined(name)
              : (m.body ?? ''),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final id = widget.eventId;
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final chat = ref.watch(groupChatProvider(id));
    final me = ref.watch(groupMeProvider(id)).value;
    final ctl = ref.read(eventChatControllerProvider(id).notifier);
    ref.listen(eventChatControllerProvider(id).select((s) => s.errorSeq), (
      _,
      _,
    ) {
      final code = ref.read(eventChatControllerProvider(id)).errorCode;
      if (code != null) {
        _say(_errorText(l, code));
      }
    });

    return ScreenCode(
      ScreenCodes.eventChat,
      child: AsyncView<GroupChatThread?>(
        value: chat,
        onRetry: () => ref.invalidate(groupChatProvider(id)),
        skeleton: (_) => _frame(
          title: '',
          body: Column(
            children: [
              for (var i = 0; i < 6; i++) ChatBubble.skeleton(mine: i.isOdd),
            ],
          ),
        ),
        data: (context, thread) {
          if (thread == null || (me?.removed ?? false)) {
            return _locked();
          }
          return _chatBody(context, thread, me, uid, ctl);
        },
      ),
    );
  }

  Widget _frame({
    required String title,
    String? subtitle,
    required Widget body,
    List<Widget>? actions,
  }) {
    final l = context.l10n;
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            key: const Key('chat-back'),
            tooltip: l.back,
            icon: const AppIcon(AppIcons.back),
            onPressed: _back,
          ),
          title: subtitle == null
              ? Text(title)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      subtitle,
                      key: const Key('chat-members-count'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
          actions: actions,
        ),
        body: body,
      ),
    );
  }

  /// Not a member (or removed): the chat opens with a paid ticket.
  Widget _locked() {
    final l = context.l10n;
    return _frame(
      title: '',
      body: Center(
        key: const Key('chat-locked'),
        child: EmptyState(
          title: l.eventChatLocked,
          body: l.eventChatLockedBody,
          illustration: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              shape: BoxShape.circle,
            ),
            child: const AppIcon(AppIcons.lock, size: AppIconSize.lg),
          ),
          actionLabel: l.chatLockedAction,
          onAction: () => context.go('/e/${widget.eventId}'),
        ),
      ),
    );
  }

  Widget _chatBody(
    BuildContext context,
    GroupChatThread thread,
    GroupMemberState? me,
    String uid,
    EventChatController ctl,
  ) {
    final l = context.l10n;
    final id = widget.eventId;
    final now = ref.watch(clockProvider)();
    final moderator =
        me?.role == GroupRole.moderator || thread.moderators.contains(uid);
    final pin = ref.watch(groupPinProvider(id)).value;
    final messages = ref.watch(groupMessagesProvider(id));
    final state = ref.watch(eventChatControllerProvider(id));
    final localMute = ref.watch(groupMuteProvider(id));

    final stream = messages.value ?? const <ChatMessage>[];
    ctl.syncWithStream(stream);
    final last = stream.isEmpty ? null : stream.last.id;
    if (last != null && last != _markedFor) {
      _markedFor = last;
      Future.microtask(
        () => ref.read(eventChatRepositoryProvider).markRead(id),
      );
    }

    final pendingIds = {for (final m in state.pending) m.id};
    final merged = <String, ChatMessage>{
      for (final m in _older) m.id: m,
      for (final m in stream) m.id: m,
      for (final m in state.pending) m.id: m,
    };
    final ordered = merged.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final newestFirst = ordered.reversed.toList();

    final closed = thread.isReadOnlyAt(now);
    final muted = me?.isMutedAt(now) ?? false;
    final modOnly = thread.moderatorsOnly && !moderator;
    final String? reason = muted
        ? l.chatMutedNote
        : modOnly
        ? l.chatModOnly
        : null;

    return _frame(
      title: thread.title,
      subtitle: l.chatMembers(thread.memberCount),
      actions: [
        if (localMute)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.s1),
            child: AppIcon(AppIcons.notificationsOff, size: 18),
          ),
        PopupMenuButton<String>(
          key: const Key('chat-more'),
          tooltip: l.chatMemberList,
          icon: const AppIcon(AppIcons.more),
          onSelected: (v) async {
            switch (v) {
              case 'members':
                await showMembersSheet(
                  context,
                  eventId: id,
                  myUid: uid,
                  moderator: moderator,
                );
              case 'mute':
                await ref.read(groupMuteProvider(id).notifier).toggle();
              case 'modonly':
                final ok = await ctl.moderate(
                  SetModeratorsOnly(on: !thread.moderatorsOnly),
                );
                if (!ok && mounted) {
                  _say(l.chatActionFailed);
                }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'members', child: Text(l.chatMemberList)),
            PopupMenuItem(
              value: 'mute',
              child: Text(localMute ? l.chatUnmuteGroup : l.chatMuteGroup),
            ),
            if (moderator)
              CheckedPopupMenuItem(
                value: 'modonly',
                checked: thread.moderatorsOnly,
                child: Text(l.chatModOnly),
              ),
          ],
        ),
      ],
      body: SafeArea(
        child: Column(
          children: [
            if (pin != null)
              _PinCard(
                pin: pin,
                open: _pinOpen,
                onTap: () => setState(() => _pinOpen = !_pinOpen),
              ),
            Expanded(
              child: AsyncView<List<ChatMessage>>(
                value: messages,
                onRetry: () => ref.invalidate(groupMessagesProvider(id)),
                skeleton: (_) => Column(
                  children: [
                    for (var i = 0; i < 6; i++)
                      ChatBubble.skeleton(mine: i.isOdd),
                  ],
                ),
                data: (context, _) => ListView.builder(
                  key: const Key('chat-list'),
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s3,
                    vertical: AppSpace.s2,
                  ),
                  itemCount: newestFirst.length + (_loadingOlder ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == newestFirst.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpace.s2),
                          child: SignatureLoader(size: LoaderSize.inline),
                        ),
                      );
                    }
                    final m = newestFirst[i];
                    final mine = m.senderId == uid;
                    final isPending =
                        pendingIds.contains(m.id) &&
                        !stream.any((s) => s.id == m.id);
                    final bubble = Consumer(
                      key: Key('msg-${m.id}'),
                      builder: (context, ref, _) => ChatBubble(
                        content: _content(ref, m, l, pending: isPending),
                        mine: mine,
                        state: switch (m.sendState) {
                          MessageSendState.sending => BubbleSendState.sending,
                          MessageSendState.failed => BubbleSendState.failed,
                          MessageSendState.sent => BubbleSendState.sent,
                        },
                        senderName: mine || m.type == MessageType.system
                            ? null
                            : m.senderName,
                        onRetry: () => ctl.retry(m),
                      ),
                    );
                    if (!moderator || m.type == MessageType.system) {
                      return bubble;
                    }
                    return Semantics(
                      onLongPress: () => _messageMenu(m, pin, ctl),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onLongPress: () => _messageMenu(m, pin, ctl),
                        child: bubble,
                      ),
                    );
                  },
                ),
              ),
            ),
            if (closed)
              Container(
                key: const Key('chat-closed'),
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.s3),
                child: Text(
                  l.eventChatClosed,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ChatComposer(
                enabled: reason == null,
                disabledReason: reason,
                hint: l.eventChatInput,
                busy: state.uploading,
                onSend: ctl.sendText,
                onPickImage: ctl.pickAndSendImage,
              ),
          ],
        ),
      ),
    );
  }
}

/// "Ghim · {name}" and the pinned text; a tap shows all of it.
class _PinCard extends StatelessWidget {
  const _PinCard({required this.pin, required this.open, required this.onTap});

  final PinnedMessage pin;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s3,
        AppSpace.s1,
        AppSpace.s3,
        AppSpace.s1,
      ),
      child: Semantics(
        button: true,
        expanded: open,
        label: '${l.chatPinned} · ${pin.senderName}: ${pin.body}',
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          key: const Key('chat-pin'),
          color: dark ? AppColorsDark.glass : AppColors.glass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppIcon(AppIcons.pushPin, size: 18),
                    const SizedBox(width: AppSpace.s2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${l.chatPinned} · ${pin.senderName}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            pin.body,
                            maxLines: open ? null : 2,
                            overflow: open ? null : TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
