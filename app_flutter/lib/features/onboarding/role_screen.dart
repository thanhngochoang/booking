import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_ext.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/widgets/app_button.dart';
import '../../data/user/user_profile.dart';
import 'role_controller.dart';

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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpace.s8),
              Text(l.roleTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpace.s6),
              _RoleCard(
                key: const Key('role-customer'),
                title: l.roleCustomerTitle,
                body: l.roleCustomerBody,
                icon: Icons.search,
                selected: _selected == UserRole.customer,
                onTap: () => setState(() => _selected = UserRole.customer),
              ),
              const SizedBox(height: AppSpace.s3),
              _RoleCard(
                key: const Key('role-photographer'),
                title: l.rolePhotographerTitle,
                body: l.rolePhotographerBody,
                icon: Icons.camera_alt_outlined,
                selected: _selected == UserRole.photographer,
                onTap: () => setState(() => _selected = UserRole.photographer),
              ),
              const Spacer(),
              AppButton.primary(
                l.roleContinue,
                key: const Key('role-continue'),
                loading: loading,
                onPressed: () =>
                    ref.read(roleControllerProvider.notifier).choose(_selected),
              ),
            ],
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
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySubtle : scheme.surface,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
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
