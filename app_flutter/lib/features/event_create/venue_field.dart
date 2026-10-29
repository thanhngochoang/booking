// lib/features/event_create/venue_field.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The words of an [EventForm.venueIssue] code (`EventField.venue`).
String venueErrorText(AppLocalizations l, String code) => switch (code) {
  'spot' => l.s1201_managedSpotRequired,
  'not_managed' => l.s1201_spotNotManaged,
  'managed' => l.s1201_spotManaged,
  'fee' => l.s1201_feeRequired,
  'amount' => l.s1201_amountRequired,
  'commitment' => l.s1201_commitmentRequired,
  _ => l.s1201_venueRequired,
};

/// "Địa điểm · bắt buộc" of S12.01 (mock `#S12.01-venue`, Decision 16): three
/// required options (managed spot, paid place, public place), the S29 spot
/// tile ([spotTile], the "Điểm chụp" sheet of S12.01-spot), then by kind:
/// the consent note (a managed spot of someone else), the place name and
/// "Đã gồm phí vào cửa" / "Chưa gồm" with the reference fee (paid place),
/// the commitment tick (public place); every host ticks the terms.
///
/// [error] is an [EventForm.venueIssue] code; it shows under the part it is
/// about. [termsError] shows "Đồng ý điều khoản để đăng" under the tick.
class VenueField extends StatefulWidget {
  const VenueField({
    super.key,
    required this.kind,
    required this.placeName,
    required this.feeIncluded,
    required this.feeVnd,
    required this.committed,
    required this.termsAccepted,
    required this.spotTile,
    required this.onKind,
    required this.onPlaceName,
    required this.onFeeIncluded,
    required this.onFee,
    required this.onCommitment,
    required this.onTerms,
    this.consentNote = false,
    this.error,
    this.termsError = false,
    this.enabled = true,
    this.focusNode,
  });

  final VenueKind? kind;
  final String placeName;
  final bool? feeIncluded;
  final int? feeVnd;
  final bool committed;
  final bool termsAccepted;
  final Widget spotTile;
  final ValueChanged<VenueKind> onKind;
  final ValueChanged<String> onPlaceName;
  final ValueChanged<bool> onFeeIncluded;
  final ValueChanged<int?> onFee;
  final ValueChanged<bool> onCommitment;
  final ValueChanged<bool> onTerms;

  /// "Chủ điểm cần đồng ý trong 72 giờ…": the chosen managed spot is not the
  /// host's own.
  final bool consentNote;
  final String? error;
  final bool termsError;
  final bool enabled;

  /// Focused by the error summary ("go to the field").
  final FocusNode? focusNode;

  @override
  State<VenueField> createState() => _VenueFieldState();
}

class _VenueFieldState extends State<VenueField> {
  late final _name = TextEditingController(text: widget.placeName);
  late final _fee = TextEditingController(
    text: widget.feeVnd == null ? '' : groupVnd(widget.feeVnd!),
  );
  final _nameFocus = FocusNode(debugLabel: 'venue-place-name');
  final _feeFocus = FocusNode(debugLabel: 'venue-fee-amount');

