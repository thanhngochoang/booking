import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/app_config.dart';
import 'package:photobooking/data/support/firestore_support_repository.dart';
import 'package:photobooking/data/support/support_repository.dart';
import 'package:photobooking/data/support/support_thread.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return FirestoreSupportRepository();
});

final supportEmailProvider = Provider<String?>((ref) => supportEmail);

final supportThreadProvider = StreamProvider.autoDispose
    .family<SupportThread?, String>((ref, threadId) {
      final repo = ref.watch(supportRepositoryProvider);
      return repo.watchThread(threadId);
    });

final supportMessagesProvider = StreamProvider.autoDispose
    .family<List<SupportMessage>, String>((ref, threadId) {
      final repo = ref.watch(supportRepositoryProvider);
      return repo.watchMessages(threadId);
    });
