import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/chat/chat.dart';

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  Future<ChatThread> thread(Map<String, dynamic> data) async {
    await db.doc('chats/c1').set(data);
    return ChatThread.fromFirestore(await db.doc('chats/c1').get());
  }

  test('a studio booking chat reads its assignee', () async {
    final t = await thread({
      'kind': 'booking',
      'customerId': 'lan',
      'photographerId': 'cuc',
      'assigneeId': 'an',
      'members': ['lan', 'cuc', 'an'],
      'bookingId': 'b1',
    });
    expect(t.assigneeId, 'an');
    expect(t.copyWith(lastMessagePreview: 'x').assigneeId, 'an');
    expect(t == t.copyWith(), isTrue);
  });

  test('the assignee sees the customer as the chat counterpart', () async {
    final t = await thread({
      'kind': 'booking',
      'customerId': 'lan',
      'photographerId': 'cuc',
      'assigneeId': 'an',
    });
    expect(t.counterpartIdOf('an'), 'lan');
    expect(t.counterpartIdOf('cuc'), 'lan');
    expect(t.counterpartIdOf('lan'), 'cuc');
    expect(t.isProviderSide('an'), isTrue);
    expect(t.isProviderSide('cuc'), isTrue);
    expect(t.isProviderSide('lan'), isFalse);
  });

  test('a chat without assignee keeps the two parties', () async {
    final t = await thread({
      'kind': 'inquiry',
      'customerId': 'lan',
      'photographerId': 'minh',
      'assigneeId': '',
    });
    expect(t.assigneeId, isNull);
    expect(t.counterpartIdOf('minh'), 'lan');
    expect(t.counterpartIdOf('lan'), 'minh');
    expect(t.isProviderSide('an'), isFalse);
  });
}
