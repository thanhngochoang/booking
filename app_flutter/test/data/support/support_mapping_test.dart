import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/support/support_thread.dart';
import '../../support/fake_support_repository.dart';

void main() {
  group('Support mapping tests', () {
    test('watchThread of a missing help thread emits null', () async {
      final fake = FakeSupportRepository();
      addTearDown(fake.dispose);

      final stream = fake.watchThread('help_u1');
      expect(await stream.first, isNull);
    });

    test('SupportMessage maps senderRole staff with name Hỗ trợ', () {
      final now = DateTime.utc(2026, 10, 10, 12, 0);
      final raw = <String, dynamic>{
        'threadId': 'help_u1',
        'senderId': 'staff_1',
        'senderRole': 'staff',
        'senderName': 'Hỗ trợ',
        'body': 'Chào bạn, chúng tôi đã nhận thông tin.',
        'createdAt': Timestamp.fromDate(now),
      };

      final msg = SupportMessage.fromMap('m1', raw);
      expect(msg.id, 'm1');
      expect(msg.senderRole, SupportSenderRole.staff);
      expect(msg.senderName, 'Hỗ trợ');
      expect(msg.body, 'Chào bạn, chúng tôi đã nhận thông tin.');
      expect(msg.createdAt, now);

      final mappedBack = msg.toMap();
      expect(mappedBack['senderRole'], 'staff');
      expect(mappedBack['senderName'], 'Hỗ trợ');
      expect(mappedBack['body'], 'Chào bạn, chúng tôi đã nhận thông tin.');
    });

    test('send without threadId calls sendSupportMessage with threadId null and returns help_{uid}', () async {
      final fake = FakeSupportRepository();
      addTearDown(fake.dispose);

      final returnedId = await fake.send(text: 'Xin chào', clientId: 'c1');
      expect(returnedId, 'help_test_user');
      expect(fake.sentCalls.length, 1);
      expect(fake.sentCalls[0].threadId, isNull);
      expect(fake.sentCalls[0].text, 'Xin chào');
      expect(fake.sentCalls[0].clientId, 'c1');
    });

    test('SupportThread round-trips correctly', () {
      final now = DateTime.utc(2026, 10, 10, 12, 0);
      final raw = <String, dynamic>{
        'kind': 'help',
        'ownerId': 'u1',
        'disputeId': null,
        'participants': ['u1'],
        'status': 'open',
        'awaitingStaff': true,
        'lastMessageAt': Timestamp.fromDate(now),
        'lastMessagePreview': 'Tin nhắn xem trước',
        'lastSenderRole': 'customer',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final thread = SupportThread.fromMap('help_u1', raw);
      expect(thread.id, 'help_u1');
      expect(thread.kind, SupportThreadKind.help);
      expect(thread.ownerId, 'u1');
      expect(thread.participants, ['u1']);
      expect(thread.status, 'open');
      expect(thread.awaitingStaff, isTrue);
      expect(thread.lastMessageAt, now);
      expect(thread.lastSenderRole, SupportSenderRole.customer);

      final mappedBack = thread.toMap();
      expect(mappedBack['id'], 'help_u1');
      expect(mappedBack['kind'], 'help');
      expect(mappedBack['awaitingStaff'], isTrue);
      expect(mappedBack['lastSenderRole'], 'customer');
    });
  });
}
