// test/data/http/realtime_channel_test.dart
import 'dart:async';
import 'dart:convert';

// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:photobooking/data/auth/id_token_source.dart';
import 'package:photobooking/data/backend_config.dart';
import 'package:photobooking/data/http/api_providers.dart';
import 'package:photobooking/data/http/realtime_channel.dart';

class TestHttpClient extends http.BaseClient {
  TestHttpClient(this.handler, {this.onClose});

  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  final void Function()? onClose;
  bool isClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);

  @override
  void close() {
    isClosed = true;
    onClose?.call();
  }
}

class _MockTokenSource implements IdTokenSource {
  _MockTokenSource({this.initialToken = 'token0', this.refreshedToken = 'token1'});

  String? initialToken;
  String? refreshedToken;
  final refreshes = <bool>[];

  @override
  Future<String?> token({bool forceRefresh = false}) async {
    refreshes.add(forceRefresh);
    return forceRefresh ? refreshedToken : initialToken;
  }
}

void main() {
  test('emits a ChangeEvent only to listeners of that topic', () async {
    final bodyController = StreamController<List<int>>();
    final channel = RealtimeChannel(
      baseUrl: Uri.parse('http://api.test'),
      tokens: const StaticIdTokenSource('token1'),
      clientFactory: () => TestHttpClient(
        (req) async => http.StreamedResponse(bodyController.stream, 200),
        onClose: () => bodyController.close(),
      ),
      backoff: (_) => Duration.zero,
    );

    final events1 = <ChangeEvent>[];
    final events2 = <ChangeEvent>[];

    final sub1 = channel.on('topic1').listen(events1.add);
    final sub2 = channel.on('topic2').listen(events2.add);

    bodyController.add(utf8.encode(
      'event: change\ndata: {"topic":"topic1","kind":"item.created"}\n\n',
    ));

    await pumpEventQueue();

    expect(events1, [
      const ChangeEvent(topic: 'topic1', kind: 'item.created'),
    ]);
    expect(events2, isEmpty);

    await sub1.cancel();
    await sub2.cancel();
    channel.dispose();
  });

  test('sends the bearer token and accept headers', () async {
    http.BaseRequest? capturedRequest;
    final bodyController = StreamController<List<int>>();
    final channel = RealtimeChannel(
      baseUrl: Uri.parse('http://api.test/api/'),
      tokens: const StaticIdTokenSource('test-bearer-token'),
      clientFactory: () => TestHttpClient(
        (req) async {
          capturedRequest = req;
          return http.StreamedResponse(bodyController.stream, 200);
        },
        onClose: () => bodyController.close(),
      ),
    );

    final sub = channel.on('any').listen((_) {});
    await pumpEventQueue();

    expect(capturedRequest, isNotNull);
    expect(capturedRequest!.method, 'GET');
    expect(capturedRequest!.url.toString(), 'http://api.test/api/v1/events');
    expect(capturedRequest!.headers['authorization'], 'Bearer test-bearer-token');
    expect(capturedRequest!.headers['accept'], 'text/event-stream');
    expect(capturedRequest!.headers['accept-encoding'], 'identity');

    await sub.cancel();
    channel.dispose();
  });

  test('retries with backoff after a drop and emits reconnected to every topic (inject backoff: (_) => Duration.zero)', () async {
    var connectCount = 0;
    final bodyControllers = <StreamController<List<int>>>[];

    final channel = RealtimeChannel(
      baseUrl: Uri.parse('http://api.test'),
      tokens: const StaticIdTokenSource('token1'),
      clientFactory: () {
        final ctrl = StreamController<List<int>>();
        bodyControllers.add(ctrl);
        return TestHttpClient(
          (req) async {
            connectCount++;
            return http.StreamedResponse(ctrl.stream, 200);
          },
          onClose: () => ctrl.close(),
        );
      },
      backoff: (_) => Duration.zero,
    );

    final events1 = <ChangeEvent>[];
    final events2 = <ChangeEvent>[];

    final sub1 = channel.on('topic1').listen(events1.add);
    final sub2 = channel.on('topic2').listen(events2.add);

    await pumpEventQueue();
    expect(connectCount, 1);
    expect(events1, isEmpty);
    expect(events2, isEmpty);

    // Simulate connection drop by closing the active response stream
    await bodyControllers[0].close();
    await pumpEventQueue();

    // Reconnect happened
    expect(connectCount, 2);
    expect(events1, [const ChangeEvent(topic: 'topic1', kind: 'reconnected')]);
    expect(events2, [const ChangeEvent(topic: 'topic2', kind: 'reconnected')]);

    await sub1.cancel();
    await sub2.cancel();
    channel.dispose();
  });

  test('first connect does not emit reconnected', () async {
    final bodyController = StreamController<List<int>>();
    final channel = RealtimeChannel(
      baseUrl: Uri.parse('http://api.test'),
      tokens: const StaticIdTokenSource('token1'),
      clientFactory: () => TestHttpClient(
        (req) async => http.StreamedResponse(bodyController.stream, 200),
        onClose: () => bodyController.close(),
      ),
    );

    final events = <ChangeEvent>[];
    final sub = channel.on('topicA').listen(events.add);
    await pumpEventQueue();

    expect(events, isEmpty);

    await sub.cancel();
    channel.dispose();
  });

  test('401 refreshes the token once then backs off', () async {
    final tokenSource = _MockTokenSource(
      initialToken: 'stale-token',
      refreshedToken: 'refreshed-token',
    );
    final requests = <http.BaseRequest>[];
    final backoffAttempts = <int>[];

    final channel = RealtimeChannel(
      baseUrl: Uri.parse('http://api.test'),
      tokens: tokenSource,
      clientFactory: () => TestHttpClient(
        (req) async {
          requests.add(req);
          return http.StreamedResponse(const Stream.empty(), 401);
        },
      ),
      backoff: (attempt) {
        backoffAttempts.add(attempt);
        return const Duration(hours: 1); // Avoid spinning in tests
      },
    );

    final sub = channel.on('topic').listen((_) {});
    await pumpEventQueue();

    expect(requests, hasLength(2));
    expect(requests[0].headers['authorization'], 'Bearer stale-token');
    expect(requests[1].headers['authorization'], 'Bearer refreshed-token');

    expect(tokenSource.refreshes, [false, true]);
    expect(backoffAttempts, [0]);

    await sub.cancel();
    channel.dispose();
  });

  test('null token does not open a connection until the next retry', () async {
    final tokenSource = _MockTokenSource(initialToken: null);
    final requests = <http.BaseRequest>[];
    final backoffAttempts = <int>[];
    final bodyController = StreamController<List<int>>();

    final channel = RealtimeChannel(
      baseUrl: Uri.parse('http://api.test'),
      tokens: tokenSource,
      clientFactory: () => TestHttpClient(
        (req) async {
          requests.add(req);
          return http.StreamedResponse(bodyController.stream, 200);
        },
        onClose: () => bodyController.close(),
      ),
      backoff: (attempt) {
        backoffAttempts.add(attempt);
        // On first retry attempt, make token available
        tokenSource.initialToken = 'valid-token';
        return Duration.zero;
      },
    );

    final sub = channel.on('topic').listen((_) {});
    await pumpEventQueue();

    expect(backoffAttempts, [0]);
    expect(requests, hasLength(1));
    expect(requests[0].headers['authorization'], 'Bearer valid-token');

    await sub.cancel();
    channel.dispose();
  });

  test('closes the connection idleGrace after the last listener cancels (fake clock via fakeAsync)', () {
    fakeAsync((async) {
      TestHttpClient? activeClient;
      final streamController = StreamController<List<int>>();

      final channel = RealtimeChannel(
        baseUrl: Uri.parse('http://api.test'),
        tokens: const StaticIdTokenSource('token'),
        clientFactory: () {
          final client = TestHttpClient(
            (req) async => http.StreamedResponse(streamController.stream, 200),
            onClose: () => streamController.close(),
          );
          activeClient = client;
          return client;
        },
        idleGrace: const Duration(seconds: 10),
      );

      final sub = channel.on('topic').listen((_) {});
      async.flushMicrotasks();

      expect(activeClient, isNotNull);
      expect(activeClient!.isClosed, isFalse);

      sub.cancel();
      async.flushMicrotasks();

      // 9 seconds elapsed: connection remains open
      async.elapse(const Duration(seconds: 9));
      expect(activeClient!.isClosed, isFalse);

      // 1 more second elapsed: idleGrace reached, connection closed
      async.elapse(const Duration(seconds: 1));
      expect(activeClient!.isClosed, isTrue);

      channel.dispose();
    });
  });

  test('pause closes and resume reopens', () async {
    final clients = <TestHttpClient>[];
    final streamControllers = <StreamController<List<int>>>[];

    final channel = RealtimeChannel(
      baseUrl: Uri.parse('http://api.test'),
      tokens: const StaticIdTokenSource('token'),
      clientFactory: () {
        final ctrl = StreamController<List<int>>();
        streamControllers.add(ctrl);
        final client = TestHttpClient(
          (req) async => http.StreamedResponse(ctrl.stream, 200),
          onClose: () => ctrl.close(),
        );
        clients.add(client);
        return client;
      },
      backoff: (_) => Duration.zero,
    );

    final sub = channel.on('topic').listen((_) {});
    await pumpEventQueue();

    expect(clients, hasLength(1));
    expect(clients[0].isClosed, isFalse);

    channel.pause();
    await pumpEventQueue();

    expect(clients[0].isClosed, isTrue);

    channel.resume();
    await pumpEventQueue();

    expect(clients, hasLength(2));
    expect(clients[1].isClosed, isFalse);

    await sub.cancel();
    channel.dispose();
  });

  test('ignores malformed change data', () async {
    final bodyController = StreamController<List<int>>();
    final channel = RealtimeChannel(
      baseUrl: Uri.parse('http://api.test'),
      tokens: const StaticIdTokenSource('token'),
      clientFactory: () => TestHttpClient(
        (req) async => http.StreamedResponse(bodyController.stream, 200),
        onClose: () => bodyController.close(),
      ),
    );

    final events = <ChangeEvent>[];
    final sub = channel.on('topic').listen(events.add);
    await pumpEventQueue();

    bodyController.add(utf8.encode('event: change\ndata: not valid json\n\n'));
    bodyController.add(utf8.encode('event: change\ndata: {"no_topic":"foo"}\n\n'));
    bodyController.add(utf8.encode('event: change\ndata: [1, 2, 3]\n\n'));
    bodyController.add(utf8.encode('event: other\ndata: {"topic":"topic","kind":"other"}\n\n'));
    bodyController.add(utf8.encode('event: change\ndata: {"topic":"topic","kind":"valid.event"}\n\n'));

    await pumpEventQueue();

    expect(events, [
      const ChangeEvent(topic: 'topic', kind: 'valid.event'),
    ]);

    await sub.cancel();
    channel.dispose();
  });

  test('realtimeChannelProvider sets RealtimeChannelHolder.current and disposes it', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer(
      overrides: [
        backendConfigProvider.overrideWithValue(
          BackendConfig.parse(backend: 'selfhosted', baseUrl: 'http://api.test'),
        ),
        idTokenSourceProvider.overrideWithValue(
          const StaticIdTokenSource('token'),
        ),
      ],
    );

    expect(RealtimeChannelHolder.current, isNull);

    final channel = container.read(realtimeChannelProvider);
    expect(channel, isNotNull);
    expect(RealtimeChannelHolder.current, same(channel));

    container.dispose();
    expect(RealtimeChannelHolder.current, isNull);
  });
}
