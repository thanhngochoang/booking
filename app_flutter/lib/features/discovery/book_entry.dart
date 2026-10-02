// lib/features/discovery/book_entry.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';

/// `/u/<photographer>/book?serviceId=…&date=yyyy-MM-dd`. The booking screens
/// (step 4) read these two parameters; both are optional.
String bookingPath({
  required String photographerId,
  String? serviceId,
  DateTime? date,
}) {
  final query = {
    'serviceId': ?serviceId,
    'date': ?(date == null ? null : dayKeyOf(date)),
  };
  return Uri(
    path: '/u/$photographerId/book',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

/// Starts a booking from S02.02, S03.01 or S02.06. A customer without a phone number
/// is sent to S04.05 first and comes back to the booking (spec 3b.1); reading the
/// contact fails closed, so a failure also goes through S04.05.
Future<void> startBooking(
  BuildContext context,
  WidgetRef ref, {
  required String photographerId,
  String? serviceId,
  DateTime? date,
}) async {
  final path = bookingPath(
    photographerId: photographerId,
    serviceId: serviceId,
    date: date,
  );
  Object? contact;
  // currentContactProvider is autoDispose: hold a listener while we wait.
  final hold = ref.listenManual(currentContactProvider, (_, _) {});
  try {
    contact = await ref.read(currentContactProvider.future);
  } catch (_) {
    contact = null;
  } finally {
    hold.close();
  }
  if (!context.mounted) {
    return;
  }
  if (contact == null) {
    context.push('/profile/phone?returnTo=${Uri.encodeComponent(path)}');
  } else {
    context.push(path);
  }
}
