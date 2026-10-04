// lib/data/contact/http_contact_link_repository.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/wire.dart';

/// get_contact_link over the self-hosted API. Same request and response as
/// the callable (`callableData`, `parseLinkResponse`); the URL is still
/// checked by ContactLauncher's allow-list before it is opened.
class HttpContactLinkRepository implements ContactLinkRepository {
  HttpContactLinkRepository({required this.api});
  final ApiClient api;

  @override
  Future<Uri> link({
    required ContactSubject subject,
    required ContactChannel channel,
  }) async {
    if (!channel.isExternal) {
      throw const ContactLinkException(ContactLinkError.unavailable);
    }
    try {
      return parseLinkResponse(
        await api.post(ApiPaths.contactLinks, callableData(subject, channel)),
      );
    } on ApiException catch (e) {
      throw ContactLinkException(linkErrorFromCode(e.code));
    }
  }
}
