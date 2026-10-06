import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/notification_prefs.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/notifications/notification_settings_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Opens the system time picker; a seam so tests can answer without the dial.
typedef TimePickerFn = Future<TimeOfDay?> Function(
  BuildContext context,
  TimeOfDay initial,
  String help,
);

final timePickerProvider = Provider<TimePickerFn>(
  (ref) =>
      (context, initial, help) => showTimePicker(
        context: context,
        initialTime: initial,
        helpText: help,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      ),
);

TimeOfDay _parse(String hhmm) {
  final p = hhmm.split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

String _format(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// S17.02: which notifications go to the phone (Push), which only to the
/// inbox (Trong app), quiet hours and shoot reminders.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The user may have changed the permission in the system settings.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref
          .read(notificationSettingsControllerProvider.notifier)
          .refreshPermission(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  NotificationSettingsController get _ctrl =>
      ref.read(notificationSettingsControllerProvider.notifier);

  /// Runs a write; a failure says so (the controller already restored the
  /// switch).
  Future<void> _run(Future<void> Function() write) async {
    final l = context.l10n;
    try {
      await write();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.notifSettingsSaveError)));
      }
    }
  }

  Future<void> _pickRange(NotificationSettingsState s) async {
    final l = context.l10n;
    final pick = ref.read(timePickerProvider);
    final from = await pick(
      context,
      _parse(s.prefs.quietFrom),
      l.notifSettingsPickFrom,
    );
    if (from == null || !mounted) {
      return;
    }
    final to = await pick(
      context,
      _parse(s.prefs.quietTo),
      l.notifSettingsPickTo,
    );
    if (to == null || !mounted) {
      return;
    }
    await _run(() => _ctrl.setQuietRange(_format(from), _format(to)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(notificationSettingsControllerProvider);
    return ScreenCode(
      ScreenCodes.notificationSettings,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.notificationTitle)),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                if (async.value?.fromCache ?? false) const OfflineBanner(),
                Expanded(
                  child: AsyncView<NotificationSettingsState>(
                    value: async,
                    loadingLabel: l.notificationTitle,
                    skeleton: (_) => const _SettingsSkeleton(),
                    onRetry: () =>
                        ref.invalidate(notificationSettingsControllerProvider),
                    data: (_, s) => _content(context, s),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, NotificationSettingsState s) {
    final l = context.l10n;
    final role = ref.watch(currentProfileProvider).value?.role;
    final customer = role != UserRole.photographer;
    final off = s.fromCache;
    final rows = <_CategoryRow>[
      _CategoryRow(NotificationCategory.booking, l.notifSettingsCatBooking),
      if (kJobsEnabled)
        _CategoryRow(NotificationCategory.jobs, l.notifSettingsCatJobs),
      if (kInstantEnabled)
        _CategoryRow(
          NotificationCategory.instant,
          l.notifSettingsCatInstant,
          pushOnly: customer,
        ),
      _CategoryRow(NotificationCategory.events, l.notifSettingsCatEvents),
      _CategoryRow(NotificationCategory.chat, l.notifSettingsCatChat),
      _CategoryRow(NotificationCategory.badges, l.notifSettingsCatBadges),
      _CategoryRow(NotificationCategory.promo, l.notifSettingsCatPromo),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        AppSpace.s6,
      ),
      children: [
        if (s.os != NotificationPermissionStatus.granted) ...[
          _OsBanner(
            permanentlyDenied:
                s.os == NotificationPermissionStatus.permanentlyDenied,
            onPressed: () =>
                s.os == NotificationPermissionStatus.permanentlyDenied
                ? _ctrl.openOsSettings()
                : _ctrl.requestPermission(),
          ),
          const SizedBox(height: AppSpace.s3),
        ],
        GlassCard(
          highlight: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s4,
              vertical: AppSpace.s2,
            ),
            child: Column(
              children: [
                _TableHeader(
                  pushOff: s.os != NotificationPermissionStatus.granted,
                ),
                for (final r in rows)
                  _TableRow(
                    row: r,
                    prefs: s.prefs,
                    disabled: off,
                    onChannel: (c, {push, inApp}) => _run(
                      () => _ctrl.setChannel(c, push: push, inApp: inApp),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        GlassCard(
          highlight: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QuietRow(
                  state: s,
                  onToggle: (v) => _run(() => _ctrl.setQuietEnabled(v)),
                  onPickRange: () => _pickRange(s),
                ),
                const Divider(height: AppSpace.s6),
                _RemindersRow(
                  state: s,
                  onChanged: ({h24, h2}) =>
                      _run(() => _ctrl.setReminder(h24: h24, h2: h2)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryRow {
  const _CategoryRow(this.category, this.label, {this.pushOnly = false});

  final NotificationCategory category;
  final String label;

  /// Only the Push switch (customers' Chụp ngay).
  final bool pushOnly;
}

const _switchColumn = 72.0;

class _OsBanner extends StatelessWidget {
  const _OsBanner({required this.permanentlyDenied, required this.onPressed});

  final bool permanentlyDenied;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return GlassCard(
      highlight: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(
              AppIcons.notifications,
              color: dark ? AppColorsDark.warning : AppColors.warning,
            ),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.notifSettingsOsOffTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    l.notifSettingsOsOffBody,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpace.s3),
                  AppButton.outline(
                    key: const Key('notification-os-banner-action'),
                    permanentlyDenied
                        ? l.notifSettingsOpenSettings
                        : l.primerEnableNotification,
                    size: AppButtonSize.xsmall,
                    onPressed: onPressed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.pushOff});

  final bool pushOff;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall;
    Widget col(String text) => SizedBox(
      width: _switchColumn,
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          child: Row(
            children: [
              Expanded(child: Text(l.notifSettingsColType, style: style)),
              col(l.notifSettingsColPush),
              col(l.notifSettingsColInApp),
            ],
          ),
        ),
        if (pushOff)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s2),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                l.notifSettingsPushOffOs,
                key: const Key('notification-push-off-caption'),
                textAlign: TextAlign.end,
                style: style,
              ),
            ),
          ),
      ],
    );
  }
}

typedef _ChannelWrite = Future<void> Function(
  NotificationCategory c, {
  bool? push,
  bool? inApp,
});

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.row,
    required this.prefs,
    required this.disabled,
    required this.onChannel,
  });

  final _CategoryRow row;
  final NotificationPrefs prefs;
  final bool disabled;
  final _ChannelWrite onChannel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ch = prefs.channels[row.category]!;
    final locked = row.category == NotificationCategory.booking;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpace.s12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: _switchColumn,
            child: _ChannelSwitch(
              key: Key('switch-${row.category.name}-push'),
              label: _label(l, row.label, l.notifSettingsColPush, ch.push),
              value: ch.push,
              onChanged: disabled
                  ? null
                  : (v) => onChannel(row.category, push: v),
            ),
          ),
          SizedBox(
            width: _switchColumn,
            child: row.pushOnly
                ? null
                : _ChannelSwitch(
                    key: Key('switch-${row.category.name}-inApp'),
                    label: locked
                        ? l.notifSwitchLocked(
                            row.label,
                            l.notifSettingsColInApp,
                          )
                        : _label(
                            l,
                            row.label,
                            l.notifSettingsColInApp,
                            ch.inApp,
                          ),
                    value: ch.inApp,
                    onChanged: disabled || locked
                        ? null
                        : (v) => onChannel(row.category, inApp: v),
                  ),
          ),
        ],
      ),
    );
  }

  static String _label(
    AppLocalizations l,
    String group,
    String channel,
    bool on,
  ) => on ? l.notifSwitchOn(group, channel) : l.notifSwitchOff(group, channel);
}

