// lib/data/http/realtime_channel.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:photobooking/data/auth/id_token_source.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/api_providers.dart';
import 'package:photobooking/data/http/sse_parser.dart';

/// A change notification event received over the realtime channel.
class ChangeEvent {
  const ChangeEvent({required this.topic, required this.kind});

  final String topic;
  final String kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChangeEvent &&
          runtimeType == other.runtimeType &&
          topic == other.topic &&
          kind == other.kind;

  @override
  int get hashCode => Object.hash(topic, kind);

  @override
  String toString() => 'ChangeEvent(topic: $topic, kind: $kind)';
}

/// Manages a single Server-Sent Events (SSE) connection to `/v1/events` for the
/// entire app, dispatching [ChangeEvent]s to topic listeners.
///
/// - The connection opens when the first topic listener subscribes and closes
///   [idleGrace] after the last listener cancels.
/// - Reconnects with exponential backoff on drop or error.
/// - Emits `ChangeEvent(topic: <t>, kind: 'reconnected')` to every subscribed
///   topic after every successful reconnect (not the first connect).
class RealtimeChannel {
  RealtimeChannel({
    required this.baseUrl,
    required this.tokens,
    http.Client Function()? clientFactory,
    this.backoff,
    this.idleGrace = const Duration(seconds: 10),
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final Uri baseUrl;
  final IdTokenSource tokens;
  final http.Client Function() _clientFactory;
  final Duration Function(int attempt)? backoff;
  final Duration idleGrace;

  final Map<String, StreamController<ChangeEvent>> _controllers = {};
  final Set<String> _activeTopics = {};

  bool _disposed = false;
  bool _paused = false;
  bool _hasConnectedOnce = false;
  int _attempt = 0;

  Timer? _idleTimer;
  Timer? _reconnectTimer;
  Timer? _connectionUpTimer;

  http.Client? _activeClient;
  StreamSubscription<SseMessage>? _sseSubscription;
  Completer<void>? _streamCompleter;
  Future<void>? _connectionLoop;

  /// Returns a stream of [ChangeEvent]s for the given [topic].
  Stream<ChangeEvent> on(String topic) {
    if (_disposed) {
      throw StateError('RealtimeChannel has been disposed');
    }
    final controller = _controllers.putIfAbsent(topic, () {
      late StreamController<ChangeEvent> c;
      c = StreamController<ChangeEvent>.broadcast(
        onListen: () {
          _activeTopics.add(topic);
          _onTopicSubscribed();
        },
        onCancel: () {
          _activeTopics.remove(topic);
          _onTopicUnsubscribed();
        },
      );
      return c;
    });
    return controller.stream;
  }

  void _onTopicSubscribed() {
    if (_disposed) return;
    _idleTimer?.cancel();
    _idleTimer = null;

    if (!_paused) {
      _ensureConnected();
    }
  }

  void _onTopicUnsubscribed() {
    if (_disposed) return;
    if (_activeTopics.isEmpty) {
      _idleTimer?.cancel();
      _idleTimer = Timer(idleGrace, () {
        _idleTimer = null;
        _disconnect();
      });
    }
  }

  /// Pauses the channel (e.g. app hidden), closing the connection.
  void pause() {
    if (_disposed || _paused) return;
    _paused = true;
    _disconnect();
  }

  /// Resumes the channel (e.g. app shown), re-opening the connection if there
  /// are active listeners.
  void resume() {
    if (_disposed || !_paused) return;
    _paused = false;
    if (_activeTopics.isNotEmpty) {
      _ensureConnected();
    }
  }

  /// Disposes of all resources, timers, and controllers.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _disconnect();
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _activeTopics.clear();
  }

  void _disconnect() {
    _connectionUpTimer?.cancel();
    _connectionUpTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_streamCompleter != null && !_streamCompleter!.isCompleted) {
      _streamCompleter!.complete();
    }
    _streamCompleter = null;
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _activeClient?.close();
    _activeClient = null;
  }

  void _ensureConnected() {
    if (_disposed || _paused || _activeTopics.isEmpty) return;
    if (_connectionLoop != null) return;

    _connectionLoop = _connect().whenComplete(() {
      _connectionLoop = null;
    });
  }

  Uri _uriFor(String path) {
    final prefix = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return baseUrl.replace(path: '$prefix$path');
  }

  http.Request _buildRequest(String token) {
    return http.Request('GET', _uriFor('/v1/events'))
      ..headers['authorization'] = 'Bearer $token'
      ..headers['accept'] = 'text/event-stream'
      ..headers['accept-encoding'] = 'identity';
  }

  Duration _defaultBackoff(int attempt) {
    final baseSec = min(30.0, pow(2.0, attempt).toDouble());
    final jitter = Random().nextDouble() * 0.5;
    return Duration(milliseconds: ((baseSec + jitter) * 1000).round());
  }

