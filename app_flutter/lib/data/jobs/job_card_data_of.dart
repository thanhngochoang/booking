// lib/data/jobs/job_card_data_of.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/geo.dart';
import 'package:photobooking/core/widgets/deliverable_chips.dart';
import 'package:photobooking/core/widgets/job_card.dart';
import 'package:photobooking/core/widgets/meta_line.dart';
import 'package:photobooking/core/widgets/provider_mark.dart';
import 'package:photobooking/core/widgets/quote_card.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/jobs/job.dart';
import 'package:photobooking/data/jobs/job_rules.dart';
import 'package:photobooking/data/jobs/quote.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/l10n/app_localizations.dart';

const int _kArtistAwardThreshold = 3;

/// Formats date and time schedule for meta line:
/// Fixed: "CN 20/10" or "CN 20/10 · 07:00"
/// Flexible: "20/10–25/10"
String _formatJobScheduleDate(JobSchedule schedule) {
  if (schedule.kind == ScheduleKind.fixed) {
    if (schedule.day != null && schedule.day!.isNotEmpty) {
      try {
        final parsed = DateTime.parse(schedule.day!);
        return formatDay(parsed);
      } catch (_) {
        return schedule.day!;
      }
    }
    return '';
  } else {
    String fromStr = schedule.from ?? '';
    String toStr = schedule.to ?? '';
    try {
      if (fromStr.isNotEmpty) {
        fromStr = formatDayMonth(DateTime.parse(fromStr));
      }
      if (toStr.isNotEmpty) {
        toStr = formatDayMonth(DateTime.parse(toStr));
      }
    } catch (_) {}
    if (fromStr.isNotEmpty && toStr.isNotEmpty) {
      return '$fromStr–$toStr';
    } else if (fromStr.isNotEmpty) {
      return fromStr;
    }
    return '';
  }
}

String _districtOnly(String areaName) {
  final parts = areaName.split(', ');
  return parts.first.trim();
}

/// Formats budget string for display:
/// e.g. "3–5M" or "2,8M" or "Để thợ báo giá"
String formatJobBudget(JobBudget? budget, AppLocalizations l) {
  if (budget == null) {
    return l.jobOpenBudget;
  }
  if (budget.min == budget.max) {
    return formatMoney(budget.max, short: true);
  }
  var minStr = formatMoney(budget.min, short: true).replaceAll('₫', '');
  final maxStr = formatMoney(budget.max, short: true);
  if (minStr.endsWith('M') && maxStr.endsWith('M')) {
    minStr = minStr.substring(0, minStr.length - 1);
  }
  return '$minStr–$maxStr';
}

/// Formats remaining deadline into "còn {m} ngày" or "còn {h} giờ"
String? formatDeadlineLeft(DateTime deadline, DateTime now, AppLocalizations l) {
  if (!now.isBefore(deadline)) {
    return null;
  }
  final diff = deadline.difference(now);
  if (diff.inDays >= 1) {
    return l.jobLeftDays(diff.inDays);
  } else {
    final hours = math.max(1, diff.inHours);
    return l.jobLeftHours(hours);
  }
}

/// Mapper for customer job card (S15.02).
JobCardData customerJobCardOf(
  Job job,
  DateTime now,
  AppLocalizations l, {
  VoidCallback? onLinkTap,
}) {
  final specialty = specialtyLabel(job.specialtyId);
  final district = _districtOnly(job.area.name);
  final scheduleDate = _formatJobScheduleDate(job.schedule);

  switch (job.status) {
    case JobStatus.awarded:
      final providerName = job.awardedTo?.name ?? '';
      final priceStr = job.awardedTo != null
          ? formatMoney(job.awardedTo!.price, short: true)
          : '';
      final metaParts = [
        if (scheduleDate.isNotEmpty) scheduleDate,
        if (district.isNotEmpty) district,
        if (providerName.isNotEmpty) providerName,
        if (priceStr.isNotEmpty) priceStr,
      ];

      return JobCardData(
        specialtyLabel: specialty,
        title: job.title,
        metaLine: metaParts.join(' · '),
        statusLabel: l.jobStatusAwarded,
        statusTone: JobCardStatusTone.accepted,
        linkLabel: l.jobOpenBooking,
        onLinkTap: onLinkTap,
      );

    case JobStatus.closed:
    case JobStatus.expired:
      final metaLine = l.jobExpiredNoPick(job.quoteCount);
      final statusLabel = job.status == JobStatus.closed
          ? l.jobStatusClosed
          : l.jobStatusExpired;

      return JobCardData(
        specialtyLabel: specialty,
        title: job.title,
        metaLine: metaLine,
        statusLabel: statusLabel,
        statusTone: JobCardStatusTone.neutral,
        dimmed: true,
        linkLabel: l.jobRepost,
        onLinkTap: onLinkTap,
      );

    case JobStatus.open:
    case JobStatus.draft:
      final budgetStr = formatJobBudget(job.budget, l);
      final metaParts = [
        if (scheduleDate.isNotEmpty) scheduleDate,
        if (district.isNotEmpty) district,
        budgetStr,
      ];

      String? footLeft;
      if (job.quoteCount > 0) {
        if (job.newQuoteCount > 0) {
          footLeft = '${l.jobQuotes(job.quoteCount)} · ${l.jobQuotesNew(job.newQuoteCount)}';
        } else {
          footLeft = l.jobQuotes(job.quoteCount);
        }
      }

      final footRight = formatDeadlineLeft(job.quoteDeadline, now, l);
      final avatarUrls = job.recentQuoters.map((q) => q.avatarUrl).whereType<String>().toList();

      return JobCardData(
        specialtyLabel: specialty,
        title: job.title,
        metaLine: metaParts.join(' · '),
        statusLabel: l.jobStatusOpen,
        statusTone: JobCardStatusTone.waiting,
        footLeft: footLeft,
        footRight: footRight,
        avatarUrls: avatarUrls,
      );
  }
}

