// lib/features/booking/steps/review_step.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/addons/addon_format.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/entry/entry_rules.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

class ReviewStep extends ConsumerStatefulWidget {
  const ReviewStep({super.key, required this.args});
  final BookingFlowArgs args;

  @override
  ConsumerState<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends ConsumerState<ReviewStep> {
  late final TextEditingController _noteController;
  late final TextEditingController _phoneController;
  late final FocusNode _phoneFocusNode;
  bool _phoneTouched = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(bookingFlowControllerProvider(widget.args));
    _noteController = TextEditingController(text: state.note);

    final initialPhone = state.phone != null ? nationalFromE164(state.phone!) : '';
    _phoneController = TextEditingController(text: initialPhone);
    _phoneFocusNode = FocusNode();
    _phoneFocusNode.addListener(_onPhoneFocusChange);
  }

  @override
  void dispose() {
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _phoneFocusNode.dispose();
    _noteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneFocusChange() {
    if (!_phoneFocusNode.hasFocus) {
      if (!_phoneTouched) {
        setState(() => _phoneTouched = true);
      }
    }
  }

  void _onNoteChanged(String text) {
    ref.read(bookingFlowControllerProvider(widget.args).notifier).setNote(text);
  }

  void _onPhoneChanged(String text) {
    final e164 = phoneFromField(text);
    ref.read(bookingFlowControllerProvider(widget.args).notifier).setPhone(e164);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(bookingFlowControllerProvider(widget.args));
    final controller = ref.read(bookingFlowControllerProvider(widget.args).notifier);
    final profileAsync = ref.watch(photographerProfileProvider(widget.args.photographerId));
    final packagesAsync = ref.watch(profilePackagesProvider(widget.args.photographerId));

    final price = state.priceVnd ?? 0;
    // S04.03-entry: the tickets of a ticketed spot ride on the same payment.
    final spotId = state.spot?.schedule.spotId;
    final entryInfo = spotId == null || state.day == null
        ? null
        : ref.watch(
            bookingEntryInfoProvider((
              spotId: spotId,
              providerId: widget.args.photographerId,
              day: state.day!,
            )),
          );
    final sells = entryInfo != null && entryInfo.sellsOn(state.day!);
    final quote = sells
        ? quoteBookingEntry(
            event: entryInfo.event!,
            picks: entryPicksOf(state, entryInfo.event!),
            waiver: entryInfo.waiver,
          )
        : null;
    final entryVnd = quote != null && state.entryOn ? quote.amount : 0;
    final payNow = (state.payVnd ?? 0) + entryVnd;
    final addonLines = <MoneyLine>[
      for (final a in state.applicableAddons)
        if (state.picks[a.id] case final qty?)
          MoneyLine(
            label: addonLineLabel(l10n, _lineOf(a, qty)),
            vnd: a.price * qty,
          ),
    ];

    final phoneError = _phoneTouched && (phoneFromField(_phoneController.text) == null)
        ? l10n.phoneInvalid
        : null;

    final date = state.day != null ? parseDayKey(state.day!) : null;
    final formattedDay = date != null ? formatDayMonth(date) : (state.day ?? '');

    ServiceSummary? matchedPackage;
    if (packagesAsync.hasValue) {
      for (final p in packagesAsync.value!) {
        if (p.id == state.serviceId) {
          matchedPackage = p;
          break;
        }
      }
    }

    final noteLength = _noteController.text.characters.length;

    return ScreenCode(
      ScreenCodes.bookReview,
      child: AbsorbPointer(
        absorbing: state.busy,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s2,
              ),
              child: Semantics(
                header: true,
                child: Row(
                  children: [
                    Text(
                      l10n.bookReview,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '4 / 4',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                child: AsyncView<PhotographerProfile?>(
                  value: profileAsync,
                  skeleton: (_) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BookingCard.skeleton(),
                      const SizedBox(height: AppSpace.s4),
                      MoneyBreakdown.skeleton(lines: 2 + state.picks.length),
                    ],
                  ),
                  data: (context, profile) {
                    final photographerName = profile?.summary.displayName ?? '';
                    final summary = BookingSummary(
                      photographerName: photographerName,
                      serviceName: state.serviceName ?? '',
                      thumbUrl: matchedPackage?.coverUrl,
                      day: formattedDay,
                      start: state.start ?? '',
                      end: state.end ?? '',
                      // From a spot the place line reads "Tại {spot}".
                      placeName: switch (state.spot) {
                        final spot? => l10n.bookAtSpot(spot.spotName),
                        null => state.placeName,
                      },
                      extraLine: state.needsPickup
                          ? l10n.bookPickupLine(state.pickupName.trim())
                          : null,
                    );

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BookingCard(data: summary),
                        const SizedBox(height: AppSpace.s3),
                        if (quote != null) ...[
                          _EntryCard(
                            args: widget.args,
                            info: entryInfo!,
                            quote: quote,
                            providerName: photographerName,
                          ),
                          const SizedBox(height: AppSpace.s3),
                        ] else if (entryInfo?.unitPrice case final unit?) ...[
                          _OnSiteCosts(unit: unit),
                          const SizedBox(height: AppSpace.s3),
                        ],
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('book-note-field'),
                                  controller: _noteController,
                                  maxLines: 3,
                                  maxLength: kNoteMaxLength,
                                  onChanged: _onNoteChanged,
                                  decoration: InputDecoration(
                                    labelText: l10n.bookNote,
                                    hintText: l10n.bookNoteHint,
                                    counterText: '$noteLength/$kNoteMaxLength',
                                    floatingLabelBehavior: FloatingLabelBehavior.always,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpace.s2),
                              Expanded(
                                child: Focus(
                                  focusNode: _phoneFocusNode,
                                  child: PhoneField(
                                    controller: _phoneController,
                                    errorText: phoneError,
                                    onChanged: _onPhoneChanged,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        MoneyBreakdown(
                          lines: [
                            MoneyLine(
                              label: l10n.bookPackageLine(state.serviceName ?? ''),
                              vnd: price,
                            ),
                            ...addonLines,
                            if (entryVnd > 0)
                              MoneyLine(
                                label: l10n.s0403_entryLine(quote!.count),
                                vnd: entryVnd,
                              ),
                            MoneyLine(
                              label: l10n.bookDepositToday,
                              vnd: payNow,
                              style: MoneyLineStyle.strong,
                            ),
                          ],
                        ),
                        if (entryVnd > 0) ...[
                          const SizedBox(height: AppSpace.s2),
                          Text(
                            l10n.s0403_twoPayees,
                            key: const Key('book-entry-payees'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          l10n.bookPolicy,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        PayMethodSelector(
                          value: state.method,
                          onChanged: controller.setMethod,
                          enabled: !state.busy,
                        ),
                        const SizedBox(height: AppSpace.s2),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: AppButton.primary(
                l10n.bookPay(formatMoney(payNow)),
                loading: state.busy,
                onPressed: (state.canContinue && phoneError == null)
                    ? controller.submit
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The S04.03 row of a pick, shaped like the line the server will store.
BookingAddonLine _lineOf(ServiceAddon a, int qty) => BookingAddonLine(
  addonId: a.id,
  kind: a.kind,
  name: a.name,
  unit: a.unit,
  unitPrice: a.price,
  qty: qty,
  amount: a.price * qty,
);

/// S04.03-entry "Vé vào cửa · {ngày}": the switch (on by default), the
/// customer's counters per type, the photographer's fixed ticket or its
/// waiver; "Bạn và thợ được miễn vé" when nothing is left to buy; switched
/// off, "Tự mua vé tại cổng ≈ {x}".
class _EntryCard extends ConsumerWidget {
  const _EntryCard({
    required this.args,
    required this.info,
    required this.quote,
    required this.providerName,
  });

  final BookingFlowArgs args;
  final BookingEntryInfo info;
  final BookingEntryQuote quote;
  final String providerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(bookingFlowControllerProvider(args));
    final ctl = ref.read(bookingFlowControllerProvider(args).notifier);
    final e = info.event!;
    final picks = entryPicksOf(state, e);
    final day = parseDayKey(state.day!)!;
    final muted = theme.colorScheme.onSurfaceVariant;
    final customers = picks.values.fold(0, (n, q) => n + q);
    Widget row(String label, Widget trailing, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.only(top: AppSpace.s1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
          trailing,
        ],
      ),
    );
    return GlassCard(
      key: const Key('book-entry'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s3,
          AppSpace.s2,
          AppSpace.s3,
          AppSpace.s3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppIcon(AppIcons.ticket, size: 18, color: muted),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Text(
                    l10n.s0403_entryCard(formatDay(day)),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Semantics(
                  label: l10n.s0403_entrySwitch,
                  child: Switch(
                    key: const Key('book-entry-switch'),
                    value: state.entryOn,
                    onChanged: state.busy ? null : ctl.setEntryOn,
                  ),
                ),
              ],
            ),
            if (!state.entryOn)
              Text(
                l10n.s0403_entryOff(formatMoney(quote.amount)),
                key: const Key('book-entry-off'),
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              )
            else if (quote.allWaived)
              Text(
                l10n.s0403_entryWaivedAll,
                key: const Key('book-entry-waived'),
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              )
            else ...[
              for (final t in e.visibleTicketTypes)
                row(
                  l10n.s0403_entryCustomer(t.name),
                  QtyStepper(
                    keyPrefix: 'book-entry-${t.id}',
                    value: picks[t.id] ?? 0,
                    min: 0,
                    max:
                        entryTicketsPerOrder -
                        (quote.providerTicket ? 1 : 0) -
                        (customers - (picks[t.id] ?? 0)),
                    enabled: !state.busy,
                    valueLabel: l10n.ticketCount(picks[t.id] ?? 0),
                    decrementLabel: l10n.s3005_less(t.name),
                    incrementLabel: l10n.s3005_more(t.name),
                    onChanged: (n) => ctl.setEntryCount(
                      e,
                      t.id,
                      n,
                      providerTicket: quote.providerTicket,
                    ),
                  ),
                ),
              row(
                quote.providerTicket
                    ? (providerName.isEmpty
                          ? l10n.s0403_entryProvider
                          : l10n.s0403_entryProviderName(providerName))
                    : l10n.s0403_entryWaivedProvider,
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                    vertical: AppSpace.s2,
                  ),
                  child: Text(
                    quote.providerTicket ? '1' : '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                key: const Key('book-entry-provider'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A spot with reference prices only: "Chi phí tại chỗ (không qua app) ·
/// Vé vào cửa ≈ {x} × 2 (bạn và thợ)".
class _OnSiteCosts extends StatelessWidget {
  const _OnSiteCosts({required this.unit});

  final int unit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return GlassCard(
      key: const Key('book-entry-onsite'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.s0403_onSite,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpace.s1),
            Text(
              l10n.s0403_onSiteTickets(formatMoney(unit)),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
