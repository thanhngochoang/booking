// lib/features/booking/payment_snack.dart
import 'package:material_ui/material_ui.dart';

/// One SnackBar at a time on S04.04.
void showPaymentSnack(ScaffoldMessengerState messenger, String text) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
