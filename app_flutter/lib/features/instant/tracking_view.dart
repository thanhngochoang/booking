// S13.05 (`#S13.05`, `-arrived`, `-stale`): a photographer took the request
// and is on the way. Full-bleed schematic map with the meet point ("Bạn":
// the customer's own live position never leaves the device, spec §9) and,
// only while `en_route`, the photographer's last track point; the ETA is
// computed again from each point (Decision 7: straight line to the meet
// point → `estimateEtaMinutes`). No point for 3 minutes → "Đang chờ cập nhật
// vị trí"; past `lateDeadlineAt` and not arrived → the late line. Chat and,
// once paid, the outside channels (Decision 11); the red cancel text opens
// S13.08 (Decision 8).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/instant/instant_geo.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/contact/contact_action.dart';
import 'package:photobooking/features/instant/customer_cancel_sheet.dart';
import 'package:photobooking/features/instant/instant_meta.dart';
import 'package:photobooking/features/instant/instant_status_badge.dart';
import 'package:photobooking/features/instant/waiting_view.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';

/// No new track point for this long → "Đang chờ cập nhật vị trí" (spec §10).
const kInstantTrackStale = Duration(minutes: 3);

/// A failed track listen is tried again this long after, at most
/// [kInstantTrackRetries] times in a row.
const kInstantTrackRetry = Duration(seconds: 10);
const kInstantTrackRetries = 3;

/// Whether the point is stale, whether the photographer is late, and when
/// either changes next (null: nothing ahead).
typedef _TrackingFlags = ({bool stale, bool late, DateTime? wakeAt});

_TrackingFlags _flagsOf(InstantRequest r, InstantTrack? point, DateTime now) {
  final enRoute = r.status == InstantStatus.enRoute;
  final lastPointAt = enRoute ? (point?.at ?? r.startedRouteAt) : null;
  final staleAt = lastPointAt?.add(kInstantTrackStale);
  final stale = staleAt != null && !now.isBefore(staleAt);
  final lateAt = r.status == InstantStatus.arrived ? null : r.lateDeadlineAt;
  final late = lateAt != null && now.isAfter(lateAt);
  DateTime? wakeAt;
  for (final at in [
    if (staleAt != null && !stale) staleAt,
    if (lateAt != null && !late) lateAt,
  ]) {
    if (wakeAt == null || at.isBefore(wakeAt)) wakeAt = at;
  }
  return (stale: stale, late: late, wakeAt: wakeAt);
}

class TrackingView extends ConsumerStatefulWidget {
  const TrackingView({super.key, required this.request});

  final InstantRequest request;

  @override
  ConsumerState<TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends ConsumerState<TrackingView> {
  /// Wakes the view when the point goes stale or the late deadline passes.
  Timer? _timer;
  DateTime? _timerAt;

  /// Listens to the track again after a failed listen.
  Timer? _retry;
  int _retries = 0;

  /// "Về vị trí của tôi" was tapped: the map keeps the meet point centred.
  bool _centred = false;

  String get _id => widget.request.id;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<InstantTrack?>>(instantTrackProvider(_id), (
      _,
      next,
    ) {
      if (next.hasError && !next.isLoading) _onTrackError(next.error!);
      if (next.hasValue && !next.isLoading) _retries = 0;
      _reschedule();
    }, fireImmediately: true);
  }

  @override
  void didUpdateWidget(TrackingView old) {
    super.didUpdateWidget(old);
    if (old.request != widget.request) _reschedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _retry?.cancel();
    super.dispose();
  }

  DateTime _now() => ref.read(clockProvider)();

  /// A failed listen is logged and tried again a few times, [kInstantTrackRetry]
  /// apart; meanwhile the view reads "no point" (the stale line follows).
  void _onTrackError(Object e) {
    debugPrint('instant track failed: ${instantErrorCodeOf(e)}');
    if (_retry != null || _retries >= kInstantTrackRetries) return;
    _retries++;
    _retry = Timer(kInstantTrackRetry, () {
      _retry = null;
      if (mounted) ref.invalidate(instantTrackProvider(_id));
    });
  }

