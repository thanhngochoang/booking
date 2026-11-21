// test/data/http/sse_parser_test.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/http/sse_parser.dart';

void main() {
  test('splits one message delivered in one-byte chunks', () async {
    const raw = 'event: test\ndata: hello world\n\n';
    final byteChunks = utf8.encode(raw).map((b) => [b]);
    final stream = Stream.fromIterable(byteChunks);

    final messages = await parseSse(stream).toList();
    expect(messages, [
      const SseMessage(event: 'test', data: 'hello world'),
    ]);
  });

  test('a multi-byte character split across chunks decodes', () async {
    // 'Thợ ảnh' contains multi-byte UTF-8 characters:
    // 'ợ' is 0x1EE3 (3 bytes in UTF-8: 0xE1, 0xBB, 0xA3)
    // 'ả' is 0x1EA3 (3 bytes in UTF-8: 0xE1, 0xBA, 0xA3)
    const raw = 'data: Thợ ảnh\n\n';
    final bytes = utf8.encode(raw);
    // Split into individual 1-byte chunks to ensure multi-byte character is split
    final stream = Stream.fromIterable(bytes.map((b) => [b]));

    final messages = await parseSse(stream).toList();
    expect(messages, [
      const SseMessage(event: 'message', data: 'Thợ ảnh'),
    ]);
  });

  test('CRLF and CR line ends', () async {
    const rawWithCrlf = 'event: first\r\ndata: line1\r\n\r\n';
    const rawWithCr = 'event: second\rdata: line2\r\r';

    final messagesCrlf = await parseSse(
      Stream.value(utf8.encode(rawWithCrlf)),
    ).toList();
    expect(messagesCrlf, [
      const SseMessage(event: 'first', data: 'line1'),
    ]);

    final messagesCr = await parseSse(
      Stream.value(utf8.encode(rawWithCr)),
    ).toList();
    expect(messagesCr, [
      const SseMessage(event: 'second', data: 'line2'),
    ]);
  });

  test('joins two data lines with a newline', () async {
    const raw = 'data: first line\ndata: second line\n\n';
    final messages = await parseSse(
      Stream.value(utf8.encode(raw)),
    ).toList();
    expect(messages, [
      const SseMessage(event: 'message', data: 'first line\nsecond line'),
    ]);
  });

  test('ignores comment lines and unknown fields', () async {
    const raw =
        ': this is a comment\n'
        'id: 12345\n'
        'retry: 3000\n'
        'foo: bar\n'
        'data: valid message\n'
        ': another comment\n'
        '\n';
    final messages = await parseSse(
      Stream.value(utf8.encode(raw)),
    ).toList();
    expect(messages, [
      const SseMessage(event: 'message', data: 'valid message'),
    ]);
  });

  test('blank line without data emits nothing', () async {
    const raw = '\n\n: comment\n\nevent: ping\n\n\n';
    final messages = await parseSse(
      Stream.value(utf8.encode(raw)),
    ).toList();
    expect(messages, isEmpty);
  });
}
