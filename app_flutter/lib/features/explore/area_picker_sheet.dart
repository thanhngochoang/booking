import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';

const _deviceId = '__device__';

/// S02.05: pick a district or city when location is off. Opened from S02.03, S02.04
/// and S02.06.
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
  bool _deviceFailed = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final location = ref.watch(locationControllerProvider);
    final areasAsync = ref.watch(areasProvider);
    final areas = areasAsync.value ?? const <AreaOption>[];
    final loadingAreas = !areasAsync.hasValue;
    if (!_seeded && location.loaded) {
      _seeded = true;
      _selected ??=
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
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s2,
                    0,
                    AppSpace.s2,
                    AppSpace.s3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l.areaPickerTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 17,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.s1),
                      // "Vị trí đang tắt…" only fits when location is off
                      // (S02.04 "Đổi" opens the sheet with it on).
                      Text(
                        location.permission == LocationPermissionStatus.granted
                            ? l.areaPickerBodyOn
                            : l.areaPickerBody,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (areas.length > 8) ...[
                        const SizedBox(height: AppSpace.s3),
                        TextField(
                          key: const Key('area-search'),
                          controller: _searchController,
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
                if (offersDevice && folded.isEmpty)
                  _AreaRow(
                    key: const Key('area-use-device'),
                    label: l.areaPickerUseDevice,
                    icon: Icons.my_location_outlined,
                    selected: _selected == _deviceId,
                    onTap: () => setState(() {
                      _selected = _deviceId;
                      _deviceFailed = false;
                    }),
                  ),
                for (final a in shown)
                  _AreaRow(
                    key: Key('area-${a.id}'),
                    label: a.name,
                    selected: _selected == a.id,
                    onTap: () => setState(() {
                      _selected = a.id;
                      _deviceFailed = false;
                    }),
                  ),
                if (loadingAreas)
                  const _AreaSkeletons()
                else if (shown.isEmpty)
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
                Semantics(
                  liveRegion: true,
                  child: _deviceFailed
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s3),
                          child: Text(
                            l.areaDeviceFailed,
                            key: const Key('area-device-failed'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // Mock S02.05: after the list, just above the main button.
                // Hidden while the keyboard is up, so the list keeps room.
                if (location.permission ==
                        LocationPermissionStatus.deniedForever &&
                    MediaQuery.viewInsetsOf(context).bottom == 0) ...[
                  AppButton.outline(
                    l.areaPickerOpenSettings,
                    key: const Key('area-open-settings'),
                    size: AppButtonSize.small,
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
    setState(() {
      _saving = true;
      _deviceFailed = false;
    });
    var close = true;
    try {
      final controller = ref.read(locationControllerProvider.notifier);
      if (id == _deviceId) {
        await controller.useDeviceLocation();
        if (!mounted) {
          return;
        }
        final s = ref.read(locationControllerProvider);
        // Stay open when the device fix did not arrive (for example the
        // permission ended denied forever): the sheet rebuilds from it.
        close =
            s.area == null &&
            s.location != null &&
            s.permission == LocationPermissionStatus.granted;
        if (!close) {
          _deviceFailed = true;
        }
      } else if (ref.read(locationControllerProvider).area?.id != id) {
        final match = areas.where((a) => a.id == id);
        if (match.isNotEmpty) {
          await controller.chooseArea(match.first);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
    if (close && mounted) {
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.s2,
      vertical: AppSpace.s1,
    ),
    child: AppOptionTile(
      label: label,
      selected: selected,
      onTap: onTap,
      leading: icon == null ? null : Icon(icon),
    ),
  );
}

class _AreaSkeletons extends StatelessWidget {
  const _AreaSkeletons();

  @override
  Widget build(BuildContext context) {
    return AppSkeletonScope(
      child: Column(
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s2,
                vertical: AppSpace.s1,
              ),
              child: AppOptionTile.skeleton(),
            ),
        ],
      ),
    );
  }
}
