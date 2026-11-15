import 'dart:async';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/pricing/price_rule_repository.dart';
import 'package:photobooking/data/pricing/price_rules.dart' hide splitRule;
import 'package:photobooking/data/pricing/price_rules.dart'
    as series
    show splitRule;

/// In-memory [PriceRuleRepository] that does what the four callables do, with
/// the app's own pure functions (`validatePriceRuleField`, `splitRule`,
/// `withException`, `scaledRule`): the same rules, limits and error codes, and
/// a record of every call. Like the server, an edit keeps only the exceptions
/// the new pattern covers, a split of a series with nothing left before the
/// day replaces (or deletes) the whole series, and a name is trimmed. Writes are made as [ownerUid]; a rule of another
/// provider is `not_found`.
class FakePriceRuleRepository implements PriceRuleRepository {
  FakePriceRuleRepository({DateTime Function()? today})
    : _today = today ?? (() => DateTime.utc(2026, 10, 1));

  final DateTime Function() _today;

  /// The signed-in photographer; owner of the rules the writes touch.
  String ownerUid = 'p1';

  /// The owner's packages. When set, `serviceId` must be one of them and
  /// `applyToAll` copies to the others; when null any `serviceId` is accepted
  /// and `applyToAll` copies nothing.
  List<PricedPackage>? packages;

  /// providerId -> ruleId -> rule.
  final Map<String, Map<String, PriceRule>> rules = {};

  final saves = <({PriceRuleInput input, String? ruleId, bool applyToAll})>[];
  final splits = <({String ruleId, DateTime day, int? price})>[];
  final exceptions = <({String ruleId, DateTime day, PriceException value})>[];
  final deletes = <String>[];

  /// The next write throws `PriceRuleException(code, field: ...)`.
  String? nextErrorCode;
  String? nextErrorField;

  /// `watchProviderRules` fails while true (the screen's load error).
  bool failWatch = false;

  /// While true, `saveRule` waits for [releaseSave].
  bool holdSave = false;
  Completer<void>? _gate;

  void releaseSave() {
    holdSave = false;
    _gate?.complete();
    _gate = null;
  }

  final _changes = StreamController<void>.broadcast();
  int _nextId = 1;

  /// Adds a rule of [providerId] (default: the owner) as if the server had
  /// written it.
  void seed(PriceRule rule, {String? providerId}) {
    (rules[providerId ?? ownerUid] ??= {})[rule.id] = rule;
    _changes.add(null);
  }

  /// The owner's rules in the order of the real repository.
  List<PriceRule> get ownerRules => _of(ownerUid);

  List<PriceRule> _of(String uid) =>
      (rules[uid]?.values.toList() ?? <PriceRule>[])..sort(comparePriceRules);

  Map<String, PriceRule> get _own => rules[ownerUid] ??= {};

  void _maybeFail() {
    final code = nextErrorCode;
    if (code == null) {
      return;
    }
    final field = nextErrorField;
    nextErrorCode = null;
    nextErrorField = null;
    throw PriceRuleException(code, field: field);
  }

  PriceRule _find(String ruleId) {
    final rule = _own[ruleId];
    if (rule == null) {
      throw const PriceRuleException('not_found');
    }
    return rule;
  }

  PriceRuleException _bad(String field) =>
      PriceRuleException('invalid_argument', field: field);

  int _countOf(String serviceId) =>
      _own.values.where((r) => r.serviceId == serviceId).length;

  String _newId() => 'rule_${_nextId++}';

  @override
  Stream<List<PriceRule>> watchProviderRules(String providerId) {
    if (failWatch) {
      return Stream.error(const PriceRuleException('unavailable'));
    }
    return Stream.multi((c) {
      c.add(_of(providerId));
      final sub = _changes.stream.listen((_) => c.add(_of(providerId)));
      c.onCancel = sub.cancel;
    });
  }

  @override
  Future<List<PriceRule>> rulesForService(
    String providerId,
    String serviceId,
  ) async => [
    for (final r in _of(providerId))
      if (r.serviceId == serviceId) r,
  ];

  @override
  Future<List<String>> saveRule(
    PriceRuleInput input, {
    String? ruleId,
    bool applyToAll = false,
  }) async {
    _maybeFail();
    if (holdSave) {
      _gate = Completer<void>();
      await _gate!.future;
    }
    saves.add((input: input, ruleId: ruleId, applyToAll: applyToAll));
    if (applyToAll && ruleId != null) {
      throw _bad('applyToAll');
    }
    final existing = ruleId == null ? null : _find(ruleId);
    if (existing != null && input.serviceId != existing.serviceId) {
      throw _bad('serviceId');
    }
    final known = packages;
    final bad = input.validate(
      today: _today(),
      serviceIds: known == null
          ? [input.serviceId]
          : [for (final p in known) p.id],
      creating: existing == null,
    );
    if (bad != null) {
      throw _bad(bad);
    }
    final id = existing?.id ?? _newId();
    var rule = PriceRule(
      id: id,
      serviceId: input.serviceId,
      price: input.price,
      repeat: input.repeat,
      name: input.name?.trim().isEmpty ?? true ? null : input.name!.trim(),
      lunar: input.lunar,
      from: input.from,
      to: input.to,
      weekdays: input.weekdays,
      start: existing?.start,
      until: existing?.until,
      exceptions: existing?.exceptions ?? const {},
      template: input.template ?? existing?.template,
    );
    if (rule.exceptions.isNotEmpty) {
      // An exception the new pattern no longer covers would still set (or
      // drop) a price on its day: it goes, like on the server.
      final plain = PriceRule(
        id: rule.id,
        serviceId: rule.serviceId,
        price: rule.price,
        repeat: rule.repeat,
        lunar: rule.lunar,
        from: rule.from,
        to: rule.to,
        weekdays: rule.weekdays,
        start: rule.start,
        until: rule.until,
      );
      rule = _withExceptions(rule, {
        for (final e in rule.exceptions.entries)
          if (_covers(plain, e.key)) e.key: e.value,
      });
    }
    final copies = <PriceRule>[];
    if (existing == null) {
      if (_countOf(rule.serviceId) + 1 > kMaxRulesPerService) {
        throw const PriceRuleException('rule_limit');
      }
      if (applyToAll && known != null) {
        final from = known.firstWhere((p) => p.id == rule.serviceId);
        for (final to in known) {
          if (to.id == rule.serviceId) {
            continue;
          }
          if (_countOf(to.id) + 1 > kMaxRulesPerService) {
            throw const PriceRuleException('rule_limit');
          }
          copies.add(scaledRule(rule, from, to, _newId()));
        }
      }
    }
    _own[id] = rule;
    for (final c in copies) {
      _own[c.id] = c;
    }
    _changes.add(null);
    return [id, ...copies.map((c) => c.id)];
  }

