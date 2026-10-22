// S13.02 (`#S13.02`, `-summary`, `-round`, `-empty`): swipe through the
// round's five suggestions, review who was chosen, "Gửi lời mời" (#140: no
// payment in any round, Decision 1); a round that ended without anyone,
// and a first round with nobody around.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/choose_controller.dart';
import 'package:photobooking/features/instant/customer_cancel_sheet.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// "Đặt lịch thường" (Decision 13): Tìm thợ ảnh; the request stays open.
const _bookNormally = '/action';

/// Mock `.picked .av`: small overlapping avatars of who was chosen.
const _pickedShown = 3;
const _pickedStep = 22.0;

/// The meta of a candidate: the tomato percent from five reviews ("Mới ·
/// {n} đánh giá" below), [sessions] the shoots done, and the ETA.
List<MetaPart> candidateMeta(
  AppLocalizations l,
  InstantCandidate c, {
  bool sessions = true,
}) => [
  if (c.reviewCount >= kTomatoPctMinReviews)
    MetaPart.tomato(c.tomatoPct)
  else if (c.reviewCount > 0)
    MetaPart.text(l.photographerReviewsNew(c.reviewCount)),
  if (sessions) MetaPart.text(l.photographerSessions(c.completedCount)),
  MetaPart.text(l.chooseEta(c.etaMinutes)),
];

enum _Mode { deck, summary, round, empty }

class ChooseView extends ConsumerWidget {
  const ChooseView({super.key, required this.request, this.askPrimer});

  final InstantRequest request;

  /// Shown once after the request's first successful invite (Decision 10).
  /// The flow screen passes it: this view leaves as soon as the request is
  /// `searching`, so the primer needs a context that stays.
  final Future<void> Function()? askPrimer;

  String get _id => request.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final provider = chooseControllerProvider(_id);
    final s = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(provider.select((s) => s.error), (_, error) {
      if (error != null) _say(context, instantErrorText(l, error));
    });

    final cards = roundCandidates(request);
    final mode = cards.isEmpty
        ? (request.roundEnded || request.committed ? _Mode.round : _Mode.empty)
        : (s.summary ? _Mode.summary : _Mode.deck);
    final amount = s.amountVnd ?? request.amountVnd;

