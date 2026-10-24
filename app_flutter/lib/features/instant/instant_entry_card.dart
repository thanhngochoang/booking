// S02.01 (`#S02.01-instant`): the Chụp ngay entry under the Home greeting.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';

/// Chụp ngay is on and the viewer is a customer (Decision 9).
bool instantEntryVisible(WidgetRef ref) =>
    ref.watch(instantEnabledProvider) &&
    ref.watch(
      currentProfileProvider.select((p) => p.value?.role == UserRole.customer),
    );

/// "Chụp ngay" → `/instant`; with an open request "Yêu cầu chụp ngay đang
/// mở" → `/instant/{id}`. Nothing (and nothing read) while hidden.
class InstantEntryCard extends ConsumerWidget {
  const InstantEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!instantEntryVisible(ref)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s3,
      ),
      child: AsyncView<String?>(
        value: ref.watch(instantActiveRequestIdProvider),
        skeleton: (_) => AppSkeleton.card(height: 64),
        // The read failed: the plain entry; creating says if one is open.
        error: (_, _, _) => const _Card(activeId: null),
        data: (_, id) => _Card(activeId: id),
      ),
    );
  }
}

/// Mock `.card.hi`: bolt tile, title, line, chevron.
class _Card extends StatelessWidget {
  const _Card({required this.activeId});

  final String? activeId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final radius = BorderRadius.circular(AppRadius.card);
    final id = activeId;
    final title = id == null ? l.instantTitle : l.instantCardResumeTitle;
    final line = id == null ? l.instantCardBody : l.instantCardResumeBody;
    return Semantics(
      link: true,
      label: '$title. $line',
      excludeSemantics: true,
      onTap: () => _open(context, id),
      child: DecoratedBox(
        key: const Key('instant-entry-card'),
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.surface : AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: dark ? AppColorsDark.borderStrong : AppColors.borderStrong,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: () => _open(context, id),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s3),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Center(
                      child: AppIcon(
                        AppIcons.instant,
                        size: 20,
                        color: secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  AppIcon(AppIcons.chevron, size: 20, color: secondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _open(BuildContext context, String? id) =>
      context.push(id == null ? '/instant' : '/instant/$id');
}
