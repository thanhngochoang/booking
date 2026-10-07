// lib/features/explore/event_routes.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the routes `/events` (S11.01) and `/e/:eventId` (S11.02) exist,
/// which they do since plan 10c. Explore links to them; tests override it with
/// `false` to see Explore without links.
final eventRoutesReadyProvider = Provider<bool>((ref) => true);

String eventListPath() => '/events';
String eventPath(String id) => '/e/$id';
