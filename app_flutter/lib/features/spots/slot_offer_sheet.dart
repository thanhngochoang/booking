// lib/features/spots/slot_offer_sheet.dart
// S29.05 "Gói chia suất": cuts a schedule's window into short fixed-price
// slots. Saved and closed through the `saveSlotOffer` / `closeSlotOffer`
// callables only; no add-ons on a slot offer (T6).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/spots/spot_repository.dart';
import 'package:photobooking/data/spots/spot_rules.dart';
import 'package:photobooking/features/spots/spot_format.dart';

/// Opens S29.05 over S29.03: a new offer for [schedule], or [offer] to edit
/// (adds the red "Đóng gói"). The result is said in a SnackBar below.
Future<void> showSlotOfferSheet(
  BuildContext context, {
  required SpotSchedule schedule,
  SlotOffer? offer,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await showAppSheet<String>(
    context,
    builder: (_) => ScreenCode(
      ScreenCodes.spotSlotOffer,
      child: SlotOfferSheet(schedule: schedule, offer: offer),
    ),
  );
  if (message != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _Field { name, price, delivery, photos, edited }

class SlotOfferSheet extends ConsumerStatefulWidget {
  const SlotOfferSheet({super.key, required this.schedule, this.offer});

  final SpotSchedule schedule;
  final SlotOffer? offer;

  @override
  ConsumerState<SlotOfferSheet> createState() => _SlotOfferSheetState();
}

class _SlotOfferSheetState extends ConsumerState<SlotOfferSheet> {
  late final _name = TextEditingController(text: widget.offer?.name);
  late final _price = TextEditingController(
    text: widget.offer == null ? '' : groupVnd(widget.offer!.price),
  );
  late final _delivery = TextEditingController(
    text: '${widget.offer?.deliveryDays ?? 3}',
  );
  late final _photos = TextEditingController(
    text: '${widget.offer?.photoCount ?? 20}',
  );
  late final _edited = TextEditingController(
    text: '${widget.offer?.editedCount ?? 10}',
  );
  late int _slot = widget.offer?.slotMinutes ?? 30;
  late int _gap = widget.offer?.gapMinutes ?? 10;
  final Map<_Field, String> _errors = {};

  /// Not one field's: the offer limit, a network error.
  String? _formError;
  bool _busy = false;

  bool get _editing => widget.offer != null;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _delivery.dispose();
    _photos.dispose();
    _edited.dispose();
    super.dispose();
  }

  List<({String start, String end})> get _slots =>
      slotsFor(widget.schedule.window, _slot, _gap);

  void _clear(_Field f) {
    if (_errors.containsKey(f) || _formError != null) {
      setState(() {
        _errors.remove(f);
        _formError = null;
      });
    }
  }

  /// The client copy of the server's checks; empty when the form can go.
  Map<_Field, String> _check() {
    final l = context.l10n;
    final out = <_Field, String>{};
    final name = _name.text.trim().characters.length;
    if (name < kSlotNameMin || name > kSlotNameMax) {
      out[_Field.name] = l.slotOfferErrorName;
    }
    final price = parseVnd(_price.text);
    if (price == null || price < kSlotPriceMin || price > kSlotPriceMax) {
      out[_Field.price] = l.slotOfferErrorPrice;
    }
    final delivery = int.tryParse(_delivery.text);
    if (delivery == null || delivery < 1 || delivery > kSlotDeliveryMax) {
      out[_Field.delivery] = l.slotOfferErrorDelivery;
    }
    final photos = int.tryParse(_photos.text);
    if (photos == null || photos < 1 || photos > kSlotPhotosMax) {
      out[_Field.photos] = l.slotOfferErrorPhotos;
    }
    final edited = int.tryParse(_edited.text);
    if (edited == null || edited < 0 || (photos != null && edited > photos)) {
      out[_Field.edited] = l.slotOfferErrorEdited;
    }
    return out;
  }

  Future<void> _save() async {
    final l = context.l10n;
    final problems = _check();
    if (problems.isNotEmpty || _slots.isEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(problems);
        _formError = null;
      });
      return;
    }
    setState(() {
      _errors.clear();
      _formError = null;
      _busy = true;
    });
    try {
      await ref
          .read(spotRepositoryProvider)
          .saveOffer(
            SlotOfferInput(
              offerId: widget.offer?.id,
              scheduleId: widget.schedule.id,
              name: _name.text.trim(),
              price: parseVnd(_price.text)!,
              slotMinutes: _slot,
              gapMinutes: _gap,
              photoCount: int.parse(_photos.text),
              editedCount: int.parse(_edited.text),
              deliveryDays: int.parse(_delivery.text),
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop(l.slotOfferSaved);
    } catch (e) {
      if (!mounted) return;
      _refused(spotErrorOf(e));
    }
  }

  void _refused(SpotError e) {
    final l = context.l10n;
    setState(() {
      _busy = false;
      switch (e.code) {
        case SpotErrorCode.contactLeak:
          _errors[_Field.name] = l.slotOfferErrorContact;
        case SpotErrorCode.limitExceeded:
          _formError = l.slotOfferLimit;
        case SpotErrorCode.invalidArgument:
          switch (e.field) {
            case 'name':
              _errors[_Field.name] = l.slotOfferErrorName;
            case 'price':
              _errors[_Field.price] = l.slotOfferErrorPrice;
            case 'deliveryDays':
              _errors[_Field.delivery] = l.slotOfferErrorDelivery;
            case 'photoCount':
              _errors[_Field.photos] = l.slotOfferErrorPhotos;
            case 'editedCount':
              _errors[_Field.edited] = l.slotOfferErrorEdited;
            case 'slotMinutes' || 'gapMinutes':
              _formError = l.slotOfferErrorFit;
            default:
              _formError = l.spotScheduleError;
          }
        default:
          _formError = l.spotScheduleError;
      }
    });
  }

  Future<void> _close() async {
    final l = context.l10n;
    final offer = widget.offer!;
    Object? failure;
    final confirmed = await showConfirmSheet(
      context,
      title: l.slotOfferCloseTitle(offer.name),
      body: l.slotOfferCloseBody,
      confirmLabel: l.slotOfferClose,
      keepLabel: l.slotOfferKeep,
      onConfirm: () async {
        try {
          await ref.read(spotRepositoryProvider).closeOffer(offer.id);
        } catch (e) {
          failure = e;
        }
      },
    );
    if (!confirmed || !mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(l.slotOfferClosed);
    } else {
      setState(() => _formError = l.spotScheduleError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final s = widget.schedule;
    final slots = _slots;
    const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

    TextField number(
      _Field f,
      String key,
      TextEditingController c,
      String label, {
      int digits = 3,
      String? suffix,
    }) => TextField(
      key: Key(key),
      controller: c,
      enabled: !_busy,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(digits),
      ],
      style: tabular,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        errorText: _errors[f],
        errorMaxLines: 2,
      ),
      onChanged: (_) => _clear(f),
    );

    return PopScope(
      canPop: !_busy,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s5,
          0,
          AppSpace.s5,
          AppSpace.s5,
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
                    child: Text(
                      l.slotOfferTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('slot-offer-dismiss'),
                  tooltip: l.slotOfferDismiss,
                  icon: const AppIcon(AppIcons.close),
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            // The spot name comes from the (cached) directory.
            AsyncView<List<SpotEntry>>(
              value: ref.watch(spotDirectoryProvider),
              skeleton: (_) => AppSkeleton.line(width: 200),
              error: (_, _, _) => const SizedBox.shrink(),
              data: (context, all) => Text(
                l.slotOfferScheduleLine(
                  all.where((e) => e.spotId == s.spotId).firstOrNull?.name ??
                      '',
                  scheduleWeekdays(s.days),
                  s.window.start,
                  s.window.end,
                ),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            TextField(
              key: const Key('slot-offer-name'),
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.sentences,
              maxLength: kSlotNameMax,
              decoration: InputDecoration(
                labelText: l.slotOfferName,
                errorText: _errors[_Field.name],
                errorMaxLines: 2,
              ),
              onChanged: (_) => _clear(_Field.name),
            ),
            const SizedBox(height: AppSpace.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('slot-offer-price'),
                    controller: _price,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [VndInputFormatter()],
                    style: tabular,
                    decoration: InputDecoration(
                      labelText: l.slotOfferPrice,
                      errorText: _errors[_Field.price],
                      errorMaxLines: 3,
                    ),
                    onChanged: (_) => _clear(_Field.price),
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: number(
                    _Field.delivery,
                    'slot-offer-delivery',
                    _delivery,
                    l.slotOfferDelivery,
                    digits: 2,
                    suffix: l.slotOfferDeliveryUnit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: number(
                    _Field.photos,
                    'slot-offer-photos',
                    _photos,
                    l.slotOfferPhotos,
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: number(
                    _Field.edited,
                    'slot-offer-edited',
                    _edited,
                    l.slotOfferEdited,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s3),
            _MinutesStepper(
              keyPrefix: 'slot-minutes',
              title: l.slotOfferMinutes,
              range: l.slotOfferMinutesRange,
              value: _slot,
              min: kSlotMinutesMin,
              max: kSlotMinutesMax,
              enabled: !_busy,
              onChanged: (v) => setState(() {
                _slot = v;
                _formError = null;
              }),
            ),
            _MinutesStepper(
              keyPrefix: 'slot-gap',
              title: l.slotOfferGap,
              range: l.slotOfferGapRange,
              value: _gap,
              min: 0,
              max: kSlotGapMax,
              enabled: !_busy,
              onChanged: (v) => setState(() {
                _gap = v;
                _formError = null;
              }),
            ),
            const SizedBox(height: AppSpace.s2),
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(
                    AppIcons.schedule,
                    size: 18,
                    color: slots.isEmpty ? theme.colorScheme.error : muted,
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Text(
                      slots.isEmpty
                          ? l.slotOfferErrorFit
                          : l.slotOfferPreview(
                              slots.length,
                              slotPreviewTimes(slots),
                            ),
                      key: const Key('slot-offer-preview'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: slots.isEmpty ? theme.colorScheme.error : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(AppIcons.info, size: 18, color: muted),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Text(
                    l.slotOfferNote,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
            if (_formError case final text?)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s3),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    text,
                    key: const Key('slot-offer-form-error'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.s4),
            AppButton.primary(
              l.slotOfferSave,
              key: const Key('slot-offer-save'),
              loading: _busy,
              onPressed: _busy || slots.isEmpty ? null : _save,
            ),
            if (_editing)
              AppButton.text(
                l.slotOfferClose,
                key: const Key('slot-offer-close'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: _busy ? null : _close,
              ),
          ],
        ),
      ),
    );
  }
}

/// "Thời lượng suất 15–90 phút  − 30 phút +" in 5-minute steps.
class _MinutesStepper extends StatelessWidget {
  const _MinutesStepper({
    required this.keyPrefix,
    required this.title,
    required this.range,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String keyPrefix;
  final String title;
  final String range;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final label = l.slotOfferMinutesValue(value);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                range,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        IconButton(
          key: Key('$keyPrefix-minus'),
          tooltip: l.slotOfferLess,
          icon: const AppIcon(AppIcons.remove),
          onPressed: enabled && value > min
              ? () => onChanged(
                  (value - kSlotStepMinutes).clamp(min, max).toInt(),
                )
              : null,
        ),
        Semantics(
          liveRegion: true,
          label: '$title $label',
          child: ExcludeSemantics(
            child: SizedBox(
              width: 64,
              child: Text(
                label,
                key: Key('$keyPrefix-value'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: Key('$keyPrefix-plus'),
          tooltip: l.slotOfferMore,
          icon: const AppIcon(AppIcons.add),
          onPressed: enabled && value < max
              ? () => onChanged(
                  (value + kSlotStepMinutes).clamp(min, max).toInt(),
                )
              : null,
        ),
      ],
    );
  }
}
