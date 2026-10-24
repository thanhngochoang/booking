import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/collab/collab_providers.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/recruit/recruit_post.dart';
import 'package:photobooking/features/recruit/recruit_edit_controller.dart'
    show kRecruitFeeMax, kRecruitFeeMin, kRecruitFeeStep;
import 'package:photobooking/l10n/app_localizations.dart';

// S27.06 / S27.07 (#151 Task 9): the collaboration listeners of the
// signed-in account and the rules the screens share.

/// The studio's invited and active collaborations (S27.06 studio, S26.04,
/// S26.02-collab, S09.02).
final studioCollaborationsProvider =
    StreamProvider.autoDispose<List<Collaboration>>((ref) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return Stream.value(const []);
      return ref.watch(collabRepositoryProvider).watchAsStudio(uid);
    });

/// The photographer's invited and active collaborations (S27.06-me, S09.02).
final myCollaborationsProvider =
    StreamProvider.autoDispose<List<Collaboration>>((ref) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return Stream.value(const []);
      return ref.watch(collabRepositoryProvider).watchAsCollaborator(uid);
    });

/// The studio's jobs, last changed first.
final studioCollabJobsProvider = StreamProvider.autoDispose<List<CollabJob>>((
  ref,
) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(collabRepositoryProvider).watchJobsAsStudio(uid);
});

/// The collaborator's jobs, last changed first.
final myCollabJobsProvider = StreamProvider.autoDispose<List<CollabJob>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(collabRepositoryProvider).watchJobsAsCollaborator(uid);
});

/// Active collaborators a studio may have: 5, or 50 once its business is
/// verified (mirror of the domain's `collaboratorLimit`).
int collaboratorLimit({required bool businessVerified}) =>
    businessVerified ? 50 : 5;

/// Studios one photographer may collaborate with.
const kMaxCollabsPerCollaborator = 5;

/// Open invites one studio may have.
const kMaxPendingCollabInvites = 5;

/// A studio may invite the same photographer again 3 days after the
/// collaboration ended.
const kCollabReinviteDays = 3;

/// A due or reported pay from this amount shows the tax reminder
/// (Decision 25).
const kCollabTaxThreshold = 5000000;

/// SharedPreferences key remembering that [uid] closed the tax reminder.
String collabTaxNoticeKey(String uid) => 'collabTaxNoticeSeen:$uid';

/// An offer still waiting for the collaborator at [now].
bool isLiveOffer(CollabJob j, DateTime now) =>
    j.offerStatus == OfferStatus.pending && now.isBefore(j.offerExpiresAt);

/// A job the collaborator holds now ("việc đang giao"): a live offer, or an
/// accepted one whose pay record has not started.
bool isOpenCollabJob(CollabJob j, DateTime now) =>
    isLiveOffer(j, now) ||
    (j.offerStatus == OfferStatus.accepted && j.payStatus == PayStatus.none);

/// Open jobs of [jobs] that [where] picks.
int openCollabJobCount(
  Iterable<CollabJob> jobs,
  DateTime now,
  bool Function(CollabJob) where,
) => jobs.where((j) => where(j) && isOpenCollabJob(j, now)).length;

/// Live offers, the soonest to lapse first (S27.06-me "Việc chờ nhận").
List<CollabJob> liveOffers(Iterable<CollabJob> jobs, DateTime now) =>
    jobs.where((j) => isLiveOffer(j, now)).toList()
      ..sort((a, b) => a.offerExpiresAt.compareTo(b.offerExpiresAt));

/// Jobs with a pay record, newest due first.
List<CollabJob> payRecords(Iterable<CollabJob> jobs) =>
    jobs.where((j) => j.payStatus != PayStatus.none).toList()..sort(
      (a, b) =>
          (b.payDueAt ?? b.updatedAt).compareTo(a.payDueAt ?? a.updatedAt),
    );

/// The studio still owes the record: "Đã trả" is offered.
bool studioOwesPay(CollabJob j) =>
    j.payStatus == PayStatus.due || j.payStatus == PayStatus.disputed;

/// Decision 25: a due or reported pay of 5.000.000₫ or more.
bool needsTaxNotice(Iterable<CollabJob> jobs) => jobs.any(
  (j) =>
      (j.payStatus == PayStatus.due || j.payStatus == PayStatus.paidReported) &&
      j.agreedFee >= kCollabTaxThreshold,
);

/// Whether [fee] is a fee the server takes (1.000–100.000.000₫, multiples
/// of 1.000₫), as `isValidRecruitFee`.
bool isValidCollabFee(int? fee) =>
    fee != null &&
    fee >= kRecruitFeeMin &&
    fee <= kRecruitFeeMax &&
    fee % kRecruitFeeStep == 0;

/// "3 giờ 52 phút", "4 giờ", "45 phút" (at least a minute).
String collabLeftText(Duration left, AppLocalizations l) {
  final minutes = left.inMinutes < 1 ? 1 : left.inMinutes;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return l.countdownMinutes(m);
  if (m == 0) return l.countdownHours(h);
  return l.collabLeftHoursMinutes(h, m);
}

