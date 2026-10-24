import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/collab/collab_providers.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/features/collab/collab_controller.dart';
import 'package:photobooking/features/studio/studio_errors.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Opens S26.02 "Mời thợ" over S26.01, or with [collaborator] "Mời cộng tác
/// viên" over S27.06 (mock `#S26.02-collab`).
Future<void> showInviteMemberSheet(
  BuildContext context, {
  bool collaborator = false,
}) => showAppSheet<void>(
  context,
  builder: (_) => ScreenCode(
    ScreenCodes.inviteMember,
    child: InviteMemberSheet(collaborator: collaborator),
  ),
);

/// Shortest name prefix the server searches (Decision 19).
const kInviteSearchMinChars = 2;

/// S26.02: search photographers by name and invite them. No gradient button:
/// each row has its own outline "Mời"; rows that cannot be invited are dimmed
/// with the reason; when the studio cannot send any invite (5 pending, full,
/// no actions left) every "Mời" is off and the last line says why.
///
/// With [collaborator] (S27, #151): the same search invites a collaborator
/// (`inviteCollaborator`); dimmed rows are the studio's own members, its
/// active collaborators, a pair ended less than 3 days ago ("Mời lại được
/// từ {date}") and unverified photographers; someone in another studio can
/// be invited (R6). The caps and the day's actions are S27's counters.
class InviteMemberSheet extends ConsumerStatefulWidget {
  const InviteMemberSheet({super.key, this.collaborator = false});

  final bool collaborator;

  @override
  ConsumerState<InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends ConsumerState<InviteMemberSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  int _searchSeq = 0;

  /// Null until the studio types [kInviteSearchMinChars] characters.
  AsyncValue<List<InviteCandidate>>? _results;

