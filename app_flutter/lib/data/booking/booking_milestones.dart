import 'package:flutter/foundation.dart';

/// Read model of `bookings/{id}/milestones/{shoot,delivery}` (#152 / #207).
@immutable
class BookingMilestones {
  const BookingMilestones({
    required this.shootAmount,
    required this.deliveryAmount,
    required this.shootStatus,
    required this.deliveryStatus,
  });

  final int shootAmount;
  final int deliveryAmount;
  final String shootStatus;
  final String deliveryStatus;

  /// Builds [BookingMilestones] from a map of `{kind: docData}`; returns null
  /// when either `shoot` or `delivery` is missing or malformed.
  static BookingMilestones? fromDocs(Map<String, Map<String, dynamic>> docs) {
    final shoot = docs['shoot'];
    final delivery = docs['delivery'];
    if (shoot == null || delivery == null) return null;
    final shootAmount = shoot['amount'];
    final deliveryAmount = delivery['amount'];
    final shootStatus = shoot['status'];
    final deliveryStatus = delivery['status'];
    if (shootAmount is! num ||
        deliveryAmount is! num ||
        shootStatus is! String ||
        deliveryStatus is! String) {
      return null;
    }
    return BookingMilestones(
      shootAmount: shootAmount.toInt(),
      deliveryAmount: deliveryAmount.toInt(),
      shootStatus: shootStatus,
      deliveryStatus: deliveryStatus,
    );
  }
}
