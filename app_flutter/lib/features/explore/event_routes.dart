// lib/features/explore/event_routes.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True once the routes `/events` (S15) and `/e/:eventId` (S16) exist. The
/// events plan overrides this default with `true` in the same change that
/// registers those routes; until then Explore shows events but does not
/// link to them.
final eventRoutesReadyProvider = Provider<bool>((ref) => false);

String eventListPath() => '/events';
String eventPath(String id) => '/e/$id';