  /// One timer for the next moment the view changes by itself (the point
  /// going stale, the late deadline), from the request and the last point.
  void _reschedule() {
    final point = ref.read(instantTrackProvider(_id)).value;
    final at = _flagsOf(widget.request, point, _now()).wakeAt;
    if (at == _timerAt && (_timer?.isActive ?? at == null)) return;
    _timer?.cancel();
    _timer = null;
    _timerAt = at;
    if (at == null) return;
    // Just past [at], so "after the deadline" holds when it fires.
    final wait = at.difference(_now()) + const Duration(milliseconds: 1);
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (!mounted) return;
      setState(() {});
      _reschedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    // The provider listens to `instant_tracks/{id}` only while the request is
    // en route (privacy, spec §9); before and after it reads null.
    final track = ref.watch(instantTrackProvider(_id));
    return AsyncView<InstantTrack?>(
      // While a failed listen is tried again, stay on the "no point" view
      // instead of a blank loading frame.
      value: track.isLoading && track.hasError && !track.hasValue
          ? AsyncError<InstantTrack?>(
              track.error!,
              track.stackTrace ?? StackTrace.empty,
            )
          : track,
      // Until the first point arrives the view is the one without a point.
      skeleton: (context) => _content(context, null),
      // An unreadable track reads as "no point": the stale line follows.
      error: (context, _, _) => _content(context, null),
      data: _content,
    );
  }

  Widget _content(BuildContext context, InstantTrack? point) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final r = widget.request;
    final p = r.photographer;
    final name = p?.name ?? '';
    final now = _now();
    final arrived = r.status == InstantStatus.arrived;
    final enRoute = r.status == InstantStatus.enRoute;
    // The photographer's position only while en route (spec §9).
    final track = enRoute ? point : null;
    final trackEta = track == null
        ? null
        : estimateEtaMinutes(
            haversineKm(track.lat, track.lng, r.meetPoint.lat, r.meetPoint.lng),
          );
    final (:stale, :late, wakeAt: _) = _flagsOf(r, point, now);
    final eta = trackEta ?? (arrived ? null : r.etaMinutes);
    final meet = r.meetPoint;
    final muted = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final noteStyle = theme.textTheme.bodySmall?.copyWith(color: muted);

