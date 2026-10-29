// lib/features/organizer/managed_spot_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/organizer/organizer_controller.dart';
import 'package:photobooking/features/organizer/organizer_routes.dart';
import 'package:photobooking/features/organizer/widgets/access_editor.dart';
import 'package:photobooking/features/organizer/widgets/organizer_parts.dart';
import 'package:photobooking/features/organizer/widgets/resident_sheet.dart';

enum _Tab { entry, residents, info }

/// Ticket types listed on the card before "+{n} loại" (mock `.dl`).
const _typesShown = 3;

/// S30.03 "Quản lý điểm" at `/organizer/spots/:spotId` (mock `#S30.03`,
/// `#S30.03-residents`): the entry event on sale with today's numbers, the
/// resident photographers and the spot's editable info. The primary follows
/// the tab: "Tạo/Sửa vé vào cửa" (or the missing step to sell: S21.04, then
/// S06.06) on "Vào cửa", "Lưu" on "Thông tin", none on "Thợ tại điểm" (its
/// first row adds).
class ManagedSpotScreen extends ConsumerStatefulWidget {
  const ManagedSpotScreen({super.key, required this.spotId});

  final String spotId;

  @override
  ConsumerState<ManagedSpotScreen> createState() => _ManagedSpotScreenState();
}

class _ManagedSpotScreenState extends ConsumerState<ManagedSpotScreen> {
  _Tab _tab = _Tab.entry;

