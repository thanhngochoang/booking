// lib/features/events/event_share_composer.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_social_providers.dart';
import 'package:photobooking/data/events/event_timeline.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/features/events/timeline_controller.dart';

const shareMaxImages = 10;
const shareMaxCaption = 2000;

/// A photo chosen for the post: its own key, so removing one never confuses another.
@immutable
class SharePhoto {
  const SharePhoto(this.key, this.picked);
  final int key;
  final PickedImage picked;
}

@immutable
class ShareState {
  const ShareState({this.photos = const [], this.sharing = false, this.error});

  final List<SharePhoto> photos;
  final bool sharing;

  /// The domain code of the last refusal (`not_eligible`, `network`, …).
  final String? error;

  ShareState copyWith({
    List<SharePhoto>? photos,
    bool? sharing,
    String? Function()? error,
  }) => ShareState(
    photos: photos ?? this.photos,
    sharing: sharing ?? this.sharing,
    error: error == null ? this.error : error(),
  );
}

/// S11.05 share form: photos in, one call out. Nothing is uploaded before
/// "Đăng", so leaving the form leaves nothing behind; the repository cleans up
/// after a refused share.
class ShareController extends Notifier<ShareState> {
  ShareController(this.eventId);
  final String eventId;
  int _seq = 0;

  @override
  ShareState build() => const ShareState();

  Future<void> pick() async {
    final room = shareMaxImages - state.photos.length;
    if (room <= 0 || state.sharing) {
      return;
    }
    final picked = await ref.read(imagePickerProvider).pickImages(max: room);
    if (!ref.mounted || picked.isEmpty) {
      return;
    }
    final left = shareMaxImages - state.photos.length;
    state = state.copyWith(
      photos: [
        ...state.photos,
        for (final p in picked.take(left)) SharePhoto(_seq++, p),
      ],
      error: () => null,
    );
  }

  void remove(int key) {
    if (state.sharing) {
      return;
    }
    state = state.copyWith(
      photos: [
        for (final p in state.photos)
          if (p.key != key) p,
      ],
    );
  }

  /// True when the post landed.
  Future<bool> share(String caption) async {
    if (state.sharing || state.photos.isEmpty) {
      return false;
    }
    state = state.copyWith(sharing: true, error: () => null);
    try {
      await ref
          .read(eventTimelineRepositoryProvider)
          .share(
            eventId,
            images: [for (final p in state.photos) p.picked],
            caption: caption.trim(),
          );
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          sharing: false,
          error: () => eventErrorCodeOf(e),
        );
      }
      return false;
    }
    if (ref.mounted) {
      state = state.copyWith(sharing: false);
      // The new post must show when the timeline is opened again.
      ref.invalidate(
        timelineControllerProvider((
          eventId: eventId,
          status: TimelineStatus.visible,
        )),
      );
      // And on the author's Hồ sơ grid and counts (S09.01).
      ref.read(ownPostsChangedProvider.notifier).bump();
    }
    return true;
  }
}

final shareControllerProvider = NotifierProvider.autoDispose
    .family<ShareController, ShareState, String>(ShareController.new);

