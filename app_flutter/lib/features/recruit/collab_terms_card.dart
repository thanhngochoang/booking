import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';

/// "Điều khoản cộng tác" (S27.03, and the invite acceptance of S27.06): the
/// three minimum terms (to be reviewed by a lawyer before going live) and
/// the checkbox "Tôi đồng ý điều khoản cộng tác".
class CollabTermsCard extends StatelessWidget {
  const CollabTermsCard({
    super.key,
    required this.agreed,
    required this.onChanged,
  });

  final bool agreed;

  /// Null disables the checkbox (while sending).
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final termStyle = TextStyle(
      fontSize: AppText.xs2,
      height: 1.4,
      color: secondary,
    );
    final change = onChanged;
    return Column(
      key: const Key('collab-terms'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? AppColorsDark.glass : AppColors.glass,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s3,
              vertical: AppSpace.s2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l.collabTermsTitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s1),
                for (final term in [
                  l.collabTerm1,
                  l.collabTerm2,
                  l.collabTerm3,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(child: Text('•  ', style: termStyle)),
                        Expanded(child: Text(term, style: termStyle)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Its own Material: the sheet's glass would hide the ink.
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            key: const Key('collab-terms-agree'),
            value: agreed,
            onChanged: change == null ? null : (v) => change(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l.collabTermsAgree, style: theme.textTheme.bodySmall),
          ),
        ),
      ],
    );
  }
}
