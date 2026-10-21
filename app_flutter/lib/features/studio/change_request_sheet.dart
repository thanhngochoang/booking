import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/studio/studio_common.dart';
import 'package:photobooking/features/studio/studio_errors.dart';

/// Opens S26.05 "Xin đổi thợ chụp" over S05.02 for [booking]'s assignee;
/// true once the server took the request, which the sheet confirms with
/// "Đã gửi yêu cầu đổi thợ" as it closes.
Future<bool> showChangeRequestSheet(BuildContext context, Booking booking) =>
    showAppSheet<bool>(
      context,
      builder: (_) => ScreenCode(
        ScreenCodes.requestPhotographerChange,
        child: ChangeRequestSheet(booking: booking),
      ),
    ).then((v) => v ?? false);

/// S26.05 (mock `#S26.05`): the current member, an optional reason, the two
/// lines of what happens next (6 hours; a refusal or no answer opens the
/// 100% cancel), "Bạn chỉ xin đổi được 1 lần." and the one primary "Gửi
/// yêu cầu đổi" (Decision 13).
class ChangeRequestSheet extends ConsumerStatefulWidget {
  const ChangeRequestSheet({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<ChangeRequestSheet> createState() => _ChangeRequestSheetState();
}

class _ChangeRequestSheetState extends ConsumerState<ChangeRequestSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sent = context.l10n.changeSent;
    final note = _controller.text.trim();
    final ok = await runStudioAction(
      context,
      () => ref
          .read(bookingRepositoryProvider)
          .requestChange(widget.booking.id, note: note.isEmpty ? null : note),
    );
    if (!mounted) return;
    if (ok) {
      navigator.pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(sent)));
    } else {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final assigneeId = widget.booking.studio?.assigneeId;
    return SingleChildScrollView(
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
                  child: Text(l.changeTitle, style: theme.textTheme.titleLarge),
                ),
              ),
              IconButton(
                key: const Key('change-close'),
                tooltip: l.studioSheetClose,
                icon: const AppIcon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s2),
          if (assigneeId != null)
            AsyncView<PhotographerProfile?>(
              value: ref.watch(photographerProfileProvider(assigneeId)),
              loaderSize: LoaderSize.inline,
              skeleton: (_) => MemberRow.skeleton(),
              onRetry: () =>
                  ref.invalidate(photographerProfileProvider(assigneeId)),
              data: (context, p) {
                final s = p?.summary;
                return StudioRowsCard(
                  rows: [
                    MemberRow(
                      key: const Key('change-current'),
                      avatarUrl: s?.avatarUrl,
                      name: s?.displayName ?? '',
                      mark: s?.verified == true
                          ? ProviderMarkKind.verified
                          : null,
                      meta: [
                        MetaPart.text(l.changeCurrent),
                        if (s != null && s.hasTomatoPct)
                          MetaPart.tomato(s.tomatoPct),
                      ],
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: AppSpace.s3),
          TextField(
            key: const Key('change-reason'),
            controller: _controller,
            enabled: !_sending,
            minLines: 2,
            maxLines: 4,
            maxLength: kStudioReasonMaxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.changeReasonLabel),
          ),
          const SizedBox(height: AppSpace.s2),
          _InfoBox(
            key: const Key('change-notes'),
            text: '${l.changeNoteRespond}\n${l.changeNoteRefund}',
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            l.changeOnce,
            style: theme.textTheme.bodySmall?.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpace.s3),
          AppButton.primary(
            l.changeSend,
            key: const Key('change-send'),
            loading: _sending,
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}

/// Mock `.esc` with the info icon: a soft accent box whose text wraps.
class _InfoBox extends StatelessWidget {
  const _InfoBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2h,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(
                AppIcons.info,
                size: AppIconSize.sm,
                color: dark
                    ? AppColorsDark.foregroundMuted
                    : AppColors.foregroundMuted,
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: dark
                        ? AppColorsDark.foreground
                        : AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
