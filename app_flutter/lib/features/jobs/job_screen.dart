// lib/features/jobs/job_screen.dart
//
// Role switch for job detail screens (owner -> S15.02, others -> S16.01).
// Replaced with full implementations in Tasks 7 and 9.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/features/job_market/job_photographer_detail.dart';
import 'package:photobooking/features/jobs/job_owner_detail.dart';

class JobScreen extends ConsumerWidget {
  const JobScreen({
    super.key,
    required this.jobId,
    this.openQuote = false,
  });

  final String jobId;
  final bool openQuote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authStateProvider).value?.uid;
    final jobAsync = ref.watch(jobProvider(jobId));

    return AsyncView<Job?>(
      value: jobAsync,
      data: (context, job) {
        if (job == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chi tiết công việc'),
            ),
            body: const EmptyState(
              title: 'Không tìm thấy việc này',
              body: '',
            ),
          );
        }
        final isOwner = currentUid != null && currentUid == job.customerId;
        if (isOwner) {
          // Owner view (S15.02)
          return JobOwnerDetail(job: job);
        }
        // Photographer view (S16.01)
        return JobPhotographerDetail(
          job: job,
          openQuote: openQuote,
        );
      },
      skeleton: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết công việc'),
        ),
        body: const Center(child: DotRingLoader()),
      ),
      error: (_, err, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết công việc'),
        ),
        body: Center(child: Text('Lỗi: $err')),
      ),
    );
  }
}
