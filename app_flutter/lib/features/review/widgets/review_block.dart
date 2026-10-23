// S05.05 for a studio booking (mock `#S05.05-studio`): one `.vblk` group
// per subject, the member who shot it and the studio.
import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/features/review/review_controller.dart';

/// One reason chip of a [ReviewFormBlock]: its label, whether it is ticked
/// and what a tap does.
typedef ReviewChipSpec = ({String label, bool selected, VoidCallback onTap});

/// The top row of a block (mock `.vblk .row`): avatar, bold [title] with an
/// optional [mark], and what the verdict counts for ([note], e.g. "Tính cho
/// hồ sơ thợ").
class ReviewBlockHeader extends StatelessWidget {
  const ReviewBlockHeader({
    super.key,
    required this.title,
    required this.note,
    this.avatarUrl,
    this.mark,
  });

  final String title;
  final String note;
  final String? avatarUrl;
  final ProviderMarkKind? mark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = context.mutedForeground;
    return Row(
      children: [
        AppAvatar(
          url: avatarUrl,
          name: title,
          size: AppAvatarSize.xs,
          decorative: true,
        ),
        const SizedBox(width: AppSpace.s2),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (mark case final kind?) ...[
                const SizedBox(width: AppSpace.s1),
                ProviderMark(kind),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        Flexible(
          child: Text(
            note,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelMedium?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// The frame of a block (mock `.vblk`): a glass card read as one group
/// named [label] ("Đánh giá thợ Minh Trí").
class ReviewBlockFrame extends StatelessWidget {
  const ReviewBlockFrame({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.glass : AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: child,
        ),
      ),
    );
  }
}

/// A block of the form: [header], the compact [VerdictPad] (sides read
/// "… cho {subject}"), the brick [chips] once a brick is thrown, and the
/// comment field labelled [textLabel].
class ReviewFormBlock extends StatelessWidget {
  const ReviewFormBlock({
    super.key,
    required this.label,
    required this.header,
    required this.subject,
    required this.verdict,
    required this.hits,
    required this.onVerdict,
    required this.chips,
    required this.controller,
    required this.textLabel,
    required this.textKey,
    required this.enabled,
  });

  final String label;
  final Widget header;
  final String subject;
  final Verdict? verdict;
  final int hits;
  final void Function(VerdictKind? kind, int hits) onVerdict;
  final List<ReviewChipSpec> chips;
  final TextEditingController controller;
  final String textLabel;
  final Key textKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ReviewBlockFrame(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          const SizedBox(height: AppSpace.s2),
          VerdictPad(
            kind: switch (verdict) {
              Verdict.tomato => VerdictKind.tomato,
              Verdict.brick => VerdictKind.brick,
              null => null,
            },
            hits: hits,
            compact: true,
            subject: subject,
            enabled: enabled,
            onChanged: onVerdict,
          ),
          if (verdict == Verdict.brick) ...[
            const SizedBox(height: AppSpace.s2),
            Wrap(
              spacing: AppSpace.s1,
              runSpacing: AppSpace.s1,
              children: [
                for (final c in chips)
                  AppChip(
                    label: c.label,
                    selected: c.selected,
                    kind: AppChipKind.context,
                    onChanged: enabled ? (_) => c.onTap() : (_) {},
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.s2),
          TextField(
            key: textKey,
            controller: controller,
            enabled: enabled,
            minLines: 2,
            maxLines: 5,
            maxLength: ReviewController.maxTextLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: textLabel,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// A sent block, read-only: [header], the verdict badge and word, the
/// brick [reasons] and the [text].
class ReviewReadOnlyBlock extends StatelessWidget {
  const ReviewReadOnlyBlock({
    super.key,
    required this.label,
    required this.header,
    required this.verdict,
    required this.hits,
    required this.reasons,
    required this.text,
  });

  final String label;
  final Widget header;
  final Verdict verdict;
  final int hits;
  final List<String> reasons;
  final String text;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final kind = verdict == Verdict.tomato
        ? VerdictKind.tomato
        : VerdictKind.brick;
    return ReviewBlockFrame(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          const SizedBox(height: AppSpace.s2),
          Row(
            children: [
              VerdictBadge(kind: kind, hits: hits),
              const SizedBox(width: AppSpace.s2),
              Flexible(
                child: Text(
                  verdict == Verdict.tomato ? l.reviewTomato : l.reviewBrick,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s2),
            Wrap(
              spacing: AppSpace.s1,
              runSpacing: AppSpace.s1,
              children: [
                for (final r in reasons)
                  Semantics(
                    label: r,
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: AppChip(
                          label: r,
                          selected: true,
                          kind: AppChipKind.context,
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.s2),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
