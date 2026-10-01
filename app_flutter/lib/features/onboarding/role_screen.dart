import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/auth/auth_controller.dart';
import 'package:photobooking/features/onboarding/role_controller.dart';

class RoleScreen extends ConsumerStatefulWidget {
  const RoleScreen({super.key});
  @override
  ConsumerState<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends ConsumerState<RoleScreen> {
  UserRole _selected = UserRole.customer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final loading = ref.watch(roleControllerProvider).isLoading;
    ref.listen(roleControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.roleSaveError)));
      }
    });
    return ScreenCode(
      ScreenCodes.role,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            // Scrolls on short or landscape screens and with large text, while the
            // button still sits at the bottom when there is room.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpace.s5),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpace.s5 * 2,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpace.s8),
                        Text(
                          l.roleTitle,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpace.s6),
                        _RoleCard(
                          key: const Key('role-customer'),
                          title: l.roleCustomerTitle,
                          body: l.roleCustomerBody,
                          icon: Icons.search,
                          selected: _selected == UserRole.customer,
                          onTap: () =>
                              setState(() => _selected = UserRole.customer),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        _RoleCard(
                          key: const Key('role-photographer'),
                          title: l.rolePhotographerTitle,
                          body: l.rolePhotographerBody,
                          icon: Icons.camera_alt_outlined,
                          selected: _selected == UserRole.photographer,
                          onTap: () =>
                              setState(() => _selected = UserRole.photographer),
                        ),
                        const Spacer(),
                        const SizedBox(height: AppSpace.s5),
                        AppButton.primary(
                          l.roleContinue,
                          key: const Key('role-continue'),
                          loading: loading,
                          onPressed: () => ref
                              .read(roleControllerProvider.notifier)
                              .choose(_selected),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        AppButton.text(
                          l.signOut,
                          key: const Key('role-sign-out'),
                          onPressed: () => ref
                              .read(authControllerProvider.notifier)
                              .signOut(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String body;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(controlRadius + 4),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s4),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.secondary,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(controlRadius + 4),
        ),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(body, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
