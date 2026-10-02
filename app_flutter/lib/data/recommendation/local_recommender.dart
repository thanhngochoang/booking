// lib/data/recommendation/local_recommender.dart
import 'dart:math' as math;

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/reason.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/l10n/app_localizations.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

double _unit(double x) => math.min(1.0, math.max(0.0, x));

/// Smoothed rating `(v*R + m*C) / (v + m)`: a handful of five-star reviews do
/// not beat a long record.
double smoothedRating(PhotographerSummary p) {
  const m = 10.0;
  const c = 4.3;
  final v = p.reviewCount.toDouble();
  final r = p.hasRating ? p.ratingAvg : c;
  return (v * r + m * c) / (v + m);
}

double _quality(PhotographerSummary p) {
  final base = (smoothedRating(p) - 3) / 2;
  final boost = 0.05 * (math.log(1 + p.completedCount) / math.ln10);
  return _unit(base + boost);
}

class _Scored {
  _Scored(this.p, this.score, this.distanceKm, this.day);
  final PhotographerSummary p;
  final double score;
  final double? distanceKm;
  final DayAvailability? day;
}

/// Ranks on the device with stars (smoothed), distance and availability. It is
/// the safety net when the remote recommender is down, slow or offline, and it
/// is what the app uses until the recommender service exists.
class LocalRecommender implements RecommendationRepository {
  LocalRecommender({
    required PostRepository posts,
    required PhotographerRepository photographers,
    required AvailabilityLookup availability,
    DateTime Function()? clock,
    AppLocalizations? strings,
  }) : // Named parameters cannot start with an underscore, so these cannot be
       // initializing formals without changing the public signature.
       // ignore: prefer_initializing_formals
       _posts = posts,
       // ignore: prefer_initializing_formals
       _photographers = photographers,
       // ignore: prefer_initializing_formals
       _availability = availability,
       _now = clock ?? (() => DateTime.now().toUtc()),
       _l = strings ?? AppLocalizationsVi();

  static const algorithm = 'local-fallback';
  static const version = '1.0.0';
  static const candidatePool = 200;
  static const maxDatedCandidates = 60;

  final PostRepository _posts;
  final PhotographerRepository _photographers;
  final AvailabilityLookup _availability;
  final DateTime Function() _now;
  final AppLocalizations _l;

  String _requestId() => 'local-${_now().microsecondsSinceEpoch}';

  ({double lat, double lng})? _origin(String? geohash6) =>
      geohash6 == null ? null : decodeGeohash(geohash6);

  double? _distance(({double lat, double lng})? from, PhotographerSummary p) =>
      from == null || !p.hasGeo
      ? null
      : haversineKm(from.lat, from.lng, p.lat!, p.lng!);

  bool _freeSoon(PhotographerSummary p, DateTime now, {int days = 7}) {
    final d = p.nextFreeDate;
    if (d == null) {
      return false;
    }
    return d.compareTo(vnDateKey(now)) >= 0 &&
        d.compareTo(vnDateKey(now.add(Duration(days: days)))) < 0;
  }

  List<Reason> _reasons(
    PhotographerSummary p, {
    String? specialtyId,
    DateTime? date,
    double? distanceKm,
    DayAvailability? day,
    required DateTime now,
  }) {
    final out = <Reason>[];
    if (date != null) {
      if (day == null) {
        out.add(
          Reason(
            code: ReasonCode.freeOnDate,
            text: _l.reasonFreeOnDate(formatDay(date)),
          ),
        );
      }
    } else if (_freeSoon(p, now)) {
      out.add(
        Reason(
          code: ReasonCode.freeOnDate,
          text: _l.reasonFreeOnDate(formatDay(p.nextFreeDay!)),
        ),
      );
    }
    if (specialtyId != null && p.specialtyIds.contains(specialtyId)) {
      out.add(
        Reason(
          code: ReasonCode.skillMatch,
          text: _l.reasonSkillMatch(specialtyLabel(specialtyId).toLowerCase()),
        ),
      );
    }
    if (distanceKm != null && distanceKm <= 5) {
      out.add(
        Reason(
          code: ReasonCode.near,
          text: _l.reasonNear(formatDistance(distanceKm)),
        ),
      );
    }
    if (p.reviewCount >= 10 && smoothedRating(p) >= 4.7) {
      out.add(
        Reason(
          code: ReasonCode.topRated,
          text: _l.reasonTopRated(formatRating(p.ratingAvg), p.reviewCount),
        ),
      );
    }
    if (p.responseMinutes != null && p.responseMinutes! <= 60) {
      out.add(Reason(code: ReasonCode.fastReply, text: _l.reasonFastReply));
    }
    final created = p.createdAt;
    if (created != null &&
        now.difference(created) <= const Duration(days: 30)) {
      out.add(Reason(code: ReasonCode.newTalent, text: _l.reasonNewTalent));
    }
    return out.take(3).toList();
  }

