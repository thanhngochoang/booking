// lib/data/http/sse_parser.dart
import 'dart:async';
import 'dart:convert';

/// A Server-Sent Event message parsed from an SSE stream.
class SseMessage {
  const SseMessage({this.event = 'message', required this.data});

  final String event;
  final String data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SseMessage &&
          runtimeType == other.runtimeType &&
          event == other.event &&
          data == other.data;

  @override
  int get hashCode => Object.hash(event, data);

  @override
  String toString() => 'SseMessage(event: $event, data: $data)';
}

/// Splits a text stream into lines across chunk boundaries, handling \n, \r\n,
/// and standalone \r line terminators.
Stream<String> _splitLines(Stream<String> textStream) {
  late StreamController<String> controller;
  StreamSubscription<String>? sub;
  bool pendingCr = false;
  final sb = StringBuffer();

  controller = StreamController<String>(
    onListen: () {
      sub = textStream.listen(
        (chunk) {
          for (var i = 0; i < chunk.length; i++) {
            final code = chunk.codeUnitAt(i);
            if (pendingCr) {
              pendingCr = false;
              if (code == 10 /* \n */) {
                // \r was already handled as a line break; skip \n of \r\n.
                continue;
              }
            }
            if (code == 13 /* \r */) {
              controller.add(sb.toString());
              sb.clear();
              pendingCr = true;
            } else if (code == 10 /* \n */) {
              controller.add(sb.toString());
              sb.clear();
            } else {
              sb.writeCharCode(code);
            }
          }
        },
        onError: controller.addError,
        onDone: () {
          if (sb.isNotEmpty || pendingCr) {
            controller.add(sb.toString());
            sb.clear();
          }
          controller.close();
        },
      );
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () => sub?.cancel(),
  );
  return controller.stream;
}

/// Parses a byte stream into a stream of [SseMessage]s according to the SSE spec:
/// - UTF-8 decoding across chunk boundaries
/// - \n, \r\n and \r line ends
/// - multi-line data: joined with \n
/// - comment lines (: prefix) and unknown fields ignored
/// - a message is emitted on the blank line
/// - default event name 'message'
Stream<SseMessage> parseSse(Stream<List<int>> bytes) async* {
  String? dataBuffer;
  String currentEvent = 'message';

  await for (final line in _splitLines(bytes.transform(utf8.decoder))) {
    if (line.isEmpty) {
      if (dataBuffer != null) {
        yield SseMessage(event: currentEvent, data: dataBuffer);
      }
      currentEvent = 'message';
      dataBuffer = null;
    } else if (line.startsWith(':')) {
      // Comment line - ignore.
    } else {
      final colonIndex = line.indexOf(':');
      final String field;
      var value = '';
      if (colonIndex >= 0) {
        field = line.substring(0, colonIndex);
        value = line.substring(colonIndex + 1);
        if (value.startsWith(' ')) {
          value = value.substring(1);
        }
      } else {
        field = line;
      }

      if (field == 'event') {
        currentEvent = value;
      } else if (field == 'data') {
        dataBuffer = dataBuffer == null ? value : '$dataBuffer\n$value';
      }
      // Unknown fields are ignored.
    }
  }
}
