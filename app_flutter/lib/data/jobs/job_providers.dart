// lib/data/jobs/job_providers.dart
//
// Riverpod providers for jobs, open jobs, quotes and drafts.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/jobs/firestore_job_repository.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_repository.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return FirestoreJobRepository(
    mediaUploader: ref.watch(mediaUploaderProvider),
  );
});

/// Watches the customer's active and past jobs.
final myJobsProvider = StreamProvider.autoDispose<List<Job>>((ref) {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.watchMyJobs();
});

/// Watches a single job by id.
final jobProvider = StreamProvider.autoDispose.family<Job?, String>((ref, jobId) {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.watchJob(jobId);
});

/// Watches all quotes on a job.
final jobQuotesProvider =
    StreamProvider.autoDispose.family<List<Quote>, String>((ref, jobId) {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.watchQuotes(jobId);
});

enum QuoteSort { fit, price, rating, saved }

class QuotesSortController extends Notifier<QuoteSort> {
  QuotesSortController(this.jobId);
  final String jobId;

  @override
  QuoteSort build() => QuoteSort.fit;

  void setSort(QuoteSort sort) => state = sort;
}

final quotesSortProvider = NotifierProvider.autoDispose
    .family<QuotesSortController, QuoteSort, String>(QuotesSortController.new);

class SavedQuotesController extends Notifier<Set<String>> {
  SavedQuotesController(this.jobId);
  final String jobId;

  String get _key => 'savedQuotes:$jobId';

  @override
  Set<String> build() {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      final list = prefs.getStringList(_key);
      return list?.toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> toggle(String quoteId) async {
    final next = Set<String>.from(state);
    if (next.contains(quoteId)) {
      next.remove(quoteId);
    } else {
      next.add(quoteId);
    }
    state = next;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setStringList(_key, next.toList());
    } catch (_) {}
  }
}

final savedQuotesProvider = NotifierProvider.autoDispose
    .family<SavedQuotesController, Set<String>, String>(
  SavedQuotesController.new,
);

/// Quotes on a job sorted according to the current [quotesSortProvider] selection.
final sortedQuotesProvider =
    Provider.autoDispose.family<List<Quote>, String>((ref, jobId) {
  final quotes = ref.watch(jobQuotesProvider(jobId)).value ?? const [];
  final sort = ref.watch(quotesSortProvider(jobId));
  final saved = ref.watch(savedQuotesProvider(jobId));

  final list = List<Quote>.from(quotes);

  switch (sort) {
    case QuoteSort.fit:
      list.sort((a, b) => b.fit.compareTo(a.fit));
      break;
    case QuoteSort.price:
      list.sort((a, b) => a.terms.price.compareTo(b.terms.price));
      break;
    case QuoteSort.rating:
      // Smoothed score: (reviewCount * score + 10 * 0.6) / (reviewCount + 10)
      double smoothedScore(Quote q) {
        final rc = q.photographer.reviewCount;
        final sc = q.photographer.score;
        return (rc * sc + 10 * 0.6) / (rc + 10);
      }
      list.sort((a, b) => smoothedScore(b).compareTo(smoothedScore(a)));
      break;
    case QuoteSort.saved:
      list.sort((a, b) {
        final aSaved = saved.contains(a.id);
        final bSaved = saved.contains(b.id);
        if (aSaved != bSaved) {
          return aSaved ? -1 : 1;
        }
        return b.fit.compareTo(a.fit);
      });
      break;
  }

  return list;
});

/// Fetches open jobs for a photographer with the given filter.
final openJobsProvider = FutureProvider.autoDispose
    .family<List<OpenJobItem>, OpenJobsFilter>((ref, filter) async {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.openJobs(filter);
});

/// Watches the photographer's quote on a specific job.
final myQuoteProvider =
    StreamProvider.autoDispose.family<Quote?, String>((ref, jobId) {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.watchMyQuote(jobId);
});

/// Watches all quotes sent by the signed-in photographer.
final myQuotesProvider = StreamProvider.autoDispose<List<Quote>>((ref) {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.watchMyQuotes();
});

/// Watches the count of unseen job invites for the photographer tab badge.
final unseenInviteCountProvider = StreamProvider.autoDispose<int>((ref) {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.watchUnseenInviteCount();
});

/// Temporary state controllers for Task 7 & Task 9
class JobDraftController extends Notifier<Object?> {
  @override
  Object? build() => null;
  void update(Object? value) => state = value;
}

final jobDraftControllerProvider =
    NotifierProvider.autoDispose<JobDraftController, Object?>(JobDraftController.new);

class QuoteSheetController extends Notifier<Object?> {
  QuoteSheetController(this.jobId);
  final String jobId;

  @override
  Object? build() => null;
  void update(Object? value) => state = value;
}

final quoteSheetControllerProvider = NotifierProvider.autoDispose
    .family<QuoteSheetController, Object?, String>(QuoteSheetController.new);
