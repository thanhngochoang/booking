// lib/features/create_post/create_post_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';
import 'package:photobooking/features/create_post/post_composer.dart';

/// S10.01: publish once for the feed and the portfolio, always tied to a package.
///
/// Mock S10.01: "Đăng bài" bar · two-column photo grid with a "+" tile · caption
/// · the package field (accent border, required) · place and style side by
/// side · "Thêm vào portfolio" switch · sticky footer with "Đăng". The
/// "Bài đăng / Sự kiện" tabs arrive with the events plan.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({
    super.key,
    required this.onAddService,
    required this.onPublished,
  });

  /// "Thêm gói", shown when the photographer has no package yet.
  final VoidCallback onAddService;

  /// Receives the id of the new post.
  final ValueChanged<String> onPublished;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  late final TextEditingController _caption;
  late final TextEditingController _location;

  @override
  void initState() {
    super.initState();
    final s = ref.read(postComposerProvider);
    _caption = TextEditingController(text: s.caption);
    _location = TextEditingController(text: s.locationName ?? '');
    // A new form (after a publish, or another account): show its fields.
    ref.listenManual(postComposerProvider.select((s) => s.draftId), (_, _) {
      final now = ref.read(postComposerProvider);
      _caption.text = now.caption;
      _location.text = now.locationName ?? '';
    });
  }

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _publish() async {
    final l = context.l10n;
    FocusScope.of(context).unfocus();
    final result = await ref.read(postComposerProvider.notifier).publish();
    if (!mounted) {
      return;
    }
    switch (result.outcome) {
      case PublishOutcome.published:
        _toast(l.createPublished);
        widget.onPublished(result.postId!);
      case PublishOutcome.imageFailed:
        _toast(l.createUploadFailed);
      case PublishOutcome.publishFailed:
        _toast(l.createPublishFailed);
      case PublishOutcome.notReady:
        break;
    }
  }

  Future<void> _pickService(
    List<ServiceSummary> services,
    String? current,
  ) async {
    final l = context.l10n;
    final picked = await showAppSheet<ServiceSummary>(
      context,
      builder: (sheet) => _SheetList(
        title: l.createServiceTitle,
        rows: [
          for (final s in services)
            AppOptionTile(
              label: '${s.name} · ${formatMoney(s.priceVnd)}',
              selected: s.id == current,
              onTap: () => Navigator.of(sheet).pop(s),
            ),
        ],
      ),
    );
    if (picked != null && mounted) {
      ref.read(postComposerProvider.notifier).setService(picked);
    }
  }

  Future<void> _pickStyle(String? current) async {
    final l = context.l10n;
    final picked = await showAppSheet<_PickedStyle>(
      context,
      builder: (sheet) => _SheetList(
        title: l.createStyleTitle,
        rows: [
          AppOptionTile(
            label: l.createStyleNone,
            selected: current == null,
            onTap: () => Navigator.of(sheet).pop(const _PickedStyle(null)),
          ),
          for (final o in kStyles)
            AppOptionTile(
              label: o.labelVi,
              selected: o.id == current,
              onTap: () => Navigator.of(sheet).pop(_PickedStyle(o.id)),
            ),
        ],
      ),
    );
    if (picked != null && mounted) {
      ref.read(postComposerProvider.notifier).setStyle(picked.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = ref.watch(postComposerProvider);
    final ctl = ref.read(postComposerProvider.notifier);
    final services = ref.watch(myServicesProvider);
    final started =
        s.images.isNotEmpty ||
        s.caption.isNotEmpty ||
        s.serviceId != null ||
        s.locationName != null;
    // Place and style sit side by side (mock `.row`) until the text is large.
    final stack =
        MediaQuery.textScalerOf(context).scale(AppText.md) > AppText.md * 1.15;
    ServiceSummary? chosen;
    for (final sv in services.value ?? const <ServiceSummary>[]) {
      if (sv.id == s.serviceId) {
        chosen = sv;
      }
    }
    // A saved draft can name a package that was hidden or deleted since: drop
    // it so the field asks for a package again instead of failing at publish.
    final loaded = services.value;
    if (loaded != null && s.serviceId != null && chosen == null) {
      Future.microtask(() {
        if (!mounted) {
          return;
        }
        final now = ref.read(postComposerProvider);
        final list = ref.read(myServicesProvider).value;
        if (list != null &&
            now.serviceId != null &&
            !list.any((e) => e.id == now.serviceId)) {
          ref.read(postComposerProvider.notifier).setService(null);
        }
      });
    }
    final canAdd = s.images.length < PostComposerController.maxImages;

    final location = TextField(
      key: const Key('create-location'),
      controller: _location,
      enabled: !s.publishing,
      maxLength: 60,
      textInputAction: TextInputAction.done,
      onChanged: ctl.setLocation,
      decoration: InputDecoration(
        labelText: l.createLocationLabel,
        counterText: '',
      ),
    );
    final style = _PickField(
      key: const Key('create-style'),
      label: l.createStyleLabel,
      value: s.styleId == null ? null : styleLabel(s.styleId!),
      placeholder: l.createStyleNone,
      onTap: s.publishing ? null : () => _pickStyle(s.styleId),
    );

    return ScreenCode(
      ScreenCodes.createPost,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l.tabCreate)),
        // Every field is built (not lazily) so the form keeps its state.
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpace.s2,
                  crossAxisSpacing: AppSpace.s2,
                ),
                itemCount: s.images.length + (canAdd ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == s.images.length) {
                    return _AddTile(
                      key: const Key('create-add'),
                      onTap: s.publishing ? null : ctl.pickImages,
                    );
                  }
                  final img = s.images[i];
                  return _ImageTile(
                    key: Key('create-tile-$i'),
                    index: i,
                    count: s.images.length,
                    image: img,
                    locked: s.publishing,
                    onRemove: () => ctl.removeImage(img.key),
                    onUp: () => ctl.moveImage(img.key, -1),
                    onDown: () => ctl.moveImage(img.key, 1),
                    onRetry: () => ctl.retryImage(img.key),
                  );
                },
              ),
              if (s.images.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s1),
                Text(
                  l.createPhotosCount(
                    s.images.length,
                    PostComposerController.maxImages,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (started && s.images.isEmpty)
                _FieldError(l.createPhotosRequired),
              const SizedBox(height: AppSpace.s4),
              TextField(
                key: const Key('create-caption'),
                controller: _caption,
                enabled: !s.publishing,
                minLines: 3,
                maxLines: 6,
                maxLength: PostComposerController.maxCaption,
                textCapitalization: TextCapitalization.sentences,
                onChanged: ctl.setCaption,
                decoration: InputDecoration(
                  labelText: l.createCaptionLabel,
                  hintText: l.createCaptionHint,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              _ServiceField(
                services: services,
                chosen: chosen,
                enabled: !s.publishing,
                onTap: (list) => _pickService(list, s.serviceId),
                onAddService: widget.onAddService,
                onRetry: () => ref.invalidate(myServicesProvider),
                showError: started && chosen == null && loaded != null,
              ),
              const SizedBox(height: AppSpace.s3),
              if (stack) ...[
                location,
                const SizedBox(height: AppSpace.s3),
                style,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: location),
                    const SizedBox(width: AppSpace.s2),
                    Expanded(child: style),
                  ],
                ),
              const SizedBox(height: AppSpace.s2),
              SwitchListTile(
                key: const Key('create-portfolio'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.createPortfolio),
                value: s.inPortfolio,
                onChanged: s.publishing ? null : ctl.setInPortfolio,
              ),
            ],
          ),
        ),
        // Mock `.foot`; AppFooterBar owns the bottom inset.
        bottomNavigationBar: AppFooterBar(
          child: SizedBox(
            height: controlHeight,
            child: AppButton.primary(
              l.createPublish,
              key: const Key('create-publish'),
              loading: s.publishing,
              onPressed: s.canPublish && chosen != null ? _publish : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// What the style sheet returns; `id == null` means "no style".
class _PickedStyle {
  const _PickedStyle(this.id);
  final String? id;
}

class _SheetList extends StatelessWidget {
  const _SheetList({required this.title, required this.rows});
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            0,
            AppSpace.s5,
            AppSpace.s3,
          ),
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              0,
              AppSpace.s4,
              AppSpace.s5,
            ),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s2),
            itemBuilder: (_, i) => rows[i],
          ),
        ),
      ],
    );
  }
}

