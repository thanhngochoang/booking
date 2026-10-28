import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/support/support_providers.dart';
import 'package:photobooking/data/support/support_thread.dart';
import 'package:photobooking/features/chat/chat_bubble_mapping.dart';
import 'package:photobooking/features/help/support_thread_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class SupportThreadView extends ConsumerStatefulWidget {
  const SupportThreadView({
    super.key,
    required this.threadId,
    required this.enabled,
    this.disabledReason,
    required this.hint,
    required this.senderLabel,
    this.emptyPlaceholder,
    this.header,
    this.scrollHeader = false,
  });

  final String threadId;
  final bool enabled;
  final String? disabledReason;
  final String hint;
  final String Function(SupportMessage) senderLabel;
  final Widget? emptyPlaceholder;
  final Widget? header;

  /// When true the [header] scrolls with the messages (S18.02: the dispute
  /// details come first, the thread under them) and the view opens at the
  /// top; it only scrolls to the end when the user sends. Otherwise the
  /// header stays fixed and the view follows the newest message.
  final bool scrollHeader;

  @override
  ConsumerState<SupportThreadView> createState() => _SupportThreadViewState();
}

class _SupportThreadViewState extends ConsumerState<SupportThreadView> {
  final ScrollController _scrollController = ScrollController();
  int _pendingSeen = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final messagesAsync = ref.watch(supportMessagesProvider(widget.threadId));
    final controller = ref.read(
      supportThreadControllerProvider(widget.threadId).notifier,
    );
    final state = ref.watch(supportThreadControllerProvider(widget.threadId));

    ref.listen(supportThreadControllerProvider(widget.threadId), (prev, next) {
      if (next.errorCode != null && next.errorSeq != prev?.errorSeq) {
        final message = switch (next.errorCode) {
          'limit_exceeded' => l.supportRateLimited,
          _ => l.supportSendFailed,
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });

    final streamMessages = messagesAsync.value ?? const <SupportMessage>[];
    controller.syncWithStream(streamMessages);

    // Merge stream messages and pending messages
    final streamIds = {for (final m in streamMessages) m.id};
    final allMessages = [
      ...streamMessages,
      for (final m in state.pending)
        if (!streamIds.contains(m.id)) m,
    ];

    final sent = state.pending.length > _pendingSeen;
    _pendingSeen = state.pending.length;
    if (allMessages.isNotEmpty && (!widget.scrollHeader || sent)) {
      _scrollToBottom();
    }

    Widget bubble(SupportMessage msg) {
      final isMine =
          (currentUid != null && msg.senderId == currentUid) ||
          (msg.senderRole == SupportSenderRole.user && msg.senderId == null);
      final system = msg.senderRole == SupportSenderRole.system;
      final label = system ? '' : widget.senderLabel(msg);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ChatBubble(
          key: Key('bubble-${msg.id}'),
          content: system ? SystemContent(msg.body) : TextContent(msg.body),
          mine: !system && isMine,
          state: sendStateOf(msg.sendState),
          senderName: label.isNotEmpty ? label : null,
          onRetry: msg.sendState == MessageSendState.failed
              ? () => controller.retry(msg.id)
              : null,
        ),
      );
    }

    Widget messages({required int skeletons, required bool scrolls}) {
      return AsyncView<List<SupportMessage>>(
        value: messagesAsync,
        skeleton: (_) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < skeletons; i++)
              ChatBubble.skeleton(mine: i.isOdd),
          ],
        ),
        onRetry: () => ref.invalidate(supportMessagesProvider(widget.threadId)),
        data: (context, _) {
          if (allMessages.isEmpty && widget.emptyPlaceholder != null) {
            return widget.emptyPlaceholder!;
          }
          if (!scrolls) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final m in allMessages) bubble(m)],
            );
          }
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s4,
              vertical: AppSpace.s3,
            ),
            itemCount: allMessages.length,
            itemBuilder: (context, index) => bubble(allMessages[index]),
          );
        },
      );
    }

    return Column(
      children: [
        if (widget.scrollHeader)
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s3,
              ),
              children: [
                if (widget.header != null) widget.header!,
                messages(skeletons: 3, scrolls: false),
              ],
            ),
          )
        else ...[
          if (widget.header != null) widget.header!,
          Expanded(child: messages(skeletons: 6, scrolls: true)),
        ],
        if (widget.enabled)
          AppFooterBar(
            child: ChatComposer(
              key: const Key('support-composer'),
              hint: widget.hint,
              enabled: true,
              onSend: (text) => controller.sendText(text),
            ),
          )
        else if (widget.disabledReason != null)
          AppFooterBar(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  widget.disabledReason!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
