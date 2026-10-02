// lib/core/widgets/chat_bubble.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';
import 'package:photobooking/core/widgets/network_photo.dart';

/// Sealed hierarchy of chat bubble content types.
sealed class ChatBubbleContent {
  const ChatBubbleContent();
}

/// Plain text message.
final class TextContent extends ChatBubbleContent {
  const TextContent(this.text);
  final String text;
}

/// Photo message.
final class ImageContent extends ChatBubbleContent {
  const ImageContent(this.url);
  final String url;
}

/// Location message with a label and map link.
final class LocationContent extends ChatBubbleContent {
  const LocationContent({required this.label, required this.mapUrl});
  final String label;
  final String mapUrl;
}

/// System notice or booking state change (centered).
final class SystemContent extends ChatBubbleContent {
  const SystemContent(this.text, {this.actions = const []});
  final String text;
  final List<Widget> actions;
}

/// Sending lifecycle state of a chat bubble.
enum BubbleSendState { sent, sending, failed }

/// Chat message bubble according to mock S07.01.
///
/// - Outgoing messages ([mine] = true): aligned to the right, filled with CTA gradient, white text.
/// - Incoming messages ([mine] = false): aligned to the left, glass surface, dark/light onSurface text.
/// - System notices ([SystemContent]): centered pill with optional actions.
/// - [BubbleSendState.sending]: dimmed with a clock icon.
/// - [BubbleSendState.failed]: shows a warning with a "Gửi lại" retry action.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.content,
    required this.mine,
    this.state = BubbleSendState.sent,
    this.senderName,
    this.onRetry,
  });

  final ChatBubbleContent content;
  final bool mine;
  final BubbleSendState state;
  final String? senderName;
  final VoidCallback? onRetry;

  static Widget skeleton({bool mine = false}) =>
      _ChatBubbleSkeleton(mine: mine);

  @override
  Widget build(BuildContext context) {
    if (content is SystemContent) {
      return _SystemBubble(content: content as SystemContent);
    }

    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );

    final isSending = state == BubbleSendState.sending;
    final isFailed = state == BubbleSendState.failed;

    Widget bubbleBody;
    final foreground = mine ? Colors.white : theme.colorScheme.onSurface;

    if (content is TextContent) {
      final text = (content as TextContent).text;
      bubbleBody = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: foreground,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      );
    } else if (content is ImageContent) {
      final url = (content as ImageContent).url;
      bubbleBody = ClipRRect(
        borderRadius: bubbleRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160, maxHeight: 160),
          child: AspectRatio(
            aspectRatio: 1,
            child: NetworkPhoto(url: url, fit: BoxFit.cover),
          ),
        ),
      );
    } else if (content is LocationContent) {
      final loc = content as LocationContent;
      bubbleBody = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 16, color: foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                loc.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      bubbleBody = const SizedBox.shrink();
    }

    Widget bubbleCard;
    if (mine) {
      bubbleCard = CtaSurface(
        borderRadius: bubbleRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: bubbleBody,
        ),
      );
    } else {
      bubbleCard = DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.glass : AppColors.glass,
          borderRadius: bubbleRadius,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: bubbleBody,
        ),
      );
    }

    Widget bubbleContent = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
      ),
      child: bubbleCard,
    );

    if (isSending) {
      bubbleContent = Opacity(opacity: 0.6, child: bubbleContent);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!mine && senderName != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                senderName!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondary,
                  fontSize: AppText.xs,
                ),
              ),
            ),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (mine && isFailed) ...[
                Semantics(
                  button: true,
                  label: 'Gửi lại',
                  onTap: onRetry,
                  child: GestureDetector(
                    onTap: onRetry,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 14,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Gửi lại',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                              fontSize: AppText.xs,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (mine && isSending) ...[
                const Padding(
                  padding: EdgeInsets.only(right: 4, bottom: 6),
                  child: Icon(
                    Icons.access_time,
                    size: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
              Flexible(child: bubbleContent),
            ],
          ),
        ],
      ),
    );
  }
}

class _SystemBubble extends StatelessWidget {
  const _SystemBubble({required this.content});
  final SystemContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: dark ? AppColorsDark.glass : AppColors.glass,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  content.text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondary,
                    fontSize: AppText.xs,
                  ),
                ),
              ),
            ),
            if (content.actions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                alignment: WrapAlignment.center,
                children: content.actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatBubbleSkeleton extends StatelessWidget {
  const _ChatBubbleSkeleton({required this.mine});
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('chat_bubble_skeleton'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        heightFactor: 1.0,
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38, maxWidth: 240),
          child: AppSkeleton.box(width: 180, height: 38, radius: 18),
        ),
      ),
    );
  }
}
