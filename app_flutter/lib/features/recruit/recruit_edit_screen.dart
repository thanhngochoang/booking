import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/recruit/recruit_area_label.dart';
import 'package:photobooking/features/recruit/recruit_card.dart';
import 'package:photobooking/features/recruit/recruit_detail_screen.dart';
import 'package:photobooking/features/recruit/recruit_edit_controller.dart';
import 'package:photobooking/features/recruit/recruit_text.dart';
import 'package:photobooking/features/recruit/studio_recruit_controller.dart';
import 'package:photobooking/features/recruit/studio_recruit_screen.dart';
import 'package:photobooking/features/settings/settings_links.dart';
import 'package:photobooking/features/verification/widgets/verify_parts.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S27.04 `/studio/recruit/new` and `/studio/recruit/:postId/edit`: kind
/// (fixed once posted), title, up to 4 specialties and 5 areas, frequency,
/// fee per shoot or negotiable, requirements, the no-contact note, and one
/// primary "Đăng tin" / "Lưu thay đổi". Errors sit under their field; done,
/// it goes back to S27.05 with "Đã đăng tin" / "Đã lưu thay đổi". Only an
/// open post of the studio can be edited (Decision 22).
class RecruitEditScreen extends ConsumerWidget {
  const RecruitEditScreen({super.key, this.postId});