    void back() {
      if (mode == _Mode.summary) {
        controller.closeSummary();
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }

    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    // Offers went out (or money is held, #202): leaving no longer ends the
    // request, so it can be cancelled here (S13.08).
    final cancellable =
        request.committed ||
        request.paid ||
        request.status == InstantStatus.pendingPayment;
    return ScreenCode(
      ScreenCodes.instantChoose,
      label: switch (mode) {
        _Mode.deck => null,
        _Mode.summary => 'summary',
        _Mode.round => 'round',
        _Mode.empty => 'empty',
      },
      child: PopScope(
        canPop: mode != _Mode.summary,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && mode == _Mode.summary) controller.closeSummary();
        },
        child: AuroraBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                tooltip: l.back,
                icon: const AppIcon(AppIcons.back),
                onPressed: back,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.chooseTitle),
                  Text(
                    l.chooseSubtitle(
                      instantGenreText(l, request.genre),
                      instantDurationText(l, request.durationMin),
                      formatMoney(amount),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
              actions: [
                if (mode == _Mode.deck)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpace.s4),
                    child: Center(
                      child: Text(
                        l.chooseCounter(
                          (s.index + 1).clamp(1, cards.length),
                          cards.length,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                if (cancellable)
                  AppButton.text(
                    l.trackingCancel,
                    key: const Key('choose-cancel'),
                    size: AppButtonSize.xsmall,
                    style: ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(
                        dark
                            ? AppColorsDark.destructive
                            : AppColors.destructive,
                      ),
                    ),
                    onPressed: () =>
                        showCustomerCancelSheet(context, ref, request: request),
                  ),
              ],
            ),
            body: switch (mode) {
              _Mode.deck => _Deck(
                request: request,
                cards: cards,
                state: s,
                controller: controller,
                // The last card: the summary when someone was chosen.
                onEmpty: () {
                  if (ref.read(provider).liked.isNotEmpty) controller.done();
                },
              ),
              _Mode.summary => _Summary(
                cards: cards,
                state: s,
                onUnpick: controller.unpick,
                onSend: () => _send(context, controller),
                onMore: controller.more,
              ),
              _Mode.round => _RoundEnded(
                fetching: s.fetching,
                onMore: controller.more,
                unavailable: _allUnavailable(request),
              ),
              _Mode.empty => _Empty(
                fetching: s.fetching,
                onRetry: controller.more,
                onBookNormally: () => context.go(_bookNormally),
              ),
            },
          ),
        ),
      ),
    );
  }

  static void _say(BuildContext context, String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// The names of the last round's people when every one of them was
  /// unavailable (the server ended the round without inviting anyone);
  /// null otherwise.
  static List<String>? _allUnavailable(InstantRequest r) {
    final rows = r.offers;
    if (rows.isEmpty ||
        rows.any((o) => o.outcome != OfferOutcome.unavailable)) {
      return null;
    }
    return [for (final o in rows) o.name];
  }

  Future<void> _send(BuildContext context, ChooseController controller) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final names = {
      for (final c in request.candidates) c.photographerId: c.name,
    };
    void say(String text) => messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    final result = await controller.send(askPrimer: askPrimer);
    switch (result) {
      case InstantPriceChanged(:final amountVnd):
        say(l.choosePriceChanged(formatMoney(amountVnd)));
      // Nobody invited: the round ends here (the view stays). Some invited:
      // only while S13.02 still shows (S13.03 lists them itself).
      case InstantInvited(:final invited, :final unavailable)
          when unavailable.isNotEmpty && (invited.isEmpty || context.mounted):
        say(
          l.chooseUnavailable(
            [for (final id in unavailable) names[id] ?? ''].join(', '),
          ),
        );
      case _:
        // InstantInvited: the listener moves the request to S13.03.
        break;
    }
  }
}

/// `#S13.02`: the deck, who was chosen and "Xong"; at the end of the deck
/// with nobody chosen, "Xem 5 người khác".
class _Deck extends StatelessWidget {
  const _Deck({
    required this.request,
    required this.cards,
    required this.state,
    required this.controller,
    required this.onEmpty,
  });

  final InstantRequest request;
  final List<InstantCandidate> cards;
  final ChooseState state;
  final ChooseController controller;
  final VoidCallback onEmpty;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final liked = [
      for (final id in state.liked)
        ?cards.where((c) => c.photographerId == id).firstOrNull,
    ];
    final ended = state.index >= cards.length;
    final Widget? below = liked.isNotEmpty
        ? _PickedRow(liked: liked, onDone: controller.done)
        : ended
        ? SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              l.chooseMore,
              key: const Key('choose-more'),
              loading: state.fetching,
              onPressed: state.fetching ? null : controller.more,
            ),
          )
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        AppSpace.s4,
      ),
      child: SwipeDeck<InstantCandidate>(
        // A new round is a new deck.
        key: ValueKey('choose-deck-${request.round}'),
        items: cards,
        initialIndex: state.index,
        initialUndoDepth: state.undoDepth,
        cardBuilder: (_, c) => _CandidateCard(candidate: c),
        onLike: controller.like,
        onSkip: controller.skip,
        onUndo: controller.undo,
        onEmpty: onEmpty,
        likeStampLabel: l.chooseStamp,
        likeLabel: l.chooseLike,
        skipLabel: l.chooseSkip,
        undoLabel: l.chooseUndo,
        belowCards: below,
      ),
    );
  }
}

/// One suggestion (mock `.sc.top`): portfolio photos with a dash per photo
/// (tap the left or right half to move), the name with the verified mark,
/// the tomato meta and up to two reasons.
class _CandidateCard extends StatefulWidget {
  const _CandidateCard({required this.candidate});

  final InstantCandidate candidate;

  @override
  State<_CandidateCard> createState() => _CandidateCardState();
}