/// A switch whose whole 48dp cell reads as one control with a full sentence.
class _ChannelSwitch extends StatelessWidget {
  const _ChannelSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      toggled: value,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      excludeSemantics: true,
      child: Center(
        child: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

class _QuietRow extends StatelessWidget {
  const _QuietRow({
    required this.state,
    required this.onToggle,
    required this.onPickRange,
  });

  final NotificationSettingsState state;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final p = state.prefs;
    final off = state.fromCache;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.notifSettingsQuietTitle,
                style: theme.textTheme.titleMedium,
              ),
              InkWell(
                key: const Key('quiet-range'),
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: off || !p.quietEnabled ? null : onPickRange,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSpace.s12),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l.notifSettingsQuietLine(p.quietFrom, p.quietTo),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        _ChannelSwitch(
          key: const Key('switch-quiet'),
          label: p.quietEnabled
              ? l.notifSettingsQuietSwitchOn
              : l.notifSettingsQuietSwitchOff,
          value: p.quietEnabled,
          onChanged: off ? null : onToggle,
        ),
      ],
    );
  }
}

class _RemindersRow extends StatelessWidget {
  const _RemindersRow({required this.state, required this.onChanged});

  final NotificationSettingsState state;
  final void Function({bool? h24, bool? h2}) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = state.prefs;
    return Row(
      children: [
        Expanded(
          child: Text(
            l.notifSettingsRemindersTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IgnorePointer(
          ignoring: state.fromCache,
          child: Opacity(
            opacity: state.fromCache ? 0.5 : 1,
            child: Wrap(
              spacing: AppSpace.s2,
              children: [
                AppChip(
                  key: const Key('reminder-24'),
                  label: l.notifSettingsReminder24,
                  selected: p.reminder24,
                  kind: AppChipKind.context,
                  onChanged: (v) => onChanged(h24: v),
                ),
                AppChip(
                  key: const Key('reminder-2'),
                  label: l.notifSettingsReminder2,
                  selected: p.reminder2,
                  kind: AppChipKind.context,
                  onChanged: (v) => onChanged(h2: v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        GlassCard(
          highlight: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Column(
              key: const Key('notification-settings-skeleton'),
              children: [
                for (var i = 0; i < 6; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
                    child: Row(
                      children: [
                        Expanded(child: AppSkeleton.line(height: 16)),
                        const SizedBox(width: AppSpace.s6),
                        AppSkeleton.line(width: 40, height: 24),
                        const SizedBox(width: AppSpace.s6),
                        AppSkeleton.line(width: 40, height: 24),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
