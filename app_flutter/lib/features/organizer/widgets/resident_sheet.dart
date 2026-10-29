// lib/features/organizer/widgets/resident_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/features/organizer/organizer_controller.dart';
import 'package:photobooking/features/organizer/widgets/organizer_parts.dart';

/// Providers taking orders the add sheet searches (the recommender pool:
/// `acceptingOrders == true` only, ≤ 200).
final residentCandidatesProvider =
    FutureProvider.autoDispose<List<PhotographerSummary>>((ref) async {
      final all = await ref.watch(photographerRepositoryProvider).candidates();
      return [
        for (final p in all)
          if (p.acceptingOrders) p,
      ];
    });

/// `…/u/<uid>` in a pasted profile link.
final _profileLink = RegExp(r'/u/([A-Za-z0-9_-]{1,128})');

/// Opens S30.03-residents: add a resident ([existing] null) or edit one.
Future<void> showResidentSheet(
  BuildContext context, {
  required String spotId,
  Resident? existing,
  PhotographerSummary? provider,
  Set<String> current = const {},
}) => showAppSheet<void>(
  context,
  builder: (_) => ResidentSheet(
    spotId: spotId,
    existing: existing,
    provider: provider,
    current: current,
  ),
);

/// S30.03-residents (mock `#S30.03-residents`): who, the two waivers, the
/// guests cap and the end day; "Gỡ khỏi danh sách" when editing.
class ResidentSheet extends ConsumerStatefulWidget {
  const ResidentSheet({
    super.key,
    required this.spotId,
    this.existing,
    this.provider,
    this.current = const {},
  });

  final String spotId;
  final Resident? existing;
  final PhotographerSummary? provider;

  /// Residents already listed (left out of the search).
  final Set<String> current;

  @override
  ConsumerState<ResidentSheet> createState() => _ResidentSheetState();
}