  // "Thông tin", filled once from the spot.
  bool _infoReady = false;
  final _description = TextEditingController();
  final _tips = TextEditingController();
  final _open = TextEditingController();
  final _close = TextEditingController();
  AccessEditorController? _access;
  PickedImage? _cover;
  String? _hoursError;
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _tips.dispose();
    _open.dispose();
    _close.dispose();
    _access?.dispose();
    super.dispose();
  }

  void _fillInfo(Spot s) {
    if (_infoReady) return;
    _infoReady = true;
    _description.text = s.description;
    _tips.text = s.tips.join('\n');
    _open.text = s.openHours?.start ?? '';
    _close.text = s.openHours?.end ?? '';
    _access = AccessEditorController(s.access);
  }

  Future<void> _pickCover() async {
    final picked = await ref.read(imagePickerProvider).pickImages(max: 1);
    if (picked.isNotEmpty && mounted) setState(() => _cover = picked.first);
  }

  Future<void> _saveInfo() async {
    final l = context.l10n;
    final open = _open.text.trim();
    final close = _close.text.trim();
    OpenHours? hours;
    String? hoursError;
    if (open.isNotEmpty || close.isNotEmpty) {
      if (!isHm(open) || !isHm(close)) {
        hoursError = l.s3004_timeFormat;
      } else if (close.compareTo(open) <= 0) {
        hoursError = l.s3004_hoursInvalid;
      } else {
        hours = OpenHours(start: open, end: close);
      }
    }
    final access = _access?.build();
    setState(() => _hoursError = hoursError);
    if (hoursError != null || access == null) return;
    setState(() => _saving = true);
    final tips = [
      for (final t in _tips.text.split('\n'))
        if (t.trim().isNotEmpty) t.trim(),
    ];
    final code = await ref
        .read(organizerActionsProvider)
        .run(
          (r) => r.updateManagedSpot(
            widget.spotId,
            description: _description.text.trim(),
            tips: tips,
            cover: _cover,
            openHours: hours,
            access: access,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (code == null) {
      setState(() => _cover = null);
      ref.invalidate(spotProvider(widget.spotId));
      orgSay(context, l.s3003_saved);
    } else {
      orgSay(
        context,
        code == 'not_spot_manager'
            ? l.s3004_notManager
            : organizerErrorText(l, code),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final spot = ref.watch(spotProvider(widget.spotId));
    final residents =
        ref.watch(spotResidentsProvider(widget.spotId)).value ?? const [];
    final name = spot.value?.name ?? '';
    return ScreenCode(
      ScreenCodes.managedSpot,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(name, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                key: const Key('managed-view-spot'),
                tooltip: l.s3003_viewSpot,
                icon: const AppIcon(AppIcons.visibility),
                onPressed: () => context.push('/spots/${widget.spotId}'),
              ),
            ],
          ),
          body: AsyncView<Spot?>(
            value: spot,
            onRetry: () => ref.invalidate(spotProvider(widget.spotId)),
            isEmpty: (s) => s == null,
            empty: (_) => EmptyState(title: l.s3004_notManager, body: ''),
            data: (context, s) {
              _fillInfo(s!);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.s5,
                      AppSpace.s2,
                      AppSpace.s5,
                      AppSpace.s2,
                    ),
                    child: SegmentedTabs<_Tab>(
                      key: const Key('managed-tabs'),
                      options: [
                        SegmentOption(
                          value: _Tab.entry,
                          label: l.s3003_tabEntry,
                        ),
                        SegmentOption(
                          value: _Tab.residents,
                          label: l.s3003_tabResidents(residents.length),
                        ),
                        SegmentOption(value: _Tab.info, label: l.s3003_tabInfo),
                      ],
                      value: _tab,
                      onChanged: (t) => setState(() => _tab = t),
                    ),
                  ),
                  Expanded(
                    child: switch (_tab) {
                      _Tab.entry => _EntryTab(spot: s),
                      _Tab.residents => _ResidentsTab(
                        spotId: s.id,
                        residents: residents,
                      ),
                      _Tab.info => _info(context, s),
                    },
                  ),
                ],
              );
            },
          ),
          bottomNavigationBar: spot.value == null
              ? null
              : switch (_tab) {
                  _Tab.entry => _EntryPrimary(spotId: widget.spotId),
                  _Tab.residents => null,
                  _Tab.info => AppFooterBar(
                    child: AppButton.primary(
                      l.s3003_save,
                      key: const Key('managed-primary'),
                      loading: _saving,
                      onPressed: _saving ? null : _saveInfo,
                    ),
                  ),
                },
        ),
      ),
    );
  }

  Widget _info(BuildContext context, Spot s) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cover = _cover;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s5),
      children: [
        TextField(
          key: const Key('info-description'),
          controller: _description,
          enabled: !_saving,
          minLines: 2,
          maxLines: 6,
          maxLength: 1000,
          decoration: InputDecoration(labelText: l.s3003_description),
        ),
        const SizedBox(height: AppSpace.s2),
        TextField(
          key: const Key('info-tips'),
          controller: _tips,
          enabled: !_saving,
          minLines: 2,
          maxLines: 6,
          decoration: InputDecoration(labelText: l.s3003_tips),
        ),
        OrgSection(l.s3003_cover),
        OrgInfoRow(
          key: const Key('info-cover'),
          icon: AppIcons.image,
          title: l.s3003_changeCover,
          subtitle: cover == null ? null : l.s3003_coverPicked(cover.name),
          onTap: _saving ? null : _pickCover,
        ),
        OrgSection(l.s3003_openHours),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('info-open'),
                controller: _open,
                enabled: !_saving,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(labelText: l.s3004_open),
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: TextField(
                key: const Key('info-close'),
                controller: _close,
                enabled: !_saving,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(labelText: l.s3004_close),
              ),
            ),
          ],
        ),
        if (_hoursError case final e?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s1),
            child: Text(
              e,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        OrgSection(l.s3003_refPrices),
        if (_access case final a?)
          AccessEditor(controller: a, enabled: !_saving),
        const SizedBox(height: AppSpace.s2),
        Text(
          l.s3003_staffOnly,
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// The "Vào cửa" primary: the next step to sell, else create or edit.
class _EntryPrimary extends ConsumerWidget {
  const _EntryPrimary({required this.spotId});

  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final org = ref.watch(myOrganizerProvider).value;
    final event = ref.watch(entryEventProvider(spotId)).value;
    final (label, path) = switch (org) {
      null || Organizer(businessVerified: false) => (
        l.s3003_verifyBusiness,
        '/verify/business',
      ),
      Organizer(payoutAccountOk: false) => (
        l.s3003_payout,
        organizerPayoutPath,
      ),
      _ when event != null => (l.s3003_edit, entryEditPath(event.id)),
      _ => (l.s3003_create, entryNewPath(spotId)),
    };
    return AppFooterBar(
      child: AppButton.primary(
        label,
        key: const Key('managed-primary'),
        onPressed: org?.isActive == false ? null : () => context.push(path),
      ),
    );
  }
}

class _EntryTab extends ConsumerWidget {
  const _EntryTab({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final org = ref.watch(myOrganizerProvider).value;
    final event = ref.watch(entryEventProvider(spot.id)).value;
    final today = vnDateKey(ref.watch(clockProvider)());
    final day = event == null
        ? null
        : ref.watch(entryDayProvider((eventId: event.id, day: today))).value;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.mutedForeground,
    );

    final Widget card;
    if (event == null) {
      card = GlassCard(
        highlight: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Text(l.s3003_noTickets, style: theme.textTheme.bodyMedium),
        ),
      );
    } else {
      final types = event.visibleTicketTypes;
      final cap = event.dailyCapacity;
      card = GlassCard(
        highlight: false,
        child: InkWell(
          key: const Key('managed-ticket-card'),
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.push('/events/${event.id}/manage'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    OrgBadge(l.s3003_onSale),
                  ],
                ),
                const SizedBox(height: AppSpace.s1),
                Text(
                  l.s3003_range(
                    dayLabel(event.startDay),
                    dayLabel(event.endDay),
                    event.openHours.start,
                    event.openHours.end,
                  ),
                  style: muted,
                ),
                if (cap != null) Text(l.s3003_capacity(cap), style: muted),
                const SizedBox(height: AppSpace.s2),
                for (final t in types.take(_typesShown))
                  Text(
                    l.s3003_typeLine(t.name, formatMoney(t.price)),
                    style: theme.textTheme.bodySmall,
                  ),
                if (types.length > _typesShown)
                  Text(
                    l.s3003_moreTypes(types.length - _typesShown),
                    style: muted,
                  ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  l.s3003_kpiToday(
                    day?.sold ?? 0,
                    day?.checkedIn ?? 0,
                    day?.held ?? 0,
                  ),
                  key: const Key('managed-kpi'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpace.s5),
      children: [
        card,
        const SizedBox(height: AppSpace.s3),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [
            AppButton.outline(
              l.s3003_gateStaff,
              key: const Key('managed-gate-staff'),
              size: AppButtonSize.small,
              icon: const AppIcon(AppIcons.badge),
              onPressed: () => context.push(gateStaffPath),
            ),
            AppButton.outline(
              l.s3003_scan,
              key: const Key('managed-scan'),
              size: AppButtonSize.small,
              icon: const AppIcon(AppIcons.qrCode),
              onPressed: () => context.push(scanPath),
            ),
          ],
        ),
        if (org?.businessVerified ?? false) ...[
          const SizedBox(height: AppSpace.s3),
          OrgInfoRow(
            key: const Key('managed-payout'),
            icon: AppIcons.wallet,
            title: l.s3003_payout,
            subtitle: l.s3003_payoutBody,
            onTap: () => context.push(organizerPayoutPath),
          ),
        ],
        if (event == null && spot.access != null) ...[
          OrgSection(l.s3003_refPrices),
          for (final f in spot.access!.fees)
            Text(
              l.s3003_typeLine(f.label, formatMoney(f.amountVnd)),
              style: theme.textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}

class _ResidentsTab extends ConsumerWidget {
  const _ResidentsTab({required this.spotId, required this.residents});

  final String spotId;
  final List<Resident> residents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final ids = [for (final r in residents) r.providerId]..sort();
    final names =
        ref.watch(spotPhotographerSummariesProvider(ids.join(','))).value ??
        const <String, PhotographerSummary>{};
    final today = vnDateKey(ref.watch(clockProvider)());
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: context.mutedForeground,
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s5),
      children: [
        GlassCard(
          highlight: false,
          child: ListTile(
            key: const Key('resident-add'),
            leading: const AppIcon(AppIcons.addCircle),
            title: Text(l.s3003_addResident),
            onTap: residents.length >= residentsMax
                ? () => orgSay(context, l.s3003_residentLimit)
                : () => showResidentSheet(
                    context,
                    spotId: spotId,
                    current: ids.toSet(),
                  ),
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        if (residents.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpace.s3),
            child: Text(l.s3003_residentsEmpty, style: muted),
          ),
        for (final r in residents) ...[
          Builder(
            builder: (context) {
              final p = names[r.providerId];
              final lines = residentLines(l, r, today);
              final name = p?.displayName ?? '';
              return GlassCard(
                highlight: false,
                child: InkWell(
                  key: Key('resident-${r.providerId}'),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  onTap: p == null
                      ? null
                      : () => showResidentSheet(
                          context,
                          spotId: spotId,
                          existing: r,
                          provider: p,
                        ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s3),
                    child: Row(
                      children: [
                        AppAvatar(url: p?.avatarUrl, name: name),
                        const SizedBox(width: AppSpace.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(lines.waiver, style: muted),
                              Text(lines.until, style: muted),
                            ],
                          ),
                        ),
                        const AppIcon(AppIcons.chevron),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpace.s2),
        ],
      ],
    );
  }
}
