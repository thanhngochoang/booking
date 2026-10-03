// lib/features/booking/steps/review_step.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';

class ReviewStep extends ConsumerWidget {
  const ReviewStep({super.key, required this.args});
  final BookingFlowArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ScreenCode(
      ScreenCodes.bookReview,
      child: Center(child: Text('ReviewStep')),
    );
  }
}
