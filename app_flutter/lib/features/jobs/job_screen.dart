// lib/features/jobs/job_screen.dart
//
// Role switch for job detail screens (owner -> S15.02, others -> S16.01).
// Replaced with full implementations in Tasks 7 and 9.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/widgets/empty_state.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
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

    return jobAsync.when(
      data: (job) {
        if (job == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Chi tiết công việc'),
            ),
            body: const EmptyState(
              title: 'Không tìm thấy công việc',
              body: 'Công việc này không tồn tại hoặc đã bị xoá.',
            ),
          );
        }
        final isOwner = currentUid != null && currentUid == job.customerId;
        if (isOwner) {
          // Owner view (S15.02)
          return JobOwnerDetail(job: job);
        }
        // Photographer view (S16.01) placeholder
        return Scaffold(
          appBar: AppBar(
            title: Text(job.title),
          ),
          body: EmptyState(
            title: job.title,
            body: openQuote
                ? 'Đang mở sheet gửi báo giá (S16.03).'
                : 'Trang xem công việc cho thợ ảnh (S16.01).',
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết công việc'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết công việc'),
        ),
        body: Center(child: Text('Lỗi: $err')),
      ),
    );
  }
}