/// S11.05 `share`: "Chia sẻ ảnh sự kiện": pick 1 to 10 photos, a caption that
/// starts with the event hashtag, "Đăng".
class EventShareComposer extends ConsumerStatefulWidget {
  const EventShareComposer({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventShareComposer> createState() => _EventShareComposerState();
}

class _EventShareComposerState extends ConsumerState<EventShareComposer> {
  final _caption = TextEditingController();
  String _prefill = '';
  bool _prefilled = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  /// Fills "#Tag " once, when the event is known and the field is still empty.
  void _prefillFrom(EventDetail e) {
    if (_prefilled) {
      return;
    }
    _prefilled = true;
    _prefill = timelineCaptionPrefillOf(e.hashtag);
    if (_caption.text.isEmpty) {
      _caption.text = _prefill;
    }
  }

  bool get _dirty {
    final s = ref.read(shareControllerProvider(widget.eventId));
    return s.photos.isNotEmpty || _caption.text.trim() != _prefill.trim();
  }

  Future<void> _leave() async {
    final l = context.l10n;
    if (ref.read(shareControllerProvider(widget.eventId)).sharing) {
      return;
    }
    if (_dirty) {
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
    _close();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/e/${widget.eventId}/timeline');
    }
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(shareControllerProvider(widget.eventId).notifier)
        .share(_caption.text);
    if (!mounted || !ok) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.shareDone)));
    _close();
  }

  String _errorText(String code) => switch (code) {
    'not_eligible' => context.l10n.shareClosed,
    _ => context.l10n.shareFailed,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final event = ref.watch(eventProvider(widget.eventId)).value;
    if (event != null) {
      _prefillFrom(event);
    }
    final s = ref.watch(shareControllerProvider(widget.eventId));
    final ctl = ref.read(shareControllerProvider(widget.eventId).notifier);
    final canAdd = s.photos.length < shareMaxImages;
    return ScreenCode(
      ScreenCodes.eventTimeline,
      label: 'share',
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _leave();
          }
        },
        child: AuroraBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              leading: IconButton(
                key: const Key('share-back'),
                tooltip: l.back,
                icon: const AppIcon(AppIcons.back),
                onPressed: s.sharing ? null : _leave,
              ),
              title: Text(l.shareTitle),
            ),
            body: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: AppSpace.s2,
                          crossAxisSpacing: AppSpace.s2,
                        ),
                    itemCount: s.photos.length + (canAdd ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == s.photos.length) {
                        return _AddTile(
                          key: const Key('share-add'),
                          label: l.createAddPhotos,
                          onTap: s.sharing ? null : ctl.pick,
                        );
                      }
                      final p = s.photos[i];
                      return _PhotoTile(
                        key: Key('share-photo-$i'),
                        photo: p,
                        locked: s.sharing,
                        onRemove: () => ctl.remove(p.key),
                      );
                    },
                  ),
                  if (s.photos.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      l.createPhotosCount(s.photos.length, shareMaxImages),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpace.s4),
                  TextField(
                    key: const Key('share-caption'),
                    controller: _caption,
                    enabled: !s.sharing,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: shareMaxCaption,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: l.createCaptionLabel,
                      hintText: l.shareCaptionHint,
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (s.error != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s2),
                        child: Text(
                          _errorText(s.error!),
                          key: const Key('share-error'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            bottomNavigationBar: AppFooterBar(
              child: SizedBox(
                height: controlHeight,
                child: AppButton.primary(
                  l.shareSend,
                  key: const Key('share-send'),
                  loading: s.sharing,
                  onPressed: s.photos.isEmpty || s.sharing ? null : _send,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "#Tag " (what the composer and S10.01 start the caption with).
String timelineCaptionPrefillOf(String hashtag) => '#$hashtag ';

class _AddTile extends StatelessWidget {
  const _AddTile({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: scheme.secondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: const Center(child: AppIcon(AppIcons.addPhoto)),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    super.key,
    required this.photo,
    required this.locked,
    required this.onRemove,
  });

  final SharePhoto photo;
  final bool locked;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(photo.picked.path),
            fit: BoxFit.cover,
            cacheWidth: 300,
            errorBuilder: (_, _, _) => ColoredBox(
              color: Theme.of(context).colorScheme.secondary,
              child: const Center(child: AppIcon(AppIcons.image)),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: l.actionCancel,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.overlay,
                foregroundColor: AppColors.foregroundInverse,
                minimumSize: const Size(48, 48),
              ),
              icon: const AppIcon(AppIcons.close, size: 16),
              onPressed: locked ? null : onRemove,
            ),
          ),
        ],
      ),
    );
  }
}
