// S13.08 (customer): cancel a Chụp ngay request. Every amount on the sheet is
// the server's dry run (Decision 8): the app shows the quote, it never
// computes money. The policy rows highlight the quote's rule with "(bây giờ)";
// row 3 reads the request's own arrived split. The confirmed quote goes with
// the real cancel; the server refuses (`conflict`) one that changed (#202).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// `cancelInstantRequest(dryRun: true)` for the customer.
final customerCancelQuoteProvider = FutureProvider.autoDispose
    .family<InstantCancelQuote, String>(
      (ref, id) =>
          ref.watch(instantRepositoryProvider).cancel(id, dryRun: true),
    );

/// The fixed refund of rows 1 and 2 (domain `quoteInstantCancel`); the
/// active row shows the quote's own percent instead.
const _freePercent = 100;
const _enRoutePercent = 80;

/// The quote is asked again this long after a cancel boundary
/// (`freeCancelUntil`, `lateDeadlineAt`), so the server is past it too.
const _boundarySlack = Duration(seconds: 1);

enum _Closed { kept, cancelled, refused }

/// Opens S13.08 over the request's view. Closes on "Giữ yêu cầu", back or a
/// tap outside, and after the cancel went through (the request's listener
/// then shows the closed view). A `conflict` from the server (the request
/// moved on, e.g. the shoot started) closes it with the generic error.
Future<void> showCustomerCancelSheet(
  BuildContext context,
  WidgetRef ref, {
  required InstantRequest request,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final generic = context.l10n.instantErrorGeneric;
  // A quote left by a sheet closed a moment ago is not reused.
  ref.invalidate(customerCancelQuoteProvider(request.id));
  final closed = await showAppSheet<_Closed>(
    context,
    builder: (_) => _CustomerCancelBody(request: request),
  );
  if (closed == _Closed.refused) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(generic)));
  }
}

bool _isConflict(Object e) =>
    InstantError(instantErrorCodeOf(e)).kind == InstantErrorKind.conflict;

class _CustomerCancelBody extends ConsumerStatefulWidget {
  const _CustomerCancelBody({required this.request});

  final InstantRequest request;

  @override
  ConsumerState<_CustomerCancelBody> createState() =>
      _CustomerCancelBodyState();
}

class _CustomerCancelBodyState extends ConsumerState<_CustomerCancelBody> {
  bool _running = false;
  bool _closing = false;
  String? _error;
  Timer? _boundary;

  /// The latest request seen (status and cancel boundaries).
  late InstantRequest _request = widget.request;

  String get _id => widget.request.id;

  @override
  void initState() {
    super.initState();
    _scheduleBoundary();
  }

  @override
  void dispose() {
    _boundary?.cancel();
    super.dispose();
  }