/// "T7 24/10" of a job's shoot day.
String collabDayText(CollabJob j) {
  final day = parseDayKey(j.day);
  return day == null ? j.day : formatDay(day);
}

/// "Cưới 4 giờ T7 24/10 · 15:30–19:30" of a job; without [hours] "Cưới 4
/// giờ T7 24/10".
String collabShootText(CollabJob j, {bool hours = true}) {
  final text = '${j.serviceName} ${collabDayText(j)}';
  return hours ? '$text · ${j.start}–${j.end}' : text;
}

/// Mock `.irow2`: a bold title over a secondary meta line.
class CollabTitleMeta extends StatelessWidget {
  const CollabTitleMeta({super.key, required this.title, required this.meta});

  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          meta,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.brightness == Brightness.dark
                ? AppColorsDark.foregroundSecondary
                : AppColors.foregroundSecondary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// "Chuyển khoản", "Tiền mặt", "Khác".
String collabMethodLabel(CollabPayMethod m, AppLocalizations l) => switch (m) {
  CollabPayMethod.bank => l.collabMethodBank,
  CollabPayMethod.cash => l.collabMethodCash,
  CollabPayMethod.other => l.collabMethodOther,
};

/// What to say when a collaboration call is refused.
String collabErrorText(
  Object error,
  AppLocalizations l, {
  DateTime? blockedUntil,
}) {
  final e = recruitErrorOf(error);
  return switch (e.code) {
    RecruitErrorCode.collabFull => l.collabErrorFull,
    RecruitErrorCode.cooldown => l.collabErrorCooldown,
    RecruitErrorCode.memberBusy => l.collabErrorBusy,
    RecruitErrorCode.membershipConflict => l.collabErrorConflict,
    RecruitErrorCode.dayTaken => l.collabErrorDayTaken,
    RecruitErrorCode.deadlinePassed => l.collabOfferExpired,
    RecruitErrorCode.rateLimited => l.recruitErrorRateLimited,
    RecruitErrorCode.recruitBlocked when blockedUntil != null =>
      l.recruitBlocked(formatDayMonth(toVn(blockedUntil))),
    RecruitErrorCode.notAcceptingOrders => l.studioErr_not_accepting_orders,
    RecruitErrorCode.conflict => l.studioErr_conflict,
    RecruitErrorCode.network => l.authErrorNetwork,
    _ => l.recruitErrorGeneric,
  };
}

/// Thrown inside a [showConfirmSheet] action so its SnackBar shows [text].
class CollabFailure implements Exception {
  const CollabFailure(this.text);
  final String text;

  @override
  String toString() => text;
}

/// Whether the studio closed the tax reminder on this device.
final collabTaxNoticeSeenProvider = NotifierProvider.autoDispose
    .family<CollabTaxNoticeSeen, bool, String>(CollabTaxNoticeSeen.new);

class CollabTaxNoticeSeen extends Notifier<bool> {
  CollabTaxNoticeSeen(this.uid);

  final String uid;

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(collabTaxNoticeKey(uid)) ??
      false;

  Future<void> dismiss() async {
    state = true;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(collabTaxNoticeKey(uid), true);
  }
}

/// Runs [action] and shows its refusal ([collabErrorText]) or [done] in a
/// SnackBar; true when it went through.
Future<bool> runCollabAction(
  BuildContext context,
  Future<void> Function() action, {
  String? done,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  String? text = done;
  var ok = true;
  try {
    await action();
  } catch (e) {
    ok = false;
    text = collabErrorText(e, l);
  }
  if (text != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
  return ok;
}

/// Mock `b-warn`: the pale yellow of each theme with fixed dark ink (the
/// dark theme's own foreground is near-white, unreadable on it), as the
/// notification rows do.
(Color, Color) collabWarnColors(bool dark) => (
  dark ? AppColorsDark.warningSubtle : AppColors.warningSubtle,
  AppColors.foreground,
);

/// Mock `.badge` of a pay record: "Cần trả" (warning), "Chưa nhận"
/// (error), "Đã báo trả" (neutral), "Đã nhận" (ok).
class CollabPayBadge extends StatelessWidget {
  const CollabPayBadge(this.status, {super.key});

  final PayStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (label, color, onColor) = switch (status) {
      PayStatus.due => (
        l.collabPayDue,
        collabWarnColors(dark).$1,
        collabWarnColors(dark).$2,
      ),
      PayStatus.disputed => (
        l.collabPayDisputed,
        dark ? AppColorsDark.errorSubtle : AppColors.errorSubtle,
        dark ? AppColorsDark.error : AppColors.error,
      ),
      PayStatus.received => (
        l.collabPayReceived,
        dark ? AppColorsDark.successSubtle : AppColors.successSubtle,
        dark ? AppColorsDark.success : AppColors.success,
      ),
      PayStatus.paidReported || PayStatus.none => (
        l.collabPayReported,
        dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
        dark
            ? AppColorsDark.foregroundSecondary
            : AppColors.foregroundSecondary,
      ),
    };
    return StatusBadge.custom(label: label, color: color, onColor: onColor);
  }
}
