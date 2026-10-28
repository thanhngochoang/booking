// lib/features/jobs/invite_sheet.dart
//
// Bottom sheet for S15.02-invite:
// Recommends photographers in the job's area/specialty, filters acceptingOrders
// and allowedProviders, supports multi-selection up to remaining quota (max 5),
// and sends invites.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/job_rules.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';

Future<void> showInviteSheet(
  BuildContext context, {
  required Job job,
  required List<String> alreadyInvitedIds,
  required List<String> quotedPhotographerIds,
}) {
  return showAppSheet<void>(
    context,
    builder: (ctx) => InviteSheet(
      job: job,
      alreadyInvitedIds: alreadyInvitedIds,
      quotedPhotographerIds: quotedPhotographerIds,
    ),
  );
}

class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({
    super.key,
    required this.job,
    required this.alreadyInvitedIds,
    required this.quotedPhotographerIds,
  });

  final Job job;
  final List<String> alreadyInvitedIds;
  final List<String> quotedPhotographerIds;

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  final Set<String> _selected = {};
  bool _submitting = false;

  int get _remainingSlots => (5 - widget.alreadyInvitedIds.length).clamp(0, 5);

  bool _isEligible(PhotographerSummary p) {
    if (!p.acceptingOrders) return false;
    if (widget.job.allowedProviders == AllowedProviders.artist &&
        p.providerType != ProviderType.artist) {
      return false;
    }
    if (widget.job.allowedProviders == AllowedProviders.studio &&
        p.providerType != ProviderType.studio) {
      return false;
    }
    return true;
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final repo = ref.read(jobRepositoryProvider);
    final l = context.l10n;

    try {
      await repo.invite(widget.job.id, _selected.toList());
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.jobInvitedToast(_selected.length))),
        );
      }
    } catch (e) {
      final err = jobErrorOf(e);
      if (mounted) {
        setState(() => _submitting = false);
        final msg = err.code == 'not_accepting_orders'
            ? 'Thợ ảnh này tạm thời chưa nhận đơn'
            : err.code;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final recommender = ref.watch(recommendationRepositoryProvider);

    return ScreenCode(
      ScreenCodes.myJobs,
      label: 'invite',
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.jobInviteTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const AppIcon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                l.jobInviteLeft(_remainingSlots),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.foregroundSecondary,
                    ),
              ),
              const SizedBox(height: AppSpace.s3),
              if (_remainingSlots <= 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s6),
                  child: Center(child: Text(l.jobInviteFull)),
                )
              else
                Flexible(
                  child: FutureBuilder<RecommendationPage>(
                    future: recommender.recommendPhotographers(
                      RecommendationQuery(
                        specialtyId: widget.job.specialtyId,
                        limit: 20,
                      ),
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: DotRingLoader(size: LoaderSize.block));
                      }
                      final items = snapshot.data?.items ?? [];
                      final eligible = items.map((i) => i.photographer).where(_isEligible).toList();

                      if (eligible.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpace.s6),
                          child: Center(child: Text(l.jobInviteEmpty)),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: eligible.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final p = eligible[i];
                          final isAlreadyInvited = widget.alreadyInvitedIds.contains(p.id);
                          final hasQuoted = widget.quotedPhotographerIds.contains(p.id);
                          final disabled = isAlreadyInvited || hasQuoted;
                          final isChecked = _selected.contains(p.id);

                          return CheckboxListTile(
                            value: isChecked,
                            enabled: !disabled && (_selected.length < _remainingSlots || isChecked),
                            onChanged: disabled
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        if (_selected.length < _remainingSlots) {
                                          _selected.add(p.id);
                                        }
                                      } else {
                                        _selected.remove(p.id);
                                      }
                                    });
                                  },
                            secondary: AppAvatar(
                              url: p.avatarUrl,
                              name: p.displayName,
                              size: AppAvatarSize.sm,
                            ),
                            title: Text(p.displayName),
                            subtitle: disabled
                                ? Text(
                                    l.jobInvitedTag,
                                    style: const TextStyle(color: AppColors.foregroundSecondary),
                                  )
                                : Text(p.areaLabel ?? ''),
                          );
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpace.s3),
              AppButton.primary(
                l.jobInviteSend(_selected.length),
                loading: _submitting,
                onPressed: _selected.isNotEmpty && !_submitting ? _send : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
