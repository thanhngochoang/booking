import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_providers.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/chat/chat_bubble_mapping.dart';
import 'package:photobooking/features/chat/chat_controller.dart';
import 'package:photobooking/features/chat/widgets/context_card.dart';
import 'package:photobooking/features/chat/widgets/quick_actions.dart';
import 'package:photobooking/features/chat/widgets/reschedule_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    this.serviceId,
    this.initialReschedule = false,
  });

  final String chatId;
  final String? serviceId;
  final bool initialReschedule;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _openedReschedule = false;
  bool _isLoadingOlder = false;
  final List<ChatMessage> _olderMessages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRepositoryProvider).markRead(widget.chatId);
      if (widget.initialReschedule && !_openedReschedule) {
        _openedReschedule = true;
        _handleOpenReschedule();
      }
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 40 &&
        !_isLoadingOlder) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    final streamMsgs =
        ref.read(chatMessagesProvider(widget.chatId)).value ?? [];
    final all = [..._olderMessages, ...streamMsgs];
    if (all.isEmpty) return;

    all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final oldest = all.first.createdAt;

    setState(() => _isLoadingOlder = true);
    try {
      final older = await ref
          .read(chatRepositoryProvider)
          .olderMessages(widget.chatId, before: oldest);
      if (mounted && older.isNotEmpty) {
        setState(() {
          _olderMessages.insertAll(0, older);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingOlder = false);
      }
    }
  }

  Future<void> _handleOpenReschedule() async {
    final thread = ref.read(chatThreadProvider(widget.chatId)).value;
    if (thread == null || thread.bookingId == null) return;
    final booking = ref.read(bookingProvider(thread.bookingId!)).value;
    if (booking == null) return;

    final res = await showRescheduleSheet(
      context,
      photographerId: thread.photographerId,
      booking: booking,
    );

    if (res != null && mounted) {
      final controller = ref.read(
        chatControllerProvider(widget.chatId).notifier,
      );
      await controller.proposeReschedule(
        bookingId: booking.id,
        day: res.day,
        start: res.start,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentUserId = ref.watch(authStateProvider).value?.uid ?? '';
    final threadAsync = ref.watch(chatThreadProvider(widget.chatId));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final controllerState = ref.watch(chatControllerProvider(widget.chatId));
    final controller = ref.watch(
      chatControllerProvider(widget.chatId).notifier,
    );
    final bookingFeatures = ref.watch(bookingFeaturesProvider);
    final now = ref.watch(clockProvider)();

    ref.listen(chatControllerProvider(widget.chatId), (prev, next) {
      final code = next.errorCode;
      if (code == null || next.errorSeq == prev?.errorSeq) return;
      _showError(code);
    });

    return ScreenCode(
      ScreenCodes.chat,
      child: Scaffold(
        appBar: _buildAppBar(context, threadAsync.value, currentUserId, l10n),
        body: AsyncView<ChatThread?>(
          value: threadAsync,
          skeleton: (_) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3,
                  vertical: AppSpace.s2,
                ),
                child: BookingCard.skeleton(size: BookingCardSize.compact),
              ),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < 6; i++)
                      ChatBubble.skeleton(mine: i.isOdd),
                  ],
                ),
              ),
            ],
          ),
          data: (context, thread) {
            if (thread == null) {
              return Center(child: Text(l10n.chatNotFound));
            }

            // Sync controller with stream messages
            messagesAsync.whenData((msgs) {
              controller.syncWithStream(msgs);
              ref.read(chatRepositoryProvider).markRead(widget.chatId);
            });

            final bookingAsync = thread.bookingId != null
                ? ref.watch(bookingProvider(thread.bookingId!))
                : const AsyncValue<Booking?>.data(null);
            final booking = bookingAsync.value;

            // Merge stream messages, older loaded messages, and local pending messages
            final streamMsgs = messagesAsync.value ?? [];
            final combinedMap = <String, ChatMessage>{};
            for (final m in _olderMessages) {
              combinedMap[m.id] = m;
            }
            for (final m in streamMsgs) {
              combinedMap[m.id] = m;
            }
            for (final m in controllerState.pendingMessages) {
              combinedMap[m.id] = m;
            }

            final allMessages = combinedMap.values.toList();
            // Sort ascending by createdAt
            allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

            // Reverse for reverse ListView: newest is at index 0 (bottom)
            final reversedMessages = allMessages.reversed.toList();

            final counterpartId = currentUserId == thread.customerId
                ? thread.photographerId
                : thread.customerId;
            final counterpartProfile = ref
                .watch(partyProfileProvider(counterpartId))
                .value;
            final counterpartName =
                counterpartProfile?.displayName ??
                (currentUserId == thread.customerId
                    ? l10n.profileRolePhotographer
                    : l10n.profileRoleCustomer);

            // Has pending proposal?
            final hasPendingProposal = allMessages.any(
              (m) =>
                  m.system?.kind == 'reschedule_proposal' &&
                  m.system?.answer == null,
            );

            // Read only?
            final isReadOnly =
                thread.readOnlyAt != null && now.isAfter(thread.readOnlyAt!);

            // Closed inquiry?
            final isClosedInquiry = thread.isClosedInquiryAt(now);

            // Inquiry 3-message limit reached?
            final isCustomer = currentUserId == thread.customerId;
            final inquiryLimitReached =
                thread.kind == ChatKind.inquiry &&
                isCustomer &&
                thread.photographerRepliedAt == null &&
                thread.customerMessagesBeforeReply >= 3;

            String? disabledReason;
            if (inquiryLimitReached) {
              disabledReason = l10n.chatInquiryCap(counterpartName);
            }

            return SafeArea(
              child: Column(
                children: [
                  ChatContextCard(thread: thread, serviceId: widget.serviceId),
                  QuickActionsRow(
                    thread: thread,
                    booking: booking,
                    rescheduleEnabled: bookingFeatures.reschedule,
                    hasPendingProposal: hasPendingProposal,
                    onSendLocation: () async {
                      final sent = await controller.sendLocation();
                      if (!sent && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.chatLocationDenied)),
                        );
                      }
                    },
                    onSendRefImage: () => controller.pickAndSendImage(),
                    onReschedule: () => _handleOpenReschedule(),
                    onConfirmPlace: (place) {
                      controller.sendText(l10n.chatConfirmPlaceText(place));
                    },
                  ),
                  Expanded(
                    child: AsyncView<List<ChatMessage>>(
                      value: messagesAsync,
                      skeleton: (_) => Column(
                        children: [
                          for (var i = 0; i < 6; i++)
                            ChatBubble.skeleton(mine: i.isOdd),
                        ],
                      ),
                      data: (context, _) {
                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s3,
                            vertical: AppSpace.s2,
                          ),
                          itemCount:
                              reversedMessages.length +
                              (_isLoadingOlder ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isLoadingOlder &&
                                index == reversedMessages.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(AppSpace.s2),
                                  child: SignatureLoader(
                                    size: LoaderSize.inline,
                                  ),
                                ),
                              );
                            }

                            final msg = reversedMessages[index];
                            final isMine = msg.senderId == currentUserId;
                            final senderName = isMine
                                ? (ref
                                          .watch(authStateProvider)
                                          .value
                                          ?.displayName ??
                                      l10n.chatMe)
                                : counterpartName;

                            final systemActions = _buildSystemActions(
                              context,
                              msg,
                              currentUserId,
                              thread,
                              controller,
                              l10n,
                            );

                            // A photo of mine sent from this screen keeps its
                            // local file, so it does not flash empty while the
                            // download URL resolves; any other photo shows its
                            // resolved URL (the stored value is only a path).
                            final isImage = msg.type == MessageType.image;
                            final localPath = !isImage
                                ? null
                                : msg.sendState != MessageSendState.sent
                                ? msg.imagePath
                                : controller.localFileFor(msg.id);
                            final imageUrl =
                                isImage &&
                                    localPath == null &&
                                    msg.imagePath != null
                                ? ref
                                      .watch(
                                        chatImageUrlProvider(msg.imagePath!),
                                      )
                                      .value
                                : null;

                            final content = bubbleContentOf(
                              msg,
                              imageUrl: imageUrl,
                              localPath: localPath,
                              l: l10n,
                              senderName: senderName,
                              systemActions: systemActions,
                            );

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpace.s1,
                              ),
                              child: ChatBubble(
                                content: content,
                                mine: isMine,
                                state: sendStateOf(msg.sendState),
                                senderName: isMine ? null : senderName,
                                onRetry: () => controller.retryMessage(msg),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (isReadOnly)
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.s3),
                      child: Text(
                        l10n.chatReadOnly,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else ...[
                    if (isClosedInquiry)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s3,
                          vertical: AppSpace.s1,
                        ),
                        child: Text(
                          l10n.chatClosed,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ChatComposer(
                      enabled: disabledReason == null,
                      disabledReason: disabledReason,
                      busy: controllerState.isUploadingImage,
                      onSend: (text) => controller.sendText(text),
                      onPickImage: () => controller.pickAndSendImage(),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ChatThread? thread,
    String currentUserId,
    AppLocalizations l10n,
  ) {
    if (thread == null) {
      return AppBar();
    }

    final counterpartId = currentUserId == thread.customerId
        ? thread.photographerId
        : thread.customerId;
    final counterpartProfile = ref
        .watch(partyProfileProvider(counterpartId))
        .value;
    final counterpartName =
        counterpartProfile?.displayName ??
        (currentUserId == thread.customerId
            ? l10n.profileRolePhotographer
            : l10n.profileRoleCustomer);
    final avatarUrl = counterpartProfile?.avatarUrl;
    final canViewProfile =
        thread.kind == ChatKind.inquiry && currentUserId == thread.customerId;
    final hasMenu = thread.bookingId != null || canViewProfile;

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(
            url: avatarUrl,
            name: counterpartName,
            size: AppAvatarSize.xs,
          ),
          const SizedBox(width: AppSpace.s2),
          Flexible(
            child: Text(counterpartName, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      actions: [
        if (hasMenu)
          PopupMenuButton<String>(
            key: const Key('chat-more'),
            tooltip: l10n.photoMoreOptions,
            icon: const AppIcon(AppIcons.more),
            onSelected: (val) {
              switch (val) {
                case 'view_booking':
                  context.push('/b/${thread.bookingId}');
                case 'view_profile':
                  context.push('/u/${thread.photographerId}');
              }
            },
            itemBuilder: (_) => [
              if (thread.bookingId != null)
                PopupMenuItem(
                  value: 'view_booking',
                  child: Text(l10n.chatViewBooking),
                ),
              if (canViewProfile)
                PopupMenuItem(
                  value: 'view_profile',
                  child: Text(l10n.chatViewProfile),
                ),
            ],
          ),
      ],
    );
  }

  /// The snackbar for a refusal reported by the controller.
  void _showError(ChatErrorCode code) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final thread = ref.read(chatThreadProvider(widget.chatId)).value;
    final now = ref.read(clockProvider)();
    final message = switch (code) {
      ChatErrorCode.notEligible
          when thread != null && thread.isClosedInquiryAt(now) =>
        l10n.chatInquiriesOff,
      ChatErrorCode.limitExceeded when thread != null => l10n.chatInquiryCap(
        _counterpartName(thread, l10n),
      ),
      _ => l10n.chatActionFailed,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _counterpartName(ChatThread thread, AppLocalizations l10n) {
    final uid = ref.read(authStateProvider).value?.uid ?? '';
    final isCustomer = uid == thread.customerId;
    final id = isCustomer ? thread.photographerId : thread.customerId;
    return ref.read(partyProfileProvider(id)).value?.displayName ??
        (isCustomer ? l10n.profileRolePhotographer : l10n.profileRoleCustomer);
  }

  List<Widget> _buildSystemActions(
    BuildContext context,
    ChatMessage msg,
    String currentUserId,
    ChatThread thread,
    ChatController controller,
    AppLocalizations l10n,
  ) {
    final sys = msg.system;
    if (sys == null ||
        sys.kind != 'reschedule_proposal' ||
        sys.answer != null ||
        sys.proposal == null) {
      return const [];
    }

    final byRole = sys.proposal!.byRole;
    final myRole = currentUserId == thread.photographerId
        ? 'photographer'
        : 'customer';

    // Proposer cannot accept their own proposal: counterpart answers!
    if (byRole == myRole) {
      return const [];
    }

    return [
      AppButton.primary(
        l10n.chatRescheduleAccept,
        key: Key('accept-reschedule-${msg.id}'),
        onPressed: () async {
          try {
            await controller.answerReschedule(msg.id, accept: true);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.chatDayTaken)));
            }
          }
        },
      ),
      const SizedBox(width: AppSpace.s2),
      AppButton.outline(
        l10n.chatRescheduleDecline,
        key: Key('decline-reschedule-${msg.id}'),
        onPressed: () async {
          final confirmed = await showConfirmSheet(
            context,
            title: l10n.chatRescheduleDeclineTitle,
            confirmLabel: l10n.chatRescheduleDecline,
            keepLabel: l10n.actionCancel,
            danger: true,
          );
          if (confirmed && context.mounted) {
            await controller.answerReschedule(msg.id, accept: false);
          }
        },
      ),
    ];
  }
}
