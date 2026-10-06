// lib/features/awards/my_awards_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/award/award_providers.dart';

/// Approved awards needed for the Nhiếp ảnh gia (NAG) tier. The server owns
/// the rule (spec section 2.3); the app only shows progress towards it.
const int kAwardTierThreshold = 3;

/// Deletes one of the owner's awards (the server also removes its proofs).
Future<void> deleteMyAward(WidgetRef ref, String awardId) =>
    ref.read(awardRepositoryProvider).delete(awardId);

/// Date as dd/MM/yyyy in Vietnam (UTC+7).
String awardDate(DateTime utc) {
  final d = utc.toUtc().add(const Duration(hours: 7));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// Day and month only (dd/MM), for "gửi 03/10".
String awardDayMonth(DateTime utc) => awardDate(utc).substring(0, 5);
