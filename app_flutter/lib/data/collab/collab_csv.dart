import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/collab/collaboration.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S27.06 "Sao chép bảng kê tháng {m} (CSV)" (Decision 19): the header and
/// one row per job, RFC 4180 (CRLF lines, a field with a comma, quote or
/// line break is quoted and its quotes doubled). Amounts are plain integer
/// VND; days are Vietnam calendar days `d/M/yyyy`. A text cell starting
/// with `=`, `+`, `-` or `@` (after spaces) gets a leading `'` so a
/// spreadsheet shows it instead of running it as a formula.
String collabCsv(List<CollabJob> jobs, AppLocalizations l) => [
  l.collabCsvHeader,
  for (final j in jobs)
    [
      _day(j.day),
      j.serviceName,
      j.collaboratorName,
      '${j.agreedFee}',
      _status(j.payStatus, l),
      _day(j.paidOn),
      _method(j.payMethod, l),
    ].map(_field).join(','),
].join('\r\n');

final _needsQuotes = RegExp(r'[",\r\n]');
final _formulaStart = RegExp(r'^\s*[=+\-@]');

String _field(String raw) {
  final v = _formulaStart.hasMatch(raw) ? "'$raw" : raw;
  return _needsQuotes.hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;
}

/// `yyyy-MM-dd` → `d/M/yyyy`; '' when missing or malformed.
String _day(String? key) {
  final d = key == null ? null : parseDayKey(key);
  return d == null ? '' : '${d.day}/${d.month}/${d.year}';
}

String _status(PayStatus s, AppLocalizations l) => switch (s) {
  PayStatus.none => '',
  PayStatus.due => l.collabPayDue,
  PayStatus.paidReported => l.collabPayReported,
  PayStatus.received => l.collabPayReceived,
  PayStatus.disputed => l.collabPayDisputed,
};

String _method(CollabPayMethod? m, AppLocalizations l) => switch (m) {
  null => '',
  CollabPayMethod.bank => l.collabMethodBank,
  CollabPayMethod.cash => l.collabMethodCash,
  CollabPayMethod.other => l.collabMethodOther,
};