class _ResidentSheetState extends ConsumerState<ResidentSheet> {
  final _search = TextEditingController();
  late final _maxGuests = TextEditingController(
    text: widget.existing?.maxGuests?.toString() ?? '',
  );
  late PhotographerSummary? _provider = widget.provider;
  late bool _waivesProvider = widget.existing?.waivesProvider ?? true;
  late bool _waivesGuests = widget.existing?.waivesGuests ?? false;
  late String? _validUntil = widget.existing?.validUntil;
  bool _busy = false;
  bool _maxError = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _search.dispose();
    _maxGuests.dispose();
    super.dispose();
  }

  String _today() => vnDateKey(ref.read(clockProvider)());

  Future<void> _pickUntil() async {
    final today = parseDayKey(_today())!;
    final current = _validUntil == null ? null : parseDayKey(_validUntil!);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today.add(const Duration(days: 30)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 3 * 366)),
    );
    if (picked != null && mounted) {
      setState(() => _validUntil = dayKeyOf(picked));
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    final p = _provider;
    if (p == null) return;
    int? max;
    if (_waivesGuests && _maxGuests.text.trim().isNotEmpty) {
      max = int.tryParse(_maxGuests.text.trim());
      if (max == null || max < 1) {
        setState(() => _maxError = true);
        return;
      }
    }
    setState(() {
      _maxError = false;
      _busy = true;
      _error = null;
    });
    final resident = Resident(
      providerId: p.id,
      waivesProvider: _waivesProvider,
      waivesGuests: _waivesGuests,
      maxGuests: _waivesGuests ? max : null,
      validUntil: _validUntil,
    );
    final code = await ref
        .read(organizerActionsProvider)
        .run((r) => r.saveResident(widget.spotId, resident));
    if (!mounted) return;
    setState(() => _busy = false);
    if (code == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(
      () => _error = switch (code) {
        'limit_exceeded' => l.s3003_residentLimit,
        'not_accepting_orders' => l.s3003_notAccepting,
        _ => organizerErrorText(l, code),
      },
    );
  }

  Future<void> _remove() async {
    final l = context.l10n;
    final p = _provider;
    if (p == null) return;
    final actions = ref.read(organizerActionsProvider);
    String? failed;
    final yes = await showConfirmSheet(
      context,
      title: l.s3003_removeResidentTitle(p.displayName),
      confirmLabel: l.s3003_removeResident,
      keepLabel: l.s30_keep,
      onConfirm: () async {
        failed = await actions.run(
          (r) => r.removeResident(widget.spotId, p.id),
        );
      },
    );
    if (!mounted || !yes) return;
    if (failed != null) {
      setState(() => _error = organizerErrorText(l, failed!));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // ListTiles paint on a Material: the sheet frame is a coloured box.
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
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
            OrgSheetHeader(
              _editing ? l.s3003_residentEditTitle : l.s3003_residentAddTitle,
            ),
            const SizedBox(height: AppSpace.s3),
            if (_provider == null) ..._picker(context) else ..._form(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _picker(BuildContext context) {
    final l = context.l10n;
    final q = _search.text.trim();
    final all = ref.watch(residentCandidatesProvider).value ?? const [];
    final link = _profileLink.firstMatch(q)?.group(1);
    final folded = foldVietnamese(q.startsWith('@') ? q.substring(1) : q);
    final matches = q.isEmpty
        ? const <PhotographerSummary>[]
        : [
            for (final p in all)
              if (!widget.current.contains(p.id) &&
                  (link != null
                      ? p.id == link
                      : foldVietnamese(p.displayName).contains(folded)))
                p,
          ].take(20).toList();
    return [
      TextField(
        key: const Key('resident-search'),
        controller: _search,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l.s3003_residentSearch,
          prefixIcon: const AppIcon(AppIcons.personSearch),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: AppSpace.s2),
      if (q.isNotEmpty && matches.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
          child: Text(
            l.s3003_residentNoMatch,
            style: TextStyle(color: context.mutedForeground),
          ),
        ),
      for (final p in matches)
        ListTile(
          key: Key('resident-pick-${p.id}'),
          contentPadding: EdgeInsets.zero,
          leading: AppAvatar(url: p.avatarUrl, name: p.displayName),
          title: Text(p.displayName),
          subtitle: Text(l.s3003_residentAccepting),
          onTap: () => setState(() => _provider = p),
        ),
    ];
  }

  List<Widget> _form(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final p = _provider!;
    final until = _validUntil;
    final untilDate = until == null ? null : parseDayKey(until);
    final max = int.tryParse(_maxGuests.text.trim());
    return [
      Row(
        children: [
          AppAvatar(url: p.avatarUrl, name: p.displayName),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.displayName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  l.s3003_residentAccepting,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpace.s2),
      SwitchListTile(
        key: const Key('resident-waive-provider'),
        contentPadding: EdgeInsets.zero,
        title: Text(l.s3003_waiveProvider),
        subtitle: Text(l.s3003_waiveProviderSub),
        value: _waivesProvider,
        onChanged: _busy ? null : (v) => setState(() => _waivesProvider = v),
      ),
      SwitchListTile(
        key: const Key('resident-waive-guests'),
        contentPadding: EdgeInsets.zero,
        title: Text(l.s3003_waiveGuests),
        subtitle: _waivesGuests && max != null && max > 0
            ? Text(l.s3003_maxGuests(max))
            : null,
        value: _waivesGuests,
        onChanged: _busy ? null : (v) => setState(() => _waivesGuests = v),
      ),
      if (_waivesGuests)
        TextField(
          key: const Key('resident-max-guests'),
          controller: _maxGuests,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l.s3003_maxGuestsField,
            helperText: l.s3003_maxGuestsHint,
            errorText: _maxError ? l.s3003_maxGuestsInvalid : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ListTile(
        key: const Key('resident-valid-until'),
        contentPadding: EdgeInsets.zero,
        title: Text(l.s3003_validUntil),
        subtitle: Text(
          untilDate == null ? l.s3003_noEnd : formatDay(untilDate),
        ),
        trailing: const AppIcon(AppIcons.calendar),
        onTap: _busy ? null : _pickUntil,
      ),
      Text(
        l.s3003_offApp,
        style: theme.textTheme.bodySmall?.copyWith(
          color: context.mutedForeground,
        ),
      ),
      if (_error case final e?) ...[
        const SizedBox(height: AppSpace.s2),
        OrgBand(text: e, icon: AppIcons.warning, tone: OrgBandTone.error),
      ],
      const SizedBox(height: AppSpace.s4),
      AppButton.primary(
        _editing ? l.s3003_saveResident : l.s3003_addConfirm,
        key: const Key('resident-save'),
        loading: _busy,
        onPressed: _busy ? null : _save,
      ),
      if (_editing)
        OrgDangerText(
          l.s3003_removeResidentLink,
          key: const Key('resident-remove'),
          onPressed: _busy ? null : _remove,
        ),
    ];
  }
}
