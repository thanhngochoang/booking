// lib/features/booking/steps/place_step.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';

class PlaceStep extends ConsumerWidget {
  const PlaceStep({super.key, required this.args});
  final BookingFlowArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(child: Text('PlaceStep'));
  }
}
