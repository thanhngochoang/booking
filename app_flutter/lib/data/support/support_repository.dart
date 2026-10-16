import 'package:photobooking/data/support/support_thread.dart';

class SupportError implements Exception {
  const SupportError(this.code);
  final String code;

  @override
  String toString() => 'SupportError($code)';
}

abstract class SupportRepository {
  String helpThreadIdFor(String uid);

  Stream<SupportThread?> watchThread(String threadId);

  Stream<List<SupportMessage>> watchMessages(String threadId, {int limit = 30});

  Future<String> send({
    String? threadId,
    required String text,
    required String clientId,
  });
}