  void _scheduleRetry() {
    if (_disposed || _paused || _activeTopics.isEmpty) return;
    _reconnectTimer?.cancel();

    final customBackoff = backoff;
    final delay = customBackoff != null
        ? customBackoff(_attempt)
        : _defaultBackoff(_attempt);
    _attempt++;

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _ensureConnected();
    });
  }

  Future<void> _connect() async {
    if (_disposed || _paused || _activeTopics.isEmpty) return;

    String? token;
    try {
      token = await tokens.token(forceRefresh: false);
    } catch (_) {
      token = null;
    }

    if (_disposed || _paused || _activeTopics.isEmpty) return;

    if (token == null) {
      _scheduleRetry();
      return;
    }

    final client = _clientFactory();
    _activeClient = client;

    http.StreamedResponse response;
    try {
      final req = _buildRequest(token);
      response = await client.send(req);
    } catch (_) {
      client.close();
      if (_activeClient == client) _activeClient = null;
      _scheduleRetry();
      return;
    }

    if (_disposed || _paused || _activeTopics.isEmpty) {
      client.close();
      if (_activeClient == client) _activeClient = null;
      return;
    }

    if (response.statusCode == 401) {
      try {
        token = await tokens.token(forceRefresh: true);
      } catch (_) {
        token = null;
      }

      if (_disposed || _paused || _activeTopics.isEmpty) {
        client.close();
        if (_activeClient == client) _activeClient = null;
        return;
      }

      if (token == null) {
        client.close();
        if (_activeClient == client) _activeClient = null;
        _scheduleRetry();
        return;
      }

      try {
        final retryReq = _buildRequest(token);
        response = await client.send(retryReq);
      } catch (_) {
        client.close();
        if (_activeClient == client) _activeClient = null;
        _scheduleRetry();
        return;
      }

      if (_disposed || _paused || _activeTopics.isEmpty) {
        client.close();
        if (_activeClient == client) _activeClient = null;
        return;
      }

      if (response.statusCode == 401 ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        client.close();
        if (_activeClient == client) _activeClient = null;
        _scheduleRetry();
        return;
      }
    } else if (response.statusCode < 200 || response.statusCode >= 300) {
      client.close();
      if (_activeClient == client) _activeClient = null;
      _scheduleRetry();
      return;
    }

    // Connected successfully (HTTP 200)
    if (_hasConnectedOnce) {
      for (final topic in _activeTopics.toList()) {
        _controllers[topic]?.add(
          ChangeEvent(topic: topic, kind: 'reconnected'),
        );
      }
    } else {
      _hasConnectedOnce = true;
    }

    _connectionUpTimer?.cancel();
    _connectionUpTimer = Timer(const Duration(seconds: 10), () {
      _attempt = 0;
    });

    final completer = Completer<void>();
    _streamCompleter = completer;

    final sub = parseSse(response.stream).listen(
      (msg) {
        if (msg.event == 'change') {
          try {
            final decoded = jsonDecode(msg.data);
            if (decoded is Map) {
              final topic = decoded['topic'];
              if (topic is String && topic.isNotEmpty) {
                final kind = decoded['kind'] is String
                    ? decoded['kind'] as String
                    : 'change';
                _controllers[topic]?.add(ChangeEvent(topic: topic, kind: kind));
              }
            }
          } catch (_) {
            // Malformed JSON is ignored.
          }
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: false,
    );
    _sseSubscription = sub;

    await completer.future;

    _connectionUpTimer?.cancel();
    _connectionUpTimer = null;
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _streamCompleter = null;
    client.close();
    if (_activeClient == client) _activeClient = null;

    if (!_disposed && !_paused && _activeTopics.isNotEmpty) {
      _scheduleRetry();
    }
  }
}

/// Static holder exposing the active [RealtimeChannel] to `watch_query.dart`.
class RealtimeChannelHolder {
  static RealtimeChannel? current;
}

/// Riverpod provider for [RealtimeChannel].
final realtimeChannelProvider = Provider<RealtimeChannel>((ref) {
  final ApiClient apiClient = ref.watch(apiClientProvider);
  final channel = RealtimeChannel(
    baseUrl: apiClient.baseUrl,
    tokens: ref.watch(idTokenSourceProvider),
  );
  RealtimeChannelHolder.current = channel;

  final lifecycle = AppLifecycleListener(
    onHide: channel.pause,
    onShow: channel.resume,
  );

  ref.onDispose(() {
    if (RealtimeChannelHolder.current == channel) {
      RealtimeChannelHolder.current = null;
    }
    lifecycle.dispose();
    channel.dispose();
  });
  return channel;
});
