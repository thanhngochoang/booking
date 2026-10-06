/// Where this install's push token is stored for the server.
abstract class DeviceRegistry {
  Future<void> register({required String uid, required String token});

  /// Deletes this install's record for [uid].
  Future<void> unregister(String uid);
}
