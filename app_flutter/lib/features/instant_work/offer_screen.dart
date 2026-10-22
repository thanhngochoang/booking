// S14.02: up to three pending offers as a stack, each with its own 60-second
// countdown from the server's `expiresAt`; "Nhận việc" wins only if first
// (Decision 4), then the S13.04 overlay and S14.03.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';
import 'package:photobooking/features/instant_work/offer_controller.dart';

/// Spec §3.3: "Hạn một lời mời 60 giây".
const _offerWindow = Duration(seconds: 60);

/// Mock S14.02 / spec §8: "Nút Nhận cao 56dp".
const _acceptHeight = 56.0;

/// Where S14.02 goes when nothing is left to answer.
const _liveShutterPath = '/work/instant';

class OfferScreen extends ConsumerStatefulWidget {
  const OfferScreen({super.key, required this.offerId});

  /// The offer that opened the screen; it is the top card while it waits.
  final String offerId;

  @override
  ConsumerState<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends ConsumerState<OfferScreen> {
  /// Rebuilds the stack when the next card's countdown reaches zero.
  Timer? _expiry;
  DateTime? _expiryAt;
  bool _sawCard = false;
  bool _leaving = false;

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  OfferController get _controller => ref.read(offerControllerProvider.notifier);

  DateTime _now() => ref.read(clockProvider)();

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// The pending offers still on the stack: the routed one first, then the
  /// soonest to expire. An offer past its `expiresAt` is gone even before
  /// the server settles it (it can no longer be accepted).
  List<InstantOffer> _visible(List<InstantOffer> offers, OfferUiState ui) {
    final now = _now();
    final open = [
      for (final o in offers)
        if (o.outcome == OfferOutcome.pending &&
            o.expiresAt.isAfter(now) &&
            !ui.dropped.contains(o.id))
          o,
    ]..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    final routed = open.indexWhere((o) => o.id == widget.offerId);
    if (routed > 0) open.insert(0, open.removeAt(routed));
    return open;
  }

  void _scheduleExpiry(List<InstantOffer> visible) {
    final next = visible.isEmpty
        ? null
        : visible
              .map((o) => o.expiresAt)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    if (next == _expiryAt) return;
    _expiry?.cancel();
    _expiryAt = next;
    if (next == null) return;
    _expiry = Timer(next.difference(_now()), () {
      if (!mounted) return;
      _expiryAt = null;
      setState(() {});
    });
  }

  /// Nothing left to answer: back to where S14.02 was opened from (Live
  /// Shutter when there is nothing below it).
  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_sawCard) _say(context.l10n.offerExpired);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(_liveShutterPath);
      }
    });
  }

  void _openJob(String requestId) {
    if (_leaving) return;
    _leaving = true;
    // S14.03 replaces S14.02: back from the job never shows the offers.
    context.pushReplacement('/work/instant/$requestId');
  }

  Future<void> _accept(String offerId) async {
    final l = context.l10n;
    try {
      await _controller.accept(offerId);
    } on Object catch (e) {
      if (!mounted) return;
      _say(switch (InstantError(instantErrorCodeOf(e)).kind) {
        InstantErrorKind.alreadyAssigned => l.offerAlreadyAssigned,
        InstantErrorKind.offerExpired => l.offerExpired,
        InstantErrorKind.notAcceptingOrders => l.offerNotAccepting,
        _ => instantErrorText(l, e),
      });
    }
  }

  Future<void> _decline(String offerId) async {
    try {
      await _controller.decline(offerId);
    } on Object catch (e) {
      if (!mounted) return;
      _say(instantErrorText(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(offerControllerProvider);
    final match = ui.match;
    if (match != null) return _matched(context, match);
    final l = context.l10n;
    final offers = ref.watch(pendingOffersProvider);
    final visible = offers.hasValue
        ? _visible(offers.requireValue, ui)
        : const <InstantOffer>[];
    if (offers.hasValue) {
      _scheduleExpiry(visible);
      if (visible.isNotEmpty) {
        _sawCard = true;
      } else if (!ui.busy) {
        _leave();
      }
    }
    return ScreenCode(
      ScreenCodes.instantOffer,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: _BarTitle(
              title: l.offerTitle,
              subtitle: visible.isEmpty
                  ? null
                  : l.offerPendingCount(visible.length),
            ),
          ),
          body: AsyncView<List<InstantOffer>>(
            value: offers,
            skeleton: (_) => const _Skeleton(),
            onRetry: () => ref.invalidate(pendingOffersProvider),
            data: (context, _) => visible.isEmpty
                ? const SizedBox.shrink()
                : _content(context, visible, ui),
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    List<InstantOffer> visible,
    OfferUiState ui,
  ) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final top = visible.first;
    final busy = ui.busy;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s2,
              AppSpace.s4,
              AppSpace.s6,
            ),
            children: [
              Center(
                child: CountdownRing(
                  key: ValueKey('countdown-${top.id}'),
                  deadline: top.expiresAt,
                  total: _offerWindow,
                  now: ref.read(clockProvider),
                  onExpired: () {
                    if (mounted) setState(() {});
                  },
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              Text(
                formatMoney(top.earningVnd),
                key: const Key('offer-earning'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: AppText.xl,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                l.offerYouGet(
                  instantGenreText(l, top.genre),
                  instantDurationText(l, top.durationMin),
                  top.photos,
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              // Room for the two edges peeking above the top card.
              const SizedBox(height: AppSpace.s5),
              OfferStack(
                offers: [
                  for (final o in visible)
                    _OfferCard(key: ValueKey('offer-${o.id}'), offer: o),
                ],
              ),
            ],
          ),
        ),
        AppFooterBar(
          child: Row(
            children: [
              Expanded(
                flex: 34,
                child: AppButton.outline(
                  l.offerDecline,
                  key: const Key('offer-decline'),
                  loading: busy && !ui.accepting,
                  onPressed: busy ? null : () => _decline(top.id),
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                flex: 66,
                child: AppButton.primary(
                  l.offerAccept,
                  key: const Key('offer-accept'),
                  loading: busy && ui.accepting,
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(
                      Size.fromHeight(_acceptHeight),
                    ),
                  ),
                  onPressed: busy ? null : () => _accept(top.id),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// S13.04 (photographer): "Lan Anh đang chờ ở Công viên Tao Đàn."
  Widget _matched(BuildContext context, OfferMatch match) {
    final name = match.name;
    if (name == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openJob(match.requestId);
      });
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final myAvatar = ref.watch(currentProfileProvider).value?.avatarUrl;
    return ScreenCode(
      ScreenCodes.instantMatched,
      label: 'provider',
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: MatchOverlay(
              name: name,
              body: l.matchBodyPhotographer(name, match.place ?? ''),
              myAvatarUrl: myAvatar,
              theirAvatarUrl: match.avatarUrl,
              onContinue: () => _openJob(match.requestId),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mock `.bar .t` with `<small>`: the title and the count under it.
class _BarTitle extends StatelessWidget {
  const _BarTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final sub = subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        if (sub != null)
          Text(
            sub,
            style: theme.textTheme.bodySmall?.copyWith(
              color: dark
                  ? AppColorsDark.foregroundMuted
                  : AppColors.foregroundMuted,
            ),
          ),
      ],
    );
  }
}

/// One offer (mock S14.02 `.card`): area and distance only, never the meet
/// point (spec §9), how many people the customer chose, and the note.
class _OfferCard extends StatelessWidget {
  const _OfferCard({super.key, required this.offer});

  final InstantOffer offer;

  /// Stands for the count inside the sentence, so it can be bold.
  static const _marker = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final meta = theme.textTheme.bodySmall?.copyWith(color: muted);
    final chosen = l.offerChosenAmong(_marker).split(_marker);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: AppSpace.s10,
                    height: AppSpace.s10,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Center(
                      child: AppIcon(
                        AppIcons.place,
                        size: 20,
                        color: secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s2h),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.areaLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l.offerDistance(
                          formatDistance(offer.distanceKm),
                          offer.etaMinutes,
                        ),
                        style: meta,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s2),
            Text.rich(
              TextSpan(
                children: [
                  for (var i = 0; i < chosen.length; i++) ...[
                    if (i > 0)
                      TextSpan(
                        text: '${offer.invitedCount}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    TextSpan(text: chosen[i]),
                  ],
                ],
              ),
              style: meta,
            ),
            if (offer.note.isNotEmpty) ...[
              const SizedBox(height: AppSpace.s2),
              Text(
                l.offerNote(offer.note),
                style: meta?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => AppSkeleton.group(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        AppSpace.s6,
      ),
      children: [
        Center(child: AppSkeleton.circle(size: 96)),
        const SizedBox(height: AppSpace.s3),
        Center(child: AppSkeleton.line(width: 120)),
        const SizedBox(height: AppSpace.s2),
        Center(child: AppSkeleton.line(width: 200)),
        const SizedBox(height: AppSpace.s5),
        AppSkeleton.card(height: 150),
      ],
    ),
  );
}
