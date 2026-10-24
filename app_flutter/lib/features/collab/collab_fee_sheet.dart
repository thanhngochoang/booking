import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/collab/collab_providers.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/features/collab/collab_controller.dart';

/// S27.06 "Sửa thù lao gợi ý": the fee S26.04 fills in when the studio
/// sends this collaborator a job; empty clears it.
Future<void> showCollabFeeSheet(BuildContext context, Collaboration c) =>
    showAppSheet<void>(
      context,
      builder: (_) => ScreenCode(
        ScreenCodes.collaboration,
        child: _FeeSheet(collaboration: c),
      ),
    );

class _FeeSheet extends ConsumerStatefulWidget {
  const _FeeSheet({required this.collaboration});

  final Collaboration collaboration;

  @override
  ConsumerState<_FeeSheet> createState() => _FeeSheetState();
}

class _FeeSheetState extends ConsumerState<_FeeSheet> {
  late final _amount = TextEditingController(
    text: switch (widget.collaboration.defaultFee) {
      final fee? => groupVnd(fee),
      null => '',
    },
  );
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final text = _amount.text.trim();
    final fee = text.isEmpty ? null : parseVnd(text);
    if (text.isNotEmpty && !isValidCollabFee(fee)) {
      setState(() => _error = l.collabFeeInvalid);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(collabRepositoryProvider)
          .setDefaultFee(widget.collaboration.collaboratorId, fee);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.collabFeeSaved)));
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
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.s4,
        0,
        AppSpace.s4,
        AppSpace.s4 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        key: const Key('collab-fee-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l.collabFeeSheetTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpace.s1),
          Text(
            l.collabFeeHint(widget.collaboration.collaboratorName),
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpace.s3),
          TextField(
            key: const Key('collab-fee-field'),
            controller: _amount,
            enabled: !_sending,
            keyboardType: TextInputType.number,
            inputFormatters: const [VndInputFormatter()],
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              suffixText: l.recruitFeeAmountSuffix,
              errorText: _error,
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          AppButton.primary(
            l.collabFeeSave,
            key: const Key('collab-fee-save'),
            loading: _sending,
            onPressed: _sending ? null : _save,
          ),
        ],
      ),
    );
  }
}
