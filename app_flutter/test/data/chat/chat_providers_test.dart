import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_providers.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';

import '../../support/fake_chat_repository.dart';

class _CountingResolver implements MediaUrlResolver {
  int calls = 0;
  int failures = 0;

  @override
  Future<String> downloadUrl(String storagePath) async {
    calls++;
    if (failures > 0) {
      failures--;
      throw StateError('offline');
    }
    return 'https://storage.test/$storagePath';
  }
}

void main() {
  const path = 'chats/c1/u2/m1.jpg';

  ProviderContainer make({
    MediaUrlResolver? resolver,
    FakeChatRepository? chats,
  }) {
    final c = ProviderContainer(
      overrides: [
        if (resolver != null)
          mediaUrlResolverProvider.overrideWithValue(resolver),
        if (chats != null) chatRepositoryProvider.overrideWithValue(chats),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<String> readOnce(ProviderContainer c) async {
    final sub = c.listen(chatImageUrlProvider(path).future, (_, _) {});
    try {
      return await sub.read();
    } finally {
      sub.close();
      await c.pump();
    }
  }

  test('chatImageUrlProvider resolves through MediaUrlResolver once', () async {
    final resolver = _CountingResolver();
    final c = make(resolver: resolver);

    expect(await readOnce(c), 'https://storage.test/$path');
    expect(await readOnce(c), 'https://storage.test/$path');

    expect(resolver.calls, 1);
  });

  test('an error is not kept: the next read retries', () async {
    final resolver = _CountingResolver()..failures = 1;
    final c = make(resolver: resolver);

    await expectLater(readOnce(c), throwsStateError);
    expect(await readOnce(c), 'https://storage.test/$path');

    expect(resolver.calls, 2);
  });

  test('totalUnreadProvider sums myChatsProvider', () async {
    final chats = FakeChatRepository(currentUserId: 'u1');
    for (final id in ['a', 'b']) {
      chats.seedThread(
        ChatThread(
          id: id,
          kind: ChatKind.inquiry,
          customerId: 'u1',
          photographerId: 'p_$id',
          lastMessageAt: DateTime.utc(2026, 10, 5),
        ),
      );
    }
    chats.seedUnread('a', 2);
    chats.seedUnread('b', 3);
    final c = make(chats: chats);
    final sub = c.listen(totalUnreadProvider, (_, _) {});
    await c.read(myChatsProvider.future);

    expect(sub.read().value, 5);

    await chats.markRead('a');
    await pumpEventQueue();
    expect(sub.read().value, 3);
    sub.close();
  });
}
