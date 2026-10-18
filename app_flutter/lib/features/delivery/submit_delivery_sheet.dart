import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_providers.dart';
import 'package:photobooking/data/delivery/delivery_repository.dart';
import 'package:photobooking/features/delivery/submit_delivery_controller.dart';
import 'package:photobooking/features/delivery/widgets/sample_tile.dart';

/// Opens the S06.07 submit delivery sheet for [booking].
/// Returns the round number on success.
Future<int?> showSubmitDeliverySheet(
  BuildContext context, {
  required Booking booking,
}) {
  return showAppSheet<int>(
    context,
    isDismissible: true,
    enableDrag: true,
    builder: (sheetContext) => SubmitDeliverySheet(booking: booking),
  );
}

class SubmitDeliverySheet extends ConsumerStatefulWidget {
  const SubmitDeliverySheet({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<SubmitDeliverySheet> createState() => _SubmitDeliverySheetState();
}

class _SubmitDeliverySheetState extends ConsumerState<SubmitDeliverySheet> {
  late final TextEditingController _linkCtrl;
  late final TextEditingController _countCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _linkCtrl = TextEditingController();
    _countCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    _countCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final controller =
        ref.read(submitDeliveryControllerProvider(widget.booking).notifier);
    final state = ref.watch(submitDeliveryControllerProvider(widget.booking));

    final nextRound = widget.booking.deliveryRound + 1;
    final isRevision = widget.booking.deliveryRound >= 1;

    // Delivery rounds from provider to display customer's revision request notes
    final roundsAsync = ref.watch(deliveryRoundsProvider(widget.booking.id));
    final latestRound = roundsAsync.value?.isNotEmpty == true
        ? roundsAsync.value!.last
        : null;

    final blocked = state.blocked;

    return ScreenCode(
      ScreenCodes.submitDelivery,
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: Title & Close
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.deliverySubmitTitle(nextRound),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const AppIcon(AppIcons.close),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s2),

              // Round >= 2: Customer revision notes banner
              if (isRevision &&
                  (latestRound?.decision?.note != null ||
                      (latestRound?.decision?.photoNotes.isNotEmpty ?? false))) ...[
                _CustomerRevisionNotesBanner(
                  round: widget.booking.deliveryRound,
                  note: latestRound?.decision?.note,
                  photoNotes: latestRound?.decision?.photoNotes ?? const [],
                ),
                const SizedBox(height: AppSpace.s3),
              ],

              // Meta / Hint
              Text(
                l10n.deliverySamplesHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColorsDark.foregroundSecondary
                      : AppColors.foregroundSecondary,
                ),
              ),
              const SizedBox(height: AppSpace.s2),

              // Samples Grid: 3-column grid
              _buildSamplesGrid(context, controller, state),
              const SizedBox(height: AppSpace.s3),

              // Field: Link original photos
              TextFormField(
                controller: _linkCtrl,
                decoration: InputDecoration(
                  labelText: l10n.deliveryLinkLabel,
                  hintText: 'https://drive.google.com/...',
                  errorText: state.link.isNotEmpty && state.linkError != null
                      ? l10n.deliveryLinkInvalid
                      : null,
                ),
                onChanged: controller.setLink,
              ),
              const SizedBox(height: AppSpace.s3),

              // Row: Count (104 dp wide) + Note
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 104,
                    child: TextFormField(
                      controller: _countCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.deliveryCountLabel,
                        errorText:
                            state.count.isNotEmpty && state.countError != null
                                ? l10n.deliveryCountInvalid
                                : null,
                      ),
                      onChanged: controller.setCount,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: TextFormField(
                      controller: _noteCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.deliveryNoteLabel,
                      ),
                      onChanged: controller.setNote,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s2),

              // Lock note: Customer only sees link after approving samples
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: AppIcon(AppIcons.save, size: 14),
                  ),
                  const SizedBox(width: AppSpace.s1),
                  Expanded(
                    child: Text(
                      l10n.deliveryLockNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColorsDark.foregroundMuted
                            : AppColors.foregroundMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s4),

              // Submit error banner if any
              if (state.error != null) ...[
                _buildErrorBanner(context, state.error!),
                const SizedBox(height: AppSpace.s2),
              ],

              // Primary submit button
              AppButton.primary(
                l10n.deliverySubmit,
                loading: state.submitting,
                onPressed: blocked != null || state.submitting
                    ? null
                    : () async {
                        final round = await controller.submit();
                        if (round != null && context.mounted) {
                          Navigator.of(context).pop(round);
                        }
                      },
              ),
              const SizedBox(height: AppSpace.s4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSamplesGrid(
    BuildContext context,
    SubmitDeliveryController controller,
    SubmitDeliveryState state,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final canAdd = state.tiles.length < 20;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.tiles.length + (canAdd ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpace.s2,
        mainAxisSpacing: AppSpace.s2,
      ),
      itemBuilder: (context, index) {
        if (index < state.tiles.length) {
          final tile = state.tiles[index];
          return SampleTile(
            key: ValueKey(tile.fileId),
            tile: tile,
            onRetry: () => controller.retryTile(tile.fileId),
            onRemove: () => controller.removeTile(tile.fileId),
          );
        }

        // Add tile
        return Semantics(
          button: true,
          label: l10n.deliveryAddSample,
          child: InkWell(
            onTap: controller.pickPhotos,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isDark ? AppColorsDark.border : AppColors.border,
                  style: BorderStyle.solid,
                ),
                color: isDark
                    ? AppColorsDark.surfaceMuted
                    : AppColors.surfaceMuted,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(AppIcons.add, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      l10n.deliveryAddSample,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner(BuildContext context, Object error) {
    final l10n = context.l10n;
    final errCode = deliveryErrorOf(error);
    final String msg = errCode == DeliveryErrorCode.notReady
        ? l10n.deliveryNotReady
        : error.toString();

    return Container(
      padding: const EdgeInsets.all(AppSpace.s2),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        msg,
        style: const TextStyle(
          color: AppColors.error,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _CustomerRevisionNotesBanner extends StatelessWidget {
  const _CustomerRevisionNotesBanner({
    required this.round,
    required this.note,
    required this.photoNotes,
  });

  final int round;
  final String? note;
  final List<DeliveryPhotoNote> photoNotes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        color: darkOr(isDark, AppColorsDark.glass, AppColors.glass),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(AppIcons.notifications, size: 16),
              const SizedBox(width: AppSpace.s1),
              Text(
                round > 0
                    ? l10n.deliveryCustomerNotesRound(round)
                    : l10n.deliveryCustomerNotes,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s1),
            Text(
              note!,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (photoNotes.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s2),
            for (final pn in photoNotes)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  l10n.deliveryPhotoNoteCaption(pn.sampleIndex + 1, pn.note),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColorsDark.foregroundSecondary
                        : AppColors.foregroundSecondary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static Color darkOr(bool isDark, Color dark, Color light) =>
      isDark ? dark : light;
}
