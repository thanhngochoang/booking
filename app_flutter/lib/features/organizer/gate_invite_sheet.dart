// lib/features/organizer/gate_invite_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/features/organizer/organizer_controller.dart';
import 'package:photobooking/features/organizer/widgets/organizer_parts.dart';

/// The invitee's side of S30.06 (`gate_staff_invited` opens
/// `/organizer/gate-staff`, which shows this sheet): "{org} mời bạn soát
/// vé", Nhận / Từ chối within 72 hours, else "Lời mời đã hết hạn". Answers
/// true (accepted), false (declined) or null (dismissed or expired).
Future<bool?> showGateInviteSheet(BuildContext context, GateStaff invite) =>
    showAppSheet<bool>(
      context,
      builder: (_) => GateInviteSheet(invite: invite),
    );

class GateInviteSheet extends ConsumerStatefulWidget {
  const GateInviteSheet({super.key, required this.invite});

  final GateStaff invite;

  @override
  ConsumerState<GateInviteSheet> createState() => _GateInviteSheetState();
}

class _GateInviteSheetState extends ConsumerState<GateInviteSheet> {
  bool? _busy;
  String? _error;

  Future<void> _answer(bool accept) async {
    final l = context.l10n;
    setState(() {
      _busy = accept;
      _error = null;
    });
    final code = await ref
        .read(organizerActionsProvider)
        .run(
          (r) => r.respondGateStaff(widget.invite.organizerId, accept: accept),
        );
    if (!mounted) return;
    if (code == null) {
      Navigator.of(context).pop(accept);
      return;
    }
    setState(() {
      _busy = null;
      _error = code == 'deadline_passed'
          ? l.s3006_expired
          : organizerErrorText(l, code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final org = ref.watch(organizerProvider(widget.invite.organizerId)).value;
    final open = widget.invite.inviteOpen(ref.watch(clockProvider)());
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s5,
        AppSpace.s2,
        AppSpace.s5,
        AppSpace.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          OrgSheetHeader(l.s3006_inviteTitle(org?.name ?? '')),
          const SizedBox(height: AppSpace.s3),
          OrgBand(text: l.s3006_scope, icon: AppIcons.lock),
          const SizedBox(height: AppSpace.s4),
          if (!open)
            OrgBand(
              key: const Key('gate-invite-expired'),
              text: l.s3006_expired,
              icon: AppIcons.hourglass,
              tone: OrgBandTone.warning,
            )
          else ...[
            if (_error case final e?) ...[
              OrgBand(text: e, icon: AppIcons.warning, tone: OrgBandTone.error),
              const SizedBox(height: AppSpace.s3),
            ],
            AppButton.primary(
              l.s3006_accept,
              key: const Key('gate-invite-accept'),
              loading: _busy == true,
              onPressed: _busy == null ? () => _answer(true) : null,
            ),
            const SizedBox(height: AppSpace.s2),
            AppButton.outline(
              l.s3006_decline,
              key: const Key('gate-invite-decline'),
              loading: _busy == false,
              onPressed: _busy == null ? () => _answer(false) : null,
            ),
          ],
        ],
      ),
    );
  }
}
