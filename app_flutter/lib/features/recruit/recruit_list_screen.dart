import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/recruit/recruit_providers.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';
import 'package:photobooking/features/recruit/recruit_list_view.dart';

/// `/recruit` (query `studioId`): S27.01 on its own page, the bar reading
/// "Công việc" over "Tuyển thợ" as in the S06.01 segment.
class RecruitListScreen extends StatelessWidget {
  const RecruitListScreen({super.key, this.studioId});

  /// S03.01 "Đang tuyển · {n} tin": that studio's open posts.
  final String? studioId;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      centerTitle: false,
      titleTextStyle: tabRootTitleStyle(context),
      title: const RecruitBarTitle(),
      actions: const [RecruitStudioPostsAction()],
    ),
    body: RecruitListView(
      initial: studioId == null || studioId!.isEmpty
          ? const RecruitFilter()
          : RecruitFilter(studioId: studioId),
    ),
  );
}

/// Mock S27.01 bar: small "Công việc" over "Tuyển thợ".
class RecruitBarTitle extends StatelessWidget {
  const RecruitBarTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.workTitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.brightness == Brightness.dark
                ? AppColorsDark.foregroundSecondary
                : AppColors.foregroundSecondary,
          ),
        ),
        Text(l.recruitTitle),
      ],
    );
  }
}

/// The studio's bar icon "Tin tuyển của studio" → S27.05 (Decision 20);
/// nothing for anyone else, or while the account's facts load.
class RecruitStudioPostsAction extends ConsumerWidget {
  const RecruitStudioPostsAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(myProviderFactsProvider).value;
    if (facts == null || !facts.isProviderAccount || !facts.isStudio) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const Key('recruit-studio-posts'),
      tooltip: context.l10n.recruitStudioPostsTooltip,
      icon: const AppIcon(AppIcons.campaign),
      onPressed: () => context.push('/studio/recruit'),
    );
  }
}
