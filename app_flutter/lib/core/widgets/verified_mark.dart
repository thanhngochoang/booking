// lib/core/widgets/verified_mark.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/provider_mark.dart';

/// Verified photographer: a small blue disc with a white check, no text.
/// Not used for badges (those are purple); see spec 3d.1.
class VerifiedMark extends StatelessWidget {
  const VerifiedMark({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.verifiedLabel;
    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: size,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.verified,
                shape: BoxShape.circle,
              ),
              child: AppIcon(
                AppIcons.check,
                size: size * 0.72,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A name followed by [VerifiedMark].
///
/// Thin wrapper over [ProviderName]; kept for one release.
@Deprecated('Use ProviderName(name, mark: ProviderMarkKind.verified).')
class VerifiedName extends StatelessWidget {
  const VerifiedName(this.name, {super.key, this.style});

  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) =>
      ProviderName(name, mark: ProviderMarkKind.verified, style: style);
}
