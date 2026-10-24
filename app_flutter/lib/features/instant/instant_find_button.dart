// S02.06 (`#S02.06-instant`): the Chụp ngay outline button above the result
// count of Tìm thợ ảnh. Not the screen's primary ("Đặt" on each card is).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant/instant_entry_card.dart';

/// Opens S13.01, or the open request when there is one (mock caption). The
/// open request is read on tap, not on every Find open.
class InstantFindButton extends ConsumerStatefulWidget {
  const InstantFindButton({super.key});

  @override
  ConsumerState<InstantFindButton> createState() => _InstantFindButtonState();
}

class _InstantFindButtonState extends ConsumerState<InstantFindButton> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    String? active;
    try {
      active = await ref.read(instantRepositoryProvider).myActiveRequestId();
    } on Object {
      // Creating says if one is open (`conflict`).
      active = null;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    context.push(active == null ? '/instant' : '/instant/$active');
  }

  @override
  Widget build(BuildContext context) {
    if (!instantEntryVisible(ref)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        0,
      ),
      child: AppButton.outline(
        context.l10n.instantFindButton,
        key: const Key('instant-find-button'),
        size: AppButtonSize.small,
        icon: const AppIcon(AppIcons.instant, size: 16),
        loading: _busy,
        onPressed: _busy ? null : _open,
      ),
    );
  }
}
