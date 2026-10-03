// S06.02: the work tab with nothing happening, turned into one next step.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

/// The one action S06.02 offers, in the spec's order of precedence.
enum WorkEmptyStep { addPhotos, addPackage, skills, share }

/// Photos a portfolio needs before the other steps count (spec S06.02).
const workEmptyMinPhotos = 6;

/// Skills score under which "Hoàn thiện kỹ năng" is offered.
const workEmptyMinCompleteness = 70;

/// Spec S06.02: under 6 photos → add photos; no active package → add one;
/// skills under 70 (or not scored yet) → complete them; else share.
WorkEmptyStep workEmptyStep({
  required int photos,
  required int activePackages,
  required int? completeness,
}) {
  if (photos < workEmptyMinPhotos) return WorkEmptyStep.addPhotos;
  if (activePackages == 0) return WorkEmptyStep.addPackage;
  if ((completeness ?? 0) < workEmptyMinCompleteness) {
    return WorkEmptyStep.skills;
  }
  return WorkEmptyStep.share;
}

@immutable
class WorkEmptyInputs {
  const WorkEmptyInputs({
    required this.photos,
    required this.activePackages,
    required this.completeness,
  });

  final int photos;
  final int activePackages;
  final int? completeness;

  WorkEmptyStep get step => workEmptyStep(
    photos: photos,
    activePackages: activePackages,
    completeness: completeness,
  );
}

/// What S06.02 needs about the photographer [uid]: photos in the portfolio's
/// first page (a further page means more than enough), active packages and
/// the server's skills score.
final workEmptyInputsProvider = FutureProvider.autoDispose
    .family<WorkEmptyInputs, String>((ref, uid) async {
      final portfolio = await ref.watch(portfolioProvider(uid).future);
      final packages = await ref.watch(myPackagesProvider.future);
      final skills = await ref.watch(
        photographerSkillsSnapshotProvider(uid).future,
      );
      final photos = portfolio.hasMore
          ? workEmptyMinPhotos
          : portfolio.posts.fold<int>(0, (n, p) => n + p.images.length);
      return WorkEmptyInputs(
        photos: photos,
        activePackages: packages.where((p) => p.active).length,
        completeness: skills.server.completeness,
      );
    }, retry: (_, _) => null);

/// S06.02 body of the work tab (its app bar belongs to `WorkScreen`).
class WorkEmptyState extends ConsumerWidget {
  const WorkEmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    if (uid == null) return const SizedBox.shrink();
    return ScreenCode(
      ScreenCodes.workEmpty,
      // No known shape: core's screen loader (ripple) while it loads.
      child: AsyncView<WorkEmptyInputs>(
        value: ref.watch(workEmptyInputsProvider(uid)),
        onRetry: () => ref.invalidate(workEmptyInputsProvider(uid)),
        data: (context, inputs) => _body(context, uid, inputs),
      ),
    );
  }

  Widget _body(BuildContext context, String uid, WorkEmptyInputs inputs) {
    final l10n = context.l10n;
    final (body, label, path) = switch (inputs.step) {
      WorkEmptyStep.addPhotos => (
        l10n.workEmptyBodyPortfolio(inputs.photos),
        l10n.workEmptyAddPhotos,
        '/action',
      ),
      WorkEmptyStep.addPackage => (
        l10n.workEmptyBodyPackage,
        l10n.workEmptyAddPackage,
        '/setup/2',
      ),
      WorkEmptyStep.skills => (
        l10n.workEmptyBodySkills,
        l10n.workEmptySkills,
        '/profile/skills',
      ),
      // No share helper in the app yet: the public profile, from where the
      // link can be copied.
      WorkEmptyStep.share => (
        l10n.workEmptyBodyShare,
        l10n.workEmptyShare,
        '/u/$uid',
      ),
    };
    return EmptyState(
      title: l10n.workEmptyTitle,
      body: body,
      actionLabel: label,
      onAction: () => path == '/action' ? context.go(path) : context.push(path),
    );
  }
}
