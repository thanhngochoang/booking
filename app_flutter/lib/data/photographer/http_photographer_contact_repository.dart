// lib/data/photographer/http_photographer_contact_repository.dart
import 'dart:async';

import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/local_watch.dart';
import 'package:photobooking/data/http/wire.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';

typedef _Setup = ({
  String uid,
  ServiceArea area,
  ContactChannels channels,
  ContactNumbers numbers,
});

/// PhotographerContactRepository over the self-hosted API.
class HttpPhotographerContactRepository
    implements PhotographerContactRepository {
  HttpPhotographerContactRepository({required this.api});
  final ApiClient api;
  final _writes = StreamController<_Setup>.broadcast();

  Future<T?> _orNull<T>(String path, T Function(Object?) read) async {
    try {
      return read(await api.get(path));
    } on ApiException catch (e) {
      if (e.code == 'not_found') return null;
      rethrow;
    }
  }

  Stream<T?> _watch<T>(
    String id,
    String path,
    T Function(Object?) read,
    T Function(_Setup) pick,
  ) => fetchThenLocal<T?>(
    () => _orNull(path, read),
    _writes.stream.where((w) => w.uid == id).map(pick),
  );

  @override
  Stream<ContactChannels?> watchChannels(String photographerId) => _watch(
    photographerId,
    ApiPaths.contactChannels(photographerId),
    channelsFromJson,
    (w) => w.channels,
  );

  /// Owner only: anyone else gets an ApiException('permission_denied') event.
  @override
  Stream<ContactNumbers?> watchNumbers(String photographerId) => _watch(
    photographerId,
    ApiPaths.contactNumbers(photographerId),
    numbersFromJson,
    (w) => w.numbers,
  );

  @override
  Stream<ServiceArea?> watchServiceArea(String photographerId) => _watch(
    photographerId,
    ApiPaths.serviceArea(photographerId),
    areaFromJson,
    (w) => w.area,
  );

  /// One PUT; the server writes area, flags, numbers and onboardingComplete
  /// in one transaction.
  @override
  Future<void> completeContactSetup(
    String uid, {
    required ServiceArea area,
    required ContactChannels channels,
    required ContactNumbers numbers,
  }) async {
    await api.put(
      ApiPaths.contactSetup(uid),
      contactSetupBody(area: area, channels: channels, numbers: numbers),
    );
    _writes.add((uid: uid, area: area, channels: channels, numbers: numbers));
  }

  void dispose() => _writes.close();
}
