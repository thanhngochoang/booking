// #202: the Chụp ngay side of V1's shared S04.04 (`InstantPay`): opening it
// after `inviteInstant` asked for the money, inviting again with the choice
// that waits on the payment ("Thanh toán tiếp", "Tạo QR mới"), and where
// S04.04 returns once the money is in.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_repository.dart';
import 'package:photobooking/features/payment/open_payment.dart';
import 'package:photobooking/features/payment/pay_subject.dart';

/// The query flag S04.04 adds when it returns because the payment is in: the
/// flow screen then asks the notification primer once (Decision 10).
const kInstantPaidQuery = 'paid';

/// `/instant/{id}`; [justPaid] adds `?paid=1`.
String instantRequestPath(String requestId, {bool justPaid = false}) => justPaid
    ? '/instant/$requestId?$kInstantPaidQuery=1'
    : '/instant/$requestId';

/// The method the first round pays with: the customer's [picked] one, else
/// the one the request already waits on, else Chuyển khoản QR (preselected,
/// Decision 2).
PayMethod instantPayMethodOf(InstantRequest r, PayMethod? picked) =>
    picked ?? r.payMethod ?? PayMethod.bankQr;

/// "Thanh toán tiếp", and S04.04's "Tạo QR mới" or resume: `inviteInstant`
/// again with the choice waiting in `pending_payment` ([r]'s
/// `pendingInviteIds`). The server reuses the open payment of the same amount
/// and method, or closes it and opens a new one; nobody is invited before it
/// is paid.
Future<InstantInviteResult> inviteInstantAgain(
  InstantRepository repo,
  InstantRequest r, {
  PayMethod? method,
}) => repo.invite(
  r.id,
  photographerIds: r.pendingInviteIds,
  skipped: const [],
  expectedAmountVnd: r.amountVnd,
  payMethod: instantPayMethodOf(r, method),
);

/// S04.04 for [requestId] with the instructions `inviteInstant` answered: the
/// VietQR, or the wallet (its `payUrl` is launched with real payments).
Future<void> openInstantPayment(
  BuildContext context,
  WidgetRef ref,
  String requestId,
  InstantPaymentNeeded result,
) => openPayment(
  context,
  ref,
  subject: InstantPay(requestId),
  instructions: result.instructions,
);
