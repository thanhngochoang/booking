// lib/features/event_manage/announce_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_social_providers.dart';

/// Longest announcement (domain `ANNOUNCEMENT_MAX`).
const announceMaxLength = 500;

/// S12.03 "Nhắn nhóm": "Ghim thông báo vào nhóm". Returns true once the
/// announcement is pinned in the group chat.
Future<bool> showAnnounceSheet(
  BuildContext context, {
  required String eventId,
}) async {
  final done = await showAppSheet<bool>(
    context,
    // A form: it never closes by a drag or a tap outside, so typed text is not lost.
    isDismissible: false,
    enableDrag: false,
    builder: (_) => ScreenCode(
      ScreenCodes.manageEvent,
      label: 'announce',
      child: AnnounceSheet(eventId: eventId),
    ),
  );
  return done ?? false;
}

class AnnounceSheet extends ConsumerStatefulWidget {
  const AnnounceSheet({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AnnounceSheet> createState() => _AnnounceSheetState();
}

class _AnnounceSheetState extends ConsumerState<AnnounceSheet> {
  final _text = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  /// One id per announcement: a retry after a lost answer reuses it, so the
  /// server posts and pins it once (review M3). Editing the text starts a new one.
  String _clientId = newUlid();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _valid {
    final n = _text.text.trim().length;
    return n >= 1 && n <= announceMaxLength;
  }

  Future<void> _close() async {
    if (_busy) {
      return;
    }
    if (_text.text.trim().isNotEmpty) {
      final l = context.l10n;
      final discard = await showConfirmSheet(
        context,
        title: l.shareDiscardTitle,
        confirmLabel: l.albumEditDiscard,
        keepLabel: l.shareKeepEditing,
      );
      if (!discard || !mounted) {
        return;
      }
    }
    Navigator.of(context).pop(false);
  }

  Future<void> _send() async {
    if (!_valid || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await ref
          .read(eventChatRepositoryProvider)
          .announce(widget.eventId, _text.text.trim(), clientId: _clientId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
      return;
    }
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close();
        }
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.s4,
          AppSpace.s2,
          AppSpace.s4,
          AppSpace.s4 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.manageAnnounceTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('announce-close'),
                  tooltip: l.actionCancel,
                  icon: const AppIcon(AppIcons.close),
                  onPressed: _busy ? null : _close,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            TextField(
              key: const Key('announce-text'),
              controller: _text,
              enabled: !_busy,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: announceMaxLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {
                _failed = false;
                _clientId = newUlid();
              }),
              decoration: InputDecoration(hintText: l.manageAnnounceHint),
            ),
            if (_failed)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s2),
                  child: Text(
                    l.manageAnnounceFailed,
                    key: const Key('announce-error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.s2),
            AppButton.primary(
              l.manageAnnounceSend,
              key: const Key('announce-send'),
              loading: _busy,
              onPressed: _valid && !_busy ? _send : null,
            ),
          ],
        ),
      ),
    );
  }
}
