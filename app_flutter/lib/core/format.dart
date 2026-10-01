import 'dart:math' as math;

import 'package:photobooking/core/geo.dart';

/// `1,2 km`: one decimal, a decimal comma, never `0,0 km`.
String formatDistance(double km) {
  final rounded = math.max(0.1, roundKm(km));
  return '${rounded.toStringAsFixed(1).replaceAll('.', ',')} km';
}
