// S18.01 · Mở khiếu nại (sheet), mock #S18.01 and #S18.01-delivery.
import 'dart:io';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/features/disputes/dispute_entry.dart';
import 'package:photobooking/features/disputes/open_dispute_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Drag distance (or speed) on the header that counts as "swipe down".
const double _dragToClose = AppSpace.s10;
const double _flingToClose = 300;

/// The S18.01 form, shown by `showOpenDisputeSheet` (dispute_entry.dart).
/// A drag on the modal would pop past `PopScope` and lose what was typed,
/// so the modal drag is off and the header handles the swipe itself: it
/// closes at once when nothing was entered, else asks "Bỏ nội dung đang
/// viết?".
class OpenDisputeSheet extends ConsumerStatefulWidget {
  const OpenDisputeSheet({
    super.key,
    required this.args,
    required this.summary,
    required this.closesAt,
    required this.origin,
  });

  final OpenDisputeArgs args;
  final DisputeSubjectSummary summary;
  final DateTime closesAt;
  final DisputeOrigin origin;

  @override
  ConsumerState<OpenDisputeSheet> createState() => _OpenDisputeSheetState();
}

class _OpenDisputeSheetState extends ConsumerState<OpenDisputeSheet> {
  double _drag = 0;
  bool _asking = false;

  OpenDisputeController get _ctl =>
      ref.read(openDisputeControllerProvider(widget.args).notifier);

