// lib/features/awards/award_nudge.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/features/photographer_setup/stored_provider_type.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

String _key(String uid) => 'awardNudgeDismissed:$uid';

/// Whether this photographer tapped "Để sau" on the S09.01 awards nudge;
/// kept on this device as `awardNudgeDismissed:<uid>`.
class AwardNudgeDismissed extends Notifier<bool> {
  AwardNudgeDismissed(this.uid);
  final String uid;

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_key(uid)) ?? false;

  Future<void> dismiss() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_key(uid), true);
  }
}

final awardNudgeDismissedProvider = NotifierProvider.autoDispose
    .family<AwardNudgeDismissed, bool, String>(AwardNudgeDismissed.new);

/// S09.01: "Có giải thưởng? Lên hạng Nhiếp ảnh gia" for an individual who is
/// not yet an artist (a studio never has a tier). Opens S25.01; "Để sau"
/// hides it for good on this device.
class AwardNudgeRow extends ConsumerWidget {
  const AwardNudgeRow({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(liveProviderTypeProvider).value;
    // Only an individual sees it; nothing while the type is unknown.
    if (type != ProviderType.individual) {
      return const SizedBox.shrink();
    }
    if (ref.watch(awardNudgeDismissedProvider(uid))) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s4),
      child: GlassCard(
        highlight: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: l.profileAwardNudge,
              excludeSemantics: true,
              onTap: () => context.push('/me/awards'),
              child: InkWell(
                key: const Key('award-nudge'),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: () => context.push('/me/awards'),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSpace.s12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.s4,
                      AppSpace.s3,
                      AppSpace.s4,
                      AppSpace.s1,
                    ),
                    child: Row(
                      children: [
                        const AwardDisc(),
                        const SizedBox(width: AppSpace.s3),
                        Expanded(
                          child: Text(
                            l.profileAwardNudge,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const AppIcon(AppIcons.chevron),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpace.s2),
                child: TextButton(
                  key: const Key('award-nudge-later'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(AppSpace.s12, AppSpace.s12),
                  ),
                  onPressed: () => ref
                      .read(awardNudgeDismissedProvider(uid).notifier)
                      .dismiss(),
                  child: Text(l.profileAwardNudgeLater),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