  @override
  Future<List<String>> splitRule(
    String ruleId,
    DateTime day, {
    int? price,
  }) async {
    _maybeFail();
    final d = calendarDay(day);
    splits.add((ruleId: ruleId, day: d, price: price));
    final rule = _find(ruleId);
    if (price != null && (price < 1 || price > 1000000000)) {
      throw _bad('price');
    }
    final key = dayKeyOf(d);
    final start = rule.start;
    final until = rule.until;
    final from = rule.from;
    final to = rule.to;
    final outside =
        (start != null && key.compareTo(start) < 0) ||
        (until != null && key.compareTo(until) > 0) ||
        (rule.repeat == PriceRepeat.none &&
            from != null &&
            to != null &&
            (key.compareTo(from) < 0 || key.compareTo(to) > 0));
    if (outside) {
      throw _bad('day');
    }
    final first = start ?? (rule.repeat == PriceRepeat.none ? from : null);
    // Also the whole series when the part before the day would have no
    // occurrence left from today (a dead series).
    final whole =
        (first != null && key.compareTo(first) <= 0) ||
        nextOccurrence(series.splitRule(rule, d, null, '').before, _today()) ==
            null;
    if (whole) {
      if (price == null) {
        _own.remove(ruleId);
        _changes.add(null);
        return const [];
      }
      _own[ruleId] = _repriced(rule, price);
      _changes.add(null);
      return [ruleId];
    }
    if (price != null && _countOf(rule.serviceId) + 1 > kMaxRulesPerService) {
      throw const PriceRuleException('rule_limit');
    }
    final out = series.splitRule(rule, d, price, _newId());
    _own[out.before.id] = out.before;
    final after = out.after;
    if (after != null) {
      _own[after.id] = after;
    }
    _changes.add(null);
    return [out.before.id, ?after?.id];
  }

  PriceRule _repriced(PriceRule r, int price) => PriceRule(
    id: r.id,
    serviceId: r.serviceId,
    price: price,
    repeat: r.repeat,
    name: r.name,
    lunar: r.lunar,
    from: r.from,
    to: r.to,
    weekdays: r.weekdays,
    start: r.start,
    until: r.until,
    exceptions: r.exceptions,
    template: r.template,
  );

  PriceRule _withExceptions(PriceRule r, Map<String, Object?> exceptions) =>
      PriceRule(
        id: r.id,
        serviceId: r.serviceId,
        price: r.price,
        repeat: r.repeat,
        name: r.name,
        lunar: r.lunar,
        from: r.from,
        to: r.to,
        weekdays: r.weekdays,
        start: r.start,
        until: r.until,
        exceptions: exceptions,
        template: r.template,
      );

  bool _covers(PriceRule plain, String dayKey) {
    final day = parseDayKey(dayKey);
    return day != null && ruleCoversDay(plain, day).covers;
  }

  @override
  Future<void> setException(
    String ruleId,
    DateTime day,
    PriceException value,
  ) async {
    _maybeFail();
    final d = calendarDay(day);
    exceptions.add((ruleId: ruleId, day: d, value: value));
    final rule = _find(ruleId);
    final next = switch (value) {
      ClearDayException() => clearException(rule, d),
      CustomDayPrice(:final price) => _withPrice(rule, d, price),
      SkipDay() => _withPrice(rule, d, null),
    };
    if (next.exceptions.length > kMaxExceptions) {
      throw const PriceRuleException('exception_limit');
    }
    _own[ruleId] = next;
    _changes.add(null);
  }

  PriceRule _withPrice(PriceRule rule, DateTime day, int? price) {
    if (price != null && (price < 1 || price > 1000000000)) {
      throw _bad('price');
    }
    // The day must belong to the pattern, so a dropped day can be priced again.
    final plain = PriceRule(
      id: rule.id,
      serviceId: rule.serviceId,
      price: rule.price,
      repeat: rule.repeat,
      lunar: rule.lunar,
      from: rule.from,
      to: rule.to,
      weekdays: rule.weekdays,
      start: rule.start,
      until: rule.until,
    );
    if (!ruleCoversDay(plain, day).covers) {
      throw _bad('day');
    }
    return withException(rule, day, price);
  }

  @override
  Future<void> deleteRule(String ruleId) async {
    _maybeFail();
    deletes.add(ruleId);
    _find(ruleId);
    _own.remove(ruleId);
    _changes.add(null);
  }
}
