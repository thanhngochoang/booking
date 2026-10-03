// lib/features/booking/steps/review_step.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
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
    final (:deposit, :remaining) = depositFor(price);

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
                      MoneyBreakdown.skeleton(lines: 3),
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
                      placeName: state.placeName,
                    );

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BookingCard(data: summary),
                        const SizedBox(height: AppSpace.s3),
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
                            MoneyLine(
                              label: l10n.bookDepositToday,
                              vnd: deposit,
                              style: MoneyLineStyle.strong,
                            ),
                            MoneyLine(
                              label: l10n.bookRemaining,
                              vnd: remaining,
                              style: MoneyLineStyle.muted,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s3),
                        EscrowNotice(text: l10n.escrowNoticeDeposit),
                        const SizedBox(height: AppSpace.s3),
                        Text(
                          l10n.bookPolicy,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        ProviderPicker(
                          value: state.provider,
                          onChanged: controller.setProvider,
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
                l10n.bookPay(formatMoney(deposit)),
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
