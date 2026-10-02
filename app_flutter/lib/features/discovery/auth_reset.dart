import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';

/// Calls [reset] when the signed-in uid changes (sign-out, or another user),
/// so one user's marks never show for the next. Call from `build()`. The
/// stream's first value is the current user and changes nothing.
void resetOnUserChange(Ref ref, void Function() reset) {
  final auth = ref.read(authRepositoryProvider);
  var owner = auth.currentUser?.uid;
  final sub = auth.authStateChanges().listen((user) {
    final uid = user?.uid;
    if (uid != owner) {
      owner = uid;
      reset();
    }
  });
  ref.onDispose(sub.cancel);
}
