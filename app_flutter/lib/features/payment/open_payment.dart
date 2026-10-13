// lib/features/payment/open_payment.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/data/booking/payments_mode.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/features/payment/pay_subject.dart';

/// After createPayment / registerEvent / inviteInstant / startFee:
/// wallet + real payments → launch payUrl;
/// then push (or replace) payPathOf(subject) with `extra: instructions`.
Future<void> openPayment(
  BuildContext context,
  WidgetRef ref, {
  required PaySubject subject,
  required PaymentInstructions instructions,
  bool replace = false,
}) async {
  if (instructions.method != PayMethod.bankQr &&
      ref.read(realPaymentsProvider)) {
    final payUrl = instructions.payUrl;
    if (payUrl != null && payUrl.isNotEmpty) {
      await ref.read(externalLauncherProvider).open(Uri.parse(payUrl));
    }
  }

  final path = payPathOf(subject);
  if (!context.mounted) return;
  if (replace) {
    context.replace(path, extra: instructions);
  } else {
    context.push(path, extra: instructions);
  }
}