/// Mock `.field .e`: a short error under a field.
class _FieldError extends StatelessWidget {
  const _FieldError(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s1),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}

/// A tap-to-choose row drawn like the mock `.field`: label above the value.
/// [accent] is the `.field.foc` border of the required package field.
class _PickField extends StatelessWidget {
  const _PickField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.accent = false,
    this.error = false,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final bool accent;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final focus = dark ? AppColorsDark.focusRing : AppColors.focusRing;
    final edge = error
        ? BorderSide(color: scheme.error, width: 2)
        : accent
        ? BorderSide(color: focus, width: 2)
        : BorderSide.none;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
      side: edge,
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$label, ${value ?? placeholder}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: scheme.secondary,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpace.s12 + AppSpace.s2,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: theme.textTheme.labelSmall),
                        Text(
                          value ?? placeholder,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: value == null ? muted : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, color: muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceField extends StatelessWidget {
  const _ServiceField({
    required this.services,
    required this.chosen,
    required this.enabled,
    required this.onTap,
    required this.onAddService,
    required this.onRetry,
    required this.showError,
  });

  final AsyncValue<List<ServiceSummary>> services;
  final ServiceSummary? chosen;
  final bool enabled;
  final ValueChanged<List<ServiceSummary>> onTap;
  final VoidCallback onAddService;
  final VoidCallback onRetry;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = services.value;
    if (list == null) {
      if (services.hasError) {
        return ErrorState(message: l.createServicesError, onRetry: onRetry);
      }
      return const AppSkeleton.box(
        height: AppSpace.s12 + AppSpace.s2,
        radius: controlRadius,
      );
    }
    if (list.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.createNoServices,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton.outline(
            l.createAddService,
            key: const Key('create-add-service'),
            onPressed: onAddService,
          ),
        ],
      );
    }
    final c = chosen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PickField(
          key: const Key('create-service'),
          label: l.createServiceLabel,
          value: c == null ? null : '${c.name} · ${formatMoney(c.priceVnd)}',
          placeholder: l.createServicePick,
          accent: true,
          error: showError,
          onTap: enabled ? () => onTap(list) : null,
        ),
        if (showError) _FieldError(l.createServiceRequired),
      ],
    );
  }
}

