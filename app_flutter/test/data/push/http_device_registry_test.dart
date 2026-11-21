// test/data/push/http_device_registry_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/push/http_device_registry.dart';

import '../http/mock_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('register sends PUT with token, provider fcm and platform', () async {
    final mockApi = MockApi({
      'PUT /v1/me/devices/inst123456789012': (req) => (200, {'ok': true}),
    });
    await prefs.setString('pushInstallId', 'inst123456789012');
    final registry = HttpDeviceRegistry(
      api: mockApi.api(),
      prefs: prefs,
      platform: 'android',
    );

    await registry.register(uid: 'u1', token: 'tok_abc');

    expect(mockApi.calls, ['PUT /v1/me/devices/inst123456789012']);
    final body =
        jsonDecode(mockApi.requests.first.body) as Map<String, dynamic>;
    expect(body, {
      'token': 'tok_abc',
      'provider': 'fcm',
      'platform': 'android',
    });
  });

  test('uses the persisted install id', () async {
    final mockApi = MockApi({
      'PUT /v1/me/devices/installAABBCC112233': (req) => (200, {'ok': true}),
    });
    await prefs.setString('pushInstallId', 'installAABBCC112233');

    final reg1 = HttpDeviceRegistry(api: mockApi.api(), prefs: prefs);
    final reg2 = HttpDeviceRegistry(api: mockApi.api(), prefs: prefs);

    await reg1.register(uid: 'u1', token: 'tok_1');
    await reg2.register(uid: 'u1', token: 'tok_2');

    expect(mockApi.calls, [
      'PUT /v1/me/devices/installAABBCC112233',
      'PUT /v1/me/devices/installAABBCC112233',
    ]);
  });

  test('unregister sends DELETE', () async {
    final mockApi = MockApi({
      'DELETE /v1/me/devices/instDel12345678': (req) => (200, {'ok': true}),
    });
    await prefs.setString('pushInstallId', 'instDel12345678');
    final registry = HttpDeviceRegistry(
      api: mockApi.api(),
      prefs: prefs,
    );

    await registry.unregister('u1');

    expect(mockApi.calls, ['DELETE /v1/me/devices/instDel12345678']);
  });

  test('delete of a missing device is not an error', () async {
    final mockApi = MockApi();
    await prefs.setString('pushInstallId', 'instNotFound1234');
    final registry = HttpDeviceRegistry(
      api: mockApi.api(),
      prefs: prefs,
    );

    await expectLater(registry.unregister('u1'), completes);
    expect(mockApi.calls, ['DELETE /v1/me/devices/instNotFound1234']);
  });

  test('ios platform is sent when configured', () async {
    final mockApi = MockApi({
      'PUT /v1/me/devices/instIos123456789': (req) => (200, {'ok': true}),
    });
    await prefs.setString('pushInstallId', 'instIos123456789');
    final registry = HttpDeviceRegistry(
      api: mockApi.api(),
      prefs: prefs,
      platform: 'ios',
    );

    await registry.register(uid: 'u1', token: 'tok_ios');

    expect(mockApi.calls, ['PUT /v1/me/devices/instIos123456789']);
    final body =
        jsonDecode(mockApi.requests.first.body) as Map<String, dynamic>;
    expect(body['platform'], 'ios');
  });
}
