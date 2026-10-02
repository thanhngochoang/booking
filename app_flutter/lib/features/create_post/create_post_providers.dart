// lib/features/create_post/create_post_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/service_summary.dart';

/// The signed-in photographer's active packages, for the package field.
final myServicesProvider = FutureProvider.autoDispose<List<ServiceSummary>>((
  ref,
) async {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    return const [];
  }
  return ref.watch(serviceRepositoryProvider).activeFor(uid);
});
