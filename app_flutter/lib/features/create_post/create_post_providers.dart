// lib/features/create_post/create_post_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

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

/// SharedPreferences key of the album the user last filed a post in.
String lastAlbumKey(String uid) => 'lastAlbum:$uid';

/// The id of the album the signed-in user last published into, or null. The
/// composer invalidates it after writing; the id may name an album that was
/// deleted since, so callers check it against `myAlbumsProvider`.
final lastAlbumProvider = Provider.autoDispose<String?>((ref) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    return null;
  }
  return ref.watch(sharedPreferencesProvider).getString(lastAlbumKey(uid));
});
