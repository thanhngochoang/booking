import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/chat/chat_bubble_mapping.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String formatChatTime(DateTime? time, DateTime now) {
  if (time == null) return '';
  final local = time.toLocal();
  final localNow = now.toLocal();
  final sameDay = local.year == localNow.year &&
      local.month == localNow.month &&
      local.day == localNow.day;
  if (sameDay) {
    return '${_two(local.hour)}:${_two(local.minute)}';
  }
  final diff = localNow.difference(local);
  if (diff.inDays < 7 && local.weekday != localNow.weekday) {
    return weekdayLabel(local.weekday);
  }
  return formatDayMonth(local);
}

/// S07.02 Chat list screen.
///
/// Shows all conversations (inquiries and bookings) newest first.
/// Counterpart profile loading shows ConversationRow.skeleton in the slot.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chatsAsync = ref.watch(myChatsProvider);
    final currentUserId = ref.watch(authStateProvider).value?.uid;
    final role = ref.watch(currentProfileProvider).value?.role;
    final isCustomer = role == UserRole.customer;
    final now = ref.watch(clockProvider)();

    return ScreenCode(
      ScreenCodes.chats,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l10n.chatsTitle),
        ),
        body: AsyncView<List<ChatListItem>>(
          value: chatsAsync,
          skeleton: (_) => Column(
            children: [
              for (var i = 0; i < 6; i++) ConversationRow.skeleton(),
            ],
          ),
          onRetry: () => ref.refresh(myChatsProvider),
          isEmpty: (items) => items.isEmpty,
          empty: (_) => EmptyState(
            title: l10n.chatsEmptyTitle,
            body: '',
            actionLabel: isCustomer ? l10n.chatsEmptyAction : null,
            onAction: isCustomer ? () => context.go('/action') : null,
          ),
          data: (context, items) => ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _ChatRow(
                key: ValueKey(item.thread.id),
                item: item,
                currentUserId: currentUserId,
                now: now,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChatRow extends ConsumerWidget {
  const _ChatRow({
    super.key,
    required this.item,
    required this.currentUserId,
    required this.now,
  });

  final ChatListItem item;
  final String? currentUserId;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thread = item.thread;
    final counterpartId = thread.counterpartIdOf(currentUserId ?? '');
    final profileAsync = ref.watch(partyProfileProvider(counterpartId));

    if (profileAsync.isLoading && !profileAsync.hasValue) {
      return ConversationRow.skeleton();
    }

    final l10n = context.l10n;
    final profile = profileAsync.value;
    // A collab chat (S27) has a studio in the customer slot: no role name.
    final counterpartName = profile?.displayName ??
        (thread.kind == ChatKind.collab
            ? l10n.chatKindCollab
            : currentUserId == thread.customerId
            ? l10n.profileRolePhotographer
            : l10n.profileRoleCustomer);
    final avatarUrl = profile?.avatarUrl;
    final status = thread.bookingStatusValue;
    final lastText = thread.lastMessagePreview ?? '';
    final String preview;
    if (thread.isClosedInquiryAt(now)) {
      preview = l10n.chatClosed;
    } else if (lastText.isEmpty) {
      // A status message has no preview text: show its sentence. upcoming,
      // shooting (S30) and reviewed post no message of their own, so the
      // last posted one stays.
      final posted = switch (status) {
        BookingStatus.upcoming || BookingStatus.shooting =>
          BookingStatus.accepted,
        BookingStatus.reviewed => BookingStatus.completed,
        _ => status,
      };
      // A revived inquiry has no status: name the kind of chat instead of a
      // blank line.
      preview = posted != null
          ? bookingStatusSentence(posted, l10n) ?? ''
          : thread.kind == ChatKind.inquiry
          ? l10n.contactInquiry
          : '';
    } else if (currentUserId != null && thread.lastSenderId == currentUserId) {
      preview = l10n.chatsYouPrefix(lastText);
    } else {
      preview = lastText;
    }
    final timeLabel = formatChatTime(thread.lastMessageAt, now);

    return ConversationRow(
      name: counterpartName,
      avatarUrl: avatarUrl,
      preview: preview,
      timeLabel: timeLabel,
      unread: item.unreadCount,
      badge: thread.kind == ChatKind.collab
          ? _CollabTag(l10n.chatKindCollab)
          : status == null
          ? null
          : StatusBadge(status),
      onTap: () => context.push('/chat/${thread.id}'),
    );
  }
}

/// "Cộng tác" on a studio–collaborator chat row (S27 Decision 16), where a
/// booking chat shows its status.
class _CollabTag extends StatelessWidget {
  const _CollabTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return StatusBadge.custom(
      label: label,
      color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
      onColor: dark
          ? AppColorsDark.foregroundSecondary
          : AppColors.foregroundSecondary,
    );
  }
}
