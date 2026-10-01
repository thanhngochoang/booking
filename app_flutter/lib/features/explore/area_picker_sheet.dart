import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';

const _deviceId = '__device__';

/// S36: pick a district or city when location is off. Opened from S13, S35
/// and S04.
Future<void> showAreaPicker(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const AreaPickerSheet());

class AreaPickerSheet extends ConsumerStatefulWidget {
  const AreaPickerSheet({super.key});

  @override
  ConsumerState<AreaPickerSheet> createState() => _AreaPickerSheetState();
}

class _AreaPickerSheetState extends ConsumerState<AreaPickerSheet> {
  String? _selected;
  bool _seeded = false;
  String _query = '';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final location = ref.watch(locationControllerProvider);
    final areas = ref.watch(areasProvider).value ?? const <AreaOption>[];
    if (!_seeded && location.loaded) {
      _seeded = true;
      _selected =
          location.area?.id ??
          (location.permission == LocationPermissionStatus.granted &&
                  location.location != null
              ? _deviceId
              : null);
    }
    final offersDevice = switch (location.permission) {
      LocationPermissionStatus.granted ||
      LocationPermissionStatus.notAsked ||
      LocationPermissionStatus.denied => true,
      _ => false,
    };
    final folded = foldVietnamese(_query.trim());
    final shown = folded.isEmpty
        ? areas
        : areas.where((a) => foldVietnamese(a.name).contains(folded)).toList();

    return ScreenCode(
      ScreenCodes.pickArea,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s5,
              0,
              AppSpace.s5,
              AppSpace.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l.areaPickerTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: AppSpace.s1),
                Text(l.areaPickerBody, style: theme.textTheme.bodySmall),
                if (areas.length > 8) ...[
                  const SizedBox(height: AppSpace.s3),
                  TextField(
                    key: const Key('area-search'),
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l.areaPickerSearch,
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
              children: [
                if (offersDevice && folded.isEmpty)
                  _AreaRow(
                    key: const Key('area-use-device'),
                    label: l.areaPickerUseDevice,
                    icon: Icons.my_location_outlined,
                    selected: _selected == _deviceId,
                    onTap: () => setState(() => _selected = _deviceId),
                  ),
                for (final a in shown)
                  _AreaRow(
                    key: Key('area-${a.id}'),
                    label: a.name,
                    selected: _selected == a.id,
                    onTap: () => setState(() => _selected = a.id),
                  ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    child: Text(
                      l.areaPickerNoMatch,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (location.permission ==
                    LocationPermissionStatus.deniedForever) ...[
                  AppButton.outline(
                    l.areaPickerOpenSettings,
                    key: const Key('area-open-settings'),
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => ref
                        .read(locationControllerProvider.notifier)
                        .openSettings(),
                  ),
                  const SizedBox(height: AppSpace.s2),
                ],
                AppButton.primary(
                  l.areaPickerUse,
                  key: const Key('area-use'),
                  loading: _saving,
                  onPressed: _selected == null ? null : () => _confirm(areas),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(List<AreaOption> areas) async {
    final id = _selected;
    if (id == null) {
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(locationControllerProvider.notifier);
    if (id == _deviceId) {
      await controller.useDeviceLocation();
    } else {
      await controller.chooseArea(areas.firstWhere((a) => a.id == id));
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(controlRadius),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s3,
              vertical: AppSpace.s2,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: AppSpace.s3),
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: AppSpace.s2),
                ],
                Expanded(child: Text(label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
