// lib/data/jobs/firestore_job_repository.dart
//
// Firestore and Functions implementation of JobRepository.
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:photobooking/core/geo.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_draft.dart';
import 'package:photobooking/data/jobs/job_repository.dart';
import 'package:photobooking/data/jobs/job_rules.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/jobs/quote_draft.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

/// Pure function to assemble open jobs for photographer browsing (S16.02).
/// Tested directly in open_jobs_assembly_test.dart.
List<OpenJobItem> assembleOpenJobs({
  required List<JobMatch> matches,
  required List<JobInvite> invites,
  required List<Job> jobs,
  required PhotographerSummary me,
  required OpenJobsFilter filter,
  required DateTime now,
  double? myRadiusKm,
  ({double lat, double lng})? myCenter,
}) {
  // 1. Build map of loaded jobs
  final jobMap = <String, Job>{};
  for (final j in jobs) {
    jobMap[j.id] = j;
  }

  // 2. Build fit map & invite map from matches and invites
  final fitMap = <String, int>{};
  final inviteSet = <String>{};
  for (final m in matches) {
    fitMap[m.jobId] = m.fit;
  }
  for (final inv in invites) {
    fitMap[inv.jobId] = inv.fit;
    inviteSet.add(inv.jobId);
  }

  // 3. Assemble base candidate items based on mode
  List<OpenJobItem> items = [];

  if (filter.mode == OpenJobsMode.fit) {
    // Union of job IDs: invites first, then matches
    final seen = <String>{};
    final orderedIds = <String>[];
    for (final inv in invites) {
      if (seen.add(inv.jobId)) orderedIds.add(inv.jobId);
    }
    for (final m in matches) {
      if (seen.add(m.jobId)) orderedIds.add(m.jobId);
    }

    for (final id in orderedIds) {
      final job = jobMap[id];
      if (job == null) continue;
      items.add(OpenJobItem(
        job: job,
        fit: fitMap[job.id],
        invited: inviteSet.contains(job.id),
      ));
    }
  } else {
    // Near mode: from loaded jobs
    for (final job in jobs) {
      // If serviceArea.center exists, drop those farther than radiusKm
      if (myCenter != null && myRadiusKm != null) {
        final dist = haversineKm(
          myCenter.lat,
          myCenter.lng,
          job.area.lat,
          job.area.lng,
        );
        if (dist > myRadiusKm) {
          continue;
        }
      }
      items.add(OpenJobItem(
        job: job,
        fit: fitMap[job.id],
        invited: inviteSet.contains(job.id),
      ));
    }
  }

  // 4. Filter: drop jobs not open or past quoteDeadline
  items = items.where((item) {
    final j = item.job;
    if (j.status != JobStatus.open) return false;
    if (!now.isBefore(j.quoteDeadline)) return false;
    return true;
  }).toList();

  // 5. Sort: invited first, then fit desc (if fit mode)
  if (filter.mode == OpenJobsMode.fit) {
    items.sort((a, b) {
      if (a.invited != b.invited) {
        return a.invited ? -1 : 1;
      }
      final fitA = a.fit ?? 0;
      final fitB = b.fit ?? 0;
      return fitB.compareTo(fitA);
    });
  }

  // 6. Apply type rule of Decision 8:
  // - individual: artist-only kept with locked: true; studio-only dropped
  // - artist: all allowed (individual/artist)
  // - studio: artist-only dropped; individual-only/studio-only rules
  final myType = me.providerType;
  final filteredByType = <OpenJobItem>[];

  for (final item in items) {
    final allowed = item.job.allowedProviders;
    if (allowed == AllowedProviders.all) {
      filteredByType.add(item);
    } else if (allowed == AllowedProviders.artist) {
      if (myType == ProviderType.artist) {
        filteredByType.add(item);
      } else if (myType == ProviderType.individual) {
        filteredByType.add(OpenJobItem(
          job: item.job,
          fit: item.fit,
          invited: item.invited,
          locked: true,
        ));
      }
      // studio drops artist-only
    } else if (allowed == AllowedProviders.studio) {
      if (myType == ProviderType.studio) {
        filteredByType.add(item);
      }
      // individual and artist drop studio-only
    }
  }

  // 7. Client filters: specialtyId and budgetOnly
  return filteredByType.where((item) {
    if (filter.specialtyId != null && filter.specialtyId!.isNotEmpty) {
      if (item.job.specialtyId != filter.specialtyId) return false;
    }
    if (filter.budgetOnly) {
      if (item.job.budget == null) return false;
      final startingPrice = me.startingPriceVnd ?? 0;
      if (item.job.budget!.max < startingPrice) return false;
    }
    return true;
  }).toList();
}

