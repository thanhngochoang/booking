// lib/features/organizer/organizer_controller.dart
//
// Shared pieces of the S30 organizer screens (#223 Task 8): running a
// callable and mapping its refusal, the S30.04 form rules (mirrors of the
// domain's `validateEntryEvent` and the entry edit rules, so the screen can
// say what is wrong before the server does), and the small labels several
// screens build.
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/organizer/organizer_repository.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Runs organizer callables for the screens.
final organizerActionsProvider = Provider<OrganizerActions>(
  (ref) => OrganizerActions(ref.watch(organizerRepositoryProvider)),
);

class OrganizerActions {
  const OrganizerActions(this.repo);

  final OrganizerRepository repo;

  /// Runs [call]; null when it went through, else the refusal's code
  /// (`OrganizerError.code`, `network` or `unknown`).
  Future<String?> run(Future<void> Function(OrganizerRepository r) call) async {
    try {
      await call(repo);
      return null;
    } catch (e) {
      return organizerErrorCodeOf(e);
    }
  }
}

/// The fallback line for a refusal a screen has no own copy for.
String organizerErrorText(AppLocalizations l, String code) =>
    code == 'network' ? l.s30_network : l.s30_error;

// ---- S30.01 -----------------------------------------------------------------

const organizerNameMin = 3;
const organizerNameMax = 60;
const organizerBioMax = 300;

/// `ORGANIZER_NAME_MIN..MAX` graphemes after trimming.
bool organizerNameOk(String name) {
  final n = name.trim().characters.length;
  return n >= organizerNameMin && n <= organizerNameMax;
}

/// `0912 ••• 678` parts of an E.164 number; null when too short to mask.
({String head, String tail})? maskedPhoneParts(String e164) {
  final d = '0${nationalDigits(e164)}';
  if (d.length < 9) return null;
  return (head: d.substring(0, 4), tail: d.substring(d.length - 3));
}

// ---- S30.02 -----------------------------------------------------------------

/// Proofs per claim (`proofPaths` 1–3).
const claimProofsMax = 3;

/// `1,2 MB` / `850 KB`.
String fileSizeLabel(int bytes) {
  if (bytes >= 1024 * 1024) {
    final mb = (bytes / (1024 * 1024) * 10).round() / 10;
    final text = mb == mb.roundToDouble()
        ? mb.round().toString()
        : mb.toStringAsFixed(1).replaceAll('.', ',');
    return '$text MB';
  }
  return '${(bytes / 1024).ceil()} KB';
}

// ---- S30.03 -----------------------------------------------------------------

const accessFeesMax = 6;
const accessNoteMax = 120;
const residentsMax = 50;

/// `HH:mm` (00:00–23:59).
bool isHm(String s) => RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s);

/// The waiver line of a resident row ("Miễn vé thợ và khách · tối đa 4
/// khách") and its end ("tới 31/12", "không hết hạn", "đã hết hạn").
({String waiver, String until}) residentLines(
  AppLocalizations l,
  Resident r,
  String today,
) {
  final base = switch ((r.waivesProvider, r.waivesGuests)) {
    (true, true) => l.s3003_residentBoth,
    (true, false) => l.s3003_residentProviderOnly,
    (false, true) => l.s3003_residentGuestsOnly,
    (false, false) => l.s3003_residentNone,
  };
  final max = r.waivesGuests ? r.maxGuests : null;
  final waiver = max == null ? base : '$base · ${l.s3003_residentMax(max)}';
  final end = r.validUntil;
  final endDate = end == null ? null : parseDayKey(end);
  final until = end == null || endDate == null
      ? l.s3003_residentNoEnd
      : end.compareTo(today) < 0
      ? l.s3003_residentExpired
      : l.s3003_residentUntil(formatDayMonth(endDate));
  return (waiver: waiver, until: until);
}

/// `dd/MM` of a `yyyy-MM-dd` day (the key itself if malformed).
String dayLabel(String day) {
  final d = parseDayKey(day);
  return d == null ? day : formatDayMonth(d);
}

/// `T5 12/11` of a `yyyy-MM-dd` day.
String dayChipLabel(String day) {
  final d = parseDayKey(day);
  return d == null ? day : formatDay(d);
}

String addDays(String day, int n) {
  final d = parseDayKey(day);
  return d == null ? day : dayKeyOf(d.add(Duration(days: n)));
}

// ---- S30.04 -----------------------------------------------------------------

const entryRangeMaxDays = 180;
const entryClosedDaysMax = 30;
const ticketTypesMax = 6;
const ticketTypeNameMin = 3;
const ticketTypeNameMax = 40;

