import 'dart:async';

import 'package:photobooking/data/earnings/earnings.dart';

abstract class EarningsRepository {
  /// Live totals; a missing document is all zero.
  Stream<EarningsSummary> watchSummary(String uid);

  /// Rows, newest day first (ties by id descending), at most [limit].
  Stream<List<EarningItem>> watchItems(String uid, {required int limit});

  /// The masked active account, null while none is registered.
  Stream<PayoutAccountView?> watchAccount(String uid);

  /// Registers or changes the payout account. Throws [PayoutAccountError].
  Future<({String accountId, String accountLast4})> saveAccount({
    required String bankCode,
    required String accountNumber,
    required String holderName,
  });
}

/// In-memory repository for tests and previews.
class FakeEarningsRepository implements EarningsRepository {
  final _summary = StreamController<EarningsSummary>.broadcast();
  final _items = StreamController<List<EarningItem>>.broadcast();
  final _account = StreamController<PayoutAccountView?>.broadcast();
  EarningsSummary _lastSummary = const EarningsSummary();
  List<EarningItem> _lastItems = const [];
  PayoutAccountView? _lastAccount;
  String? _failNext;

  /// `bankCode:last4` of each successful save; never a full number.
  final List<String> saves = [];

  void emitSummary(EarningsSummary s) {
    _lastSummary = s;
    _summary.add(s);
  }

  void emitItems(List<EarningItem> items) {
    _lastItems = items;
    _items.add(items);
  }

  void setAccount(PayoutAccountView? a) {
    _lastAccount = a;
    _account.add(a);
  }

  void failNextSave(String code) => _failNext = code;

  @override
  Stream<EarningsSummary> watchSummary(String uid) async* {
    yield _lastSummary;
    yield* _summary.stream;
  }

  @override
  Stream<List<EarningItem>> watchItems(
    String uid, {
    required int limit,
  }) async* {
    yield _lastItems.take(limit).toList();
    yield* _items.stream.map((l) => l.take(limit).toList());
  }

  @override
  Stream<PayoutAccountView?> watchAccount(String uid) async* {
    yield _lastAccount;
    yield* _account.stream;
  }

  @override
  Future<({String accountId, String accountLast4})> saveAccount({
    required String bankCode,
    required String accountNumber,
    required String holderName,
  }) async {
    final fail = _failNext;
    if (fail != null) {
      _failNext = null;
      throw PayoutAccountError(fail);
    }
    final last4 = accountNumber.substring(accountNumber.length - 4);
    saves.add('$bankCode:$last4');
    final id = 'acc-${saves.length}';
    setAccount(
      PayoutAccountView(
        accountId: id,
        bankCode: bankCode,
        accountLast4: last4,
        holderName: holderName,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    return (accountId: id, accountLast4: last4);
  }
}
