// lib/features/jobs/quote_checkout_screen.dart
//
// Screen for 100% quote payment (#S15.04-pay).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/job_rules.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/features/jobs/quote_checkout_controller.dart';
import 'package:photobooking/features/payment/open_payment.dart';
import 'package:photobooking/features/payment/pay_subject.dart';

class QuoteCheckoutScreen extends ConsumerStatefulWidget {
  const QuoteCheckoutScreen({
    super.key,
    required this.jobId,
    required this.photographerId,
  });

  final String jobId;
  final String photographerId;

  @override
  ConsumerState<QuoteCheckoutScreen> createState() => _QuoteCheckoutScreenState();
}

class _QuoteCheckoutScreenState extends ConsumerState<QuoteCheckoutScreen> {
  late final TextEditingController _addressController;
  late final TextEditingController _noteController;

  QuoteCheckoutArgs get _args => QuoteCheckoutArgs(
        jobId: widget.jobId,
        photographerId: widget.photographerId,
      );

  @override
  void initState() {
    super.initState();
    final ctlState = ref.read(quoteCheckoutControllerProvider(_args));
    _addressController = TextEditingController(text: ctlState.placeName);
    _noteController = TextEditingController(text: ctlState.note);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final jobAsync = ref.watch(jobProvider(widget.jobId));
    final quotesAsync = ref.watch(jobQuotesProvider(widget.jobId));
    final checkoutState = ref.watch(quoteCheckoutControllerProvider(_args));
    final controller = ref.read(quoteCheckoutControllerProvider(_args).notifier);

    // Watch for server errors to show SnackBar or return
    ref.listen<QuoteCheckoutState>(quoteCheckoutControllerProvider(_args), (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        final err = next.error!;
        if (err.code == 'day_taken') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.quoteDayTaken)),
          );
          if (context.canPop()) {
            context.pop();
          }
        } else if (err.code == 'not_accepting_orders') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.quoteNotAccepting)),
          );
        } else if (err.code == 'blocked') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.bookingErrBlocked)),
          );
        } else if (err.field != 'place') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: ${err.code}')),
          );
        }
      }
    });

    return ScreenCode(
      ScreenCodes.applicationDetail,
      label: 'pay',
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.quotePayTitle),
        ),
        body: AsyncView<Job?>(
          value: jobAsync,
          data: (context, job) {
            if (job == null) {
              return const Center(child: Text('Không tìm thấy công việc'));
            }

            final allQuotes = quotesAsync.value ?? const [];
            final quote = allQuotes.cast<Quote?>().firstWhere(
                  (q) => q?.photographerId == widget.photographerId || q?.id == widget.photographerId,
                  orElse: () => null,
                );

            if (quote == null) {
              return const Center(child: Text('Không tìm thấy công việc'));
            }

            return _buildCheckoutBody(
              context,
              job: job,
              quote: quote,
              checkoutState: checkoutState,
              controller: controller,
            );
          },
          error: (_, err, _) => Center(child: Text('Lỗi: $err')),
        ),
      ),
    );
  }

  Widget _buildCheckoutBody(
    BuildContext context, {
    required Job job,
    required Quote quote,
    required QuoteCheckoutState checkoutState,
    required QuoteCheckoutController controller,
  }) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final p = quote.photographer;
    final price = quote.terms.price;
    final formattedPrice = formatMoney(price);

    // Format day from proposal or job schedule
    String formattedDay = '';
    if (quote.proposal.day.isNotEmpty) {
      try {
        formattedDay = formatDayMonth(DateTime.parse(quote.proposal.day));
      } catch (_) {
        formattedDay = quote.proposal.day;
      }
    } else if (job.schedule.day != null && job.schedule.day!.isNotEmpty) {
      try {
        formattedDay = formatDayMonth(DateTime.parse(job.schedule.day!));
      } catch (_) {
        formattedDay = job.schedule.day!;
      }
    }

    final startTime = quote.proposal.start.isNotEmpty
        ? quote.proposal.start
        : (job.schedule.start ?? '09:00');
    final endTime = quote.proposal.end.isNotEmpty
        ? quote.proposal.end
        : (job.schedule.end ?? '11:00');

    final summary = BookingCardData(
      photographerName: p.name,
      serviceName: job.title,
      thumbUrl: p.avatarUrl,
      day: formattedDay,
      start: startTime,
      end: endTime,
      placeName: job.area.name,
    );

    // Milestones
    final milestones = milestoneAmountsOf(price);
    final milestoneLines = [
      MilestoneLine(
        title: l.quoteM1,
        subtitle: l.quoteM1Sub,
        amountVnd: milestones.shoot,
      ),
      MilestoneLine(
        title: l.quoteM2,
        subtitle: l.quoteM2Sub(3),
        amountVnd: milestones.delivery,
      ),
    ];

    String? addressErrorText;
    if (checkoutState.fieldError != null) {
      addressErrorText = l.quotePayErrAddress;
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BookingCard(data: summary),
                const SizedBox(height: AppSpace.s4),

                // Address field (required, 3-120 chars)
                TextField(
                  key: const Key('quote-pay-address-field'),
                  controller: _addressController,
                  maxLength: 120,
                  onChanged: controller.setPlace,
                  decoration: InputDecoration(
                    labelText: l.quotePayAddress,
                    hintText: l.quotePayAddressHint,
                    helperText: l.quotePayAddressNote,
                    errorText: addressErrorText,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
                const SizedBox(height: AppSpace.s3),

                // Note field (optional)
                TextField(
                  key: const Key('quote-pay-note-field'),
                  controller: _noteController,
                  maxLines: 3,
                  maxLength: 300,
                  onChanged: controller.setNote,
                  decoration: InputDecoration(
                    labelText: l.quotePayNote,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
                const SizedBox(height: AppSpace.s4),

                // Money breakdown (100% line)
                MoneyBreakdown(
                  lines: [
                    MoneyLine(
                      label: l.quotePayLine(p.name),
                      vnd: price,
                    ),
                    MoneyLine(
                      label: l.quotePayTotal,
                      vnd: price,
                      style: MoneyLineStyle.strong,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s4),

                // Milestone summary
                MilestoneTable(lines: milestoneLines),
                const SizedBox(height: AppSpace.s3),

                // Policy note
                Text(
                  l.quotePayPolicy,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpace.s4),

                // PayMethodSelector
                PayMethodSelector(
                  value: checkoutState.method,
                  onChanged: controller.setMethod,
                  enabled: !checkoutState.submitting,
                ),
                const SizedBox(height: AppSpace.s4),
              ],
            ),
          ),
        ),

        // Pay button
        Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: AppButton.primary(
            l.quotePayButton(formattedPrice),
            key: const Key('quote-pay-submit-button'),
            loading: checkoutState.submitting,
            onPressed: checkoutState.isValid && !checkoutState.submitting
                ? () async {
                    final res = await controller.pay();
                    if (res != null && context.mounted) {
                      await openPayment(
                        context,
                        ref,
                        subject: BookingPay(res.bookingId),
                        instructions: res.checkout.toInstructions(),
                        replace: true,
                      );
                    }
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
