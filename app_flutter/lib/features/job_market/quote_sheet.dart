// lib/features/job_market/quote_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/album/album.dart';
import 'package:photobooking/data/album/album_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_card_data_of.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/features/job_market/quote_sheet_controller.dart';

Future<bool?> showQuoteSheet(
  BuildContext context, {
  required Job job,
  Quote? initialQuote,
}) {
  return showAppSheet<bool>(
    context,
    isDismissible: true,
    enableDrag: true,
    builder: (ctx) => QuoteSheet(
      job: job,
      initialQuote: initialQuote,
    ),
  );
}

class QuoteSheet extends ConsumerStatefulWidget {
  const QuoteSheet({
    super.key,
    required this.job,
    this.initialQuote,
  });

  final Job job;
  final Quote? initialQuote;

  @override
  ConsumerState<QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends ConsumerState<QuoteSheet> {
  late final TextEditingController _priceController;
  late final TextEditingController _messageController;
  late final TextEditingController _editedController;
  late final TextEditingController _deliveryController;
  late final TextEditingController _revisionsController;

  @override
  void initState() {
    super.initState();
    final quote = widget.initialQuote;
    _priceController = TextEditingController(
      text: quote != null && quote.terms.price > 0 ? quote.terms.price.toString() : '',
    );
    _messageController = TextEditingController(text: quote?.message ?? '');
    _editedController = TextEditingController(
      text: quote != null ? quote.terms.editedCount.toString() : '0',
    );
    _deliveryController = TextEditingController(
      text: quote != null ? quote.terms.deliveryDays.toString() : '7',
    );
    _revisionsController = TextEditingController(
      text: quote != null ? quote.terms.revisions.toString() : '1',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (quote != null) {
        ref.read(quoteSheetControllerProvider(widget.job.id).notifier).initFromQuote(quote);
      }
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    _editedController.dispose();
    _deliveryController.dispose();
    _revisionsController.dispose();
    super.dispose();
  }

  Future<bool> _handlePop() async {
    final state = ref.read(quoteSheetControllerProvider(widget.job.id));
    if (!state.isDirty) return true;
    final l = context.l10n;
    final discard = await showConfirmSheet(
      context,
      title: l.quoteDiscardTitle,
      body: '',
      confirmLabel: l.quoteDiscard,
      keepLabel: l.quoteKeep,
      danger: true,
    );
    return discard;
  }

  void _pickPackage(List<ServicePackage> packages) {
    final l = context.l10n;
    final notifier = ref.read(quoteSheetControllerProvider(widget.job.id).notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(l.quoteBasedOnNone),
              onTap: () {
                notifier.clearPackage();
                Navigator.pop(ctx);
              },
            ),
            for (final pkg in packages.where((p) => p.active))
              ListTile(
                title: Text(pkg.name),
                subtitle: Text(formatMoney(pkg.priceVnd)),
                onTap: () {
                  notifier.applyPackage(pkg);
                  _priceController.text = pkg.priceVnd.toString();
                  if (pkg.editedCount != null) {
                    _editedController.text = pkg.editedCount.toString();
                  }
                  if (pkg.deliveryDays != null) {
                    _deliveryController.text = pkg.deliveryDays.toString();
                  }
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _pickAlbum(List<AlbumSummary> albums) {
    final l = context.l10n;
    final notifier = ref.read(quoteSheetControllerProvider(widget.job.id).notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(l.quoteAlbumNone),
              onTap: () {
                notifier.setAlbumId(null);
                Navigator.pop(ctx);
              },
            ),
            for (final album in albums.where((a) => a.mediaCount > 0))
              ListTile(
                title: Text(album.title),
                subtitle: Text(l.quoteAlbumValue(album.title, album.mediaCount)),
                onTap: () {
                  notifier.setAlbumId(album.id);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProposalDate(BuildContext context) async {
    final job = widget.job;
    final l = context.l10n;
    final notifier = ref.read(quoteSheetControllerProvider(job.id).notifier);
    final availability = ref.read(availabilityLookupProvider);

    DateTime firstDate = DateTime.tryParse(job.dayFrom) ?? ref.read(clockProvider)();
    DateTime lastDate = DateTime.tryParse(job.dayTo) ?? firstDate.add(const Duration(days: 30));
    if (lastDate.isBefore(firstDate)) lastDate = firstDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (day) {
        return true;
      },
    );

    if (pickedDate == null || !mounted) return;

    final dayKey = vnDateKey(pickedDate);
    final pMap = await availability.on(dayKey, [job.customerId]);
    if (!context.mounted) return;
    if (pMap.values.any((s) => s == DayAvailability.booked)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.quoteErrDayTaken)),
      );
      return;
    }

    final start = job.schedule.start ?? '09:00';
    final duration = job.schedule.durationMinutes;
    final parts = start.split(':');
    final startMins = (int.tryParse(parts[0]) ?? 9) * 60 + (parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0);
    final endMins = startMins + duration;
    final endH = (endMins ~/ 60) % 24;
    final endM = endMins % 60;
    final end = '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';

    notifier.setProposal(QuoteProposal(
      day: dayKey,
      start: start,
      end: end,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(quoteSheetControllerProvider(widget.job.id));
    final notifier = ref.read(quoteSheetControllerProvider(widget.job.id).notifier);

    final packagesAsync = ref.watch(myPackagesProvider);
    final packages = packagesAsync.value ?? const <ServicePackage>[];

    final albumsAsync = ref.watch(myAlbumsProvider);
    final albums = (albumsAsync.value ?? const <AlbumSummary>[])
        .where((a) => a.mediaCount > 0)
        .toList();

    final selectedPkg = state.basedOnServiceId != null
        ? packages.where((p) => p.id == state.basedOnServiceId).firstOrNull
        : null;

    final selectedAlbum = state.albumId != null
        ? albums.where((a) => a.id == state.albumId).firstOrNull
        : null;

    final budgetStr = formatJobBudget(widget.job.budget, l);

    final milestones = state.milestones;
    final milestoneLine = l.quoteMilestones(
      formatMoney(milestones.shoot),
      formatMoney(milestones.delivery),
    );

    ref.listen<QuoteSheetState>(quoteSheetControllerProvider(widget.job.id), (_, next) {
      if (next.generalError != null) {
        final text = switch (next.generalError) {
          'quoteErrLimit' => l.quoteErrLimit,
          'quoteErrDayTaken' => l.quoteErrDayTaken,
          'quoteErrNotEligible' => l.quoteErrNotEligible,
          'quoteErrInCheckout' => l.quoteErrInCheckout,
          'quoteNotAccepting' => l.quoteNotAccepting,
          'quoteErrClosed' => l.quoteErrClosed,
          _ => next.generalError!,
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(text)));
      }
    });

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldClose = await _handlePop();
        if (!context.mounted) return;
        if (shouldClose) {
          Navigator.of(context).pop();
        }
      },
      child: ScreenCode(
        ScreenCodes.submitQuote,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row: Title + Budget
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state.isEditing ? l.jobEditQuote : l.quoteSheetTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    l.quoteSheetBudget(budgetStr),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s3),

              // Package row: Dựa trên gói · tuỳ chọn
              InkWell(
                key: const Key('quote-package-selector'),
                onTap: () => _pickPackage(packages),
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.quoteBasedOn,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selectedPkg != null
                                  ? '${selectedPkg.name} · ${formatMoney(selectedPkg.priceVnd)}'
                                  : l.quoteBasedOnNone,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const AppIcon(AppIcons.chevron, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s3),

              // Flexible job proposal picker
              if (widget.job.schedule.kind == ScheduleKind.flexible) ...[
                InkWell(
                  key: const Key('quote-proposal-picker'),
                  onTap: () => _pickProposalDate(context),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: state.errors.containsKey('proposal')
                            ? theme.colorScheme.error
                            : theme.colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.quoteProposal,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                state.proposal != null
                                    ? '${state.proposal!.day} · ${state.proposal!.start}–${state.proposal!.end}'
                                    : l.quoteProposalHint(widget.job.dayFrom, widget.job.dayTo),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (state.errors.containsKey('proposal')) ...[
                                const SizedBox(height: 2),
                                Text(
                                  l.quoteErrProposal,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const AppIcon(AppIcons.chevron, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s3),
              ],

              // Price input (numeric keyboard, required > 0)
              TextField(
                key: const Key('quote-price-input'),
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (val) {
                  final p = int.tryParse(val) ?? 0;
                  notifier.setPrice(p);
                },
                decoration: InputDecoration(
                  labelText: l.quotePrice,
                  errorText: state.errors.containsKey('price') ? l.quoteErrPrice : null,
                  suffixText: '₫',
                ),
              ),
              const SizedBox(height: AppSpace.s1),

              // Live milestone preview line
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: AppSpace.s3),
                child: Text(
                  milestoneLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),

              // Deliverables row (Ảnh chỉnh, Giao trong, Sửa)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('quote-edited-input'),
                      controller: _editedController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (val) {
                        notifier.setEditedCount(int.tryParse(val) ?? 0);
                      },
                      decoration: InputDecoration(
                        labelText: l.quoteEditedField,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: TextField(
                      key: const Key('quote-delivery-input'),
                      controller: _deliveryController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (val) {
                        notifier.setDeliveryDays(int.tryParse(val) ?? 7);
                      },
                      decoration: InputDecoration(
                        labelText: l.quoteDeliveryField,
                        suffixText: 'ngày',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: TextField(
                      key: const Key('quote-revisions-input'),
                      controller: _revisionsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (val) {
                        notifier.setRevisions(int.tryParse(val) ?? 1);
                      },
                      decoration: InputDecoration(
                        labelText: l.quoteRevisionsField,
                        suffixText: 'lần',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s3),

              // Message field (20-500 chars, counter {n} / 500)
              TextField(
                key: const Key('quote-message-input'),
                controller: _messageController,
                maxLines: 4,
                maxLength: 500,
                onChanged: notifier.setMessage,
                decoration: InputDecoration(
                  labelText: l.quoteMessage,
                  alignLabelWithHint: true,
                  counterText: l.quoteMessageCount(state.message.trim().length),
                  errorText: state.errors.containsKey('message')
                      ? (state.errors['message'] == 'quoteErrContact'
                          ? l.quoteErrContact
                          : l.quoteErrMessage)
                      : null,
                ),
              ),
              const SizedBox(height: AppSpace.s2),

              // Attached album picker (optional, non-empty albums only)
              InkWell(
                key: const Key('quote-album-selector'),
                onTap: () => _pickAlbum(albums),
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.quoteAlbumField,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selectedAlbum != null
                                  ? l.quoteAlbumValue(selectedAlbum.title, selectedAlbum.mediaCount)
                                  : l.quoteAlbumNone,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const AppIcon(AppIcons.chevron, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s3),

              // Escrow info note
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIcon(AppIcons.info, size: 16),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Text(
                      l.quoteNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s4),

              // Primary submit button
              AppButton.primary(
                state.isEditing ? l.quoteSaveEdit : l.quoteSend,
                key: const Key('quote-submit-button'),
                loading: state.submitting,
                onPressed: (state.price > 0 && state.message.trim().length >= 20 && !state.submitting)
                    ? () async {
                        final ok = await notifier.submit(widget.job);
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                state.isEditing ? l.quoteSavedToast : l.quoteSentToast,
                              ),
                            ),
                          );
                          Navigator.of(context).pop(true);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: AppSpace.s4),
            ],
          ),
        ),
      ),
    );
  }
}