/// Mapper for photographer job card (S16.02).
JobCardData photographerJobCardOf(
  OpenJobItem item,
  PhotographerSummary me,
  DateTime now,
  AppLocalizations l,
) {
  final job = item.job;
  final specialty = specialtyLabel(job.specialtyId);
  final district = _districtOnly(job.area.name);
  final scheduleDate = _formatJobScheduleDate(job.schedule);

  // Check lock
  final isLocked = item.locked ||
      (job.allowedProviders == AllowedProviders.artist &&
          me.providerType == ProviderType.individual);

  if (isLocked) {
    final k = math.max(0, _kArtistAwardThreshold - me.approvedAwardCount);
    return JobCardData(
      specialtyLabel: specialty,
      title: job.title,
      metaLine: '',
      locked: true,
      lockLabel: l.jobArtistLock(k),
      dimmed: true,
    );
  }

  // Meta line: "ngày · giờ · quận · khoảng cách"
  final metaParts = <String>[];
  if (scheduleDate.isNotEmpty) metaParts.add(scheduleDate);
  if (job.schedule.start != null && job.schedule.start!.isNotEmpty) {
    metaParts.add(job.schedule.start!);
  }
  if (district.isNotEmpty) metaParts.add(district);
  if (me.lat != null && me.lng != null) {
    final km = haversineKm(me.lat!, me.lng!, job.area.lat, job.area.lng);
    metaParts.add(formatDistance(km));
  }

  final budgetStr = formatJobBudget(job.budget, l);

  // footRight: "{n} báo giá · còn {m} ngày"
  final daysLeft = deadlineLeft(job, now)?.inDays ?? 0;
  final footRight = l.jobCardMeta(job.quoteCount, daysLeft);

  return JobCardData(
    specialtyLabel: specialty,
    title: job.title,
    metaLine: metaParts.join(' · '),
    invited: item.invited,
    fitPercent: item.fit,
    budgetLabel: budgetStr,
    footRight: footRight,
  );
}

/// Mapper for quote card (S15.03).
QuoteCardData quoteCardOf(
  Quote quote,
  Job job, {
  required bool saved,
  required DateTime now,
  required AppLocalizations l,
}) {
  final p = quote.photographer;
  final mark = providerMarkOf(
    type: p.providerType,
    verified: p.verified,
    businessVerified: p.providerType == ProviderType.studio,
  );

  // Trust line parts
  final trustParts = <MetaPart>[];
  if (p.tomatoPct > 0) {
    trustParts.add(MetaPart.tomato(p.tomatoPct));
  }
  if (p.completedCount > 0) {
    trustParts.add(MetaPart.text(l.quoteTrustSessions(p.completedCount)));
  }
  if (p.providerType == ProviderType.artist && p.approvedAwardCount > 0) {
    trustParts.add(MetaPart.text(l.quoteTrustAwards(p.approvedAwardCount)));
  } else if (p.providerType == ProviderType.studio && p.studioDistrict != null) {
    trustParts.add(MetaPart.text(p.studioDistrict!));
  }

  // Price & Budget note
  final priceLabel = formatMoney(quote.terms.price, short: true);
  final fitResult = budgetFit(quote.terms.price, job.budget);
  String? budgetNote;
  bool budgetOver = false;

  if (job.budget != null) {
    if (fitResult.fit == BudgetFit.inBudget) {
      budgetNote = l.quoteInBudget;
      budgetOver = false;
    } else if (fitResult.fit == BudgetFit.over) {
      final overAmount = fitResult.over >= 1000000
          ? formatMoney(fitResult.over, short: true)
          : '${(fitResult.over / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M';
      budgetNote = l.quoteOverBudget(overAmount);
      budgetOver = true;
    }
  }

  // Deliverables
  final deliverables = <DeliverableItem>[];
  if (quote.terms.editedCount > 0) {
    deliverables.add(DeliverableItem(label: l.quoteEditedChip(quote.terms.editedCount)));
  }
  if (quote.terms.deliveryDays > 0) {
    deliverables.add(DeliverableItem(label: l.quoteDaysChip(quote.terms.deliveryDays)));
  }
  if (quote.terms.revisions > 0) {
    deliverables.add(DeliverableItem(label: l.quoteRevisionsChip(quote.terms.revisions)));
  }
  if (quote.proposal.day.isNotEmpty) {
    String dayFormatted = quote.proposal.day;
    try {
      dayFormatted = formatDayMonth(DateTime.parse(quote.proposal.day));
    } catch (_) {}
    deliverables.add(
      DeliverableItem(
        label: l.quoteFree(dayFormatted),
        positive: true,
      ),
    );
  }

  // Message first line
  String? firstLine;
  if (quote.message.isNotEmpty) {
    firstLine = quote.message.split('\n').first.trim();
  }

  return QuoteCardData(
    name: p.name,
    avatarUrl: p.avatarUrl,
    mark: mark,
    invited: quote.invited,
    trustParts: trustParts,
    priceLabel: priceLabel,
    budgetNote: budgetNote,
    budgetOver: budgetOver,
    deliverables: deliverables,
    messageFirstLine: firstLine,
    fitPercent: quote.fit > 0 ? quote.fit : null,
    saved: saved,
    withdrawn: quote.status == QuoteStatus.withdrawn,
  );
}
