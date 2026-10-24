import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/collab/collab_providers.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/features/collab/collab_controller.dart';
import 'package:photobooking/features/recruit/collab_terms_card.dart';

/// S27.06-me "Xem & nhận": "Cộng tác với {studio}", the collaboration terms
/// and "Tôi đồng ý điều khoản cộng tác"; the primary "Nhận lời cộng tác"
/// stays off until the box is ticked.
Future<void> showCollabAcceptSheet(BuildContext context, Collaboration c) =>
    showAppSheet<void>(
      context,
      builder: (_) => ScreenCode(
        ScreenCodes.collaboration,
        child: _AcceptSheet(collaboration: c),
      ),
    );

class _AcceptSheet extends ConsumerStatefulWidget {
  const _AcceptSheet({required this.collaboration});

  final Collaboration collaboration;

  @override
  ConsumerState<_AcceptSheet> createState() => _AcceptSheetState();
}

class _AcceptSheetState extends ConsumerState<_AcceptSheet> {
  bool _agreed = false;
  bool _sending = false;
  String? _error;

  Future<void> _accept() async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final c = widget.collaboration;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(collabRepositoryProvider)
          .respondInvite(c.studioId, accept: true, acceptTerms: true);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l.collabAcceptedToast(c.studioName))),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = collabErrorText(e, l);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: Column(
        key: const Key('collab-accept-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.collabAcceptSheetTitle(widget.collaboration.studioName),
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          CollabTermsCard(
            agreed: _agreed,
            onChanged: _sending ? null : (v) => setState(() => _agreed = v),
          ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s2),
              child: Text(
                e,
                key: const Key('collab-accept-error'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: AppSpace.s3),
          AppButton.primary(
            l.collabAcceptSheetConfirm,
            key: const Key('collab-accept-confirm'),
            loading: _sending,
            onPressed: _agreed && !_sending ? _accept : null,
          ),
        ],
      ),
    );
  }
}