/// Mock: the last grid cell, a field-coloured square with a "+".
class _AddTile extends StatelessWidget {
  const _AddTile({super.key, required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final radius = BorderRadius.circular(AppRadius.control);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: context.l10n.createAddPhotos,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: theme.colorScheme.secondary,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(child: Icon(Icons.add_rounded, color: muted)),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    super.key,
    required this.index,
    required this.count,
    required this.image,
    required this.locked,
    required this.onRemove,
    required this.onUp,
    required this.onDown,
    required this.onRetry,
  });

  final int index;
  final int count;
  final ComposerImage image;
  final bool locked;
  final VoidCallback onRemove;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final failed = image.status == ComposerImageStatus.failed;
    final uploading = image.status == ComposerImageStatus.uploading;
    final editable = !locked && !uploading;
    const ink = AppColors.foregroundInverse;
    final scrim = IconButton.styleFrom(
      backgroundColor: AppColors.overlay,
      foregroundColor: ink,
    );
    const onPhoto = TextStyle(color: ink, fontSize: AppText.sm);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: LayoutBuilder(
        builder: (context, box) {
          // Decode at the tile's size, in steps so a resize reuses the cache.
          final cacheWidth = ((box.maxWidth * ratio) / 50).ceil() * 50;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(image.picked.path),
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                errorBuilder: (_, _, _) => ColoredBox(color: scheme.secondary),
              ),
              if (failed || uploading)
                const ColoredBox(color: AppColors.overlay),
              if (editable) ...[
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    key: Key('create-remove-$index'),
                    tooltip: l.createRemove,
                    style: scrim,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onRemove,
                  ),
                ),
                if (index > 0)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: IconButton(
                      key: Key('create-up-$index'),
                      tooltip: l.createMoveUp,
                      style: scrim,
                      icon: const Icon(Icons.arrow_upward_rounded),
                      onPressed: onUp,
                    ),
                  ),
                if (index < count - 1)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      key: Key('create-down-$index'),
                      tooltip: l.createMoveDown,
                      style: scrim,
                      icon: const Icon(Icons.arrow_downward_rounded),
                      onPressed: onDown,
                    ),
                  ),
              ],
              if (image.status == ComposerImageStatus.uploaded)
                const Positioned(
                  top: AppSpace.s2,
                  left: AppSpace.s2,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                  ),
                ),
              if (uploading)
                Positioned(
                  left: AppSpace.s2,
                  right: AppSpace.s2,
                  bottom: AppSpace.s2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.createUploading((image.progress * 100).round()),
                        style: onPhoto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpace.s1),
                      LinearProgressIndicator(
                        value: image.progress,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ],
                  ),
                ),
              if (failed)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: Key('create-retry-$index'),
                          tooltip: l.createRetryPhoto,
                          style: scrim,
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: locked ? null : onRetry,
                        ),
                        Text(
                          l.createUploadFailed,
                          textAlign: TextAlign.center,
                          style: onPhoto,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
