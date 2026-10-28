// lib/features/jobs/my_jobs_tab.dart
//
// Customer jobs tab for S15.02 in MyBookingsScreen.
// Orders open jobs by nearest deadline, awarded, then closed and expired newest first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_card_data_of.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/features/jobs/job_entry.dart';

class MyJobsTab extends ConsumerWidget {
  const MyJobsTab({super.key});

  List<Job> _sortJobs(List<Job> jobs) {
    final openJobs = jobs.where((j) => j.status == JobStatus.open || j.status == JobStatus.draft).toList();
    final awardedJobs = jobs.where((j) => j.status == JobStatus.awarded).toList();
    final closedOrExpiredJobs = jobs.where((j) => j.status == JobStatus.closed || j.status == JobStatus.expired).toList();

    // Open by nearest quote deadline
    openJobs.sort((a, b) => a.quoteDeadline.compareTo(b.quoteDeadline));

    // Awarded by newest updated/created
    awardedJobs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // Closed/expired newest first
    closedOrExpiredJobs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return [...openJobs, ...awardedJobs, ...closedOrExpiredJobs];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final now = ref.watch(clockProvider)();
    final myJobsAsync = ref.watch(myJobsProvider);

    return ScreenCode(
      ScreenCodes.myJobs,
      child: AsyncView<List<Job>>(
        value: myJobsAsync,
        data: (context, allJobs) {
          final sorted = _sortJobs(allJobs);
          if (sorted.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s8),
              child: EmptyState(
                title: l.jobEmptyTitle,
                actionLabel: l.jobEmptyAction,
                onAction: () => startJobPost(context, ref),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpace.s4),
            itemCount: sorted.length + 1, // extra slot for "Đăng việc mới" button
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
            itemBuilder: (context, i) {
              if (i == sorted.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
                  child: AppButton.outline(
                    l.jobNewPost,
                    onPressed: () => startJobPost(context, ref),
                  ),
                );
              }

              final job = sorted[i];
              final cardData = customerJobCardOf(
                job,
                now,
                l,
                onLinkTap: () {
                  if (job.status == JobStatus.awarded && job.bookingId != null) {
                    context.push('/b/${job.bookingId}');
                  } else if (job.status == JobStatus.closed || job.status == JobStatus.expired) {
                    startJobPost(context, ref, fromJobId: job.id);
                  }
                },
              );

              return JobCard(
                data: cardData,
                onTap: () => context.push('/jobs/${job.id}'),
              );
            },
          );
        },
        skeleton: (_) => ListView(
          padding: const EdgeInsets.all(AppSpace.s4),
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(height: AppSpace.s3),
              JobCard.skeleton(),
            ],
          ],
        ),
        error: (_, err, _) => Center(
          child: Text('Lỗi: $err'),
        ),
      ),
    );
  }
}
