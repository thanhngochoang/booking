// lib/features/jobs/job_post_screen.dart
//
// S15.01 Post a Job (2 steps):
// Step 1: Specialty chips, title counter, description, reference photos grid, privacy note, Tiếp tục.
// Step 2: Fixed vs flexible tabs, schedule picker, area picker, budget fields + chip,
// wants picker, allowed providers chips, deadline days picker, submit.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_draft.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/explore/area_picker_sheet.dart';
import 'package:photobooking/features/jobs/job_draft_controller.dart';
import 'package:photobooking/features/jobs/job_post_sheets.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class JobPostScreen extends ConsumerStatefulWidget {
  const JobPostScreen({
    super.key,
    this.fromJobId,
    this.editJobId,
  });

  final String? fromJobId;
  final String? editJobId;

  @override
  ConsumerState<JobPostScreen> createState() => _JobPostScreenState();
}

class _JobPostScreenState extends ConsumerState<JobPostScreen> {
  late TextEditingController _titleCtl;
  late TextEditingController _descCtl;
  late TextEditingController _budgetMinCtl;
  late TextEditingController _budgetMaxCtl;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(jobDraftStateProvider).draft;
    _titleCtl = TextEditingController(text: draft.title);
    _descCtl = TextEditingController(text: draft.description);
    _budgetMinCtl = TextEditingController(
      text: draft.budget?.min != null ? draft.budget!.min.toString() : '',
    );
    _budgetMaxCtl = TextEditingController(
      text: draft.budget?.max != null ? draft.budget!.max.toString() : '',
    );
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _budgetMinCtl.dispose();
    _budgetMaxCtl.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final state = ref.read(jobDraftStateProvider);
    final ctl = ref.read(jobDraftStateProvider.notifier);
    final l = context.l10n;