class FirestoreJobRepository implements JobRepository {
  FirestoreJobRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    required this.mediaUploader,
  })  : _customFirestore = firestore,
        _customFunctions = functions,
        _customAuth = auth;

  final FirebaseFirestore? _customFirestore;
  final FirebaseFunctions? _customFunctions;
  final FirebaseAuth? _customAuth;
  final MediaUploader mediaUploader;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _customFunctions ?? FirebaseFunctions.instanceFor(region: functionsRegion);
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  String? get _uid {
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data, {int timeoutSeconds = 15}) async {
    try {
      final callable = _functions.httpsCallable(
        name,
        options: HttpsCallableOptions(timeout: Duration(seconds: timeoutSeconds)),
      );
      final res = await callable.call<dynamic>(data);
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return const {};
    } catch (e) {
      throw jobErrorOf(e);
    }
  }

  @override
  Stream<List<Job>> watchMyJobs({int limit = 20}) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Job.fromFirestore(doc.id, doc.data()))
            .whereType<Job>()
            .toList());
  }

  @override
  Stream<Job?> watchJob(String jobId) {
    return _firestore.collection('jobs').doc(jobId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Job.fromFirestore(doc.id, doc.data());
    });
  }

  @override
  Future<Job?> getJob(String jobId) async {
    final doc = await _firestore.collection('jobs').doc(jobId).get();
    if (!doc.exists) return null;
    return Job.fromFirestore(doc.id, doc.data());
  }

  @override
  Stream<List<Quote>> watchQuotes(String jobId, {int limit = 50}) {
    return _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('quotes')
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Quote.fromFirestore(doc.id, doc.data()))
            .whereType<Quote>()
            .toList());
  }

  @override
  Future<List<String>> invitedIds(String jobId) async {
    final snap = await _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('invites')
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  @override
  Future<JobReference> uploadReference(PickedImage image, {required String draftId}) async {
    final uid = _uid;
    if (uid == null) throw const JobError('permission_denied');
    final ulid = newUlid();
    final storagePath = 'jobRefs/$uid/$draftId/$ulid.jpg';
    final event = await mediaUploader
        .upload(image, storagePath: storagePath, purpose: ImagePurpose.share)
        .last;
    if (event.media == null) {
      throw const JobError('upload_failed');
    }
    return JobReference(url: event.media!.url, path: storagePath);
  }

  @override
  Future<void> deleteReference(JobReference ref) async {
    await mediaUploader.delete(ref.path);
  }

  @override
  Future<({String jobId, int matched})> createJob(JobDraft draft) async {
    final data = await _call('createJob', draft.toCreatePayload(), timeoutSeconds: 30);
    return (
      jobId: data['jobId'] as String? ?? '',
      matched: (data['matched'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> updateJob(String jobId, JobDraft draft) async {
    await _call('updateJob', draft.toUpdatePayload(jobId));
  }

  @override
  Future<DateTime> extendJob(String jobId) async {
    final data = await _call('extendJob', {'jobId': jobId});
    final raw = data['quoteDeadline'];
    return (raw is String ? DateTime.tryParse(raw)?.toUtc() : null) ??
        DateTime.now().toUtc();
  }

  @override
  Future<void> closeJob(String jobId) async {
    await _call('closeJob', {'jobId': jobId});
  }

  @override
  Future<List<String>> invite(String jobId, List<String> photographerIds) async {
    final data = await _call('inviteToJob', {
      'jobId': jobId,
      'photographerIds': photographerIds,
    });
    final list = data['invited'];
    if (list is List) {
      return list.cast<String>();
    }
    return const [];
  }

  @override
  Future<void> declineQuote(String jobId, String photographerId, {String? reason}) async {
    await _call('declineQuote', {
      'jobId': jobId,
      'photographerId': photographerId,
      'reason': ?reason,
    });
  }

  @override
  Future<({String bookingId, BookingCheckout checkout})> acceptQuote({
    required String jobId,
    required String photographerId,
    required String placeName,
    String? note,
    required PayMethod method,
  }) async {
    final data = await _call('acceptQuote', {
      'jobId': jobId,
      'photographerId': photographerId,
      'place': {'name': placeName},
      'note': ?note,
      'method': method.code,
    }, timeoutSeconds: 30);

    final bookingId = data['bookingId'] as String? ?? '';
    final checkoutRaw = data['checkout'];
    final checkout = bookingCheckoutFrom(checkoutRaw);
    if (checkout == null) {
      throw const JobError('internal');
    }
    return (bookingId: bookingId, checkout: checkout);
  }

  @override
  Future<void> markQuotesSeen(String jobId) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'newQuoteCount': 0,
        'quotesSeenAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Rules protect this; ignore if not permitted or offline
    }
  }

  @override
  Future<List<OpenJobItem>> openJobs(OpenJobsFilter filter) async {
    final uid = _uid;
    if (uid == null) return const [];

    final now = DateTime.now().toUtc();

    // 1. Fetch photographer profile for me
    final pDoc = await _firestore.collection('photographers').doc(uid).get();
    final uDoc = await _firestore.collection('users').doc(uid).get();
    final pData = pDoc.data() ?? {};
    final uData = uDoc.data() ?? {};

    final areaMap = pData['serviceArea'] is Map ? pData['serviceArea'] as Map : null;
    final geo = areaMap != null ? (areaMap['center'] is GeoPoint ? areaMap['center'] : areaMap['geo']) : null;
    final myCity = areaMap != null && areaMap['city'] is String ? areaMap['city'] as String : '';
    final myRadiusKm = areaMap != null && areaMap['radiusKm'] is num ? (areaMap['radiusKm'] as num).toDouble() : null;
    final myCenter = geo is GeoPoint ? (lat: geo.latitude, lng: geo.longitude) : null;

    final me = PhotographerSummary(
      id: uid,
      displayName: uData['displayName'] as String? ?? '',
      providerType: ProviderType.fromCode(pData['providerType']),
      startingPriceVnd: (pData['startingPrice'] as num?)?.toInt(),
      areaLabel: myCity,
      lat: myCenter?.lat,
      lng: myCenter?.lng,
    );

    List<JobMatch> matches = [];
    List<JobInvite> invites = [];
    List<Job> jobs = [];

    if (filter.mode == OpenJobsMode.fit) {
      // Collection-group matches & invites
      final matchesFuture = _firestore
          .collectionGroup('matches')
          .where('photographerId', isEqualTo: uid)
          .where('jobStatus', isEqualTo: 'open')
          .orderBy('fit', descending: true)
          .limit(20)
          .get();

      final invitesFuture = _firestore
          .collectionGroup('invites')
          .where('photographerId', isEqualTo: uid)
          .where('jobStatus', isEqualTo: 'open')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final results = await Future.wait([matchesFuture, invitesFuture]);
      final matchesSnap = results[0];
      final invitesSnap = results[1];

      matches = matchesSnap.docs
          .map((d) => JobMatch.fromFirestore(d.id, d.data()))
          .whereType<JobMatch>()
          .toList();

      invites = invitesSnap.docs
          .map((d) => JobInvite.fromFirestore(d.id, d.data()))
          .whereType<JobInvite>()
          .toList();

      // Union of job IDs (up to 30)
      final seen = <String>{};
      final candidateIds = <String>[];
      for (final inv in invites) {
        if (seen.add(inv.jobId)) candidateIds.add(inv.jobId);
        if (candidateIds.length >= 30) break;
      }
      if (candidateIds.length < 30) {
        for (final m in matches) {
          if (seen.add(m.jobId)) candidateIds.add(m.jobId);
          if (candidateIds.length >= 30) break;
        }
      }

      if (candidateIds.isNotEmpty) {
        final jobsSnap = await _firestore
            .collection('jobs')
            .where(FieldPath.documentId, whereIn: candidateIds)
            .get();
        jobs = jobsSnap.docs
            .map((d) => Job.fromFirestore(d.id, d.data()))
            .whereType<Job>()
            .toList();
      }
    } else {
      // Near mode: jobs where status == 'open' and area.cityKey == cityKeyOf(serviceArea.city) orderBy quoteDeadline limit 30
      final cityKey = cityKeyOf(myCity);
      final jobsSnap = await _firestore
          .collection('jobs')
          .where('status', isEqualTo: 'open')
          .where('area.cityKey', isEqualTo: cityKey)
          .orderBy('quoteDeadline')
          .limit(30)
          .get();

      jobs = jobsSnap.docs
          .map((d) => Job.fromFirestore(d.id, d.data()))
          .whereType<Job>()
          .toList();
    }

    return assembleOpenJobs(
      matches: matches,
      invites: invites,
      jobs: jobs,
      me: me,
      filter: filter,
      now: now,
      myRadiusKm: myRadiusKm,
      myCenter: myCenter,
    );
  }

  @override
  Future<Quote?> myQuote(String jobId) async {
    final uid = _uid;
    if (uid == null) return null;
    final doc = await _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('quotes')
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return Quote.fromFirestore(doc.id, doc.data());
  }

  @override
  Stream<Quote?> watchMyQuote(String jobId) {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('quotes')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? Quote.fromFirestore(doc.id, doc.data()) : null);
  }

  @override
  Stream<List<Quote>> watchMyQuotes({int limit = 30}) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _firestore
        .collectionGroup('quotes')
        .where('photographerId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Quote.fromFirestore(doc.id, doc.data()))
            .whereType<Quote>()
            .toList());
  }

  @override
  Stream<int> watchUnseenInviteCount() {
    final uid = _uid;
    if (uid == null) return Stream.value(0);
    return _firestore
        .collectionGroup('invites')
        .where('photographerId', isEqualTo: uid)
        .where('jobStatus', isEqualTo: 'open')
        .where('seenAt', isNull: true)
        .limit(5)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Future<void> markInviteSeen(String jobId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('invites')
          .doc(uid)
          .update({'seenAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  @override
  Future<void> recordView(String jobId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('views')
          .doc(uid)
          .set({'at': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  @override
  Future<({int fit})> submitQuote(QuoteDraft draft) async {
    final data = await _call('submitQuote', draft.toPayload());
    return (fit: (data['fit'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<void> withdrawQuote(String jobId) async {
    await _call('withdrawQuote', {'jobId': jobId});
  }

  @override
  Future<String> openInquiry(String jobId, {String? photographerId}) async {
    final data = await _call('openJobInquiry', {
      'jobId': jobId,
      'photographerId': ?photographerId,
    });
    return data['chatId'] as String? ?? '';
  }
}
