// lib/features/booking/steps/place_step.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
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
  bool _edited = false;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(bookingFlowControllerProvider(widget.args)).placeName;
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

    return ScreenCode(
      ScreenCodes.bookReview, // place step is part of S04 flow
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
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: AppButton.primary(
              l10n.bookContinuePrice(formatMoney(state.priceVnd ?? 0)),
              onPressed: state.canContinue ? controller.next : null,
            ),
          ),
        ],
      ),
    );
  }
}