    if (state.draft.title.isNotEmpty || state.draft.specialtyId.isNotEmpty) {
      final confirmed = await showConfirmSheet(
        context,
        title: l.jobPostSaveDraftTitle,
        body: l.jobPostSaveDraftBody,
        confirmLabel: l.jobPostSaveDraft,
        keepLabel: l.jobPostDiscard,
        danger: false,
        onConfirm: () async {
          await ctl.saveDraft();
        },
      );
      if (!confirmed) {
        await ctl.discard();
      }
      return true;
    }
    return true;
  }

  void _onSpecialtySelected(String id) {
    ref.read(jobDraftStateProvider.notifier).setSpecialty(id);
  }

  Future<void> _pickImages() async {
    final picker = ref.read(imagePickerProvider);
    final picked = await picker.pickImages(max: 5);
    if (picked.isNotEmpty) {
      await ref.read(jobDraftStateProvider.notifier).addReferences(picked);
    }
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final res = await ref.read(jobDraftStateProvider.notifier).submit();
    if (!mounted) return;

    if (res != null) {
      final msg = res.matched > 0
          ? l.jobPostPosted(res.matched)
          : l.jobPostPostedNone;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      context.replace('/jobs/${res.jobId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(jobDraftStateProvider);
    final ctl = ref.read(jobDraftStateProvider.notifier);

    // Sync controllers if updated from draft restore
    if (_titleCtl.text.isEmpty && state.draft.title.isNotEmpty) {
      _titleCtl.text = state.draft.title;
    }
    if (_descCtl.text.isEmpty && state.draft.description.isNotEmpty) {
      _descCtl.text = state.draft.description;
    }

    return ScreenCode(
      ScreenCodes.jobPost,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final canLeave = await _onWillPop();
          if (canLeave && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: state.step == 1
                ? IconButton(
                    icon: const AppIcon(AppIcons.close),
                    onPressed: () async {
                      final canLeave = await _onWillPop();
                      if (canLeave && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  )
                : IconButton(
                    icon: const AppIcon(AppIcons.back),
                    onPressed: ctl.back,
                  ),
            title: Text(l.jobPostTitle),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                child: Center(
                  child: Text(
                    l.jobPostStep(state.step),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.foregroundSecondary,
                        ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              StepProgress(current: state.step, total: 2, showCount: false),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: state.step == 1
                      ? _buildStep1(l, state, ctl)
                      : _buildStep2(l, state, ctl),
                ),
              ),
              _buildFooter(l, state, ctl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(AppLocalizations l, JobDraftState state, JobDraftController ctl) {
    final titleCount = state.draft.title.characters.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.jobPostWhat,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpace.s2),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [
            for (final s in kSpecialties)
              ChoiceChip(
                label: Text(s.labelVi),
                selected: state.draft.specialtyId == s.id,
                onSelected: (_) => _onSpecialtySelected(s.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s4),
        TextField(
          controller: _titleCtl,
          maxLength: 60,
          decoration: InputDecoration(
            labelText: l.jobPostName,
            counterText: l.jobPostNameCount(titleCount),
            errorText: state.errors['title'],
          ),
          onChanged: ctl.setTitle,
        ),
        const SizedBox(height: AppSpace.s2),
        TextField(
          controller: _descCtl,
          maxLines: 4,
          maxLength: 1000,
          decoration: InputDecoration(
            labelText: l.jobPostDesc,
            errorText: state.errors['description'],
          ),
          onChanged: ctl.setDescription,
        ),
        const SizedBox(height: AppSpace.s4),
        Text(
          l.jobPostRefs.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.foregroundSecondary,
              ),
        ),
        const SizedBox(height: AppSpace.s2),
        _buildReferencesGrid(state, ctl),
        if (state.errors['references'] != null) ...[
          const SizedBox(height: AppSpace.s1),
          Text(
            state.errors['references']!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: AppSpace.s4),
        Container(
          padding: const EdgeInsets.all(AppSpace.s3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIcon(AppIcons.lock, size: 16),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(
                  l.jobPostPrivacy,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReferencesGrid(JobDraftState state, JobDraftController ctl) {
    final refs = state.draft.references;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: refs.length < 5 ? refs.length + 1 : 5,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: AppSpace.s2,
        mainAxisSpacing: AppSpace.s2,
      ),
      itemBuilder: (context, i) {
        if (i < refs.length) {
          final r = refs[i];
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.network(r.url, fit: BoxFit.cover),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => ctl.removeReference(r),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const AppIcon(AppIcons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        } else {
          return InkWell(
            onTap: _pickImages,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Center(
                child: AppIcon(AppIcons.add, color: AppColors.foregroundSecondary),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildStep2(AppLocalizations l, JobDraftState state, JobDraftController ctl) {
    final schedule = state.draft.schedule;
    final now = DateTime.now();
    final minFixedDay = now.add(Duration(days: state.draft.deadlineDays + 1));
    final maxFixedDay = now.add(const Duration(days: 365));

    String scheduleValue = l.jobPostWhenEmpty;
    if (schedule.kind == ScheduleKind.fixed) {
      if (schedule.day != null && schedule.start != null && schedule.end != null) {
        scheduleValue = l.jobPostWhenFixedValue(
          schedule.day!,
          '${schedule.start}–${schedule.end}',
          '${(schedule.durationMinutes / 60).toStringAsFixed(1)} giờ',
        );
      }
    } else {
      if (schedule.from != null && schedule.to != null) {
        scheduleValue = l.jobPostWhenFlexValue(
          schedule.from!,
          schedule.to!,
          '${(schedule.durationMinutes / 60).toStringAsFixed(1)} giờ',
        );
      }
    }

    final areaValue = state.draft.area.name.isNotEmpty
        ? state.draft.area.name
        : l.jobPostAreaEmpty;

    final wants = state.draft.wants;
    final wantsValue = wants.editedCount != null && wants.deliveryDays != null
        ? l.jobPostWantsValue(wants.editedCount!, wants.deliveryDays!)
        : l.jobPostWantsAny;

    final deadlineDateStr = formatDay(now.add(Duration(days: state.draft.deadlineDays)));
    final deadlineValue = l.jobPostDeadlineValue(state.draft.deadlineDays, deadlineDateStr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.jobPostWhen),
          subtitle: Text(scheduleValue),
          trailing: const AppIcon(AppIcons.chevron),
          onTap: () async {
            final res = await showScheduleSheet(
              context,
              current: schedule,
              minFixedDay: minFixedDay,
              maxFixedDay: maxFixedDay,
            );
            if (res != null) ctl.setSchedule(res);
          },
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.jobPostArea),
          subtitle: Text(areaValue),
          trailing: const AppIcon(AppIcons.chevron),
          onTap: () async {
            final picked = await pickAreaOption(context);
            if (picked != null) {
              ctl.setArea(
                JobDraftArea(
                  areaId: picked.id,
                  name: picked.name,
                  lat: picked.lat,
                  lng: picked.lng,
                ),
              );
            }
          },
        ),
        const Divider(),
        const SizedBox(height: AppSpace.s2),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _budgetMinCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.jobPostBudgetFrom,
                  hintText: '500.000',
                ),
                onChanged: (_) {
                  final min = int.tryParse(_budgetMinCtl.text.trim()) ?? 0;
                  final max = int.tryParse(_budgetMaxCtl.text.trim()) ?? 0;
                  if (max >= min && max > 0) {
                    ctl.setBudget(min, max);
                  }
                },
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: TextField(
                controller: _budgetMaxCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.jobPostBudgetTo,
                  hintText: '2.000.000',
                ),
                onChanged: (_) {
                  final min = int.tryParse(_budgetMinCtl.text.trim()) ?? 0;
                  final max = int.tryParse(_budgetMaxCtl.text.trim()) ?? 0;
                  if (max >= min && max > 0) {
                    ctl.setBudget(min, max);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s1),
        ActionChip(
          label: Text(l.jobPostBudgetOpen),
          onPressed: () {
            _budgetMinCtl.clear();
            _budgetMaxCtl.clear();
            ctl.clearBudget();
          },
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.jobPostWants),
          subtitle: Text(wantsValue),
          trailing: const AppIcon(AppIcons.chevron),
          onTap: () async {
            final res = await showWantsSheet(context, current: wants);
            if (res != null) ctl.setWants(res);
          },
        ),
        const Divider(),
        const SizedBox(height: AppSpace.s2),
        Text(
          l.jobPostWho,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpace.s1),
        Wrap(
          spacing: AppSpace.s2,
          children: [
            ChoiceChip(
              label: Text(l.jobPostWhoAll),
              selected: state.draft.allowedProviders == AllowedProviders.all,
              onSelected: (_) => ctl.setAllowed(AllowedProviders.all),
            ),
            ChoiceChip(
              label: Text(l.jobPostWhoArtist),
              selected: state.draft.allowedProviders == AllowedProviders.artist,
              onSelected: (_) => ctl.setAllowed(AllowedProviders.artist),
            ),
            ChoiceChip(
              label: Text(l.jobPostWhoStudio),
              selected: state.draft.allowedProviders == AllowedProviders.studio,
              onSelected: (_) => ctl.setAllowed(AllowedProviders.studio),
            ),
          ],
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.jobPostDeadline),
          subtitle: Text(deadlineValue),
          trailing: const AppIcon(AppIcons.chevron),
          onTap: () async {
            final res = await showDeadlineSheet(context, currentDays: state.draft.deadlineDays);
            if (res != null) ctl.setDeadlineDays(res);
          },
        ),
      ],
    );
  }

  Widget _buildFooter(AppLocalizations l, JobDraftState state, JobDraftController ctl) {
    final canProceed = ctl.canProceed();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: AppButton.primary(
          state.step == 1
              ? l.jobPostNext
              : (widget.editJobId != null ? l.jobPostSave : l.jobPostSubmit),
          loading: state.submitting,
          onPressed: canProceed && !state.submitting
              ? () {
                  if (state.step == 1) {
                    ctl.next();
                  } else {
                    _submit();
                  }
                }
              : null,
        ),
      ),
    );
  }
}
