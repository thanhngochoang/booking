// lib/features/job_market/open_jobs_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_card_data_of.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/job_repository.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

class OpenJobsTab extends ConsumerStatefulWidget {
  const OpenJobsTab({super.key});

  @override
  ConsumerState<OpenJobsTab> createState() => _OpenJobsTabState();
}

class _OpenJobsTabState extends ConsumerState<OpenJobsTab> {
  OpenJobsMode _mode = OpenJobsMode.fit;
  String? _specialtyId;
  bool _budgetOnly = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = ref.watch(clockProvider)();
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final introAsync = ref.watch(myIntroProvider);
    final profileAsync = ref.watch(photographerProfileProvider(uid));

    // Check onboarding setup requirement
    final intro = introAsync.value;
    if (intro != null && !intro.onboardingComplete) {
      return ScreenCode(
        ScreenCodes.openJobs,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: EmptyState(
            title: l.openJobsNeedSetupTitle,
            actionLabel: l.openJobsNeedSetupAction,
            onAction: () => context.push('/setup'),
          ),
        ),
      );
    }

    final me = profileAsync.value?.summary ??
        PhotographerSummary(
          id: uid,
          displayName: '',
          providerType: ProviderType.individual,
        );

    final firstSpecialty = (me.specialtyIds.isNotEmpty)
        ? me.specialtyIds.first
        : (kSpecialties.isNotEmpty ? kSpecialties.first.id : null);
    final firstSpecialtyLabel = firstSpecialty != null ? specialtyLabel(firstSpecialty) : null;

    final filter = OpenJobsFilter(
      mode: _mode,
      specialtyId: _specialtyId,
      budgetOnly: _budgetOnly,
    );

    final openJobsAsync = ref.watch(openJobsProvider(filter));

    return ScreenCode(
      ScreenCodes.openJobs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
            child: Row(
              children: [
                AppChip(
                  key: const Key('filter-fit'),
                  label: l.openJobsFit,
                  selected: _mode == OpenJobsMode.fit && _specialtyId == null && !_budgetOnly,
                  onChanged: (sel) {
                    if (sel) {
                      setState(() {
                        _mode = OpenJobsMode.fit;
                        _specialtyId = null;
                        _budgetOnly = false;
                      });
                    }
                  },
                ),
                const SizedBox(width: AppSpace.s2),
                AppChip(
                  key: const Key('filter-near'),
                  label: l.openJobsNear,
                  selected: _mode == OpenJobsMode.near,
                  onChanged: (sel) {
                    setState(() {
                      _mode = sel ? OpenJobsMode.near : OpenJobsMode.fit;
                    });
                  },
                ),
                if (firstSpecialty != null && firstSpecialtyLabel != null) ...[
                  const SizedBox(width: AppSpace.s2),
                  AppChip(
                    key: const Key('filter-specialty'),
                    label: firstSpecialtyLabel,
                    selected: _specialtyId == firstSpecialty,
                    onChanged: (sel) {
                      setState(() {
                        _specialtyId = sel ? firstSpecialty : null;
                      });
                    },
                  ),
                ],
                const SizedBox(width: AppSpace.s2),
                AppChip(
                  key: const Key('filter-budget'),
                  label: l.openJobsBudget,
                  selected: _budgetOnly,
                  onChanged: (sel) {
                    setState(() {
                      _budgetOnly = sel;
                    });
                  },
                ),
              ],
            ),
          ),

          // Job list or empty state
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(openJobsProvider(filter));
              },
              child: AsyncView(
                value: openJobsAsync,
                data: (context, rawItems) {
                  final items = rawItems.where((item) {
                    if (item.job.allowedProviders == AllowedProviders.studio &&
                        me.providerType == ProviderType.individual) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (items.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      children: [
                        const SizedBox(height: 60),
                        EmptyState(
                          title: l.openJobsEmpty,
                          actionLabel: l.openJobsEmptyAction,
                          onAction: () => context.push('/profile/skills'),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
                    itemCount: items.length,
                    itemBuilder: (context, idx) {
                      final item = items[idx];
                      final cardData = photographerJobCardOf(item, me, now, l);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s3),
                        child: JobCard(
                          key: Key('job-card-${item.job.id}'),
                          data: cardData,
                          variant: JobCardVariant.photographer,
                          onTap: () {
                            if (cardData.locked) {
                              context.push('/me/awards');
                            } else {
                              context.push('/jobs/${item.job.id}');
                            }
                          },
                        ),
                      );
                    },
                  );
                },
                skeleton: (_) => ListView.builder(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  itemCount: 4,
                  itemBuilder: (_, _) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s3),
                    child: JobCard.skeleton(variant: JobCardVariant.photographer),
                  ),
                ),
                error: (_, err, _) => Center(child: Text(err.toString())),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