  int _offset(String? cursor) => int.tryParse(cursor ?? '') ?? 0;

  @override
  Future<RecommendationPage> recommendPhotographers(
    RecommendationQuery q,
  ) async {
    final now = _now();
    var pool = (await _photographers.candidates(limit: candidatePool))
        .where((p) => !q.excludeIds.contains(p.id))
        .where(
          (p) =>
              q.specialtyId == null || p.specialtyIds.contains(q.specialtyId),
        )
        .where((p) => q.styleId == null || p.styleIds.contains(q.styleId))
        .where(
          (p) =>
              q.budgetMax == null ||
              p.startingPriceVnd == null ||
              p.startingPriceVnd! <= q.budgetMax!,
        )
        .toList();

    var day = const <String, DayAvailability>{};
    if (q.date != null) {
      pool.sort((a, b) {
        final byQuality = _quality(b).compareTo(_quality(a));
        if (byQuality != 0) {
          return byQuality;
        }
        // Quality saturates at 1.0, so break ties by the evidence: the most
        // reviewed are kept in the cut, then id for a stable order.
        final byRating = smoothedRating(b).compareTo(smoothedRating(a));
        if (byRating != 0) {
          return byRating;
        }
        final byReviews = b.reviewCount.compareTo(a.reviewCount);
        return byReviews != 0 ? byReviews : a.id.compareTo(b.id);
      });
      if (pool.length > maxDatedCandidates) {
        pool = pool.sublist(0, maxDatedCandidates);
      }
      day = await _availability.on(dayKeyOf(q.date!), pool.map((p) => p.id));
      pool = pool
          .where(
            (p) =>
                day[p.id] != DayAvailability.booked &&
                day[p.id] != DayAvailability.off,
          )
          .toList();
    }

    final origin = _origin(q.geohash6);
    final scored = <_Scored>[];
    for (final p in pool) {
      final d = _distance(origin, p);
      final geo = d == null ? 0.5 : math.exp(-d / 8);
      final state = day[p.id];
      final availability = q.date != null
          ? (state == DayAvailability.pending ? 0.5 : 1.0)
          : (_freeSoon(p, now) ? 1.0 : 0.4);
      scored.add(
        _Scored(
          p,
          0.5 * _quality(p) + 0.3 * geo + 0.2 * availability,
          d,
          state,
        ),
      );
    }

    int byScore(_Scored a, _Scored b) {
      final s = b.score.compareTo(a.score);
      return s != 0 ? s : a.p.id.compareTo(b.p.id);
    }

    int nullsLast<T extends num>(T? a, T? b) {
      if (a == null && b == null) {
        return 0;
      }
      if (a == null) {
        return 1;
      }
      if (b == null) {
        return -1;
      }
      return a.compareTo(b);
    }

    scored.sort(switch (q.sort) {
      RecommendationSort.best => byScore,
      RecommendationSort.near => (a, b) {
        final c = nullsLast<double>(a.distanceKm, b.distanceKm);
        return c != 0 ? c : byScore(a, b);
      },
      RecommendationSort.price => (a, b) {
        final c = nullsLast<int>(a.p.startingPriceVnd, b.p.startingPriceVnd);
        return c != 0 ? c : byScore(a, b);
      },
      RecommendationSort.rating => (a, b) {
        final c = smoothedRating(b.p).compareTo(smoothedRating(a.p));
        return c != 0 ? c : byScore(a, b);
      },
    });

    final start = math.min(_offset(q.cursor), scored.length);
    final limit = clampPageSize(q.limit);
    final slice = scored.skip(start).take(limit).toList();
    final hasMore = start + slice.length < scored.length;
    return RecommendationPage(
      items: [
        for (var i = 0; i < slice.length; i++)
          RecommendedPhotographer(
            photographer: slice[i].p,
            rank: start + i + 1,
            score: _unit(slice[i].score),
            distanceKm: slice[i].distanceKm,
            reasons: _reasons(
              slice[i].p,
              specialtyId: q.specialtyId,
              date: q.date,
              distanceKm: slice[i].distanceKm,
              day: slice[i].day,
              now: now,
            ),
          ),
      ],
      requestId: _requestId(),
      algorithm: algorithm,
      algorithmVersion: version,
      nextCursor: hasMore ? '${start + slice.length}' : null,
    );
  }

