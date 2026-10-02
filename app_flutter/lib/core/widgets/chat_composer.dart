// lib/core/widgets/chat_composer.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';
import 'package:photobooking/core/widgets/signature_loader.dart';

/// Bottom composer for sending messages and picking images (mock S07.01).
///
/// - Camera/Image picker button on the left (shows [SignatureLoader] and locks when [busy]).
/// - Rounded input field with placeholder or [disabledReason].
/// - Send action button on the right (disabled on empty/whitespace, clears input upon send).
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    this.onPickImage,
    this.enabled = true,
    this.disabledReason,
    this.busy = false,
  });

  final ValueChanged<String> onSend;
  final VoidCallback? onPickImage;
  final bool enabled;
  final String? disabledReason;

  /// Whether an attachment upload is currently in flight.
  /// When true, image picker shows an inline loader and blocks further selection.
  final bool busy;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (!widget.enabled) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    final canSend = widget.enabled && _controller.text.trim().isNotEmpty;
    final canPick =
        widget.enabled && !widget.busy && widget.onPickImage != null;

    final fieldBg = dark ? AppColorsDark.glass : AppColors.glass;
    final border = theme.colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image / Camera button
          Semantics(
            button: true,
            label: 'Chọn ảnh',
            enabled: canPick,
            child: Material(
              type: MaterialType.transparency,
              child: Ink(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: border),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: canPick ? widget.onPickImage : null,
                  child: Center(
                    child: widget.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: FittedBox(
                              child: SignatureLoader(size: LoaderSize.inline),
                            ),
                          )
                        : Icon(
                            Icons.camera_alt_outlined,
                            size: 20,
                            color: canPick
                                ? theme.colorScheme.primary
                                : secondary,
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Message input
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40, maxHeight: 100),
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                style: theme.textTheme.bodyMedium,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: widget.enabled
                      ? 'Nhập tin nhắn…'
                      : (widget.disabledReason ?? 'Cuộc trò chuyện đã đóng'),
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: secondary,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: fieldBg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    borderSide: BorderSide(color: border),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    borderSide: BorderSide(
                      color: border.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          Semantics(
            button: true,
            label: 'Gửi tin nhắn',
            enabled: canSend,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: canSend ? _handleSend : null,
                child: Opacity(
                  opacity: canSend ? 1.0 : 0.4,
                  child: CtaSurface(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
