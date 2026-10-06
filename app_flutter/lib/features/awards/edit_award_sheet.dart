// lib/features/awards/edit_award_sheet.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/features/album/my_albums_controller.dart';
import 'package:photobooking/features/awards/edit_award_controller.dart';

/// S25.02: add an award, or edit [awardId]. Returns true when the award was
/// sent for review, null when the sheet was closed without saving.
///
/// A new award gets its id here, before any proof image is uploaded, so the
/// files can live under `awardProofs/{uid}/{awardId}/`.
Future<bool?> showEditAwardSheet(BuildContext context, {String? awardId}) {
  final args = AwardArgs(awardId ?? newUlid(), existing: awardId != null);
  return showAppSheet<bool>(
    context,
    // A drag would pop past PopScope: what was typed and the uploads must
    // survive; close asks first.
    enableDrag: false,
    builder: (_) =>
        ScreenCode(ScreenCodes.editAward, child: _EditAwardSheet(args: args)),
  );
}

class _EditAwardSheet extends ConsumerWidget {
  const _EditAwardSheet({required this.args});
  final AwardArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AsyncView<AwardDraft?>(
      value: ref.watch(awardDraftProvider(args)),
      loaderSize: LoaderSize.block,
      onRetry: () => ref.invalidate(awardDraftProvider(args)),
      skeleton: (_) => const _FormSkeleton(),
      error: (context, _, _) => _LoadFailed(
        message: l.s2502LoadError,
        onRetry: () => ref.invalidate(awardDraftProvider(args)),
      ),
      data: (context, draft) {
        if (args.existing && draft == null) {
          return _LoadFailed(
            message: l.s2502LoadError,
            onRetry: () => ref.invalidate(awardDraftProvider(args)),
          );
        }
        return _AwardForm(args: args);
      },
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s4),
    child: ErrorState(message: message, onRetry: onRetry),
  );
}

class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.s5,
      0,
      AppSpace.s5,
      AppSpace.s5,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSkeleton.box(height: AppSpace.s12),
        const SizedBox(height: AppSpace.s3),
        AppSkeleton.box(height: AppSpace.s12),
        const SizedBox(height: AppSpace.s3),
        AppSkeleton.box(height: AppSpace.s12),
      ],
    ),
  );
}

class _AwardForm extends ConsumerStatefulWidget {
  const _AwardForm({required this.args});
  final AwardArgs args;

  @override
  ConsumerState<_AwardForm> createState() => _AwardFormState();
}

class _AwardFormState extends ConsumerState<_AwardForm> {
  late final TextEditingController _competition;
  late final TextEditingController _year;
  late final TextEditingController _category;

  EditAwardController get _ctl =>
      ref.read(editAwardControllerProvider(widget.args).notifier);

  /// The current calendar year in Vietnam (UTC+7).
  int get _maxYear =>
      ref.read(clockProvider)().toUtc().add(const Duration(hours: 7)).year;

  @override
  void initState() {
    super.initState();
    final s = ref.read(editAwardControllerProvider(widget.args));
    _competition = TextEditingController(text: s.competition);
    _year = TextEditingController(text: s.year);
    _category = TextEditingController(text: s.category);
  }

