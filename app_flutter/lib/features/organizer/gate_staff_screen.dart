// lib/features/organizer/gate_staff_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/organizer/gate_invite_sheet.dart';
import 'package:photobooking/features/organizer/organizer_controller.dart';
import 'package:photobooking/features/organizer/widgets/invite_sheet.dart';
import 'package:photobooking/features/organizer/widgets/organizer_parts.dart';

/// Gate staff per organizer (`MAX_GATE_STAFF`).
const gateStaffMax = 10;

/// S30.06 "Nhân viên soát vé" at `/organizer/gate-staff` (mock `#S30.06`):
/// the organizer's gate staff with today's scans, "Mời nhân viên" (by
/// verified phone; an `@username` answers "Không tìm thấy tài khoản" until
/// usernames exist), and "Gỡ" behind a red confirm. The same path is where
/// `gate_staff_invited` leads the invitee: their open invite opens
/// [GateInviteSheet] once.
class GateStaffScreen extends ConsumerStatefulWidget {
  const GateStaffScreen({super.key});

  @override
  ConsumerState<GateStaffScreen> createState() => _GateStaffScreenState();
}

class _GateStaffScreenState extends ConsumerState<GateStaffScreen> {
  bool _inviteShown = false;

  Future<void> _openInvite(GateStaff invite) async {
    final l = context.l10n;
    final accepted = await showGateInviteSheet(context, invite);
    if (!mounted || accepted == null) return;
    orgSay(context, accepted ? l.s3006_accepted : l.s3006_declined);
  }

  Future<void> _invite(int live) async {
    final l = context.l10n;
    if (live >= gateStaffMax) {
      orgSay(context, l.s3006_limit);
      return;
    }
    final sent = await showInviteStaffSheet(context);
    if (sent && mounted) orgSay(context, l.s3006_inviteSent);
  }

  Future<void> _row(GateStaff g, String name) async {
    final l = context.l10n;
    final remove = await showAppSheet<bool>(
      context,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s5,
          AppSpace.s2,
          AppSpace.s5,
          AppSpace.s5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OrgSheetHeader(name),
            OrgBand(text: l.s3006_scope, icon: AppIcons.lock),
            const SizedBox(height: AppSpace.s3),
            OrgDangerText(
              l.s3006_remove,
              key: const Key('gate-remove'),
              onPressed: () => Navigator.of(sheet).pop(true),
            ),
          ],
        ),
      ),
    );
    if (remove != true || !mounted) return;
    final actions = ref.read(organizerActionsProvider);
    String? failed;
    final yes = await showConfirmSheet(
      context,
      title: l.s3006_removeTitle(name),
      confirmLabel: l.s3006_remove,
      keepLabel: l.s30_keep,
      onConfirm: () async {
        failed = await actions.run((r) => r.removeGateStaff(g.staffUid));
      },
    );
    if (!yes || !mounted) return;
    orgSay(
      context,
      failed == null ? l.s3006_removed : organizerErrorText(l, failed!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final org = ref.watch(myOrganizerProvider).value;
    final staff = ref.watch(gateStaffProvider).value ?? const <GateStaff>[];
    final invites =
        ref.watch(myGateInvitesProvider).value ?? const <GateStaff>[];
    final now = ref.watch(clockProvider)();
    final today = vnDateKey(now);
    final live = [
      for (final g in staff)
        if (g.status != GateStaffStatus.removed) g,
    ]..sort((a, b) => a.status.index.compareTo(b.status.index) * -1);
    final pending = [
      for (final g in invites)
        if (g.status == GateStaffStatus.invited) g,
    ];
    if (!_inviteShown && pending.isNotEmpty) {
      _inviteShown = true;
      final first = pending.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openInvite(first);
      });
    }

    return ScreenCode(
      ScreenCodes.gateStaff,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(l.s3006_title),
            actions: [
              if (org != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpace.s4),
                  child: Center(
                    child: Text(
                      l.s3006_count(live.length),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.mutedForeground,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpace.s5),
            children: [
              for (final g in pending) ...[
                _InviteRow(invite: g, onTap: () => _openInvite(g)),
                const SizedBox(height: AppSpace.s2),
              ],
              if (org != null) ...[
                if (live.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.s3),
                    child: Text(
                      l.s3006_empty,
                      style: TextStyle(color: context.mutedForeground),
                    ),
                  ),
                for (final g in live) ...[
                  _StaffRow(
                    staff: g,
                    today: today,
                    now: now,
                    onTap: (name) => _row(g, name),
                  ),
                  const SizedBox(height: AppSpace.s2),
                ],
              ],
              const SizedBox(height: AppSpace.s2),
              OrgBand(text: l.s3006_scope, icon: AppIcons.lock),
            ],
          ),
          bottomNavigationBar: org == null
              ? null
              : AppFooterBar(
                  child: AppButton.primary(
                    l.s3006_invite,
                    key: const Key('gate-invite'),
                    onPressed: org.isActive ? () => _invite(live.length) : null,
                  ),
                ),
        ),
      ),
    );
  }
}

class _StaffRow extends ConsumerWidget {
  const _StaffRow({
    required this.staff,
    required this.today,
    required this.now,
    required this.onTap,
  });

  final GateStaff staff;
  final String today;
  final DateTime now;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final profile = ref.watch(partyProfileProvider(staff.staffUid)).value;
    final name = profile?.displayName ?? '';
    final active = staff.status == GateStaffStatus.active;
    final hours = now.difference(staff.invitedAt).inHours;
    final meta = active
        ? l.s3006_scansToday(staff.scansOn(today))
        : staff.inviteOpen(now)
        ? l.s3006_invitedAgo(hours < 1 ? 1 : hours)
        : l.s3006_expired;
    return GlassCard(
      highlight: false,
      child: InkWell(
        key: Key('gate-${staff.staffUid}'),
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => onTap(name),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Row(
            children: [
              AppAvatar(url: profile?.avatarUrl, name: name),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              OrgBadge(
                active ? l.s3006_active : l.s3006_invited,
                pending: !active,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An invite naming me (the invitee): the organizer and "Đã mời".
class _InviteRow extends ConsumerWidget {
  const _InviteRow({required this.invite, required this.onTap});

  final GateStaff invite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final org = ref.watch(organizerProvider(invite.organizerId)).value;
    return GlassCard(
      highlight: false,
      child: ListTile(
        key: Key('gate-invite-${invite.organizerId}'),
        leading: const AppIcon(AppIcons.qrCode),
        title: Text(org?.name ?? ''),
        trailing: OrgBadge(l.s3006_invited, pending: true),
        onTap: onTap,
      ),
    );
  }
}
