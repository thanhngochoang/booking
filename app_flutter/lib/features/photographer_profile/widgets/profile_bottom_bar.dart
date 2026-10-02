// lib/features/photographer_profile/widgets/profile_bottom_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/contact/contact_action.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';

/// The fixed bar of S03.01. Visitors: the in-app inquiry (the only contact
/// before a booking, spec 3b.1) and "Đặt lịch · từ …". Owner: "Chỉnh sửa
/// hồ sơ". Sits below the scroll view, so it never covers the last item.
class ProfileBottomBar extends ConsumerWidget {
  const ProfileBottomBar({
    super.key,
    required this.photographerId,
    required this.owner,
    required this.onEdit,
  });

  final String photographerId;
  final bool owner;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final packages = ref.watch(profilePackagesProvider(photographerId));
    final from = startingPriceOf(packages.value ?? const []);
    final none = !owner && packages.hasValue && from == null;
    final Widget bar = owner
        ? AppButton.primary(
            l.profileEdit,
            key: const Key('profile-edit'),
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: onEdit,
          )
        : Row(
            children: [
              PhotographerContactAction(
                photographerId: photographerId,
                access: ContactAccess.locked,
                source: ScreenCodes.photographerProfile,
                onInquiry: () => context.push(inquiryPath(photographerId)),
              ),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: AppButton.primary(
                  from == null
                      ? l.profileBook
                      : l.profileBookFrom(formatMoney(from, short: true)),
                  key: const Key('profile-book'),
                  onPressed: from == null
                      ? null
                      : () => startBooking(
                          context,
                          ref,
                          photographerId: photographerId,
                        ),
                ),
              ),
            ],
          );
    return AppFooterBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (none) ...[
            Text(
              l.profileNoServices,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpace.s2),
          ],
          bar,
        ],
      ),
    );
  }
}
