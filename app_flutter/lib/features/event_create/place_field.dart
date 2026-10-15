// lib/features/event_create/place_field.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/features/explore/location_controller.dart';

/// "Địa điểm" of S12.02: the place name, the meeting point, the area (its
/// centre is the point on the map) and "Dùng vị trí hiện tại", which puts the
/// device position over that point (Decision 22: no map pin).
class PlaceField extends ConsumerStatefulWidget {
  const PlaceField({
    super.key,
    required this.name,
    required this.meetingPoint,
    required this.areaId,
    required this.hasDevicePoint,
    required this.onText,
    required this.onArea,
    required this.onDevicePoint,
    this.error,
    this.nameFocus,
    this.enabled = true,
  });

  final String name;
  final String meetingPoint;
  final String? areaId;

  /// The point came from the device, not from the area.
  final bool hasDevicePoint;
  final String? error;
  final FocusNode? nameFocus;
  final bool enabled;

  final void Function({String? name, String? meetingPoint}) onText;
  final ValueChanged<AreaOption> onArea;
  final void Function(double lat, double lng) onDevicePoint;

  @override
  ConsumerState<PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends ConsumerState<PlaceField> {
  late final TextEditingController _name;
  late final TextEditingController _meeting;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _meeting = TextEditingController(text: widget.meetingPoint);
  }

  @override
  void dispose() {
    _name.dispose();
    _meeting.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pickArea(List<AreaOption> areas) async {
    final l = context.l10n;
    final picked = await showAppSheet<AreaOption>(
      context,
      builder: (sheet) => Column(
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
            child: Semantics(
              header: true,
              child: Text(
                l.createEventArea,
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                0,
                AppSpace.s4,
                AppSpace.s5,
              ),
              itemCount: areas.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s2),
              itemBuilder: (_, i) => AppOptionTile(
                key: Key('place-area-${areas[i].id}'),
                label: areas[i].name,
                selected: areas[i].id == widget.areaId,
                onTap: () => Navigator.of(sheet).pop(areas[i]),
              ),
            ),
          ),
        ],
      ),
    );
    if (picked != null && mounted) {
      widget.onArea(picked);
    }
  }

  Future<void> _useLocation() async {
    if (_locating) {
      return;
    }
    final l = context.l10n;
    setState(() => _locating = true);
    final here = await ref.read(locationRepositoryProvider).currentPosition();
    if (!mounted) {
      return;
    }
    setState(() => _locating = false);
    if (here == null) {
      _say(l.createEventLocationFailed);
      return;
    }
    widget.onDevicePoint(here.lat, here.lng);
    _say(l.createEventLocationUsed);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final areas = ref.watch(areasProvider);
    final area = [
      for (final a in areas.value ?? const <AreaOption>[])
        if (a.id == widget.areaId) a,
    ].firstOrNull;
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(controlRadius);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('place-name'),
          controller: _name,
          focusNode: widget.nameFocus,
          enabled: widget.enabled,
          maxLength: 120,
          textInputAction: TextInputAction.next,
          onChanged: (v) => widget.onText(name: v),
          decoration: InputDecoration(
            labelText: l.createEventPlace,
            counterText: '',
            errorText: widget.error,
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        TextField(
          key: const Key('place-meeting'),
          controller: _meeting,
          enabled: widget.enabled,
          maxLength: 120,
          textInputAction: TextInputAction.done,
          onChanged: (v) => widget.onText(meetingPoint: v),
          decoration: InputDecoration(
            labelText: l.createEventMeeting,
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        Semantics(
          button: true,
          enabled: widget.enabled,
          label: '${l.createEventArea}, ${area?.name ?? l.createEventAreaPick}',
          excludeSemantics: true,
          onTap: widget.enabled && areas.hasValue
              ? () => _pickArea(areas.requireValue)
              : null,
          child: Material(
            color: scheme.secondary,
            borderRadius: radius,
            child: InkWell(
              key: const Key('place-area'),
              borderRadius: radius,
              onTap: widget.enabled && areas.hasValue
                  ? () => _pickArea(areas.requireValue)
                  : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSpace.s12 + AppSpace.s2,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                    vertical: AppSpace.s2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.createEventArea,
                              style: theme.textTheme.labelSmall,
                            ),
                            Text(
                              area?.name ?? l.createEventAreaPick,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: area == null ? muted : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppIcon(AppIcons.expandMore, color: muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.text(
            l.createEventUseLocation,
            key: const Key('place-use-location'),
            size: AppButtonSize.small,
            loading: _locating,
            icon: AppIcon(
              AppIcons.myLocation,
              size: 18,
              selected: widget.hasDevicePoint,
            ),
            onPressed: widget.enabled ? _useLocation : null,
          ),
        ),
      ],
    );
  }
}
