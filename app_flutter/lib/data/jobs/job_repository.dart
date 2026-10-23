// lib/data/jobs/job_repository.dart
//
// Repository contract for jobs, quotes, invites and matching.
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_draft.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/jobs/quote_draft.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

enum OpenJobsMode { fit, near }

class OpenJobsFilter {
  const OpenJobsFilter({
    this.mode = OpenJobsMode.fit,
    this.specialtyId,
    this.budgetOnly = false,
  });

  final OpenJobsMode mode;
  final String? specialtyId;
  final bool budgetOnly;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenJobsFilter &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          specialtyId == other.specialtyId &&
          budgetOnly == other.budgetOnly;

  @override
  int get hashCode => Object.hash(mode, specialtyId, budgetOnly);
}

abstract class JobRepository {
  Stream<List<Job>> watchMyJobs({int limit = 20});
  Stream<Job?> watchJob(String jobId);
  Future<Job?> getJob(String jobId);
  Stream<List<Quote>> watchQuotes(String jobId, {int limit = 50});
  Future<List<String>> invitedIds(String jobId);
  Future<JobReference> uploadReference(PickedImage image, {required String draftId});
  Future<void> deleteReference(JobReference ref);
  Future<({String jobId, int matched})> createJob(JobDraft draft);
  Future<void> updateJob(String jobId, JobDraft draft);
  Future<DateTime> extendJob(String jobId);
  Future<void> closeJob(String jobId);
  Future<List<String>> invite(String jobId, List<String> photographerIds);
  Future<void> declineQuote(String jobId, String photographerId, {String? reason});
  Future<({String bookingId, BookingCheckout checkout})> acceptQuote({
    required String jobId,
    required String photographerId,
    required String placeName,
    String? note,
    required PayMethod method,
  });
  Future<void> markQuotesSeen(String jobId);
  Future<List<OpenJobItem>> openJobs(OpenJobsFilter filter);
  Future<Quote?> myQuote(String jobId);
  Stream<Quote?> watchMyQuote(String jobId);
  Stream<List<Quote>> watchMyQuotes({int limit = 30});
  Stream<int> watchUnseenInviteCount();
  Future<void> markInviteSeen(String jobId);
  Future<void> recordView(String jobId);
  Future<({int fit})> submitQuote(QuoteDraft draft);
  Future<void> withdrawQuote(String jobId);
  Future<String> openInquiry(String jobId, {String? photographerId});
}