    return ScreenCode(
      ScreenCodes.instantTracking,
      label: arrived ? 'arrived' : (stale ? 'stale' : null),
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpace.s6),
              children: [
                MapPreview(
                  key: const Key('tracking-map'),
                  borderRadius: BorderRadius.zero,
                  route: track != null,
                  center: _centred ? (lat: meet.lat, lng: meet.lng) : null,
                  onRecenter: () => setState(() => _centred = true),
                  pins: [
                    MapPin(
                      lat: meet.lat,
                      lng: meet.lng,
                      label: l.trackingSelf,
                      self: true,
                    ),
                    if (track != null)
                      MapPin(
                        lat: track.lat,
                        lng: track.lng,
                        label: l.trackingPin(name, trackEta!),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s4,
                    AppSpace.s3,
                    AppSpace.s4,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (p != null) ...[
                        _PartyRow(
                          party: p,
                          meta: [
                            ...instantPartyMeta(l, p),
                            if (!arrived)
                              if (stale)
                                MetaPart.text(l.trackingStale)
                              else if (eta != null)
                                MetaPart.text(
                                  l.trackingEta(eta),
                                  bold: l.trackingEtaBold(eta),
                                ),
                          ],
                          badge: instantStatusText(l, r.status),
                        ),
                        const SizedBox(height: AppSpace.s2h),
                      ],
                      if (arrived) ...[
                        Text(
                          l.trackingArrived,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l.trackingArrivedBody(name, meet.name),
                          style: noteStyle,
                        ),
                      ] else ...[
                        if (late) ...[
                          Text(
                            r.paid
                                ? l.trackingLate(name)
                                : l.trackingLateUnpaid(name),
                            key: const Key('tracking-late'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: dark
                                  ? AppColorsDark.warning
                                  : AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpace.s1),
                        ],
                        if (p != null)
                          Text(l.trackingNote(name), style: noteStyle),
                      ],
                      if (p != null) ...[
                        const SizedBox(height: AppSpace.s2h),
                        _ContactRow(request: r, photographerId: p.id),
                      ],
                      const SizedBox(height: AppSpace.s1),
                      _cancel(context, r, now: now, late: late),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mock `.btn.txt` in `--bad`: "Huỷ (miễn phí thêm 1:40)" until
  /// `freeCancelUntil`, "Huỷ (hoàn 100%)" once the photographer is late, else
  /// "Huỷ". Unpaid (every #140 request) there is no money to speak of:
  /// always "Huỷ". Each opens S13.08 with the server's quote.
  Widget _cancel(
    BuildContext context,
    InstantRequest r, {
    required DateTime now,
    required bool late,
  }) {
    final l = context.l10n;
    Widget button(String label) => _RedText(
      label,
      key: const Key('tracking-cancel'),
      onPressed: () => showCustomerCancelSheet(context, ref, request: r),
    );
    if (!r.paid || r.status == InstantStatus.arrived) {
      return button(l.trackingCancel);
    }
    if (late) return button(l.trackingCancelLate);
    final freeUntil = r.freeCancelUntil;
    if (freeUntil == null || !now.isBefore(freeUntil)) {
      return button(l.trackingCancel);
    }
    return CountdownText(
      deadline: freeUntil,
      now: ref.read(clockProvider),
      builder: (context, left) => button(
        left > Duration.zero
            ? l.trackingCancelFree(waitingClock(left))
            : l.trackingCancel,
      ),
    );
  }
}

/// Mock `.row`: avatar, name with the verified mark, the meta line, badge.
class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.party, required this.meta, this.badge});

  final InstantParty party;
  final List<MetaPart> meta;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final b = badge;
    return Row(
      children: [
        AppAvatar(url: party.avatarUrl, name: party.name, decorative: true),
        const SizedBox(width: AppSpace.s2h),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      party.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (party.verified) ...[
                    const SizedBox(width: AppSpace.s1),
                    const VerifiedMark(),
                  ],
                ],
              ),
              MetaLine(meta, maxLines: 2),
            ],
          ),
        ),
        if (b != null) ...[
          const SizedBox(width: AppSpace.s2),
          InstantStatusBadge(b),
        ],
      ],
    );
  }
}

/// "Nhắn tin" (the request's chat) and, once paid, "Liên hệ" (call, Zalo,
/// WhatsApp through `getContactLink` with the request as subject). Unpaid
/// — every #140 request — the server keeps contact locked (`paidAt`), so
/// the dial is not shown at all; the chat stays.
class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.request, required this.photographerId});

  final InstantRequest request;
  final String photographerId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chatId = request.chatId;
    final message = AppButton.outline(
      l.trackingMessage,
      key: const Key('tracking-message'),
      size: AppButtonSize.small,
      onPressed: chatId == null ? null : () => context.push('/chat/$chatId'),
    );
    if (!request.paid) return message;
    return Row(
      children: [
        Expanded(child: message),
        const SizedBox(width: AppSpace.s2),
        Expanded(
          child: PhotographerContactAction(
            photographerId: photographerId,
            access: ContactAccess.unlocked,
            source: ScreenCodes.instantTracking,
            subject: ContactSubject.instantRequest(request.id),
            style: ContactDialStyle.labeled,
          ),
        ),
      ],
    );
  }
}

/// Mock `.btn.txt` in `--bad`.
class _RedText extends StatelessWidget {
  const _RedText(this.label, {super.key, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppButton.text(
      label,
      size: AppButtonSize.small,
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(
          dark ? AppColorsDark.destructive : AppColors.destructive,
        ),
      ),
      onPressed: onPressed,
    );
  }
}