class _CandidateCardState extends State<_CandidateCard> {
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = widget.candidate;
    final scheme = Theme.of(context).colorScheme;
    final photos = c.photos.take(3).toList();
    final onPhoto = AppColors.onScrim;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: photos.isEmpty
              ? ColoredBox(color: scheme.secondary)
              : NetworkPhoto(url: photos[_photo], retry: false),
        ),
        if (photos.length > 1) ...[
          // Tap the left or right half for the previous or next photo; the
          // photos are decorative for a screen reader.
          ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(
                      () => _photo = (_photo - 1).clamp(0, photos.length - 1),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(
                      () => _photo = (_photo + 1).clamp(0, photos.length - 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: AppSpace.s2,
            left: AppSpace.s2h,
            right: AppSpace.s2h,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < photos.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpace.s1),
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: i == _photo
                              ? AppColors.foregroundInverse
                              : AppColors.overlayLight,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.scrim],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s4,
                  AppSpace.s10,
                  AppSpace.s4,
                  AppSpace.s4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.foregroundInverse,
                              fontSize: AppText.md,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (c.verified) ...[
                          const SizedBox(width: AppSpace.s1),
                          const VerifiedMark(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    MetaLine(
                      candidateMeta(l, c),
                      style: TextStyle(color: onPhoto),
                    ),
                    if (c.reasons.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.s2),
                      Wrap(
                        spacing: AppSpace.s1,
                        runSpacing: AppSpace.s1,
                        children: [
                          for (final r in c.reasons.take(2)) _Reason(r),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mock `.swipe .rs span`: a reason on the photo.
class _Reason extends StatelessWidget {
  const _Reason(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.overlayLight.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2, vertical: 3),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.foregroundInverse,
          fontSize: AppText.xs,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// Mock `.picked`: who was chosen so far, and "Xong".
class _PickedRow extends StatelessWidget {
  const _PickedRow({required this.liked, required this.onDone});

  final List<InstantCandidate> liked;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final shown = liked.take(_pickedShown).toList();
    final size = AppAvatarSize.xs.dimension;
    return Row(
      children: [
        SizedBox(
          width: size + _pickedStep * (shown.length - 1),
          height: size,
          child: Stack(
            children: [
              for (final (i, c) in shown.indexed)
                Positioned(
                  left: _pickedStep * i,
                  child: AppAvatar(
                    url: c.avatarUrl,
                    name: c.name,
                    size: AppAvatarSize.xs,
                    decorative: true,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s2),
        Expanded(
          child: Text(
            l.choosePicked(liked.length),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        AppButton.outline(
          l.chooseDone,
          key: const Key('choose-done'),
          size: AppButtonSize.xsmall,
          onPressed: onDone,
        ),
      ],
    );
  }
}

/// `#S13.02-summary` in #140: who was chosen, "Bỏ chọn", "Gửi lời mời" and
/// "Xem 5 người khác"; no payment method (Task 8, #202, adds it).
class _Summary extends StatelessWidget {
  const _Summary({
    required this.cards,
    required this.state,
    required this.onUnpick,
    required this.onSend,
    required this.onMore,
  });

  final List<InstantCandidate> cards;
  final ChooseState state;
  final ValueChanged<String> onUnpick;
  final VoidCallback onSend;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final liked = [
      for (final id in state.liked)
        ?cards.where((c) => c.photographerId == id).firstOrNull,
    ];
    final busy = state.sending || state.fetching;
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
              Text(
                l.chooseSummaryTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.s2),
              if (liked.isNotEmpty)
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s3,
                      vertical: AppSpace.s1,
                    ),
                    child: Column(
                      children: [
                        for (final (i, c) in liked.indexed) ...[
                          if (i > 0) const Divider(height: 1),
                          _PickedPerson(
                            candidate: c,
                            onUnpick: () => onUnpick(c.photographerId),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpace.s3),
              EscrowNotice(text: l.chooseEscrow, maxLines: null),
            ],
          ),
        ),
        AppFooterBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton.primary(
                l.chooseInvite,
                key: const Key('choose-invite'),
                loading: state.sending,
                onPressed: liked.isEmpty || busy ? null : onSend,
              ),
              AppButton.text(
                l.chooseMore,
                key: const Key('choose-more'),
                loading: state.fetching,
                onPressed: busy ? null : onMore,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mock `.irow2`: avatar, name, tomato meta and ETA, "Bỏ chọn".
class _PickedPerson extends StatelessWidget {
  const _PickedPerson({required this.candidate, required this.onUnpick});

  final InstantCandidate candidate;
  final VoidCallback onUnpick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = candidate;
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
      child: Row(
        children: [
          AppAvatar(
            url: c.avatarUrl,
            name: c.name,
            size: AppAvatarSize.sm,
            decorative: true,
          ),
          const SizedBox(width: AppSpace.s2h),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                MetaLine(candidateMeta(l, c, sessions: false)),
              ],
            ),
          ),
          // "Bỏ chọn Minh Trí" for a screen reader.
          Semantics(
            key: Key('choose-unpick-${c.photographerId}'),
            container: true,
            button: true,
            label: l.chooseUnpickA11y(c.name),
            onTap: onUnpick,
            excludeSemantics: true,
            child: AppButton.text(
              l.chooseUnpick,
              size: AppButtonSize.xsmall,
              style: TextButton.styleFrom(foregroundColor: secondary),
              onPressed: onUnpick,
            ),
          ),
        ],
      ),
    );
  }
}

/// `#S13.02-round`: the round ended without anyone; choose again (#202:
/// with the money already held).
class _RoundEnded extends StatelessWidget {
  const _RoundEnded({
    required this.fetching,
    required this.onMore,
    this.unavailable,
  });

  final bool fetching;
  final VoidCallback onMore;

  /// Everyone chosen was busy, so nobody was invited: the banner says so
  /// instead of "Chưa ai nhận".
  final List<String>? unavailable;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s2,
              AppSpace.s4,
              AppSpace.s4,
            ),
            child: Column(
              children: [
                Semantics(
                  key: const Key('choose-round-banner'),
                  liveRegion: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dark ? AppColorsDark.glass : AppColors.glass,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s3),
                      child: Row(
                        children: [
                          AppIcon(
                            AppIcons.hourglass,
                            size: AppIconSize.sm,
                            color: secondary,
                          ),
                          const SizedBox(width: AppSpace.s2),
                          Expanded(
                            child: Text(switch (unavailable) {
                              final names? => l.chooseUnavailable(
                                names.join(', '),
                              ),
                              null => l.chooseRoundEnded,
                            }, style: theme.textTheme.bodySmall),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                const Expanded(child: _EmptyDeck()),
              ],
            ),
          ),
        ),
        AppFooterBar(
          child: AppButton.primary(
            l.chooseMore,
            key: const Key('choose-more'),
            loading: fetching,
            onPressed: fetching ? null : onMore,
          ),
        ),
      ],
    );
  }
}

/// Mock `.swipe` with only `.b2` / `.b3`: the deck, empty.
class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget card(double dy, double scale, double opacity) => Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: scheme.outlineVariant),
            ),
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [card(24, 0.88, 0.3), card(12, 0.94, 0.55)],
      ),
    );
  }
}

/// `#S13.02-empty`: nobody around before any invite; nothing was paid.
class _Empty extends StatelessWidget {
  const _Empty({
    required this.fetching,
    required this.onRetry,
    required this.onBookNormally,
  });

  final bool fetching;
  final VoidCallback onRetry;
  final VoidCallback onBookNormally;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  AppIcons.personSearch,
                  size: 40,
                  color: dark
                      ? AppColorsDark.foregroundSecondary
                      : AppColors.foregroundSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            Text(
              l.chooseEmptyTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s2),
            Text(
              l.chooseEmptyBody,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.s4),
            AppButton.primary(
              l.chooseEmptyRetry,
              key: const Key('choose-retry'),
              size: AppButtonSize.small,
              loading: fetching,
              onPressed: fetching ? null : onRetry,
            ),
            AppButton.outline(
              l.instantBookNormally,
              key: const Key('choose-book-normally'),
              size: AppButtonSize.small,
              onPressed: onBookNormally,
            ),
          ],
        ),
      ),
    );
  }
}