  /// Collaborator mode: the studio's latest relationship with each row.
  Map<String, Collaboration> _pairs = const {};
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
    var pairs = const <String, Collaboration>{};
    final next = await AsyncValue.guard(() async {
      final rows = await ref.read(studioRepositoryProvider).search(q);
      final uid = ref.read(authStateProvider).value?.uid;
      if (widget.collaborator && uid != null && rows.isNotEmpty) {
        final found = await ref.read(collabRepositoryProvider).pairsOf(uid, [
          for (final r in rows) r.uid,
        ]);
        pairs = {for (final p in found) p.collaboratorId: p};
      }
      return rows;
    });
    // A newer query wins.
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _results = next;
      _pairs = pairs;
    });
  }

  Future<void> _invite(InviteCandidate c) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = c.uid);
    final ok = widget.collaborator
        ? await runCollabAction(
            context,
            () => ref.read(collabRepositoryProvider).invite(c.uid),
          )
        : await runStudioAction(
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

  /// Why no invite can go out now, or null; '' while the numbers load
  /// (every "Mời" off, no line).
  String? _blockedReason(AppLocalizations l) {
    if (widget.collaborator) return _collabBlockedReason(l);
    final quota = ref.watch(studioQuotaProvider(true)).value;
    final relations = ref.watch(myStudioRelationsProvider).value ?? const [];
    final businessVerified =
        ref.watch(myIntroProvider).value?.businessVerified ?? false;
    final max = studioMaxMembers(businessVerified: businessVerified);
    if (quota?.exhausted ?? false) return l.studioQuotaOut;
    if (relations.openInvites >= kStudioMaxPendingInvites) {
      return l.studioInviteFullPending;
    }
    if (relations.atCap(max)) return l.studioInviteFullMembers(max);
    return null;
  }

  String? _collabBlockedReason(AppLocalizations l) {
    final counters = ref.watch(myRecruitCountersProvider).value;
    final facts = ref.watch(myProviderFactsProvider).value;
    if (counters == null || facts == null) return '';
    final now = ref.watch(clockProvider)();
    final until = counters.recruitBlockedUntil;
    if (until != null && counters.isBlocked(now)) {
      return l.recruitBlocked(formatDayMonth(toVn(until)));
    }
    if (counters.collabActionsLeft(now) <= 0) return l.studioQuotaOut;
    if (counters.pendingInviteCount >= kMaxPendingCollabInvites) {
      return l.studioInviteFullPending;
    }
    final max = collaboratorLimit(businessVerified: facts.businessVerified);
    if (counters.activeCollabCount >= max) return l.collabErrorFull;
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
                    widget.collaborator ? l.collabInvite : l.studioInviteTitle,
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
              hintText: widget.collaborator
                  ? l.collabInviteSearch
                  : l.studioInviteSearch,
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
                      widget.collaborator
                          ? _CollaboratorLine(
                              key: ValueKey('invite-row-${c.uid}'),
                              candidate: c,
                              pair: _pairs[c.uid],
                              now: ref.watch(clockProvider)(),
                              invited: _invited.contains(c.uid),
                              sending: _sending == c.uid,
                              onInvite: blocked != null || _sending != null
                                  ? null
                                  : () => _invite(c),
                            )
                          : _CandidateLine(
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
          if (blocked != null && blocked.isNotEmpty)
            Text(
              blocked,
              key: const Key('invite-blocked'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          Text(
            widget.collaborator ? l.collabInviteFooter : l.studioInviteFootnote,
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

/// A row of the collaborator mode (`#S26.02-collab`): why it cannot be
/// invited, or the photographer's % and area with "Mời".
class _CollaboratorLine extends StatelessWidget {
  const _CollaboratorLine({
    super.key,
    required this.candidate,
    required this.pair,
    required this.now,
    required this.invited,
    required this.sending,
    required this.onInvite,
  });

  final InviteCandidate candidate;

  /// The studio's latest relationship with them, if any.
  final Collaboration? pair;
  final DateTime now;
  final bool invited;
  final bool sending;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = candidate;
    final p = pair;
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final mark = c.verified ? ProviderMarkKind.verified : null;
    MemberRow dimmed(String why) => MemberRow(
      avatarUrl: c.avatarUrl,
      name: c.name,
      mark: mark,
      enabled: false,
      meta: [MetaPart.text(why)],
    );
    final endedAt = p?.endedAt;
    final reinviteFrom = p?.status == CollabStatus.ended && endedAt != null
        ? endedAt.add(const Duration(days: kCollabReinviteDays))
        : null;
    if (c.state == InviteState.member) return dimmed(l.collabInviteRowMember);
    // A pending S26 member invite: the server refuses a collaborator invite.
    if (c.state == InviteState.invited) {
      return dimmed(l.collabInviteRowMemberInvited);
    }
    if (p?.status == CollabStatus.active) {
      return dimmed(l.collabInviteRowActive);
    }
    if (reinviteFrom != null && now.isBefore(reinviteFrom)) {
      return dimmed(
        l.collabInviteRowCooldown(formatDayMonth(toVn(reinviteFrom))),
      );
    }
    if (!c.verified) return dimmed(l.collabInviteRowUnverified);
    final pending =
        invited ||
        (p?.status == CollabStatus.invited && now.isBefore(p!.expiresAt));
    return MemberRow(
      avatarUrl: c.avatarUrl,
      name: c.name,
      mark: mark,
      meta: [
        if (c.tomatoPct case final pct?) MetaPart.tomato(pct),
        if (c.areaLabel case final area?) MetaPart.text(area),
      ],
      trailing: pending
          ? Text(
              l.studioInviteInvited,
              key: Key('invited-${c.uid}'),
              style: TextStyle(fontSize: AppText.xs2, color: secondary),
            )
          : AppButton.outline(
              l.collabInviteAction,
              key: Key('invite-${c.uid}'),
              size: AppButtonSize.xsmall,
              loading: sending,
              onPressed: onInvite,
            ),
    );
  }
}