  @override
  void dispose() {
    _competition.dispose();
    _year.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (ref.read(editAwardControllerProvider(widget.args)).phase ==
        EditPhase.saving) {
      return;
    }
    if (!_ctl.dirty) {
      Navigator.of(context).pop();
      return;
    }
    final l = context.l10n;
    final discard = await showConfirmSheet(
      context,
      title: l.albumEditDiscardTitle,
      body: l.albumEditDiscardBody,
      confirmLabel: l.albumEditDiscard,
      keepLabel: l.albumEditKeep,
    );
    if (discard && mounted) {
      // Closing deletes the files uploaded for this award (controller dispose).
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    final ok = await _ctl.submit(maxYear: _maxYear);
    if (ok && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _pickWork() async {
    final choice = await showAppSheet<_WorkChoice>(
      context,
      builder: (_) => _WorkPicker(
        selectedId: ref
            .read(editAwardControllerProvider(widget.args))
            .workPostId,
      ),
    );
    if (choice != null && mounted) {
      _ctl.setWork(choice.postId, choice.thumbUrl);
    }
  }

  Future<void> _openProof() => showAppSheet<void>(
    context,
    builder: (_) => _ProofSheet(args: widget.args),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final s = ref.watch(editAwardControllerProvider(widget.args));
    final ctl = _ctl;
    final maxYear = _maxYear;
    final busy = s.phase == EditPhase.saving;
    final editing = widget.args.existing;
    final yearTyped = s.year.trim().isNotEmpty;
    final proofLinks = s.filledLinks.where(EditAwardState.linkValid).length;
    final proofSummary = s.proofCount == 0
        ? l.s2502ProofNone
        : l.s2502ProofSummary(s.proofImageCount, proofLinks);
    final waiting = s.uploading || s.hasFailedTile;
    return PopScope(
      canPop: !ctl.dirty && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s5,
          0,
          AppSpace.s5,
          AppSpace.s4,
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
                      editing ? l.s2502Edit : l.s2502Add,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('award-close'),
                  tooltip: l.albumEditClose,
                  constraints: const BoxConstraints.tightFor(
                    width: AppSpace.s12,
                    height: AppSpace.s12,
                  ),
                  icon: const AppIcon(AppIcons.close),
                  onPressed: busy ? null : _close,
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpace.s2),
                    Focus(
                      onFocusChange: (f) {
                        if (!f) {
                          ctl.touch();
                        }
                      },
                      child: TextField(
                        key: const Key('award-competition'),
                        controller: _competition,
                        enabled: !busy,
                        maxLength: kAwardCompetitionMax,
                        textInputAction: TextInputAction.next,
                        onChanged: ctl.setCompetition,
                        buildCounter: _noCounter,
                        decoration: InputDecoration(
                          labelText: l.s2502Competition,
                          errorText:
                              (s.touched || s.competition.isNotEmpty) &&
                                  !s.competitionValid
                              ? l.s2502CompetitionRequired
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: AppSpace.s16 + AppSpace.s10,
                          child: TextField(
                            key: const Key('award-year'),
                            controller: _year,
                            enabled: !busy,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            textInputAction: TextInputAction.next,
                            onChanged: ctl.setYear,
                            decoration: InputDecoration(
                              labelText: l.s2502Year,
                              errorText:
                                  yearTyped &&
                                      s.year.length == 4 &&
                                      s.yearValue(maxYear) == null
                                  ? l.s2502YearInvalid(maxYear)
                                  : null,
                              errorMaxLines: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpace.s2),
                        Expanded(
                          child: TextField(
                            key: const Key('award-category'),
                            controller: _category,
                            enabled: !busy,
                            maxLength: kAwardCategoryMax,
                            textInputAction: TextInputAction.done,
                            onChanged: ctl.setCategory,
                            buildCounter: _noCounter,
                            decoration: InputDecoration(
                              labelText: l.s2502Category,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s3),
                    Semantics(
                      header: true,
                      child: Text(
                        l.s2502Result,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: AppSpace.s2,
                      children: [
                        for (final r in AwardResult.values)
                          AppChip(
                            key: Key('award-result-${r.code}'),
                            label: awardResultShortLabel(l, r),
                            selected: s.result == r,
                            kind: AppChipKind.context,
                            onChanged: busy ? (_) {} : (_) => ctl.setResult(r),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s2),
                    _PickRow(
                      key: const Key('award-work'),
                      label: l.s2502Work,
                      value: s.workPostId == null
                          ? l.s2502WorkNone
                          : l.s2502WorkChosen,
                      thumbUrl: s.workThumbUrl,
                      onTap: busy ? null : _pickWork,
                    ),
                    const SizedBox(height: AppSpace.s2),
                    _PickRow(
                      key: const Key('award-proof'),
                      label: l.s2502Proof,
                      value: proofSummary,
                      onTap: busy ? null : _openProof,
                    ),
                    const SizedBox(height: AppSpace.s3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: AppIcon(
                            AppIcons.lock,
                            size: AppText.base,
                            color: muted,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s2),
                        Expanded(
                          child: Text(
                            l.s2502Privacy,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (s.failure != null) ...[
                      const SizedBox(height: AppSpace.s2),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          switch (s.failure!) {
                            EditFailure.limit => l.s2502SubmitLimit,
                            EditFailure.rejected => l.s2502SubmitRejected,
                            EditFailure.generic => l.s2502SubmitError,
                          },
                          key: const Key('award-error'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    if (waiting) ...[
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        l.s2502SubmitWait,
                        key: const Key('award-wait'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            AppButton.primary(
              l.s2502Submit,
              key: const Key('award-submit'),
              loading: busy,
              onPressed: s.canSubmit(maxYear) ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;

/// A tappable field-like row with a label, a value and a chevron (mock
/// `.fieldrow`), optionally with a thumbnail.
class _PickRow extends StatelessWidget {
  const _PickRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.thumbUrl,
  });

  final String label;
  final String value;
  final String? thumbUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(AppRadius.control);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$label. $value',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outline),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.s12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s3,
                vertical: AppSpace.s2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: theme.textTheme.labelSmall),
                        Text(value, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  if (thumbUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: SizedBox.square(
                        dimension: AppSpace.s8 + AppSpace.s1,
                        child: NetworkPhoto(url: thumbUrl!, retry: false),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                  ],
                  const AppIcon(AppIcons.chevron),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkChoice {
  const _WorkChoice(this.postId, this.thumbUrl);
  final String? postId;
  final String? thumbUrl;
}

/// "Tác phẩm": single choice over the photographer's own `work` posts
/// (`PostPickerGrid`, the same grid as S24.04). Tapping a post chooses it.
class _WorkPicker extends ConsumerWidget {
  const _WorkPicker({required this.selectedId});
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final posts = ref.watch(myPostsProvider(MyPostsFilter.all));
    void retry() => ref.invalidate(myPostsProvider(MyPostsFilter.all));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            0,
            AppSpace.s5,
            AppSpace.s2,
          ),
          child: Semantics(
            header: true,
            child: Text(l.s2502WorkTitle, style: theme.textTheme.titleLarge),
          ),
        ),
        Flexible(
          child: AsyncView<MyPostsState>(
            value: posts,
            loaderSize: LoaderSize.block,
            onRetry: retry,
            skeleton: (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: Row(
                children: [
                  for (var c = 0; c < PostPickerGrid.columns; c++) ...[
                    if (c > 0) const SizedBox(width: AppSpace.s1),
                    Expanded(child: AppSkeleton.box(height: AppSpace.s12 * 2)),
                  ],
                ],
              ),
            ),
            error: (context, _, _) =>
                ErrorState(message: l.s2502WorkLoadError, onRetry: retry),
            isEmpty: (s) => s.posts.isEmpty,
            empty: (_) => Padding(
              padding: const EdgeInsets.all(AppSpace.s5),
              child: Text(
                l.s2502WorkEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            data: (context, state) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: PostPickerGrid(
                items: [
                  for (final p in state.posts)
                    PostPickItem(
                      postId: p.id,
                      thumbUrl: p.cover.url,
                      imageCount: p.images.length,
                      label: p.caption.split('\n').first.trim(),
                    ),
                ],
                selected: [?selectedId],
                onToggle: (id) {
                  final PostSummary post = state.posts.firstWhere(
                    (p) => p.id == id,
                  );
                  Navigator.of(context).pop(_WorkChoice(id, post.cover.url));
                },
              ),
            ),
          ),
        ),
        if (selectedId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s5,
              AppSpace.s2,
              AppSpace.s5,
              AppSpace.s2,
            ),
            child: AppButton.outline(
              l.s2502WorkClear,
              key: const Key('award-work-clear'),
              onPressed: () =>
                  Navigator.of(context).pop(const _WorkChoice(null, null)),
            ),
          ),
        const SizedBox(height: AppSpace.s2),
      ],
    );
  }
}

/// "Minh chứng": up to 3 images (uploaded as picked) and 2 https links. What
/// is entered lives in the controller, so closing this sheet loses nothing.
class _ProofSheet extends ConsumerStatefulWidget {
  const _ProofSheet({required this.args});
  final AwardArgs args;

  @override
  ConsumerState<_ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends ConsumerState<_ProofSheet> {
  final _links = <TextEditingController>[];

  EditAwardController get _ctl =>
      ref.read(editAwardControllerProvider(widget.args).notifier);

  @override
  void initState() {
    super.initState();
    for (final v in ref.read(editAwardControllerProvider(widget.args)).links) {
      _links.add(TextEditingController(text: v));
    }
  }

  @override
  void dispose() {
    for (final c in _links) {
      c.dispose();
    }
    super.dispose();
  }

  void _addLink() {
    if (_links.length >= kAwardMaxProofLinks) {
      return;
    }
    _ctl.addLink();
    setState(() => _links.add(TextEditingController()));
  }

  void _removeLink(int i) {
    _ctl.removeLink(i);
    setState(() {
      _links.removeAt(i).dispose();
      if (_links.isEmpty) {
        _links.add(TextEditingController());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = ref.watch(editAwardControllerProvider(widget.args));
    final busy = s.phase == EditPhase.saving;
    final room = s.tiles.length < kAwardMaxProofImages && !busy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s5,
        0,
        AppSpace.s5,
        AppSpace.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l.s2502ProofTitle, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppSpace.s2),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.s2502ProofImages(s.tiles.length, kAwardMaxProofImages),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpace.s2),
                  Wrap(
                    spacing: AppSpace.s2,
                    runSpacing: AppSpace.s2,
                    children: [
                      for (final (i, t) in s.tiles.indexed)
                        _ProofTileView(
                          key: Key('proof-tile-$i'),
                          index: i,
                          tile: t,
                          enabled: !busy,
                          onRemove: () => _ctl.removeTile(t.key),
                          onRetry: () => _ctl.retry(t.key),
                        ),
                      if (room)
                        _AddImageTile(
                          key: const Key('award-add-image'),
                          label: l.s2502ProofAddImage,
                          onTap: _ctl.pickImages,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    l.s2502ProofLinks(kAwardMaxProofLinks),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpace.s2),
                  for (final (i, c) in _links.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              key: Key('award-link-$i'),
                              controller: c,
                              enabled: !busy,
                              keyboardType: TextInputType.url,
                              autocorrect: false,
                              maxLength: kAwardLinkMax,
                              buildCounter: _noCounter,
                              onChanged: (v) => _ctl.setLink(i, v),
                              decoration: InputDecoration(
                                labelText: l.s2502LinkLabel,
                                hintText: 'https://',
                                errorText:
                                    c.text.trim().isNotEmpty &&
                                        !EditAwardState.linkValid(c.text)
                                    ? l.s2502LinkHttps
                                    : null,
                              ),
                            ),
                          ),
                          if (_links.length > 1 || c.text.isNotEmpty)
                            IconButton(
                              key: Key('award-link-remove-$i'),
                              tooltip: l.s2502LinkRemove,
                              constraints: const BoxConstraints.tightFor(
                                width: AppSpace.s12,
                                height: AppSpace.s12,
                              ),
                              icon: const AppIcon(AppIcons.close),
                              onPressed: busy ? null : () => _removeLink(i),
                            ),
                        ],
                      ),
                    ),
                  if (_links.length < kAwardMaxProofLinks)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('award-add-link'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(AppSpace.s12, AppSpace.s12),
                        ),
                        onPressed: busy ? null : _addLink,
                        icon: const AppIcon(AppIcons.add),
                        label: Text(l.s2502ProofAddLink),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          AppButton.outline(
            l.s2502ProofDone,
            key: const Key('award-proof-done'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Big enough that the 48dp remove button on the corner leaves the middle
/// of the tile (the retry button) free.
const double _tileSize = AppSpace.s16 + AppSpace.s10;

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.control);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outline),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: radius),
          onTap: onTap,
          child: const SizedBox.square(
            dimension: _tileSize,
            child: Center(child: AppIcon(AppIcons.addPhoto)),
          ),
        ),
      ),
    );
  }
}

class _ProofTileView extends StatelessWidget {
  const _ProofTileView({
    super.key,
    required this.index,
    required this.tile,
    required this.enabled,
    required this.onRemove,
    required this.onRetry,
  });

  final int index;
  final ProofTile tile;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final n = index + 1;
    const ink = AppColors.foregroundInverse;
    final status = switch (tile.status) {
      ProofStatus.uploading => l.s2502TileUploading(n),
      ProofStatus.failed => l.s2502TileFailed(n),
      ProofStatus.done => l.s2502TileDone(n),
      ProofStatus.saved => l.s2502TileSaved(n),
    };
    final local = tile.local;
    return SizedBox.square(
      dimension: _tileSize,
      child: Semantics(
        label: status,
        container: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: scheme.surfaceContainerHighest),
              if (local != null)
                Image.file(
                  File(local.path),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                )
              else
                const Center(child: AppIcon(AppIcons.description)),
              if (tile.status == ProofStatus.uploading) ...[
                const ColoredBox(color: AppColors.overlay),
                Center(
                  child: UploadProgressRing(
                    fraction: tile.progress,
                    size: AppSpace.s8,
                  ),
                ),
              ],
              if (tile.status == ProofStatus.failed) ...[
                const ColoredBox(color: AppColors.overlay),
                Center(
                  child: IconButton(
                    key: Key('proof-retry-$index'),
                    tooltip: l.actionRetry,
                    constraints: const BoxConstraints.tightFor(
                      width: AppSpace.s12,
                      height: AppSpace.s12,
                    ),
                    icon: const AppIcon(AppIcons.refresh, color: ink),
                    onPressed: enabled ? onRetry : null,
                  ),
                ),
              ],
              if (tile.status == ProofStatus.done)
                const Positioned(
                  left: AppSpace.s1,
                  bottom: AppSpace.s1,
                  child: AppIcon(
                    AppIcons.checkCircle,
                    size: AppText.base2,
                    color: AppColors.success,
                  ),
                ),
              if (enabled)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    key: Key('proof-remove-$index'),
                    tooltip: l.s2502TileRemove(n),
                    constraints: const BoxConstraints.tightFor(
                      width: AppSpace.s12,
                      height: AppSpace.s12,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.overlay,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(AppSpace.s1),
                        child: AppIcon(
                          AppIcons.close,
                          size: AppText.base2,
                          color: ink,
                        ),
                      ),
                    ),
                    onPressed: onRemove,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
