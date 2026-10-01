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
    final allowButton = AppButton.primary(
      l.locationAllow,
      key: const Key('location-allow'),
      loading: requesting,
      onPressed: requesting ? null : onAllow,
    );
    final laterButton = AppButton.outline(
      l.locationLater,
      key: const Key('location-later'),
      onPressed: requesting ? null : onLater,
    );
    return GlassCard(
      highlight: !requesting,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: subtle,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.place_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l.locationPromptTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s1),
                      Text(
                        l.locationPromptBody,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            // Side by side normally; stacked when large text would wrap a label.
            if (MediaQuery.textScalerOf(context).scale(16) > 18.4)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  allowButton,
                  const SizedBox(height: AppSpace.s2),
                  laterButton,
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: allowButton),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(child: laterButton),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
