import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/features/studio/studio_common.dart';
import 'package:photobooking/features/studio/studio_errors.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Opens S26.02 "Mời thợ" over S26.01.
Future<void> showInviteMemberSheet(BuildContext context) => showAppSheet<void>(
  context,
  builder: (_) =>
      const ScreenCode(ScreenCodes.inviteMember, child: InviteMemberSheet()),
);

/// Shortest name prefix the server searches (Decision 19).
const kInviteSearchMinChars = 2;

/// S26.02: search photographers by name and invite them. No gradient button:
/// each row has its own outline "Mời"; rows that cannot be invited are dimmed
/// with the reason; when the studio cannot send any invite (5 pending, full,
/// no actions left) every "Mời" is off and the last line says why.
class InviteMemberSheet extends ConsumerStatefulWidget {
  const InviteMemberSheet({super.key});

  @override
  ConsumerState<InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends ConsumerState<InviteMemberSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  int _searchSeq = 0;

  /// Null until the studio types [kInviteSearchMinChars] characters.
  AsyncValue<List<InviteCandidate>>? _results;
  final _invited = <String>{};
  String? _sending;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final q = text.trim();
    if (q.characters.length < kInviteSearchMinChars) {
      _searchSeq++;
      if (_results != null) setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    final seq = ++_searchSeq;
    setState(() => _results = const AsyncLoading());
    final next = await AsyncValue.guard(
      () => ref.read(studioRepositoryProvider).search(q),
    );
    // A newer query wins.
    if (!mounted || seq != _searchSeq) return;
    setState(() => _results = next);
  }

  Future<void> _invite(InviteCandidate c) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = c.uid);
    final ok = await runStudioAction(
      context,
      () => ref.read(studioRepositoryProvider).invite(c.uid),
    );
    if (!mounted) return;
    setState(() {
      _sending = null;
      if (ok) _invited.add(c.uid);
    });
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.studioInviteDone(c.name))),
      );
    }
  }

  /// Why no invite can go out now, or null.
  String? _blockedReason(AppLocalizations l) {
    final quota = ref.watch(studioQuotaProvider(true)).value;
    final relations = ref.watch(myStudioRelationsProvider).value ?? const [];
    final businessVerified =
        ref.watch(myIntroProvider).value?.businessVerified ?? false;
    final max = studioMaxMembers(businessVerified: businessVerified);
    final members = relations
        .where((r) => r.status == RelationStatus.active)
        .length;
    final invites = relations
        .where((r) => r.status == RelationStatus.invited)
        .length;
    if (quota?.exhausted ?? false) return l.studioQuotaOut;
    if (invites >= kStudioMaxPendingInvites) return l.studioInviteFullPending;
    if (members + invites >= max) return l.studioInviteFullMembers(max);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final blocked = _blockedReason(l);
    final results = _results;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.studioInviteTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                key: const Key('invite-close'),
                tooltip: l.studioSheetClose,
                icon: const AppIcon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          TextField(
            key: const Key('invite-search'),
            controller: _query,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.studioInviteSearch,
              prefixIcon: const AppIcon(AppIcons.search),
            ),
          ),
          if (results != null)
            Flexible(
              child: AsyncView<List<InviteCandidate>>(
                value: results,
                loaderSize: LoaderSize.inline,
                skeleton: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (var i = 0; i < 3; i++) MemberRow.skeleton()],
                ),
                onRetry: () => _onChanged(_query.text),
                isEmpty: (rows) => rows.isEmpty,
                empty: (_) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                  child: Text(
                    l.studioInviteNoResults,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondary,
                    ),
                  ),
                ),
                data: (context, rows) => ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: AppSpace.s2),
                  children: [
                    for (final c in rows)
                      _CandidateLine(
                        key: ValueKey('invite-row-${c.uid}'),
                        candidate: c,
                        invited:
                            c.state == InviteState.invited ||
                            _invited.contains(c.uid),
                        sending: _sending == c.uid,
                        onInvite: blocked != null || _sending != null
                            ? null
                            : () => _invite(c),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpace.s2),
          if (blocked != null)
            Text(
              blocked,
              key: const Key('invite-blocked'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          Text(
            l.studioInviteFootnote,
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _CandidateLine extends StatelessWidget {
  const _CandidateLine({
    super.key,
    required this.candidate,
    required this.invited,
    required this.sending,
    required this.onInvite,
  });

  final InviteCandidate candidate;
  final bool invited;
  final bool sending;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = candidate;
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final mark = c.verified ? ProviderMarkKind.verified : null;
    switch (c.state) {
      case InviteState.inStudio:
        return MemberRow(
          avatarUrl: c.avatarUrl,
          name: c.name,
          mark: mark,
          enabled: false,
          meta: [MetaPart.text(l.studioInviteInStudio(c.studioName ?? ''))],
        );
      case InviteState.cooldown:
        final from = c.availableFrom;
        return MemberRow(
          avatarUrl: c.avatarUrl,
          name: c.name,
          mark: mark,
          enabled: false,
          meta: [
            if (from != null)
              MetaPart.text(l.studioInviteCooldown(formatDayMonth(toVn(from)))),
          ],
        );
      case InviteState.member:
        return MemberRow(
          avatarUrl: c.avatarUrl,
          name: c.name,
          mark: mark,
          enabled: false,
          meta: [MetaPart.text(l.studioInviteMember)],
        );
      case InviteState.invitable || InviteState.invited:
        return MemberRow(
          avatarUrl: c.avatarUrl,
          name: c.name,
          mark: mark,
          meta: [
            if (c.tomatoPct case final pct?) MetaPart.tomato(pct),
            if (c.areaLabel case final area?) MetaPart.text(area),
          ],
          trailing: invited
              ? Text(
                  l.studioInviteInvited,
                  key: Key('invited-${c.uid}'),
                  style: TextStyle(fontSize: AppText.xs2, color: secondary),
                )
              : AppButton.outline(
                  l.studioInviteRowAction,
                  key: Key('invite-${c.uid}'),
                  size: AppButtonSize.xsmall,
                  loading: sending,
                  onPressed: onInvite,
                ),
        );
    }
  }
}
