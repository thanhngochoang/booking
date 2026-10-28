// lib/features/job_market/job_photographer_detail.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_card_data_of.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/awards/my_awards_controller.dart';
import 'package:photobooking/features/job_market/quote_sheet.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class JobPhotographerDetail extends ConsumerStatefulWidget {
  const JobPhotographerDetail({
    super.key,
    required this.job,
    this.openQuote = false,
  });

  final Job job;
  final bool openQuote;

  @override
  ConsumerState<JobPhotographerDetail> createState() =>
      _JobPhotographerDetailState();
}

class _JobPhotographerDetailState extends ConsumerState<JobPhotographerDetail> {
  bool _recordedView = false;
  bool _markedInvite = false;
  bool _quoteOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordViewAndMarkInvite();
      if (widget.openQuote && !_quoteOpened) {
        _quoteOpened = true;
        _openQuoteSheet();
      }
    });
  }

  void _recordViewAndMarkInvite() {
    final repo = ref.read(jobRepositoryProvider);
    if (!_recordedView) {
      _recordedView = true;
      repo.recordView(widget.job.id);
    }
    if (!_markedInvite) {
      _markedInvite = true;
      repo.markInviteSeen(widget.job.id);
    }
  }

  void _openQuoteSheet([Quote? quote]) {
    showQuoteSheet(
      context,
      job: widget.job,
      initialQuote: quote,
    );
  }

  Future<void> _withdrawQuote(Quote quote) async {
    final l = context.l10n;
    final repo = ref.read(jobRepositoryProvider);

    // If job has active checkout
    final now = ref.read(clockProvider)();
    if (widget.job.checkout != null &&
        widget.job.checkout!.expiresAt.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.quoteErrInCheckout)),
      );
      return;
    }

    final confirmed = await showConfirmSheet(
      context,
      title: l.jobWithdrawTitle,
      body: l.jobWithdrawBody,
      confirmLabel: l.jobWithdraw,
      keepLabel: l.actionCancel,
      danger: true,
      onConfirm: () async {
        await repo.withdrawQuote(widget.job.id);
      },
    );

    if (confirmed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.jobWithdrawnToast)),
      );
    }
  }

  Future<void> _openChat() async {
    final repo = ref.read(jobRepositoryProvider);
    try {
      final chatId = await repo.openInquiry(widget.job.id);
      if (mounted) {
        context.push('/chat/$chatId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _viewReferencePhoto(int index) {
    final urls = widget.job.references.map((r) => r.url).toList();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SimplePhotoViewer(
          urls: urls,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final now = ref.watch(clockProvider)();
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final myProfile = ref.watch(photographerProfileProvider(uid)).value?.summary;
    final myQuoteAsync = ref.watch(myQuoteProvider(widget.job.id));
    final myQuote = myQuoteAsync.value;

    final job = widget.job;
    final specialty = specialtyLabel(job.specialtyId);
    final isClosed = job.status != JobStatus.open || !now.isBefore(job.quoteDeadline);

    // Provider lock check (artist-only for individual)
    final isIndividual = myProfile?.providerType == ProviderType.individual;
    final isArtistOnly = job.allowedProviders == AllowedProviders.artist;
    final isLockedArtist = isArtistOnly && isIndividual;

    // Day availability check
    final availability = ref.watch(availabilityLookupProvider);
    final dayKey = job.schedule.day ?? job.dayFrom;
    final dayAvailabilityFuture = availability.on(dayKey, [uid]);

    return ScreenCode(
      ScreenCodes.jobDetailForPhotographer,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('job-back-button'),
            icon: const AppIcon(AppIcons.back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: const [
            // Bookmark and more (...) hidden per spec (S19)
          ],
        ),
        body: FutureBuilder<Map<String, DayAvailability>>(
          future: dayAvailabilityFuture,
          builder: (context, snap) {
            final dayState = snap.data?[uid];
            final isDayBooked = dayState == DayAvailability.booked;
            final isDayPending = dayState == DayAvailability.pending;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag row: specialty, "Bạn được mời", FitPill
                        Wrap(
                          spacing: AppSpace.s1,
                          runSpacing: AppSpace.s1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: dark ? AppColorsDark.glass : AppColors.glass,
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Text(
                                specialty,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: dark ? AppColorsDark.foreground : AppColors.foreground,
                                ),
                              ),
                            ),
                            if (myQuote?.invited == true ||
                                job.inviteCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  'Bạn được mời',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: dark
                                        ? AppColorsDark.primary
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            if (myQuote != null && myQuote.fit > 0)
                              FitPill(percent: myQuote.fit)
                            else
                              const FitPill(percent: 85),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s2),

                        // Fraunces 21 title
                        Text(
                          job.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFamily: 'Fraunces',
                            fontWeight: FontWeight.w600,
                            fontSize: 21,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s3),

                        // Poster row: avatar, name, "Đã thuê {n} lần · SĐT đã xác minh"
                        Row(
                          children: [
                            AppAvatar(
                              name: job.customer.name,
                              url: job.customer.avatarUrl,
                              size: AppAvatarSize.md,
                            ),
                            const SizedBox(width: AppSpace.s2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.customer.name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${l.jobHirer(job.customer.hireCount)} · ${l.jobPhoneOk}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s4),

                        // Info row 1: Date with calendar status line
                        _buildInfoRow(
                          icon: AppIcons.calendarCheck,
                          title: _formatScheduleTitle(job),
                          statusLine: isDayBooked
                              ? l.jobBusy
                              : (isDayPending ? l.jobPending : l.jobFree),
                          statusColor: isDayBooked
                              ? AppColors.error
                              : (isDayPending
                                  ? AppColors.warning
                                  : AppColors.success),
                        ),
                        const SizedBox(height: AppSpace.s3),

                        // Info row 2: Area with distance and sub-line
                        _buildInfoRow(
                          icon: AppIcons.place,
                          title: _formatAreaTitle(job, myProfile, l),
                          subLine: l.jobAreaSub,
                        ),
                        const SizedBox(height: AppSpace.s3),

                        // Info row 3: Budget with wants
                        _buildInfoRow(
                          icon: AppIcons.payment,
                          title: l.jobBudgetLine(formatJobBudget(job.budget, l)),
                          subLine: l.jobWantsLine(job.wants.editedCount ?? 0, job.wants.deliveryDays ?? 7),
                        ),
                        const SizedBox(height: AppSpace.s4),

                        // Description text
                        if (job.description.isNotEmpty) ...[
                          Text(
                            job.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSpace.s3),
                        ],

                        // 3-column reference grid (tap opens photo viewer)
                        if (job.references.isNotEmpty) ...[
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: AppSpace.s2,
                              mainAxisSpacing: AppSpace.s2,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: job.references.length,
                            itemBuilder: (context, idx) {
                              final refItem = job.references[idx];
                              return InkWell(
                                onTap: () => _viewReferencePhoto(idx),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  child: NetworkPhoto(
                                    url: refItem.url,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpace.s3),
                        ],

                        // Competition info: "{n} thợ ảnh đã báo giá · còn {m} ngày"
                        Text(
                          l.jobCompetition(
                            job.quoteCount,
                            math.max(0, job.quoteDeadline.difference(now).inDays),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s4),

                        // Lock info for artist-only if locked
                        if (isLockedArtist) ...[
                          const SizedBox(height: AppSpace.s3),
                          InkWell(
                            onTap: () => context.push('/me/awards'),
                            child: Row(
                              children: [
                                const AppIcon(AppIcons.lock, size: 16, color: AppColors.warning),
                                const SizedBox(width: AppSpace.s2),
                                Expanded(
                                  child: Text(
                                    l.jobArtistLock(math.max(0, kAwardTierThreshold - (myProfile?.approvedAwardCount ?? 0))),
                                    style: const TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const AppIcon(AppIcons.chevron, size: 16, color: AppColors.warning),
                              ],
                            ),
                          ),
                        ],

                        // Quoted State (#S16.01-mine)
                        if (myQuote != null &&
                            myQuote.status != QuoteStatus.withdrawn) ...[
                          _buildMyQuoteSection(myQuote, l, theme),
                          const SizedBox(height: AppSpace.s4),
                        ],
                      ],
                    ),
                  ),
                ),

                // Footer bar
                _buildFooterBar(
                  context,
                  l,
                  myQuote,
                  isClosed,
                  isLockedArtist,
                  isDayBooked,
                  myProfile,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    String? statusLine,
    Color? statusColor,
    String? subLine,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AppIcon(icon, size: 20),
        ),
        const SizedBox(width: AppSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (statusLine != null) ...[
                const SizedBox(height: 2),
                Text(
                  statusLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (subLine != null) ...[
                const SizedBox(height: 2),
                Text(
                  subLine,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyQuoteSection(Quote quote, AppLocalizations l, ThemeData theme) {
    final isAccepted = quote.status == QuoteStatus.accepted;
    final isPending = quote.status == QuoteStatus.submitted;

    return Container(
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Báo giá của bạn · ${formatMoney(quote.terms.price, short: true)} · ${isAccepted ? l.myQuotesChosen : l.myQuotesPending}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAccepted
                          ? l.jobChosen
                          : 'Đang chờ khách phản hồi',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isAccepted
                            ? AppColors.success
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPending)
                TextButton(
                  key: const Key('job-withdraw-quote-button'),
                  onPressed: () => _withdrawQuote(quote),
                  child: Text(
                    l.jobWithdraw,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (isAccepted && quote.bookingId != null) ...[
            const SizedBox(height: AppSpace.s2),
            AppButton.primary(
              l.jobOpenShoot,
              key: const Key('job-open-shoot-button'),
              onPressed: () => context.push('/b/${quote.bookingId}'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooterBar(
    BuildContext context,
    AppLocalizations l,
    Quote? quote,
    bool isClosed,
    bool isLockedArtist,
    bool isDayBooked,
    PhotographerSummary? myProfile,
  ) {
    // Determine primary action button
    Widget primaryButton;

    if (isClosed) {
      primaryButton = AppButton.primary(
        l.jobClosedNotice,
        key: const Key('job-primary-action'),
        onPressed: null,
      );
    } else if (isLockedArtist) {
      primaryButton = AppButton.primary(
        l.jobArtistLockButton,
        key: const Key('job-primary-action'),
        onPressed: null,
      );
    } else if (isDayBooked && (quote == null || quote.status == QuoteStatus.withdrawn)) {
      primaryButton = AppButton.primary(
        l.jobDayBusy,
        key: const Key('job-primary-action'),
        onPressed: null,
      );
    } else if (quote != null && quote.status == QuoteStatus.submitted) {
      primaryButton = AppButton.primary(
        l.jobEditQuote,
        key: const Key('job-primary-action'),
        onPressed: () => _openQuoteSheet(quote),
      );
    } else {
      primaryButton = AppButton.primary(
        l.jobQuote,
        key: const Key('job-primary-action'),
        onPressed: () => _openQuoteSheet(quote),
      );
    }

    return AppFooterBar(
      child: Row(
        children: [
          IconButton(
            key: const Key('job-ask-customer-button'),
            tooltip: l.jobAsk,
            icon: const AppIcon(AppIcons.chat),
            onPressed: _openChat,
          ),
          const SizedBox(width: AppSpace.s2),
          Expanded(child: primaryButton),
        ],
      ),
    );
  }

  String _formatScheduleTitle(Job job) {
    if (job.schedule.kind == ScheduleKind.flexible) {
      return '${job.dayFrom} – ${job.dayTo} · ${job.schedule.durationMinutes} phút';
    }
    final day = job.schedule.day ?? job.dayFrom;
    final start = job.schedule.start ?? '';
    final end = job.schedule.end ?? '';
    final hours = job.schedule.durationMinutes ~/ 60;
    return '$day · $start–$end · $hours giờ';
  }

  String _formatAreaTitle(
    Job job,
    PhotographerSummary? profile,
    AppLocalizations l,
  ) {
    final areaName = job.area.name;
    final district = areaName.split(',').first.trim();
    if (profile?.lat != null && profile?.lng != null) {
      final km = haversineKm(
        profile!.lat!,
        profile.lng!,
        job.area.lat,
        job.area.lng,
      );
      final kmStr = (km < 10) ? km.toStringAsFixed(1) : km.toStringAsFixed(0);
      return l.jobAreaLine(district, kmStr);
    }
    return areaName;
  }
}

class _SimplePhotoViewer extends StatefulWidget {
  const _SimplePhotoViewer({
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<_SimplePhotoViewer> createState() => _SimplePhotoViewerState();
}

class _SimplePhotoViewerState extends State<_SimplePhotoViewer> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.urls.length,
        itemBuilder: (context, idx) {
          return Center(
            child: InteractiveViewer(
              child: NetworkPhoto(
                url: widget.urls[idx],
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
