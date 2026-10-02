// lib/data/contact/functions_contact_link_repository.dart
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';

/// Calls the callable `getContactLink` (server side: a later plan). Thin on
/// purpose: all rules are in the pure functions of contact_link_repository.dart.
class FunctionsContactLinkRepository implements ContactLinkRepository {
  FunctionsContactLinkRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);
  final FirebaseFunctions _functions;

  @override
  Future<Uri> link({
    required ContactSubject subject,
    required ContactChannel channel,
  }) async {
    try {
      final result = await _functions
          .httpsCallable(
            'getContactLink',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
          )
          .call<Object?>(callableData(subject, channel));
      return parseLinkResponse(result.data);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final code = details is Map && details['code'] is String
          ? details['code'] as String
          : e.message;
      throw ContactLinkException(linkErrorFromCode(code));
    }
  }
}
