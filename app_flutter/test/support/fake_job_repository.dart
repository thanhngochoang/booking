// test/support/fake_job_repository.dart
//
// In-memory fake for JobRepository with controllable errors and recorded calls.
import 'dart:async';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_draft.dart';
import 'package:photobooking/data/jobs/job_repository.dart';
import 'package:photobooking/data/jobs/job_rules.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/jobs/quote_draft.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

class FakeJobRepository implements JobRepository {
  FakeJobRepository({this.currentUid = 'c1', DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final String currentUid;
  final DateTime Function() _clock;

  final Map<String, Job> jobs = {};
  final Map<String, Map<String, Quote>> quotesByJob = {}; // jobId -> {photographerId: Quote}
  final Map<String, Set<String>> invitesByJob = {}; // jobId -> Set<photographerId>
  final Map<String, Set<String>> seenInvites = {}; // jobId -> Set<photographerId>
  final Map<String, Set<String>> viewsByJob = {}; // jobId -> Set<photographerId>
  final List<JobReference> uploadedReferences = [];

  // Recorded calls
  final List<JobDraft> createCalls = [];
  final List<({String jobId, JobDraft draft})> updateCalls = [];
  final List<String> extendCalls = [];
  final List<String> closeCalls = [];
  final List<String> markQuotesSeenCalls = [];
  final List<({String jobId, List<String> photographerIds})> inviteCalls = [];
  final List<({String jobId, String photographerId, String? reason})> declineCalls = [];
  final List<({String jobId, String photographerId, String placeName, String? note, PayMethod method})> acceptCalls = [];
  final List<QuoteDraft> submitQuoteCalls = [];
  final List<String> withdrawCalls = [];
  final List<({String jobId, String? photographerId})> inquiryCalls = [];

  // Controllable errors and return values
  Object? nextCreateError;
  int? nextCreateMatched;
  Object? nextUpdateError;
  Object? nextExtendError;
  Object? nextCloseError;
  Object? nextInviteError;
  Object? nextDeclineError;
  Object? nextAcceptError;
  Object? nextSubmitQuoteError;
  Object? nextWithdrawError;
  Object? nextInquiryError;

  final _jobControllers = <String, StreamController<Job?>>{};
  final _quotesControllers = <String, StreamController<List<Quote>>>{};
  final _myJobsController = StreamController<List<Job>>.broadcast();
  final _myQuotesController = StreamController<List<Quote>>.broadcast();
  final _inviteCountController = StreamController<int>.broadcast();

  void notifyJob(String jobId) {
    _jobControllers[jobId]?.add(jobs[jobId]);
    _myJobsController.add(jobs.values.where((j) => j.customerId == currentUid).toList());
  }

  void notifyQuotes(String jobId) {
    _quotesControllers[jobId]?.add(quotesByJob[jobId]?.values.toList() ?? []);
    final myQuotes = <Quote>[];
    for (final qMap in quotesByJob.values) {
      final q = qMap[currentUid];
      if (q != null) myQuotes.add(q);
    }
    _myQuotesController.add(myQuotes);
  }

  void notifyInvites() {
    int unseen = 0;
    for (final entry in invitesByJob.entries) {
      final jobId = entry.key;
      final job = jobs[jobId];
      if (job != null && job.status == JobStatus.open) {
        if (entry.value.contains(currentUid)) {
          final seen = seenInvites[jobId]?.contains(currentUid) ?? false;
          if (!seen) unseen++;
        }
      }
    }
    _inviteCountController.add(unseen);
  }

  @override
  Stream<List<Job>> watchMyJobs({int limit = 20}) {
    return _myJobsController.stream;
  }

  @override
  Stream<Job?> watchJob(String jobId) {
    final controller = _jobControllers.putIfAbsent(jobId, () => StreamController<Job?>.broadcast());
    // Emit current value if present
    if (jobs.containsKey(jobId)) {
      scheduleMicrotask(() {
        if (!controller.isClosed) controller.add(jobs[jobId]);
      });
    }
    return controller.stream;
  }

  @override
  Future<Job?> getJob(String jobId) async {
    return jobs[jobId];
  }

  @override
  Stream<List<Quote>> watchQuotes(String jobId, {int limit = 50}) {
    final controller = _quotesControllers.putIfAbsent(jobId, () => StreamController<List<Quote>>.broadcast());
    // Emit current value if present
    if (quotesByJob.containsKey(jobId)) {
      scheduleMicrotask(() {
        if (!controller.isClosed) controller.add(quotesByJob[jobId]?.values.toList() ?? []);
      });
    }
    return controller.stream;
  }

  @override
  Future<List<String>> invitedIds(String jobId) async {
    return invitesByJob[jobId]?.toList() ?? const [];
  }

  @override
  Future<JobReference> uploadReference(PickedImage image, {required String draftId}) async {
    final ref = JobReference(
      url: 'https://example.com/jobRefs/$currentUid/$draftId/img.jpg',
      path: 'jobRefs/$currentUid/$draftId/img.jpg',
    );
    uploadedReferences.add(ref);
    return ref;
  }

  @override
  Future<void> deleteReference(JobReference ref) async {
    uploadedReferences.remove(ref);
  }

  @override
  Future<({String jobId, int matched})> createJob(JobDraft draft) async {
    if (nextCreateError != null) {
      final err = nextCreateError!;
      nextCreateError = null;
      throw err;
    }
    createCalls.add(draft);
    final jobId = 'job_${newUlid()}';
    final now = _clock();
    final newJob = Job(
      id: jobId,
      customerId: currentUid,
      customer: const JobCustomer(name: 'Current Customer'),
      specialtyId: draft.specialtyId,
      title: draft.title,
      description: draft.description,
      references: draft.references,
      schedule: draft.schedule,
      dayFrom: draft.schedule.day ?? draft.schedule.from ?? '',
      dayTo: draft.schedule.day ?? draft.schedule.to ?? '',
      area: JobArea(
        areaId: draft.area.areaId,
        name: draft.area.name,
        city: cityOf(draft.area.name),
        cityKey: cityKeyOf(draft.area.name),
        lat: draft.area.lat,
        lng: draft.area.lng,
        geohash5: 'w4rqp',
      ),
      budget: draft.budget,
      wants: draft.wants,
      allowedProviders: draft.allowedProviders,
      quoteDeadline: now.add(Duration(days: draft.deadlineDays)),
      status: JobStatus.open,
      createdAt: now,
      updatedAt: now,
    );
    jobs[jobId] = newJob;
    notifyJob(jobId);
    final matchedCount = nextCreateMatched ?? 5;
    nextCreateMatched = null;
    return (jobId: jobId, matched: matchedCount);
  }

  @override
  Future<void> updateJob(String jobId, JobDraft draft) async {
    if (nextUpdateError != null) {
      final err = nextUpdateError!;
      nextUpdateError = null;
      throw err;
    }
    updateCalls.add((jobId: jobId, draft: draft));
    final existing = jobs[jobId];
    if (existing == null) throw const JobError('not_found');
    final updated = Job(
      id: jobId,
      customerId: existing.customerId,
      customer: existing.customer,
      specialtyId: draft.specialtyId,
      title: draft.title,
      description: draft.description,
      references: draft.references,
      schedule: draft.schedule,
      dayFrom: draft.schedule.day ?? draft.schedule.from ?? '',
      dayTo: draft.schedule.day ?? draft.schedule.to ?? '',
      area: JobArea(
        areaId: draft.area.areaId,
        name: draft.area.name,
        city: cityOf(draft.area.name),
        cityKey: cityKeyOf(draft.area.name),
        lat: draft.area.lat,
        lng: draft.area.lng,
        geohash5: existing.area.geohash5,
      ),
      budget: draft.budget,
      wants: draft.wants,
      allowedProviders: draft.allowedProviders,
      quoteDeadline: existing.quoteDeadline,
      extended: existing.extended,
      status: existing.status,
      quoteCount: existing.quoteCount,
      newQuoteCount: existing.newQuoteCount,
      viewCount: existing.viewCount,
      inviteCount: existing.inviteCount,
      matchCount: existing.matchCount,
      recentQuoters: existing.recentQuoters,
      createdAt: existing.createdAt,
      updatedAt: _clock(),
    );
    jobs[jobId] = updated;
    notifyJob(jobId);
  }

  @override
  Future<DateTime> extendJob(String jobId) async {
    if (nextExtendError != null) {
      final err = nextExtendError!;
      nextExtendError = null;
      throw err;
    }
    extendCalls.add(jobId);
    final existing = jobs[jobId];
    if (existing == null) throw const JobError('not_found');
    final newDeadline = existing.quoteDeadline.add(const Duration(days: 7));
    jobs[jobId] = Job(
      id: existing.id,
      customerId: existing.customerId,
      customer: existing.customer,
      specialtyId: existing.specialtyId,
      title: existing.title,
      description: existing.description,
      references: existing.references,
      schedule: existing.schedule,
      dayFrom: existing.dayFrom,
      dayTo: existing.dayTo,
      area: existing.area,
      budget: existing.budget,
      wants: existing.wants,
      allowedProviders: existing.allowedProviders,
      quoteDeadline: newDeadline,
      extended: true,
      status: existing.status,
      createdAt: existing.createdAt,
      updatedAt: _clock(),
    );
    notifyJob(jobId);
    return newDeadline;
  }

  @override
  Future<void> closeJob(String jobId) async {
    if (nextCloseError != null) {
      final err = nextCloseError!;
      nextCloseError = null;
      throw err;
    }
    closeCalls.add(jobId);
    final existing = jobs[jobId];
    if (existing == null) throw const JobError('not_found');
    jobs[jobId] = Job(
      id: existing.id,
      customerId: existing.customerId,
      customer: existing.customer,
      specialtyId: existing.specialtyId,
      title: existing.title,
      description: existing.description,
      references: existing.references,
      schedule: existing.schedule,
      dayFrom: existing.dayFrom,
      dayTo: existing.dayTo,
      area: existing.area,
      budget: existing.budget,
      wants: existing.wants,
      allowedProviders: existing.allowedProviders,
      quoteDeadline: existing.quoteDeadline,
      extended: existing.extended,
      status: JobStatus.closed,
      closedAt: _clock(),
      createdAt: existing.createdAt,
      updatedAt: _clock(),
    );
    notifyJob(jobId);
  }

  @override
  Future<List<String>> invite(String jobId, List<String> photographerIds) async {
    if (nextInviteError != null) {
      final err = nextInviteError!;
      nextInviteError = null;
      throw err;
    }
    inviteCalls.add((jobId: jobId, photographerIds: photographerIds));
    final set = invitesByJob.putIfAbsent(jobId, () => <String>{});
    final added = <String>[];
    for (final pid in photographerIds) {
      if (set.add(pid)) added.add(pid);
    }
    notifyInvites();
    return added;
  }

  @override
  Future<void> declineQuote(String jobId, String photographerId, {String? reason}) async {
    if (nextDeclineError != null) {
      final err = nextDeclineError!;
      nextDeclineError = null;
      throw err;
    }
    declineCalls.add((jobId: jobId, photographerId: photographerId, reason: reason));
    final q = quotesByJob[jobId]?[photographerId];
    if (q != null) {
      quotesByJob[jobId]![photographerId] = Quote(
        id: q.id,
        jobId: q.jobId,
        photographerId: q.photographerId,
        customerId: q.customerId,
        jobTitle: q.jobTitle,
        photographer: q.photographer,
        terms: q.terms,
        milestoneAmounts: q.milestoneAmounts,
        proposal: q.proposal,
        message: q.message,
        status: QuoteStatus.declined,
        declineReason: reason,
        createdAt: q.createdAt,
        updatedAt: _clock(),
      );
      notifyQuotes(jobId);
    }
  }

  @override
  Future<({String bookingId, BookingCheckout checkout})> acceptQuote({
    required String jobId,
    required String photographerId,
    required String placeName,
    String? note,
    required PayMethod method,
  }) async {
    if (nextAcceptError != null) {
      final err = nextAcceptError!;
      nextAcceptError = null;
      throw err;
    }
    acceptCalls.add((
      jobId: jobId,
      photographerId: photographerId,
      placeName: placeName,
      note: note,
      method: method,
    ));
    final bookingId = 'b_${newUlid()}';
    final checkout = BookingCheckout(
      paymentId: 'pay_1',
      method: method,
      amount: quotesByJob[jobId]?[photographerId]?.terms.price ?? 1000000,
      expiresAt: _clock().add(const Duration(minutes: 30)),
      transferCode: 'PB 123456',
      attempt: 1,
    );
    return (bookingId: bookingId, checkout: checkout);
  }

  @override
  Future<void> markQuotesSeen(String jobId) async {
    markQuotesSeenCalls.add(jobId);
    final existing = jobs[jobId];
    if (existing != null) {
      jobs[jobId] = Job(
        id: existing.id,
        customerId: existing.customerId,
        customer: existing.customer,
        specialtyId: existing.specialtyId,
        title: existing.title,
        description: existing.description,
        references: existing.references,
        schedule: existing.schedule,
        dayFrom: existing.dayFrom,
        dayTo: existing.dayTo,
        area: existing.area,
        budget: existing.budget,
        wants: existing.wants,
        allowedProviders: existing.allowedProviders,
        quoteDeadline: existing.quoteDeadline,
        extended: existing.extended,
        status: existing.status,
        quoteCount: existing.quoteCount,
        newQuoteCount: 0,
        viewCount: existing.viewCount,
        inviteCount: existing.inviteCount,
        matchCount: existing.matchCount,
        recentQuoters: existing.recentQuoters,
        quotesSeenAt: _clock(),
        createdAt: existing.createdAt,
        updatedAt: _clock(),
      );
      notifyJob(jobId);
    }
  }

  List<OpenJobItem>? openJobsOverride;
  List<Quote>? myQuotesList;
  int myStartingPrice = 0;

  @override
  Future<List<OpenJobItem>> openJobs(OpenJobsFilter filter) async {
    List<OpenJobItem> items;
    if (openJobsOverride != null) {
      items = List<OpenJobItem>.from(openJobsOverride!);
    } else {
      final now = _clock();
      items = <OpenJobItem>[];
      for (final j in jobs.values) {
        if (j.status == JobStatus.open && now.isBefore(j.quoteDeadline)) {
          final invited = invitesByJob[j.id]?.contains(currentUid) ?? false;
          items.add(OpenJobItem(
            job: j,
            fit: 85,
            invited: invited,
          ));
        }
      }
    }

    if (filter.specialtyId != null) {
      items = items.where((i) => i.job.specialtyId == filter.specialtyId).toList();
    }
    if (filter.budgetOnly) {
      items = items.where((i) {
        final maxBudget = i.job.budget?.max;
        return maxBudget == null || maxBudget >= myStartingPrice;
      }).toList();
    }
    return items;
  }

  @override
  Future<Quote?> myQuote(String jobId) async {
    return quotesByJob[jobId]?[currentUid];
  }

  @override
  Stream<Quote?> watchMyQuote(String jobId) {
    final controller = _quotesControllers.putIfAbsent(jobId, () => StreamController<List<Quote>>.broadcast());
    Future.microtask(() => controller.add(quotesByJob[jobId]?.values.toList() ?? []));
    return controller.stream.map((quotes) => quotesByJob[jobId]?[currentUid]);
  }

  @override
  Stream<List<Quote>> watchMyQuotes({int limit = 30}) {
    if (myQuotesList != null) {
      scheduleMicrotask(() {
        if (!_myQuotesController.isClosed) {
          _myQuotesController.add(myQuotesList!);
        }
      });
    }
    return _myQuotesController.stream;
  }

  @override
  Stream<int> watchUnseenInviteCount() {
    return _inviteCountController.stream;
  }

  @override
  Future<void> markInviteSeen(String jobId) async {
    seenInvites.putIfAbsent(jobId, () => <String>{}).add(currentUid);
    notifyInvites();
  }

  @override
  Future<void> recordView(String jobId) async {
    viewsByJob.putIfAbsent(jobId, () => <String>{}).add(currentUid);
  }

  @override
  Future<({int fit})> submitQuote(QuoteDraft draft) async {
    if (nextSubmitQuoteError != null) {
      final err = nextSubmitQuoteError!;
      nextSubmitQuoteError = null;
      throw err;
    }
    submitQuoteCalls.add(draft);
    final now = _clock();
    final quote = Quote(
      id: currentUid,
      jobId: draft.jobId,
      photographerId: currentUid,
      customerId: jobs[draft.jobId]?.customerId ?? 'cust_1',
      jobTitle: jobs[draft.jobId]?.title ?? 'Job Title',
      photographer: const QuoteProvider(name: 'My Photographer', providerType: ProviderType.individual),
      terms: QuoteTerms(
        price: draft.price,
        durationMinutes: 60,
        editedCount: draft.editedCount,
        deliveryDays: draft.deliveryDays,
        revisions: draft.revisions,
      ),
      milestoneAmounts: QuoteMilestoneAmounts(
        shoot: (draft.price * 50) ~/ 100,
        delivery: draft.price - ((draft.price * 50) ~/ 100),
      ),
      proposal: draft.proposal ?? const QuoteProposal(day: '2026-10-25', start: '09:00', end: '10:00'),
      message: draft.message,
      albumId: draft.albumId,
      basedOnServiceId: draft.basedOnServiceId,
      fit: 90,
      status: QuoteStatus.submitted,
      createdAt: now,
      updatedAt: now,
    );
    quotesByJob.putIfAbsent(draft.jobId, () => {})[currentUid] = quote;
    notifyQuotes(draft.jobId);
    return (fit: 90);
  }

  @override
  Future<void> withdrawQuote(String jobId) async {
    if (nextWithdrawError != null) {
      final err = nextWithdrawError!;
      nextWithdrawError = null;
      throw err;
    }
    withdrawCalls.add(jobId);
    final q = quotesByJob[jobId]?[currentUid];
    if (q != null) {
      quotesByJob[jobId]![currentUid] = Quote(
        id: q.id,
        jobId: q.jobId,
        photographerId: q.photographerId,
        customerId: q.customerId,
        jobTitle: q.jobTitle,
        photographer: q.photographer,
        terms: q.terms,
        milestoneAmounts: q.milestoneAmounts,
        proposal: q.proposal,
        message: q.message,
        status: QuoteStatus.withdrawn,
        withdrawnAt: _clock(),
        createdAt: q.createdAt,
        updatedAt: _clock(),
      );
      notifyQuotes(jobId);
    }
  }

  @override
  Future<String> openInquiry(String jobId, {String? photographerId}) async {
    if (nextInquiryError != null) {
      final err = nextInquiryError!;
      nextInquiryError = null;
      throw err;
    }
    inquiryCalls.add((jobId: jobId, photographerId: photographerId));
    return 'chat_${newUlid()}';
  }
}
