import 'dart:async';

import 'package:photobooking/data/earnings/earnings.dart';

abstract class EarningsRepository {
  /// Live totals; a missing document is all zero.
  Stream<EarningsSummary> watchSummary(String uid);

  /// Rows, newest day first (ties by id descending), at most [limit].
  Stream<List<EarningItem>> watchItems(String uid, {required int limit});

  /// The masked active account, null while none is registered.
  Stream<PayoutAccountView?> watchAccount(String uid);

  /// Asks the bank for the holder name and compares it with the verified name.
  /// Throws [PayoutAccountError] (`limit_exceeded` after 20 a day).
  Future<PayoutNameLookup> lookupAccountName({
    required String bankCode,
    required String accountNumber,
  });

  /// Sends an OTP for changing to this account. Throws [PayoutAccountError].
  Future<PayoutOtpTicket> requestAccountOtp({
    required String bankCode,
    required String accountNumber,
  });

  /// Registers (no [otpCode]) or changes (with [otpCode]) the payout account.
  /// A change is active from [activeFrom] (72 h later). Throws
  /// [PayoutAccountError].
  Future<({String accountId, String accountLast4, DateTime activeFrom})>
  saveAccount({
    required String bankCode,
    required String accountNumber,
    String? otpCode,
  });
}

String _last4(String number) =>
    number.length <= 4 ? number : number.substring(number.length - 4);

/// In-memory repository for tests and previews. Records calls as
/// `bankCode:last4` (saves `bankCode:last4[:otp]`), never a full number.
class FakeEarningsRepository implements EarningsRepository {
  FakeEarningsRepository({DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _clock;
  final _summary = StreamController<EarningsSummary>.broadcast();
  final _items = StreamController<List<EarningItem>>.broadcast();
  final _account = StreamController<PayoutAccountView?>.broadcast();
  EarningsSummary _lastSummary = const EarningsSummary();
  List<EarningItem> _lastItems = const [];
  PayoutAccountView? _lastAccount;
  String? _failNext;
  String? _failNextLookup;
  String? _failNextOtp;

  /// `bankCode:last4` of each successful save, plus `:otp` when one was given.
  final List<String> saves = [];

  /// `bankCode:last4` of each lookup, failed ones included.
  final List<String> lookupCalls = [];

  /// `bankCode:last4` of each OTP request, failed ones included.
  final List<String> otpCalls = [];

  /// Lookup answers keyed `bankCode:number`; any other key gets
  /// [defaultLookup].
  final Map<String, PayoutNameLookup> nextLookup = {};

  /// A matched lookup for the signed-in tester "Minh Trí".
  PayoutNameLookup defaultLookup = const PayoutNameLookup(
    decision: PayoutNameDecision.matched,
    holderName: 'NGUYEN MINH TRI',
    verifiedName: 'Nguyễn Minh Trí',
  );

  /// The ticket [requestAccountOtp] answers with.
  PayoutOtpTicket otpTicket = const PayoutOtpTicket(
    phoneLast4: '0001',
    expiresInSeconds: 300,
    resendInSeconds: 60,
  );

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

  void failNextLookup(String code) => _failNextLookup = code;

  void failNextOtp(String code) => _failNextOtp = code;

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
  Future<PayoutNameLookup> lookupAccountName({
    required String bankCode,
    required String accountNumber,
  }) async {
    lookupCalls.add('$bankCode:${_last4(accountNumber)}');
    final fail = _failNextLookup;
    if (fail != null) {
      _failNextLookup = null;
      throw PayoutAccountError(fail);
    }
    return nextLookup['$bankCode:$accountNumber'] ?? defaultLookup;
  }

  @override
  Future<PayoutOtpTicket> requestAccountOtp({
    required String bankCode,
    required String accountNumber,
  }) async {
    otpCalls.add('$bankCode:${_last4(accountNumber)}');
    final fail = _failNextOtp;
    if (fail != null) {
      _failNextOtp = null;
      throw PayoutAccountError(fail);
    }
    return otpTicket;
  }

  /// A first account is active at once; a change 72 h later. The name status
  /// is `pending_review` when the key's [nextLookup] answer is `review`.
  @override
  Future<({String accountId, String accountLast4, DateTime activeFrom})>
  saveAccount({
    required String bankCode,
    required String accountNumber,
    String? otpCode,
  }) async {
    final fail = _failNext;
    if (fail != null) {
      _failNext = null;
      throw PayoutAccountError(fail);
    }
    final last4 = _last4(accountNumber);
    saves.add(['$bankCode:$last4', ?otpCode].join(':'));
    final id = 'acc-${saves.length}';
    final now = _clock();
    final activeFrom = _lastAccount == null
        ? now
        : now.add(const Duration(hours: 72));
    final lookup = nextLookup['$bankCode:$accountNumber'] ?? defaultLookup;
    final review = lookup.decision == PayoutNameDecision.review;
    setAccount(
      PayoutAccountView(
        accountId: id,
        bankCode: bankCode,
        accountLast4: last4,
        // As the server: a review account carries the verified name.
        holderName:
            (review
                ? lookup.verifiedName ?? lookup.holderName
                : lookup.holderName ?? lookup.verifiedName) ??
            '',
        updatedAt: now,
        activeFrom: activeFrom,
        nameStatus: review
            ? PayoutNameStatus.pendingReview
            : PayoutNameStatus.matched,
      ),
    );
    return (accountId: id, accountLast4: last4, activeFrom: activeFrom);
  }
}