  void _close(_Closed how) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(how);
  }

  /// Asks the server again; not while the real cancel runs.
  void _requote() {
    if (_running || _closing || !mounted) return;
    setState(() => _error = null);
    ref.invalidate(customerCancelQuoteProvider(_id));
  }

  /// The rule changes when the free window ends and at the late deadline:
  /// one timer for the next of them still ahead.
  void _scheduleBoundary() {
    _boundary?.cancel();
    _boundary = null;
    final now = ref.read(clockProvider)();
    DateTime? next;
    for (final d in [_request.freeCancelUntil, _request.lateDeadlineAt]) {
      if (d != null && d.isAfter(now) && (next == null || d.isBefore(next))) {
        next = d;
      }
    }
    if (next == null) return;
    _boundary = Timer(next.difference(now) + _boundarySlack, () {
      _requote();
      if (mounted) _scheduleBoundary();
    });
  }

  Future<void> _confirm() async {
    if (_running || _closing) return;
    final l = context.l10n;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      // The quote on screen goes with the cancel: if the server's changed in
      // between (a window ended), it answers `conflict` and nothing moves.
      final shown = ref.read(customerCancelQuoteProvider(_id)).value;
      await ref
          .read(instantRepositoryProvider)
          .cancel(_id, dryRun: false, expected: shown);
      if (!mounted) return;
      _close(_Closed.cancelled);
    } on Object catch (e) {
      if (!mounted) return;
      if (_isConflict(e)) {
        _close(_Closed.refused);
        return;
      }
      // The request is still open: the sheet stays with the reason.
      setState(() {
        _running = false;
        _error = instantErrorText(l, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final provider = customerCancelQuoteProvider(_id);
    final quote = ref.watch(provider);
    // The request moved on (e.g. the photographer is on the way): new quote.
    ref.listen(instantRequestProvider(_id).select((v) => v.value), (_, next) {
      if (next == null) return;
      final moved = next.status != _request.status;
      _request = next;
      _scheduleBoundary();
      if (moved) _requote();
    });
    ref.listen(provider, (_, next) {
      final error = next.error;
      if (!next.isLoading && error != null && _isConflict(error)) {
        _close(_Closed.refused);
      }
    });
    // Only a fresh quote may be confirmed: never one being replaced.
    final ready = quote.hasValue && !quote.isLoading && !quote.hasError;
    return ScreenCode(
      ScreenCodes.instantCancel,
      child: PopScope(
        canPop: !_running,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            0,
            AppSpace.s4,
            AppSpace.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.cancelInstantTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpace.s3),
              AsyncView<InstantCancelQuote>(
                value: quote,
                skeleton: (_) =>
                    AppSkeletonScope(child: PolicyTable.skeleton(rows: 3)),
                onRetry: _requote,
                data: (context, q) => _QuoteContent(
                  request: _request,
                  quote: q,
                  error: _error,
                  running: _running,
                  onConfirm: ready && !_running ? _confirm : null,
                  onKeep: _running ? null : () => _close(_Closed.kept),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rows, the summary line and the two buttons for one quote.
class _QuoteContent extends StatelessWidget {
  const _QuoteContent({
    required this.request,
    required this.quote,
    required this.error,
    required this.running,
    required this.onConfirm,
    required this.onKeep,
  });

  final InstantRequest request;
  final InstantCancelQuote quote;
  final String? error;
  final bool running;
  final VoidCallback? onConfirm;
  final VoidCallback? onKeep;

  /// Decision 8: the mock row of the rule; none for `unpaid` (no money
  /// moves, so no refund rule applies) or a rule the sheet does not show.
  static int _rowOf(InstantCancelRule? rule) => switch (rule) {
    InstantCancelRule.fullRefund ||
    InstantCancelRule.freeWindow ||
    InstantCancelRule.photographerLate => 0,
    InstantCancelRule.enRoute => 1,
    InstantCancelRule.arrived => 2,
    _ => -1,
  };

  List<PolicyRow> _rows(AppLocalizations l, int active) {
    final whens = [l.cancelRowFree, l.cancelRowEnRoute, l.cancelRowArrived];
    final percents = [
      _freePercent,
      _enRoutePercent,
      100 - request.arrivedCancelPhotographerPercent,
    ];
    return [
      for (var i = 0; i < whens.length; i++)
        PolicyRow(
          when: i == active ? l.cancelRowNow(whens[i]) : whens[i],
          outcome: l.cancelOutcome(
            i == active ? quote.refundPercent : percents[i],
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final lineStyle = theme.textTheme.bodyMedium?.copyWith(color: secondary);
    final unpaid = quote.rule == InstantCancelRule.unpaid;
    final active = _rowOf(quote.rule);
    final name = request.photographer?.name ?? '';
    final refund = formatMoney(quote.refundVnd);
    final fee = formatMoney(quote.feeVnd);
    final error = this.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PolicyTable(
          rows: _rows(l, active),
          activeIndex: active,
          whenMaxLines: 3,
        ),
        const SizedBox(height: AppSpace.s3),
        if (quote.rule == InstantCancelRule.photographerLate) ...[
          Text(l.cancelInstantLate(name), style: lineStyle),
          const SizedBox(height: AppSpace.s1),
        ],
        if (unpaid)
          Text(l.cancelInstantUnpaid, style: lineStyle)
        else if (quote.feeVnd > 0 &&
            quote.rule != InstantCancelRule.photographerLate)
          _Amounts(
            l.cancelInstantRefundFee(refund, fee, name),
            refund: refund,
            fee: fee,
            style: lineStyle,
          )
        else
          _Amounts(
            l.cancelInstantRefundAll(refund),
            refund: refund,
            style: lineStyle,
          ),
        if (error != null) ...[
          const SizedBox(height: AppSpace.s2),
          Text(
            error,
            key: const Key('customer-cancel-error'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: dark ? AppColorsDark.destructive : AppColors.destructive,
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s4),
        AppButton.danger(
          unpaid
              ? l.cancelInstantConfirmUnpaid
              : l.cancelInstantConfirm(refund),
          key: const Key('customer-cancel-confirm'),
          loading: running,
          onPressed: onConfirm,
        ),
        const SizedBox(height: AppSpace.s1),
        AppButton.text(
          l.cancelInstantKeep,
          key: const Key('customer-cancel-keep'),
          onPressed: onKeep,
        ),
      ],
    );
  }
}

/// The summary line with its amounts in tabular figures (mock `.tn`): the
/// [refund] bold, the [fee] not (mock `#S13.08`).
class _Amounts extends StatelessWidget {
  const _Amounts(this.text, {required this.refund, this.fee, this.style});

  final String text;
  final String refund;
  final String? fee;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    final strong = tabular.copyWith(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final spans = <InlineSpan>[];
    var from = 0;
    for (final (part, partStyle) in [(refund, strong), (fee, tabular)]) {
      if (part == null) continue;
      final at = text.indexOf(part, from);
      if (at < 0) continue;
      if (at > from) spans.add(TextSpan(text: text.substring(from, at)));
      spans.add(TextSpan(text: part, style: partStyle));
      from = at + part.length;
    }
    if (from < text.length) spans.add(TextSpan(text: text.substring(from)));
    return Text.rich(TextSpan(children: spans), style: style);
  }
}