  Future<void> _close() async {
    final s = ref.read(openDisputeControllerProvider(widget.args));
    if (s.submitting || _asking) {
      return;
    }
    if (!s.dirty) {
      Navigator.of(context).pop();
      return;
    }
    final l = context.l10n;
    _asking = true;
    final discard = await showConfirmSheet(
      context,
      title: l.disputeDiscardTitle,
      confirmLabel: l.disputeDiscardConfirm,
      keepLabel: l.disputeDiscardKeep,
    );
    _asking = false;
    if (discard && mounted) {
      _ctl.discard();
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    final id = await _ctl.submit();
    if (id != null && mounted) {
      Navigator.of(context).pop(id);
    }
  }

  String _title(AppLocalizations l) =>
      widget.origin == DisputeOrigin.deliveryCheck
      ? l.disputeSheetTitleDelivery
      : l.disputeSheetTitle;

  String _window(AppLocalizations l, int? hours) {
    if (hours == null) {
      return l.disputeErrDeadline;
    }
    return switch (widget.origin) {
      DisputeOrigin.booking => l.disputeWindowLeft(hours),
      DisputeOrigin.deliveryCheck => l.disputeWindowLeftDelivery(hours),
      DisputeOrigin.ticket => l.disputeWindowLeftTicket(hours),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final destructive = dark
        ? AppColorsDark.destructive
        : AppColors.destructive;
    final s = ref.watch(openDisputeControllerProvider(widget.args));
    final reasons = DisputeReason.offeredFor(widget.origin);
    final selected = s.reason == null ? null : reasons.indexOf(s.reason!);
    final length = s.descriptionLength;
    final error = s.error;
    final clock = ref.read(clockProvider);

    return PopScope(
      canPop: !s.dirty && !s.submitting,
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
            GestureDetector(
              key: const Key('dispute-sheet-header'),
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _drag = 0,
              onVerticalDragUpdate: (d) => _drag += d.delta.dy,
              onVerticalDragEnd: (d) {
                if (_drag > _dragToClose ||
                    d.velocity.pixelsPerSecond.dy > _flingToClose) {
                  _close();
                }
                _drag = 0;
              },
              child: Semantics(
                container: true,
                label: '${widget.summary.title}, ${widget.summary.subtitle}',
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          _title(l),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('dispute-close'),
                      tooltip: l.disputeSheetClose,
                      constraints: const BoxConstraints.tightFor(
                        width: AppSpace.s12,
                        height: AppSpace.s12,
                      ),
                      icon: const AppIcon(AppIcons.close),
                      onPressed: s.submitting ? null : _close,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CountdownText(
                      deadline: widget.closesAt,
                      now: clock,
                      interval: const Duration(minutes: 1),
                      builder: (_, left) => EscrowNotice(
                        key: const Key('dispute-window'),
                        icon: AppIcons.schedule,
                        maxLines: null,
                        text: _window(
                          l,
                          disputeHoursLeft(
                            widget.closesAt,
                            widget.closesAt.subtract(left),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s3),
                    Text(
                      l.disputeReasonTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpace.s2),
                    ReasonPicker(
                      reasons: [
                        for (final r in reasons) disputeReasonLabel(l, r),
                      ],
                      selected: selected != null && selected >= 0
                          ? selected
                          : null,
                      style: ReasonPickerStyle.chips,
                      // The description below is the explanation: no extra
                      // "other" field.
                      otherField: false,
                      onSelected: s.submitting
                          ? (_) {}
                          : (i) => _ctl.setReason(reasons[i]),
                    ),
                    const SizedBox(height: AppSpace.s3),
                    TextField(
                      key: const Key('dispute-description'),
                      enabled: !s.submitting,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: kDisputeDescriptionMax,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: _ctl.setDescription,
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => Text(
                            '$currentLength/$maxLength',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                      decoration: InputDecoration(
                        labelText: l.disputeDescriptionLabel,
                        hintText: l.disputeDescriptionHint,
                        hintMaxLines: 2,
                        alignLabelWithHint: true,
                        helperText:
                            length > 0 && length < kDisputeDescriptionMin
                            ? l.disputeDescriptionTooShort
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      l.disputeEvidenceTitle(s.photos.length),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpace.s2),
                    GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppSpace.s1,
                      crossAxisSpacing: AppSpace.s1,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final (i, p) in s.photos.indexed)
                          _EvidenceTile(
                            key: ValueKey(p.key),
                            index: i,
                            slot: p,
                            enabled: !s.submitting,
                            onRemove: () => _ctl.remove(p.key),
                            onRetry: () => _ctl.retry(p.key),
                          ),
                        if (s.photos.length < kDisputeMaxPhotos)
                          _AddTile(
                            label: l.disputeEvidenceAdd,
                            onTap: s.submitting ? null : _ctl.pick,
                          ),
                      ],
                    ),
                    if (s.hasFailedPhoto) ...[
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        l.disputeEvidenceFailed,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: destructive,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.s3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: AppIcon(AppIcons.lock, size: 14, color: muted),
                        ),
                        const SizedBox(width: AppSpace.s2),
                        Expanded(
                          child: Text(
                            l.disputeEvidenceNote,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpace.s3),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _errorText(l, error),
                          key: const Key('dispute-error'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: destructive,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            AppButton.primary(
              l.disputeSubmit,
              key: const Key('dispute-submit'),
              loading: s.submitting,
              onPressed:
                  s.canSubmit &&
                      disputeHoursLeft(widget.closesAt, clock()) != null
                  ? _submit
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

String _errorText(AppLocalizations l, String code) => switch (code) {
  'conflict' => l.disputeErrConflict,
  'deadline_passed' => l.disputeErrDeadline,
  'not_eligible' => l.disputeErrNotEligible,
  _ => l.disputeErrGeneric,
};

/// The dashed "add a photo" tile (mock `.ph.add`).
class _AddTile extends StatelessWidget {
  const _AddTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final line = Theme.of(context).colorScheme.outline;
    final ink = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final radius = BorderRadius.circular(AppRadius.sm);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          key: const Key('dispute-add-photo'),
          borderRadius: radius,
          onTap: onTap,
          child: CustomPaint(
            foregroundPainter: _DashedOutline(line, radius),
            child: Center(child: AppIcon(AppIcons.addPhoto, color: ink)),
          ),
        ),
      ),
    );
  }
}

/// One evidence photo at 1:1: the local file while it uploads (with its
/// ring), a retry overlay when it failed, and a remove button in the corner.
class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({
    super.key,
    required this.index,
    required this.slot,
    required this.enabled,
    required this.onRemove,
    required this.onRetry,
  });

  final int index;
  final EvidenceSlot slot;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    const ink = AppColors.foregroundInverse;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: scheme.surfaceContainerHighest),
          Image.file(
            File(slot.picked.path),
            fit: BoxFit.cover,
            cacheWidth: 360,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          if (slot.uploading) ...[
            const ColoredBox(color: AppColors.overlay),
            Center(
              child: UploadProgressRing(
                fraction: slot.progress,
                size: AppSpace.s8,
              ),
            ),
          ],
          if (slot.failed)
            Material(
              color: AppColors.overlay,
              child: InkWell(
                key: Key('dispute-photo-retry-$index'),
                onTap: enabled ? onRetry : null,
                child: Semantics(
                  button: true,
                  label: l.actionRetry,
                  child: const Center(
                    child: AppIcon(AppIcons.refresh, color: ink),
                  ),
                ),
              ),
            ),
          if (enabled)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                key: Key('dispute-photo-remove-$index'),
                tooltip: l.disputeEvidenceRemove,
                constraints: const BoxConstraints.tightFor(
                  width: AppSpace.s12,
                  height: AppSpace.s12,
                ),
                icon: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.overlay,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpace.s1),
                    child: AppIcon(AppIcons.close, size: 16, color: ink),
                  ),
                ),
                onPressed: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}

/// 1px dashed outline inside the rounded rect (mock `border: 1px dashed`).
class _DashedOutline extends CustomPainter {
  const _DashedOutline(this.color, this.radius);

  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(radius.toRRect((Offset.zero & size).deflate(0.5)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final PathMetric metric in path.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        canvas.drawPath(metric.extractPath(at, at + 4), paint);
        at += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) =>
      old.color != color || old.radius != radius;
}
