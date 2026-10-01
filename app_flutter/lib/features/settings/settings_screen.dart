import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final mode = ref.watch(themeModeProvider);
    final name = ref.watch(currentProfileProvider).value?.displayName;
    final themes = [
      (ThemeMode.dark, l.themeDark, Icons.dark_mode_outlined),
      (ThemeMode.light, l.themeLight, Icons.light_mode_outlined),
      (ThemeMode.system, l.themeSystem, Icons.brightness_auto_outlined),
    ];
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l.settingsTitle)),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s5),
            children: [
              _SectionLabel(l.settingsAccount),
              GlassCard(
                highlight: false,
                child: ListTile(
                  key: const Key('settings-edit-profile'),
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(l.settingsEditProfile),
                  subtitle: Text(name ?? l.settingsEditProfileBody),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/profile'),
                ),
              ),
              const SizedBox(height: AppSpace.s6),
              _SectionLabel(l.settingsAppearance),
              GlassCard(
                highlight: false,
                child: Column(
                  children: [
                    for (final (value, label, icon) in themes)
                      ListTile(
                        key: Key('theme-${value.name}'),
                        leading: Icon(icon),
                        title: Text(label),
                        selected: value == mode,
                        trailing: value == mode
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () =>
                            ref.read(themeModeProvider.notifier).set(value),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpace.s1, bottom: AppSpace.s2),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}
