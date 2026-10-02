import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/features/settings/button_style_controller.dart';
import 'package:photobooking/features/settings/show_screen_codes_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final mode = ref.watch(themeModeProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final name = profile?.displayName;
    final hasAvatar = profile?.avatarUrl != null;
    final buttonStyle = ref.watch(buttonStyleProvider);
    final showCodes = ref.watch(showScreenCodesProvider);
    final themes = [
      (ThemeMode.dark, l.themeDark, Icons.dark_mode_outlined),
      (ThemeMode.light, l.themeLight, Icons.light_mode_outlined),
      (ThemeMode.system, l.themeSystem, Icons.brightness_auto_outlined),
    ];
    return ScreenCode(
      ScreenCodes.settings,
      child: AuroraBackground(
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
                      for (final (i, (value, label, icon))
                          in themes.indexed) ...[
                        if (i > 0) const _RowDivider(),
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
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s6),
                _SectionLabel(l.settingsButtonStyle),
                GlassCard(
                  highlight: false,
                  child: Column(
                    children: [
                      ListTile(
                        key: const Key('button-gradient'),
                        leading: const Icon(Icons.gradient_rounded),
                        title: Text(l.buttonStyleGradient),
                        selected: buttonStyle == ButtonStyleMode.gradient,
                        trailing: buttonStyle == ButtonStyleMode.gradient
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () => ref
                            .read(buttonStyleProvider.notifier)
                            .set(ButtonStyleMode.gradient),
                      ),
                      const _RowDivider(),
                      ListTile(
                        key: const Key('button-avatar'),
                        enabled: hasAvatar,
                        leading: const Icon(Icons.face_retouching_natural),
                        title: Text(l.buttonStyleAvatar),
                        subtitle: hasAvatar
                            ? null
                            : Text(l.buttonStyleAvatarNeedsPhoto),
                        selected:
                            hasAvatar && buttonStyle == ButtonStyleMode.avatar,
                        trailing:
                            hasAvatar && buttonStyle == ButtonStyleMode.avatar
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () => ref
                            .read(buttonStyleProvider.notifier)
                            .set(ButtonStyleMode.avatar),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                Semantics(
                  label: l.settingsButtonPreview,
                  child: ExcludeSemantics(
                    child: AppButton.primary(
                      l.settingsButtonPreview,
                      size: AppButtonSize.small,
                      onPressed: () {},
                    ),
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: AppSpace.s6),
                  _SectionLabel(l.settingsDeveloper),
                  GlassCard(
                    highlight: false,
                    child: SwitchListTile(
                      key: const Key('show-screen-codes'),
                      secondary: const Icon(Icons.pin_outlined),
                      title: Text(l.settingsShowScreenCodes),
                      subtitle: Text(l.settingsShowScreenCodesBody),
                      value: showCodes,
                      onChanged: (v) =>
                          ref.read(showScreenCodesProvider.notifier).set(v),
                    ),
                  ),
                ],
              ],
            ),
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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Mock: 10.5px uppercase, .08em tracking, --ink-3. Read in sentence case.
    return Padding(
      padding: const EdgeInsets.only(left: AppSpace.s1, bottom: AppSpace.s2),
      child: Semantics(
        header: true,
        label: text,
        child: ExcludeSemantics(
          child: Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: AppText.xs2,
              fontWeight: FontWeight.w500,
              letterSpacing: AppText.xs2 * 0.08,
              color: dark
                  ? AppColorsDark.foregroundMuted
                  : AppColors.foregroundMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hairline between rows of one settings card (mock S31).
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    indent: AppSpace.s4,
    endIndent: AppSpace.s4,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}
