import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_providers.dart';
import 'package:photobooking/data/delivery/delivery_repository.dart';

Future<bool?> showRevisionSheet(
  BuildContext context, {
  required Booking booking,
  required DeliveryRound round,
  required String providerName,
  bool extra = false,
}) {
  return showAppSheet<bool>(
    context,
    builder: (sheetContext) => RevisionSheet(
      booking: booking,
      round: round,
      providerName: providerName,
      extra: extra,
    ),
  );
}

class RevisionSheet extends ConsumerStatefulWidget {
  const RevisionSheet({
    super.key,
    required this.booking,
    required this.round,
    required this.providerName,
    this.extra = false,
  });

  final Booking booking;
  final DeliveryRound round;
  final String providerName;
  final bool extra;

  @override
  ConsumerState<RevisionSheet> createState() => _RevisionSheetState();
}

class _RevisionSheetState extends ConsumerState<RevisionSheet> {
  final Set<int> _selectedIndices = {};
  final Map<int, String> _photoNotes = {};
  final TextEditingController _generalNoteController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _generalNoteController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _generalNoteController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_submitting) return false;
    final hasGeneralNote = _generalNoteController.text.trim().isNotEmpty;
    final hasSelectedPhotos = _selectedIndices.isNotEmpty;
    final hasPhotoNotes = _photoNotes.values.any((n) => n.trim().isNotEmpty);
    return hasGeneralNote || hasSelectedPhotos || hasPhotoNotes;
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        _photoNotes.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
    // Open photo note dialog when selecting a photo
    if (_selectedIndices.contains(index)) {
      _openPhotoNoteDialog(index);
    }
  }

  Future<void> _openPhotoNoteDialog(int index) async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => _PhotoNoteDialog(
        index: index + 1,
        initialNote: _photoNotes[index] ?? '',
      ),
    );
    if (note != null && mounted) {
      setState(() {
        if (note.trim().isEmpty) {
          _photoNotes.remove(index);
        } else {
          _photoNotes[index] = note.trim();
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    final l10n = context.l10n;
    final repo = ref.read(deliveryRepositoryProvider);

    final photoNotesList = _selectedIndices.map((idx) {
      return DeliveryPhotoNote(
        sampleIndex: idx,
        note: _photoNotes[idx] ?? '',
      );
    }).toList();

    try {
      await repo.requestRevision(
        bookingId: widget.booking.id,
        note: _generalNoteController.text.trim().isEmpty
            ? null
            : _generalNoteController.text.trim(),
        photoNotes: photoNotesList,
        extra: widget.extra,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        final errCode = deliveryErrorOf(e);
        final msg = errCode == DeliveryErrorCode.notReady
            ? l10n.deliveryNotReady
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final textMuted = dark ? AppColorsDark.foregroundSecondary : AppColors.foregroundSecondary;
    final accent = dark ? AppColorsDark.primary : AppColors.primary;
    final samples = widget.round.samples;

    final title = widget.extra
        ? l10n.deliveryExtraRoundTitle
        : l10n.deliveryRevisionSheetTitle;

    final roundNum = widget.round.round;
    final totalRounds = widget.booking.revisionsIncluded;

    return ScreenCode(
      ScreenCodes.requestRevision,
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s2,
            AppSpace.s4,
            AppSpace.s6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedIndices.isNotEmpty) ...[
                          const SizedBox(width: AppSpace.s2),
                          Text(
                            l10n.deliveryRevisionSheetSelectedCount(_selectedIndices.length),
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w600,
                              fontSize: AppText.base,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppIcon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s2),
              // Hint
              Text(
                widget.extra
                    ? l10n.deliveryExtraRoundHint(widget.providerName)
                    : l10n.deliveryRevisionSheetHint,
                style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
              ),
              const SizedBox(height: AppSpace.s3),
              // Selectable Grid
              _SelectableGrid(
                samples: samples,
                selectedIndices: _selectedIndices,
                photoNotes: _photoNotes,
                onTap: _toggleSelect,
              ),
              const SizedBox(height: AppSpace.s4),
              // General note
              TextField(
                controller: _generalNoteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.deliveryRevisionGeneralNote,
                  hintText: l10n.deliveryRevisionGeneralNote,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              // Round info
              if (!widget.extra)
                Text(
                  l10n.deliveryRevisionRoundFree(roundNum, totalRounds),
                  style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
                ),
              const SizedBox(height: AppSpace.s4),
              // Submit button
              AppButton.primary(
                widget.extra ? l10n.deliveryExtraRoundSend : l10n.deliveryRevisionSend,
                loading: _submitting,
                onPressed: _canSubmit ? _submit : null,
              ),
              if (!_canSubmit) ...[
                const SizedBox(height: AppSpace.s2),
                Center(
                  child: Text(
                    l10n.deliveryRevisionSendDisabled,
                    style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableGrid extends StatelessWidget {
  const _SelectableGrid({
    required this.samples,
    required this.selectedIndices,
    required this.photoNotes,
    required this.onTap,
  });

  final List<DeliverySampleRef> samples;
  final Set<int> selectedIndices;
  final Map<int, String> photoNotes;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const crossAxisCount = 3;
    const spacing = AppSpace.s2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;

        // Order of selection for numbered tags: 1, 2, ...
        final selectionOrder = selectedIndices.toList();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(samples.length, (index) {
            final sample = samples[index];
            final isSelected = selectedIndices.contains(index);
            final orderNumber = isSelected ? selectionOrder.indexOf(index) + 1 : null;
            final note = photoNotes[index];

            return SizedBox(
              width: itemWidth,
              height: itemWidth,
              child: GestureDetector(
                key: ValueKey('revision-tile-$index'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _SampleImage(storagePath: sample.thumbPath),
                      if (isSelected)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            color: Colors.black.withValues(alpha: 0.25),
                          ),
                        ),
                      if (orderNumber != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$orderNumber',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (note != null && note.isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.65),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SampleImage extends ConsumerWidget {
  const _SampleImage({required this.storagePath});

  final String storagePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(deliveryImageUrlProvider(storagePath)).value;
    if (url != null) {
      return NetworkPhoto(url: url, fit: BoxFit.cover, retry: false);
    }
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: AppIcon(AppIcons.image, size: 24),
      ),
    );
  }
}

class _PhotoNoteDialog extends StatefulWidget {
  const _PhotoNoteDialog({
    required this.index,
    required this.initialNote,
  });

  final int index;
  final String initialNote;

  @override
  State<_PhotoNoteDialog> createState() => _PhotoNoteDialogState();
}

class _PhotoNoteDialogState extends State<_PhotoNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyChip(String text) {
    final current = _controller.text.trim();
    if (current.isEmpty) {
      _controller.text = text;
    } else if (!current.contains(text)) {
      _controller.text = '$current, $text';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chips = [
      l10n.deliveryRevisionChipBrighter,
      l10n.deliveryRevisionChipLessYellow,
      l10n.deliveryRevisionChipRemoveObject,
      l10n.deliveryRevisionChipStraighten,
    ];

    return AlertDialog(
      title: Text(l10n.deliveryRevisionNoteForPhoto(widget.index)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpace.s2,
              runSpacing: AppSpace.s1,
              children: chips.map((c) {
                return ActionChip(
                  label: Text(c),
                  onPressed: () => _applyChip(c),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpace.s3),
            TextField(
              controller: _controller,
              maxLength: 120,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: l10n.deliveryRevisionNoteForPhoto(widget.index),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Xong'),
        ),
      ],
    );
  }
}
