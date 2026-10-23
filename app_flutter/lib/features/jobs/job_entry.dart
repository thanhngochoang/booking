// lib/features/jobs/job_entry.dart
//
// Entry point helper startJobPost:
// - Verifies that the customer has a verified phone number (redirects to /profile/phone?returnTo=...)
// - Checks that the customer does not exceed the limit of 3 open jobs
// - Navigates to /jobs/new (with ?from={id} or ?edit={id} if provided)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';

Future<void> startJobPost(
  BuildContext context,
  WidgetRef ref, {
  String? fromJobId,
  String? editJobId,
}) async {
  String destination = '/jobs/new';
  if (editJobId != null) {
    destination = '/jobs/new?edit=$editJobId';
  } else if (fromJobId != null) {
    destination = '/jobs/new?from=$fromJobId';
  }

  // 1. Phone number check
  Object? contact;
  final hold = ref.listenManual(currentContactProvider, (_, _) {});
  try {
    contact = await ref.read(currentContactProvider.future);
  } catch (_) {
    contact = null;
  } finally {
    hold.close();
  }

  if (!context.mounted) return;

  if (contact == null) {
    context.push('/profile/phone?returnTo=${Uri.encodeComponent(destination)}');
    return;
  }

  // 2. Open jobs limit check (max 3 open jobs) if creating new / reposting
  if (editJobId == null) {
    final jobsHold = ref.listenManual(myJobsProvider, (_, _) {});
    try {
      final myJobs = await ref.read(myJobsProvider.future);
      final openCount = myJobs.where((j) => j.status == JobStatus.open).length;
      if (openCount >= 3) {
        if (context.mounted) {
          final l = context.l10n;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.jobPostLimit)),
          );
        }
        return;
      }
    } catch (_) {
    } finally {
      jobsHold.close();
    }
  }

  if (context.mounted) {
    context.push(destination);
  }
}