  @override
  Future<RecommendationPage> similar(
    String photographerId, {
    int limit = 8,
  }) async {
    final target = (await _photographers.summaries([
      photographerId,
    ]))[photographerId];
    RecommendationPage empty() => RecommendationPage(
      items: const [],
      requestId: _requestId(),
      algorithm: algorithm,
      algorithmVersion: version,
    );
    if (target == null) {
      return empty();
    }
    final mine = target.specialtyIds.toSet();
    final scored = <(PhotographerSummary, double, double?, String)>[];
    for (final p in await _photographers.candidates(limit: candidatePool)) {
      if (p.id == photographerId) {
        continue;
      }
      final theirs = p.specialtyIds.toSet();
      final common = mine.intersection(theirs);
      if (common.isEmpty) {
        continue;
      }
      final jaccard = common.length / mine.union(theirs).length;
      final d = target.hasGeo && p.hasGeo
          ? haversineKm(target.lat!, target.lng!, p.lat!, p.lng!)
          : null;
      final closeness = d == null ? 0.5 : math.exp(-d / 8);
      scored.add((
        p,
        0.6 * jaccard + 0.25 * closeness + 0.15 * _quality(p),
        d,
        common.first,
      ));
    }
    scored.sort((a, b) {
      final s = b.$2.compareTo(a.$2);
      return s != 0 ? s : a.$1.id.compareTo(b.$1.id);
    });
    final top = scored.take(clampPageSize(limit)).toList();
    return RecommendationPage(
      items: [
        for (var i = 0; i < top.length; i++)
          RecommendedPhotographer(
            photographer: top[i].$1,
            rank: i + 1,
            score: _unit(top[i].$2),
            distanceKm: top[i].$3,
            reasons: [
              Reason(
                code: ReasonCode.skillMatch,
                text: _l.reasonSkillMatch(
                  specialtyLabel(top[i].$4).toLowerCase(),
                ),
              ),
              if (top[i].$3 != null && top[i].$3! <= 5)
                Reason(
                  code: ReasonCode.near,
                  text: _l.reasonNear(formatDistance(top[i].$3!)),
                ),
            ],
          ),
      ],
      requestId: _requestId(),
      algorithm: algorithm,
      algorithmVersion: version,
    );
  }

  @override
  Future<PostRecommendationPage> recommendPosts(
    PostRecommendationQuery q,
  ) async {
    final now = _now();
    final page = await _posts.feed(
      kind: PostKind.work,
      specialtyId: q.specialtyId,
      cursor: q.cursor,
      limit: q.limit,
    );
    final authors = await _photographers.summaries(
      page.posts.map((p) => p.photographerId),
    );
    final known = [
      for (final post in page.posts)
        if (authors[post.photographerId] != null) post,
    ];
    final boosted = known.where(
      (p) => _freeSoon(authors[p.photographerId]!, now, days: 14),
    );
    final rest = known.where(
      (p) => !_freeSoon(authors[p.photographerId]!, now, days: 14),
    );
    final ordered = [...boosted, ...rest];
    final origin = _origin(q.geohash6);
    return PostRecommendationPage(
      items: [
        for (var i = 0; i < ordered.length; i++)
          () {
            final author = authors[ordered[i].photographerId]!;
            final d = _distance(origin, author);
            final reasons = <Reason>[
              if (_freeSoon(author, now, days: 14))
                Reason(
                  code: ReasonCode.freeOnDate,
                  text: _l.reasonFreeOnDate(formatDay(author.nextFreeDay!)),
                ),
              if (d != null && d <= 5)
                Reason(
                  code: ReasonCode.near,
                  text: _l.reasonNear(formatDistance(d)),
                ),
            ];
            return RecommendedPost(
              post: ordered[i],
              photographer: author,
              rank: i + 1,
              reasons: reasons,
            );
          }(),
      ],
      requestId: _requestId(),
      algorithm: algorithm,
      algorithmVersion: version,
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<void> sendFeedback(List<RecommendationSignal> signals) async {
    // Nothing is stored on the device; the remote implementation sends these
    // to the service.
  }
}