  /// Null when creating.
  final String? postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final id = postId;
    return ScreenCode(
      ScreenCodes.recruitEdit,
      child: StudioRecruitGate(
        builder: (context, facts) => id == null
            ? _Form(key: const ValueKey('recruit-new'), facts: facts)
            : AsyncView<RecruitPost?>(
                value: ref.watch(recruitPostProvider(id)),
                onRetry: () => ref.invalidate(recruitPostProvider(id)),
                isEmpty: (p) =>
                    p == null ||
                    p.studioId != ref.read(authStateProvider).value?.uid ||
                    !recruitPostIsOpen(p, ref.read(clockProvider)()),
                empty: (_) => Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(title: Text(l.recruitEditTitle)),
                  body: Padding(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    child: RecruitNote(
                      l.recruitClosedNote,
                      icon: AppIcons.info,
                    ),
                  ),
                ),
                data: (context, p) => _Form(
                  key: ValueKey('recruit-edit-$id'),
                  facts: facts,
                  post: p,
                ),
              ),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({super.key, required this.facts, this.post});

  final ProviderFacts facts;

  /// The open post being edited; null when creating.
  final RecruitPost? post;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final RecruitEditController _c = RecruitEditController(
    postId: widget.post?.id,
    initial: widget.post,
  )..addListener(_rebuild);

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _c
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  Future<void> _submit(DateTime? blockedUntil) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final ok = await _c.submit(
      ref.read(recruitRepositoryProvider),
      l,
      blockedUntil: blockedUntil,
    );
    if (!ok || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _c.editing ? l.recruitSavedToast : l.recruitPostedToast,
          ),
        ),
      );
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/studio/recruit');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final countersValue = ref.watch(myRecruitCountersProvider);
    final counters = countersValue.value;
    final blockedUntil = counters != null && counters.isBlocked(now)
        ? counters.recruitBlockedUntil
        : null;
    // A new post waits for the counters and follows S27.05's rule: not
    // blocked (Decision 15), under 3 open posts, a post action left today.
    // Editing a running post stays possible.
    final full =
        counters != null && counters.openPostCount >= kRecruitMaxOpenPosts;
    final noActions = counters != null && counters.postActionsLeft(now) <= 0;
    final canCreate =
        counters != null && blockedUntil == null && !full && !noActions;
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final editing = _c.editing;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(editing ? l.recruitEditTitle : l.recruitNewTitle),
        actions: [
          if (!editing && counters != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.s4),
              child: Center(
                child: Text(
                  l.recruitOpenSlots(
                    (kRecruitMaxOpenPosts - counters.openPostCount).clamp(
                      0,
                      kRecruitMaxOpenPosts,
                    ),
                  ),
                  key: const Key('recruit-open-slots'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          AppSpace.s1,
          AppSpace.s4,
          AppSpace.s6,
        ),
        children: [
          if (!editing && blockedUntil != null) ...[
            VerifyAlert(
              l.recruitBlocked(recruitBlockedDate(blockedUntil)),
              key: const Key('recruit-blocked'),
            ),
            const SizedBox(height: AppSpace.s3),
          ],
          _Label(l.recruitKindLabel),
          _kind(l),
          const SizedBox(height: AppSpace.s3),
          TextField(
            key: const Key('recruit-title'),
            controller: _c.title,
            enabled: !_c.sending,
            inputFormatters: const [RecruitTextLimit(kRecruitTitleMax)],
            textInputAction: TextInputAction.next,
            onChanged: (_) => _c.edited(RecruitField.title),
            decoration: InputDecoration(
              labelText: l.recruitTitleLabel,
              errorText: _c.errors[RecruitField.title],
              counter: RecruitTextCounter(
                controller: _c.title,
                max: kRecruitTitleMax,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          _ChipsField(
            key: const Key('recruit-specialties'),
            label: l.recruitSpecialtiesPick,
            options: [for (final s in kSpecialties) (s.id, s.labelVi)],
            selected: _c.specialties,
            canPick: _c.canPickSpecialty,
            onToggle: _c.sending ? null : _c.toggleSpecialty,
            error: _c.errors[RecruitField.specialties],
          ),
          const SizedBox(height: AppSpace.s3),
          _ChipsField(
            key: const Key('recruit-areas'),
            label: l.recruitAreasPick,
            options: [
              for (final a in builtInAreas) (a.id, recruitAreaName(a.id)),
            ],
            selected: _c.areas,
            canPick: _c.canPickArea,
            onToggle: _c.sending ? null : _c.toggleArea,
            error: _c.errors[RecruitField.areas],
          ),
          const SizedBox(height: AppSpace.s3),
          _Label(l.recruitFrequencyLabel),
          SegmentedTabs<RecruitFrequency>(
            key: const Key('recruit-frequency'),
            options: [
              for (final f in RecruitFrequency.values)
                SegmentOption(value: f, label: recruitFrequencyLong(f, l)),
            ],
            value: _c.frequency,
            onChanged: _c.sending ? (_) {} : _c.setFrequency,
          ),
          const SizedBox(height: AppSpace.s3),
          _Label(l.recruitFeePick),
          SegmentedTabs<bool>(
            key: const Key('recruit-fee-kind'),
            options: [
              SegmentOption(value: true, label: l.recruitFeeKindPerShoot),
              SegmentOption(value: false, label: l.recruitFeeKindNegotiable),
            ],
            value: _c.perShoot,
            onChanged: _c.sending ? (_) {} : _c.setPerShoot,
          ),
          if (_c.perShoot) ...[
            const SizedBox(height: AppSpace.s2),
            TextField(
              key: const Key('recruit-fee-amount'),
              controller: _c.amount,
              enabled: !_c.sending,
              keyboardType: TextInputType.number,
              inputFormatters: const [VndInputFormatter()],
              onChanged: (_) => _c.edited(RecruitField.fee),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                hintText: l.recruitFeeAmountHint,
                suffixText: l.recruitFeeAmountSuffix,
                errorText: _c.errors[RecruitField.fee],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s3),
          TextField(
            key: const Key('recruit-requirements'),
            controller: _c.requirements,
            enabled: !_c.sending,
            minLines: 2,
            maxLines: 6,
            inputFormatters: const [RecruitTextLimit(kRecruitRequirementsMax)],
            textInputAction: TextInputAction.newline,
            onChanged: (_) => _c.edited(RecruitField.requirements),
            decoration: InputDecoration(
              labelText: l.recruitRequirements,
              hintText: l.recruitRequirementsHint,
              errorText: _c.errors[RecruitField.requirements],
              errorMaxLines: 2,
              counter: RecruitTextCounter(
                controller: _c.requirements,
                max: kRecruitRequirementsMax,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          RecruitNote(l.recruitFormNote, icon: AppIcons.info),
        ],
      ),
      bottomNavigationBar: AppFooterBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!editing)
              // Shows only a failure of the counters, with "Thử lại".
              AsyncView<RecruitCounters>(
                value: countersValue,
                loaderSize: LoaderSize.inline,
                skeleton: (_) => const SizedBox.shrink(),
                error: (context, e, _) => _CountersError(
                  message: errorMessage(e, l),
                  onRetry: () => ref.invalidate(myRecruitCountersProvider),
                ),
                data: (_, _) => const SizedBox.shrink(),
              ),
            if (!editing && noActions && !full && blockedUntil == null) ...[
              Text(
                l.recruitErrorRateLimited,
                key: const Key('recruit-no-actions'),
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
              const SizedBox(height: AppSpace.s2),
            ],
            if (_c.formError case final e?) ...[
              Text(
                e,
                key: const Key('recruit-form-error'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: AppSpace.s2),
            ],
            _primary(l, editing || canCreate, blockedUntil, full: full),
          ],
        ),
      ),
    );
  }

  Widget _primary(
    AppLocalizations l,
    bool allowed,
    DateTime? blockedUntil, {
    required bool full,
  }) {
    if (!widget.facts.acceptingOrders &&
        !_c.editing &&
        ref.watch(verifyStartReadyProvider)) {
      return AppButton.primary(
        l.recruitVerifyToPost,
        key: const Key('recruit-submit'),
        onPressed: () => context.push('/verify/start'),
      );
    }
    return AppButton.primary(
      _c.editing
          ? l.recruitSave
          : full
          ? l.recruitFull
          : l.recruitPublish,
      key: const Key('recruit-submit'),
      loading: _c.sending,
      onPressed: allowed ? () => _submit(blockedUntil) : null,
    );
  }

  Widget _kind(AppLocalizations l) {
    Widget tile(RecruitKind k, String label, String hint) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: AppOptionTile(
        key: Key('recruit-kind-${k.code}'),
        label: label,
        description: hint,
        selected: _c.kind == k,
        // Fixed once posted (Decision 22): the other kind is dimmed.
        enabled: !_c.editing || _c.kind == k,
        onTap: () => _c.setKind(k),
      ),
    );
    return Semantics(
      label: l.recruitKindLabel,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile(
            RecruitKind.collaborator,
            l.recruitKindCollaborator,
            l.recruitKindCollaboratorHint,
          ),
          tile(
            RecruitKind.member,
            l.recruitKindMemberLabel,
            l.recruitKindMemberHint,
          ),
        ],
      ),
    );
  }
}

/// Mock small uppercase caption over a group.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s1),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: AppText.xs,
            fontWeight: FontWeight.w600,
            color: theme.brightness == Brightness.dark
                ? AppColorsDark.foregroundMuted
                : AppColors.foregroundMuted,
          ),
        ),
      ),
    );
  }
}

/// A caption, a wrap of chips picked up to a limit (the rest dimmed), and
/// the field's error line.
class _ChipsField extends StatelessWidget {
  const _ChipsField({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.canPick,
    required this.onToggle,
    required this.error,
  });

  final String label;

  /// `(id, label)`.
  final List<(String, String)> options;
  final List<String> selected;
  final bool Function(String id) canPick;
  final ValueChanged<String>? onToggle;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toggle = onToggle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        Wrap(
          spacing: AppSpace.s2,
          children: [
            for (final (id, text) in options)
              AppChip(
                key: ValueKey('recruit-chip-$id'),
                label: text,
                kind: AppChipKind.context,
                selected: selected.contains(id),
                enabled: toggle != null && canPick(id),
                onChanged: (_) => toggle?.call(id),
              ),
          ],
        ),
        if (error case final e?)
          Text(
            e,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}

/// A failed counters read in the footer: the message and "Thử lại".
class _CountersError extends StatelessWidget {
  const _CountersError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              key: const Key('recruit-counters-error'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          AppButton.text(
            context.l10n.retry,
            key: const Key('recruit-counters-retry'),
            size: AppButtonSize.xsmall,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
