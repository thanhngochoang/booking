import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/collab/collab_member_view.dart';
import 'package:photobooking/features/collab/collab_studio_view.dart';
import 'package:photobooking/features/studio/invite_member_sheet.dart';

/// S27.06 `/collab` (query `offer` opens S27.07): a studio sees its
/// collaborators, what it owes and its invites ([CollabStudioView], one
/// primary "Mời cộng tác viên"); an individual or artist sees offers,
/// studios, invites and pay ([CollabMemberView], no primary).
class CollabScreen extends ConsumerWidget {
  const CollabScreen({super.key, this.offerBookingId});

  /// The booking of an offer to open on load (`/collab?offer=…`).
  final String? offerBookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final facts = ref.watch(myProviderFactsProvider);
    final studio = facts.value?.isStudio ?? false;
    return ScreenCode(
      ScreenCodes.collaboration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l.collabTitle)),
        body: AsyncView<ProviderFacts?>(
          value: facts,
          onRetry: () => ref.invalidate(myProviderFactsProvider),
          data: (context, f) {
            if (f == null || !f.isProviderAccount) {
              return const SizedBox.shrink();
            }
            return f.isStudio
                ? const CollabStudioView()
                : CollabMemberView(offerBookingId: offerBookingId);
          },
        ),
        bottomNavigationBar: studio
            ? AppFooterBar(
                child: AppButton.primary(
                  l.collabInvite,
                  key: const Key('collab-invite'),
                  onPressed: () =>
                      showInviteMemberSheet(context, collaborator: true),
                ),
              )
            : null,
      ),
    );
  }
}
