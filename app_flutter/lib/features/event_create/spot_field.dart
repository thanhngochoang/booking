// lib/features/event_create/spot_field.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// "Điểm chụp · bắt buộc" of S12.01 (mock `S12.01-spot`): a tile under the
/// event name that opens a sheet with search, the [suggestions] (already
/// ordered, best first) and the last choice "Không thuộc điểm chụp nào".
///
/// [value] is the chosen spot id; with [decided] and no value the organizer
/// chose "Không thuộc điểm chụp nào". [onChanged] gets the spot id, or null
/// for none. [error] shows under the tile.
class SpotField extends StatelessWidget {
  const SpotField({
    super.key,
    required this.suggestions,
    required this.value,
    required this.decided,
    required this.onChanged,
    this.error,
    this.focusNode,
    this.enabled = true,
  });

  final List<SpotEntry> suggestions;
  final String? value;
  final bool decided;
  final ValueChanged<String?> onChanged;
  final String? error;
  final FocusNode? focusNode;
  final bool enabled;

  SpotEntry? get _chosen {
    for (final s in suggestions) {
      if (s.spotId == value) {
        return s;
      }
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showAppSheet<_SpotChoice>(
      context,
      builder: (sheet) =>
          _SpotSheet(suggestions: suggestions, value: value, decided: decided),
    );
    if (picked != null) {
      onChanged(picked.spotId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final text = value != null
        ? _chosen?.name
        : decided
        ? l.eventSpotNone
        : null;
    final radius = BorderRadius.circular(controlRadius);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: error == null
          ? BorderSide.none
          : BorderSide(color: scheme.error, width: 2),
    );
    final onTap = enabled ? () => _open(context) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: '${l.eventSpotLabel}, ${text ?? l.eventSpotPlaceholder}',
          excludeSemantics: true,
          onTap: onTap,
          child: Material(
            color: scheme.secondary,
            shape: shape,
            child: InkWell(
              key: const Key('spot-field'),
              focusNode: focusNode,
              customBorder: shape,
              onTap: onTap,
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
                              l.eventSpotLabel,
                              style: theme.textTheme.labelSmall,
                            ),
                            Text(
                              text ?? l.eventSpotPlaceholder,
                              key: const Key('spot-field-value'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: text == null ? muted : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppIcon(AppIcons.chevron, color: muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (error case final e?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s1),
            child: Semantics(
              liveRegion: true,
              child: Text(
                e,
                key: const Key('spot-field-error'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          ),
      ],
    );
  }
}

/// What the sheet returns; [spotId] null is "Không thuộc điểm chụp nào".
class _SpotChoice {
  const _SpotChoice(this.spotId);
  final String? spotId;
}

class _SpotSheet extends StatefulWidget {
  const _SpotSheet({
    required this.suggestions,
    required this.value,
    required this.decided,
  });

  final List<SpotEntry> suggestions;
  final String? value;
  final bool decided;

  @override
  State<_SpotSheet> createState() => _SpotSheetState();
}

class _SpotSheetState extends State<_SpotSheet> {
  static const _noneId = '__none__';

  final _search = TextEditingController();
  late String? _selected = widget.value ?? (widget.decided ? _noneId : null);
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  SpotEntry? get _selectedSpot {
    for (final s in widget.suggestions) {
      if (s.spotId == _selected) {
        return s;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final folded = foldVietnamese(_query.trim());
    final shown = folded.isEmpty
        ? widget.suggestions
        : [
            for (final s in widget.suggestions)
              if (foldVietnamese(s.name).contains(folded) ||
                  foldVietnamese(s.city).contains(folded))
                s,
          ];
    final spot = _selectedSpot;
    final canPick = _selected != null && (_selected == _noneId || spot != null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            0,
            AppSpace.s2,
            AppSpace.s2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.eventSpotSheetTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                key: const Key('spot-sheet-close'),
                tooltip: l.eventSpotClose,
                icon: const AppIcon(AppIcons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s5),
          child: Text(l.eventSpotSheetHint, style: theme.textTheme.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s3,
            AppSpace.s4,
            AppSpace.s2,
          ),
          child: Semantics(
            label: l.eventSpotSearch,
            child: TextField(
              key: const Key('spot-search'),
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.eventSpotSearch,
                prefixIcon: const AppIcon(AppIcons.search),
              ),
            ),
          ),
        ),
        Flexible(
          child: Semantics(
            label: l.eventSpotSheetTitle,
            container: true,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                0,
                AppSpace.s4,
                AppSpace.s2,
              ),
              children: [
                for (final s in shown) ...[
                  AppOptionTile(
                    key: Key('spot-option-${s.spotId}'),
                    label: s.name,
                    description: _describe(l, s),
                    selected: _selected == s.spotId,
                    leading: _Thumb(url: s.cardUrl),
                    onTap: () => setState(() => _selected = s.spotId),
                  ),
                  const SizedBox(height: AppSpace.s2),
                ],
                if (shown.isEmpty && folded.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    child: Text(
                      l.eventSpotNoMatch,
                      key: const Key('spot-no-match'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                AppOptionTile(
                  key: const Key('spot-option-none'),
                  label: l.eventSpotNone,
                  description: l.eventSpotNoneHint,
                  icon: AppIcons.placeOff,
                  selected: _selected == _noneId,
                  onTap: () => setState(() => _selected = _noneId),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: AppButton.primary(
            spot != null
                ? l.eventSpotPick(spot.name)
                : _selected == _noneId
                ? l.eventSpotPickNone
                : l.eventSpotPlaceholder,
            key: const Key('spot-sheet-pick'),
            onPressed: canPick
                ? () => Navigator.of(context)
                      .pop(_SpotChoice(_selected == _noneId ? null : _selected))
                : null,
          ),
        ),
      ],
    );
  }

  String _describe(AppLocalizations l, SpotEntry s) => s.inSeason
      ? '${s.city} · ${l.spotInSeason}'
      : s.seasonMonths.isEmpty
      ? '${s.city} · ${l.spotSeasonAllYear}'
      : s.city;
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        width: 40,
        height: 40,
        child: url == null
            ? ColoredBox(
                color: scheme.secondary,
                child: const Center(child: AppIcon(AppIcons.place, size: 20)),
              )
            : NetworkPhoto(url: url!, retry: false),
      ),
    );
  }
}