  @override
  void didUpdateWidget(VenueField old) {
    super.didUpdateWidget(old);
    // A spot fills the name, the spot's access the fee: show them unless the
    // field is being typed in.
    if (!_nameFocus.hasFocus && _name.text != widget.placeName) {
      _name.text = widget.placeName;
    }
    final fee = widget.feeVnd == null ? '' : groupVnd(widget.feeVnd!);
    if (!_feeFocus.hasFocus && parseVnd(_fee.text) != widget.feeVnd) {
      _fee.text = fee;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _fee.dispose();
    _nameFocus.dispose();
    _feeFocus.dispose();
    super.dispose();
  }

  bool _is(String? code, List<String> codes) =>
      code != null && codes.contains(code);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final kind = widget.kind;
    final error = widget.error;
    final enabled = widget.enabled;
    String? text(List<String> codes) =>
        _is(error, codes) ? venueErrorText(l, error!) : null;

    Widget option(VenueKind k, String label, String hint, IconData icon) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s2),
          child: Focus(
            focusNode: k == VenueKind.managedSpot ? widget.focusNode : null,
            skipTraversal: true,
            child: AppOptionTile(
              key: Key('venue-kind-${k.code}'),
              label: label,
              description: hint,
              icon: icon,
              selected: kind == k,
              enabled: enabled,
              onTap: () => widget.onKind(k),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l.s1201_venue, style: theme.textTheme.labelMedium),
        ),
        const SizedBox(height: AppSpace.s2),
        Semantics(
          container: true,
          label: l.s1201_venue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              option(
                VenueKind.managedSpot,
                l.s1201_venueManaged,
                l.s1201_venueManagedHint,
                AppIcons.store,
              ),
              option(
                VenueKind.paidPlace,
                l.s1201_venuePaid,
                l.s1201_venuePaidHint,
                AppIcons.ticket,
              ),
              option(
                VenueKind.publicPlace,
                l.s1201_venuePublic,
                l.s1201_venuePublicHint,
                AppIcons.park,
              ),
            ],
          ),
        ),
        if (text(['required']) case final e?) _VenueError(e),
        const SizedBox(height: AppSpace.s1),
        widget.spotTile,
        if (text(['spot', 'not_managed', 'managed']) case final e?)
          _VenueError(e),
        if (kind == VenueKind.managedSpot && widget.consentNote) ...[
          const SizedBox(height: AppSpace.s2),
          Text(
            l.s1201_consentNote,
            key: const Key('venue-consent-note'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.mutedForeground,
            ),
          ),
        ],
        if (kind == VenueKind.paidPlace) ...[
          const SizedBox(height: AppSpace.s3),
          TextField(
            key: const Key('venue-place-name'),
            controller: _name,
            focusNode: _nameFocus,
            enabled: enabled,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onChanged: widget.onPlaceName,
            decoration: InputDecoration(labelText: l.s1201_placeName),
          ),
          const SizedBox(height: AppSpace.s3),
          SegmentedTabs<bool?>(
            key: const Key('venue-fee-included'),
            options: [
              SegmentOption(
                value: true,
                label: l.s1201_feeIncluded,
                enabled: enabled,
              ),
              SegmentOption(
                value: false,
                label: l.s1201_feeNotIncluded,
                enabled: enabled,
              ),
            ],
            value: widget.feeIncluded,
            onChanged: (v) => widget.onFeeIncluded(v!),
          ),
          if (text(['fee']) case final e?) _VenueError(e),
          if (widget.feeIncluded == false) ...[
            const SizedBox(height: AppSpace.s3),
            TextField(
              key: const Key('venue-fee-amount'),
              controller: _fee,
              focusNode: _feeFocus,
              enabled: enabled,
              keyboardType: TextInputType.number,
              inputFormatters: const [VndInputFormatter()],
              onChanged: (v) => widget.onFee(parseVnd(v)),
              decoration: InputDecoration(
                labelText: l.s1201_feeAmount,
                errorText: text(['amount']),
                errorMaxLines: 2,
              ),
            ),
          ],
        ],
        if (kind == VenueKind.publicPlace) ...[
          const SizedBox(height: AppSpace.s2),
          _Tick(
            key: const Key('venue-commitment'),
            value: widget.committed,
            label: l.s1201_commitment,
            enabled: enabled,
            onChanged: widget.onCommitment,
          ),
          if (text(['commitment']) case final e?) _VenueError(e),
        ],
        const SizedBox(height: AppSpace.s2),
        _Tick(
          key: const Key('venue-terms'),
          value: widget.termsAccepted,
          label: l.s1201_terms,
          enabled: enabled,
          onChanged: widget.onTerms,
        ),
        if (widget.termsError) _VenueError(l.s1201_termsRequired),
      ],
    );
  }
}

/// Mock `.chk`: a leading checkbox and its label, the whole row tappable.
class _Tick extends StatelessWidget {
  const _Tick({
    super.key,
    required this.value,
    required this.label,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    value: value,
    onChanged: enabled ? (v) => onChanged(v ?? false) : null,
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
  );
}

/// Mock `.field .e`: a short error under a part of the field.
class _VenueError extends StatelessWidget {
  const _VenueError(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s1),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}
