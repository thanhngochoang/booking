// lib/data/http/wire.dart
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';

/// Paths of services/api/api/openapi.yaml. Ids are opaque [A-Za-z0-9_-].
abstract final class ApiPaths {
  static const me = '/v1/me';
  static String user(String id) => '/v1/users/${Uri.encodeComponent(id)}';
  static String userRole(String id) => '${user(id)}/role';
  static String userContact(String id) => '${user(id)}/contact';
  static String photographer(String id) =>
      '/v1/photographers/${Uri.encodeComponent(id)}';
  static String contactChannels(String id) =>
      '${photographer(id)}/contact-channels';
  static String contactNumbers(String id) =>
      '${photographer(id)}/contact-numbers';
  static String serviceArea(String id) => '${photographer(id)}/service-area';
  static String contactSetup(String id) => '${photographer(id)}/contact-setup';
  static const contactLinks = '/v1/contact-links';
}

/// Every (method, contract path) the app calls; test/data/http/openapi_drift_test.dart
/// checks each against openapi.yaml.
const apiOperations = <(String, String)>[
  ('POST', '/v1/me'),
  ('GET', '/v1/users/{userId}'),
  ('PATCH', '/v1/users/{userId}'),
  ('PUT', '/v1/users/{userId}/role'),
  ('GET', '/v1/users/{userId}/contact'),
  ('PUT', '/v1/users/{userId}/contact'),
  ('GET', '/v1/photographers/{photographerId}/contact-channels'),
  ('GET', '/v1/photographers/{photographerId}/contact-numbers'),
  ('GET', '/v1/photographers/{photographerId}/service-area'),
  ('PUT', '/v1/photographers/{photographerId}/contact-setup'),
  ('POST', '/v1/contact-links'),
];

Never _malformed() => throw const ApiException(200, ApiException.malformed);

Map<String, dynamic> _map(Object? json) =>
    json is Map<String, dynamic> ? json : _malformed();

String _name(String raw) => raw.length > 80 ? raw.substring(0, 80) : raw;

/// Same fallback name as FirestoreUserRepository.ensureProfile.
Map<String, Object?> ensureProfileBody(AuthUser user) {
  final given = user.displayName?.trim() ?? '';
  final name = given.isNotEmpty
      ? given
      : (user.email?.split('@').first ?? 'Người dùng');
  return {
    'displayName': _name(name.isEmpty ? 'Người dùng' : name),
    if (user.photoUrl != null) 'avatarUrl': user.photoUrl,
  };
}

Map<String, Object?> updateUserBody(String displayName) => {
  'displayName': _name(displayName),
};

Map<String, Object?> setRoleBody(UserRole role) => {'role': role.name};

UserProfile profileFromJson(Object? json) {
  final m = _map(json);
  if (m['id'] is! String || m['displayName'] is! String) _malformed();
  try {
    return UserProfile.fromJson({
      'uid': m['id'],
      'displayName': m['displayName'],
      'role': m['role'],
      'avatarUrl': m['avatarUrl'],
    });
  } on Object {
    _malformed();
  }
}

UserContact userContactFromJson(Object? json) {
  final m = _map(json);
  final phone = m['phone'];
  if (phone is! String) _malformed();
  return UserContact(
    phone: phone,
    phoneVerified: m['phoneVerified'] == true,
    allowZalo: m['allowZalo'] != false,
    allowWhatsApp: m['allowWhatsApp'] == true,
  );
}

Map<String, Object?> saveContactBody({
  required String phone,
  required bool allowZalo,
  required bool allowWhatsApp,
}) => {'phone': phone, 'allowZalo': allowZalo, 'allowWhatsApp': allowWhatsApp};

ContactChannels channelsFromJson(Object? json) =>
    ContactChannels.fromMap(_map(json)) ?? _malformed();

ContactNumbers numbersFromJson(Object? json) =>
    ContactNumbers.fromMap(_map(json)) ?? _malformed();

ServiceArea areaFromJson(Object? json) =>
    ServiceArea.fromMap(_map(json)) ?? _malformed();

Map<String, Object?> contactSetupBody({
  required ServiceArea area,
  required ContactChannels channels,
  required ContactNumbers numbers,
}) => {
  'area': area.toMap(),
  'channels': channels.toMap(),
  'numbers': numbers.toMap(),
};
