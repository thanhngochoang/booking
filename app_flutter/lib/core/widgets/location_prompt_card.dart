import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/app_chip.dart';
import 'package:photobooking/core/widgets/glass_card.dart';

enum LocationPromptState { ask, requesting, denied }

/// Asks for location at the moment the user wants it (S13). It does not call
/// the OS permission dialog; the screen does that in [onAllow].
class LocationPromptCard extends StatelessWidget {
  const LocationPromptCard({
    super.key,
    required this.state,
    required this.onAllow,
    required this.onLater,
    this.onChooseArea,
  }) : assert(
         state != LocationPromptState.denied || onChooseArea != null,
         'denied needs onChooseArea',
       );

  final LocationPromptState state;
  final VoidCallback onAllow;
  final VoidCallback onLater;
  final VoidCallback? onChooseArea;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (state == LocationPromptState.denied) {
      return Align(
        alignment: Alignment.centerLeft,
        child: AppChip(
          key: const Key('location-choose-area'),
          label: l.locationChooseArea,
          selected: false,
          leading: const Icon(Icons.place_outlined),
          onChanged: (_) => onChooseArea!(),
        ),
      );
    }
    final theme = Theme.of(context);
    final requesting = state == LocationPromptState.requesting;
    final subtle = theme.brightness == Brightness.dark
        ? AppColorsDark.primarySubtle
        : AppColors.primarySubtle;
    final buttons = Wrap(
      spacing: AppSpace.s2,
      runSpacing: AppSpace.s2,
      children: [
        AppButton.primary(
          l.locationAllow,
          key: const Key('location-allow'),
          size: AppButtonSize.xsmall,
          tapAlignment: Alignment.topCenter,
          loading: requesting,
          onPressed: requesting ? null : onAllow,
        ),
        AppButton.outline(
          l.locationLater,
          key: const Key('location-later'),
          size: AppButtonSize.xsmall,
          tapAlignment: Alignment.topCenter,
          onPressed: requesting ? null : onLater,
        ),
      ],
    );
    // Mock S13 `.card.hi`: 36dp accent-soft icon, bold 13px title, body,
    // then two compact buttons inside the text column.
    return GlassCard(
      highlight: !requesting,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s3,
          AppSpace.s3,
          AppSpace.s3,
          0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              key: const Key('location-prompt-icon'),
              decoration: BoxDecoration(color: subtle, shape: BoxShape.circle),
              child: SizedBox.square(
                dimension: 36,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s2h),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l.locationPromptTitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s1),
                  Text(l.locationPromptBody, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpace.s2),
                  buttons,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
