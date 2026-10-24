import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/recruit/recruit_area_label.dart';
import 'package:photobooking/features/recruit/recruit_card.dart';
import 'package:photobooking/features/recruit/recruit_list_controller.dart';

/// S27.01 "Tuyển thợ": filter chips (Khu vực, Thể loại, the two kinds), the
/// open posts with score-2 ones first and tagged "Hợp với bạn", "Xem thêm"
/// at the end, and the R3 note. The body of `/recruit` and of the last
/// segment of S06.01 (Decision 20). A non-provider account sees only the
/// note and queries nothing (R3).
class RecruitListView extends ConsumerStatefulWidget {
  const RecruitListView({super.key, this.initial = const RecruitFilter()});

  /// A `studioId` filter (S03.01 "Đang tuyển") hides the chips: the query
  /// takes one studio or one filter key, not both.
  final RecruitFilter initial;

  @override
  ConsumerState<RecruitListView> createState() => _RecruitListViewState();
}

class _RecruitListViewState extends ConsumerState<RecruitListView> {
  late RecruitFilter _filter = widget.initial;

  static const _gutter = EdgeInsets.symmetric(horizontal: AppSpace.s4);

  void _set(RecruitFilter f) => setState(() => _filter = f);

  RecruitFilter _with({
    RecruitKind? Function()? kind,
    String? Function()? area,
    String? Function()? specialty,
  }) => RecruitFilter(
    kind: kind == null ? _filter.kind : kind(),
    area: area == null ? _filter.area : area(),
    specialty: specialty == null ? _filter.specialty : specialty(),
  );

  Future<void> _pickArea() async {
    final l = context.l10n;
    final picked = await _showPicker(
      context,
      title: l.recruitFilterArea,
      options: [for (final a in builtInAreas) (a.id, a.name)],
      selected: _filter.area,
    );
    if (picked != null && mounted) {
      _set(_with(area: () => picked.isEmpty ? null : picked));
    }
  }

  Future<void> _pickSpecialty() async {
    final l = context.l10n;
    final picked = await _showPicker(
      context,
      title: l.recruitFilterSpecialty,
      options: [for (final s in kSpecialties) (s.id, s.labelVi)],
      selected: _filter.specialty,
    );
    if (picked != null && mounted) {
      _set(_with(specialty: () => picked.isEmpty ? null : picked));
    }
  }

  void _toggleKind(RecruitKind k) =>
      _set(_with(kind: () => _filter.kind == k ? null : k));

  Future<void> _loadMore() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(recruitListProvider(_filter).notifier).loadMore();
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.recruitErrorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final value = ref.watch(recruitListProvider(_filter));
    // Chips only for a provider (R3) and without a studio filter.
    final provider =
        ref.watch(myProviderFactsProvider).value?.isProviderAccount ?? false;
    final chips = provider && _filter.studioId == null;
    final now = ref.watch(clockProvider)();
    return ScreenCode(
      ScreenCodes.recruitList,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chips) _chips(context),
          Expanded(
            child: AsyncView<RecruitListState>(
              value: value,
              skeleton: (_) => _skeleton(),
              onRetry: () => ref.invalidate(recruitListProvider(_filter)),
              isEmpty: (s) => s.visible && s.posts.isEmpty,
              empty: (_) => ListView(
                padding: const EdgeInsets.all(AppSpace.s4),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                    child: Text(
                      l.recruitEmpty,
                      key: const Key('recruit-empty'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  RecruitNote(l.recruitOnlyProvidersNote),
                ],
              ),
              data: (context, s) => s.visible
                  ? _list(context, s, now)
                  : ListView(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      children: [RecruitNote(l.recruitOnlyProvidersNote)],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips(BuildContext context) {
    final l = context.l10n;
    const more = AppIcon(AppIcons.expandMore);
    final area = _filter.area;
    final specialty = _filter.specialty;
    return SingleChildScrollView(
      key: const Key('recruit-filters'),
      scrollDirection: Axis.horizontal,
      padding: _gutter,
      child: Row(
        children: [
          AppChip(
            key: const Key('recruit-filter-area'),
            label: area == null ? l.recruitFilterArea : recruitAreaName(area),
            selected: area != null,
            trailing: more,
            onChanged: (_) => _pickArea(),
          ),
          const SizedBox(width: AppSpace.s2),
          AppChip(
            key: const Key('recruit-filter-specialty'),
            label: specialty == null
                ? l.recruitFilterSpecialty
                : recruitSpecialtyLabel(specialty),
            selected: specialty != null,
            trailing: more,
            onChanged: (_) => _pickSpecialty(),
          ),
          for (final k in RecruitKind.values) ...[
            const SizedBox(width: AppSpace.s2),
            AppChip(
              key: Key('recruit-filter-kind-${k.code}'),
              label: recruitKindLabel(k, l),
              selected: _filter.kind == k,
              onChanged: (_) => _toggleKind(k),
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(BuildContext context, RecruitListState s, DateTime now) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        AppSpace.s6,
      ),
      children: [
        for (final p in s.posts) ...[
          RecruitCard(
            key: Key('recruit-card-${p.id}'),
            post: p,
            match: s.matches(p),
            now: now,
            onTap: () => context.push('/recruit/${p.id}'),
          ),
          const SizedBox(height: AppSpace.s2),
        ],
        if (s.hasMore)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s2),
            child: AppButton.outline(
              l.recruitLoadMore,
              key: const Key('recruit-load-more'),
              size: AppButtonSize.small,
              loading: s.loadingMore,
              onPressed: _loadMore,
            ),
          ),
        const SizedBox(height: AppSpace.s1),
        RecruitNote(l.recruitOnlyProvidersNote),
      ],
    );
  }

  Widget _skeleton() => ListView(
    padding: const EdgeInsets.all(AppSpace.s4),
    children: [
      for (var i = 0; i < 3; i++) ...[
        RecruitCard.skeleton(key: ValueKey('recruit-card-skeleton-$i')),
        const SizedBox(height: AppSpace.s2),
      ],
    ],
  );
}

/// One of [options] (`(id, label)`), or '' for "Tất cả"; null when the sheet
/// is dismissed.
Future<String?> _showPicker(
  BuildContext context, {
  required String title,
  required List<(String, String)> options,
  required String? selected,
}) => showAppSheet<String>(
  context,
  builder: (sheetContext) {
    final l = sheetContext.l10n;
    final theme = Theme.of(sheetContext);
    Widget option(String id, String label, bool on) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: AppOptionTile(
        label: label,
        selected: on,
        onTap: () => Navigator.of(sheetContext).pop(id),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s5,
            0,
            AppSpace.s5,
            AppSpace.s3,
          ),
          child: Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              0,
              AppSpace.s4,
              AppSpace.s4,
            ),
            children: [
              option('', l.recruitFilterAll, selected == null),
              for (final (id, label) in options)
                option(id, label, selected == id),
            ],
          ),
        ),
      ],
    );
  },
);
