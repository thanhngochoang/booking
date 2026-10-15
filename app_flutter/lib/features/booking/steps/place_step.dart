// lib/features/booking/steps/place_step.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';

class PlaceStep extends ConsumerStatefulWidget {
  const PlaceStep({super.key, required this.args});
  final BookingFlowArgs args;

  @override
  ConsumerState<PlaceStep> createState() => _PlaceStepState();
}

class _PlaceStepState extends ConsumerState<PlaceStep> {
  late final TextEditingController _controller;
  late final TextEditingController _pickupController;
  bool _edited = false;
  bool _pickupEdited = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(bookingFlowControllerProvider(widget.args));
    _controller = TextEditingController(text: state.placeName);
    _pickupController = TextEditingController(text: state.pickupName);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pickupController.dispose();
    super.dispose();
  }

  void _onPickupChanged(String value) {
    if (!_pickupEdited) {
      setState(() => _pickupEdited = true);
    }
    ref.read(bookingFlowControllerProvider(widget.args).notifier).setPickup(value);
  }

  void _choosePickup(String text) {
    _pickupController.text = text;
    _pickupController.selection = TextSelection.collapsed(offset: text.length);
    setState(() => _pickupEdited = true);
    ref.read(bookingFlowControllerProvider(widget.args).notifier).setPickup(text);
  }

  void _onChanged(String value) {
    if (!_edited) {
      setState(() => _edited = true);
    }
    ref.read(bookingFlowControllerProvider(widget.args).notifier).setPlace(value);
  }

  void _chooseSuggestion(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    setState(() => _edited = true);
    ref.read(bookingFlowControllerProvider(widget.args).notifier).setPlace(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(bookingFlowControllerProvider(widget.args));
    final controller = ref.read(bookingFlowControllerProvider(widget.args).notifier);
    final profile = ref.watch(photographerProfileProvider(widget.args.photographerId)).value;

    final suggestions = <String>{};
    if (widget.args.area != null && widget.args.area!.trim().isNotEmpty) {
      suggestions.add(widget.args.area!.trim());
    }
    final areaLabel = profile?.summary.areaLabel;
    if (areaLabel != null && areaLabel.trim().isNotEmpty) {
      suggestions.add(areaLabel.trim());
    }

    final hasError = _edited && state.placeName.trim().length < kPlaceMinLength;
    final pickupShort =
        state.pickupName.trim().characters.length < kPlaceMinLength;
    final String? pickupError;
    if (state.error == BookingErrorCode.pickupRequired) {
      pickupError = l10n.bookPickupRequired;
    } else if (pickupShort && _pickupEdited) {
      pickupError = l10n.bookPlaceTooShort;
    } else {
      pickupError = null;
    }
    final transport = state.transportAddon;

    return ScreenCode(
      ScreenCodes.bookPlace,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s4,
              vertical: AppSpace.s2,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.bookPlaceTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpace.s2),
                  TextField(
                    controller: _controller,
                    maxLength: kPlaceMaxLength,
                    autofocus: true,
                    onChanged: _onChanged,
                    decoration: InputDecoration(
                      hintText: l10n.bookPlaceHint,
                      errorText: hasError ? l10n.bookPlaceTooShort : null,
                      counterText: '',
                    ),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s3),
                    Wrap(
                      spacing: AppSpace.s2,
                      runSpacing: AppSpace.s2,
                      children: [
                        for (final s in suggestions)
                          AppChip(
                            label: s,
                            selected: state.placeName == s,
                            kind: AppChipKind.context,
                            onChanged: (_) => _chooseSuggestion(s),
                          ),
                      ],
                    ),
                  ],
                  if (transport != null) ...[
                    const SizedBox(height: AppSpace.s4),
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              l10n.bookPickupTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpace.s2),
                        Flexible(
                          child: Text(
                            transport.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s2),
                    TextField(
                      key: const Key('book-pickup-field'),
                      controller: _pickupController,
                      maxLength: kPlaceMaxLength,
                      onChanged: _onPickupChanged,
                      decoration: InputDecoration(
                        labelText: l10n.bookPickupTitle,
                        hintText: l10n.bookPickupHint,
                        errorText: pickupError,
                        counterText: '',
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.s3),
                      Wrap(
                        spacing: AppSpace.s2,
                        runSpacing: AppSpace.s2,
                        children: [
                          for (final s in suggestions)
                            AppChip(
                              key: Key('book-pickup-chip-$s'),
                              label: s,
                              selected: state.pickupName == s,
                              kind: AppChipKind.context,
                              onChanged: (_) => _choosePickup(s),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpace.s3),
                    // Mock `.lockn`: the pickup stays between the two parties.
                    Row(
                      key: const Key('book-pickup-private'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppIcon(
                          AppIcons.lock,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpace.s2),
                        Expanded(
                          child: Text(
                            l10n.bookPickupPrivate,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: AppButton.primary(
              l10n.bookContinuePrice(formatMoney(state.totalVnd ?? 0)),
              onPressed: state.canContinue ? controller.next : null,
            ),
          ),
        ],
      ),
    );
  }
}