enum EntryField { range, hours, capacity, types, closedDays }

enum EntryRule {
  rangeTooLong,
  startPast,
  endBeforeStart,
  timeFormat,
  hoursInvalid,
  capacityInvalid,
  capacityBelowSold,
  typesEmpty,
  typesMax,
  closedDaysMax,
}

/// What S30.04 holds while it is edited (text fields as typed).
class EntryForm {
  const EntryForm({
    required this.name,
    required this.startDay,
    required this.endDay,
    required this.open,
    required this.close,
    required this.capacity,
    required this.types,
    this.closedDays = const [],
  });

  final String name;
  final String startDay;
  final String endDay;
  final String open;
  final String close;

  /// Empty = no daily cap.
  final String capacity;
  final List<EntryTicketType> types;
  final List<String> closedDays;
}

/// The daily cap typed in [text]: `(ok: true, value: null)` when empty.
({bool ok, int? value}) capacityOf(String text) {
  final t = text.trim();
  if (t.isEmpty) return (ok: true, value: null);
  final n = int.tryParse(t);
  return n == null || n < 1 ? (ok: false, value: null) : (ok: true, value: n);
}

/// Ticket type names are 3–40 graphemes.
bool ticketTypeNameOk(String name) {
  final n = name.trim().characters.length;
  return n >= ticketTypeNameMin && n <= ticketTypeNameMax;
}

/// An integer VND price > 0, or null.
int? ticketTypePriceOf(String text) {
  final v = parseVnd(text);
  return v == null || v <= 0 ? null : v;
}

/// The first future day whose tickets pass [cap], earliest first.
({String day, int sold})? firstDayOverCapacity(
  Map<String, int> soldPerDay,
  int cap,
) {
  final days = soldPerDay.keys.toList()..sort();
  for (final d in days) {
    final n = soldPerDay[d]!;
    if (n > cap) return (day: d, sold: n);
  }
  return null;
}

/// The S30.04 rules, one refusal per field (the first that applies). When
/// [editing], a past start is the stored one (the server accepts it) and the
/// daily cap may not go under a day's tickets ([soldPerDay]).
Map<EntryField, EntryRule> entryFormErrors(
  EntryForm f, {
  required String today,
  bool editing = false,
  Map<String, int> soldPerDay = const {},
}) {
  final out = <EntryField, EntryRule>{};
  final start = parseDayKey(f.startDay);
  final end = parseDayKey(f.endDay);
  if (start == null || end == null) {
    out[EntryField.range] = EntryRule.endBeforeStart;
  } else if (!editing && f.startDay.compareTo(today) < 0) {
    out[EntryField.range] = EntryRule.startPast;
  } else if (end.isBefore(start)) {
    out[EntryField.range] = EntryRule.endBeforeStart;
  } else if (end.difference(start).inDays + 1 > entryRangeMaxDays) {
    out[EntryField.range] = EntryRule.rangeTooLong;
  }
  if (!isHm(f.open) || !isHm(f.close)) {
    out[EntryField.hours] = EntryRule.timeFormat;
  } else if (f.close.compareTo(f.open) <= 0) {
    out[EntryField.hours] = EntryRule.hoursInvalid;
  }
  final cap = capacityOf(f.capacity);
  if (!cap.ok) {
    out[EntryField.capacity] = EntryRule.capacityInvalid;
  } else if (editing &&
      cap.value != null &&
      firstDayOverCapacity(soldPerDay, cap.value!) != null) {
    out[EntryField.capacity] = EntryRule.capacityBelowSold;
  }
  if (f.types.isEmpty) {
    out[EntryField.types] = EntryRule.typesEmpty;
  } else if (f.types.length > ticketTypesMax) {
    out[EntryField.types] = EntryRule.typesMax;
  }
  if (f.closedDays.length > entryClosedDaysMax) {
    out[EntryField.closedDays] = EntryRule.closedDaysMax;
  }
  return out;
}

/// Tickets held or paid per visit day from [today] on (the server's
/// `updateEntry` counts the same rows).
Map<String, int> entrySoldPerDay(
  Iterable<EventRegistration> regs,
  String today,
) {
  final out = <String, int>{};
  for (final r in regs) {
    final d = r.visitDay;
    if (!r.isActive || d == null || d.compareTo(today) < 0) continue;
    out[d] = (out[d] ?? 0) + r.quantity;
  }
  return out;
}

/// Ticket types somebody holds or paid: they can only be hidden.
Set<String> entrySoldTypeIds(Iterable<EventRegistration> regs) => {
  for (final r in regs)
    if (r.isActive)
      for (final i in r.items) i.ticketTypeId,
};
