// lib/features/organizer/widgets/invite_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/organizer/organizer_controller.dart';
import 'package:photobooking/features/organizer/widgets/organizer_parts.dart';

/// The target `inviteGateStaff` gets: an `@username` as typed, a Vietnamese
/// number as E.164, anything else trimmed (the server answers `not_found`).
/// The server resolves verified phone numbers only for now, so an
/// `@username` answers `not_found` until usernames exist.
String gateInviteTarget(String raw) {
  final t = raw.trim();
  if (t.startsWith('@')) return t;
  return normalizePhone(t) ?? t;
}

/// S30.06 "Mời nhân viên": answers true once the invite is sent.
Future<bool> showInviteStaffSheet(BuildContext context) => showAppSheet<bool>(
  context,
  builder: (_) => const GateInviteForm(),
).then((v) => v ?? false);

class GateInviteForm extends ConsumerStatefulWidget {
  const GateInviteForm({super.key});

  @override
  ConsumerState<GateInviteForm> createState() => _GateInviteFormState();
}

class _GateInviteFormState extends ConsumerState<GateInviteForm> {
  final _target = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = context.l10n;
    if (_target.text.trim().isEmpty) {
      setState(() => _error = l.s3006_targetRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final code = await ref
        .read(organizerActionsProvider)
        .run((r) => r.inviteGateStaff(gateInviteTarget(_target.text)));
    if (!mounted) return;
    if (code == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = switch (code) {
        'not_found' || 'invalid_argument' => l.s3006_notFound,
        'limit_exceeded' => l.s3006_limit,
        _ => organizerErrorText(l, code),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.s5,
        AppSpace.s2,
        AppSpace.s5,
        AppSpace.s5 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          OrgSheetHeader(l.s3006_invite),
          const SizedBox(height: AppSpace.s3),
          TextField(
            key: const Key('invite-target'),
            controller: _target,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l.s3006_target,
              errorText: _error,
            ),
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: AppSpace.s3),
          OrgBand(text: l.s3006_scope, icon: AppIcons.lock),
          const SizedBox(height: AppSpace.s4),
          AppButton.outline(
            l.s3006_inviteSend,
            key: const Key('invite-send'),
            loading: _busy,
            onPressed: _busy ? null : _send,
          ),
        ],
      ),
    );
  }
}
