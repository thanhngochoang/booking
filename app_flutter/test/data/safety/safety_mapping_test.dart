import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/safety/safety.dart';

void main() {
  group('BlockIndex', () {
    test('hidden is the union; hides(null) is false', () {
      const idx = BlockIndex(
        blockedIds: {'u1', 'u2'},
        blockedByIds: {'u2', 'u3'},
      );
      expect(idx.hidden, {'u1', 'u2', 'u3'});
      expect(idx.blockedByMe('u1'), isTrue);
      expect(idx.blockedByMe('u3'), isFalse);
      expect(idx.blockedMe('u3'), isTrue);
      expect(idx.blockedMe('u1'), isFalse);

      expect(idx.hides('u1'), isTrue);
      expect(idx.hides('u2'), isTrue);
      expect(idx.hides('u3'), isTrue);
      expect(idx.hides('u4'), isFalse);
      expect(idx.hides(null), isFalse);
    });
  });

  group('ReportTarget', () {
    test('user factory sets owner and target', () {
      final t = ReportTarget.user(uid: 'u1', name: 'Minh', avatarUrl: 'http://avatar.jpg');
      expect(t.type, ReportTargetType.user);
      expect(t.id, 'u1');
      expect(t.ownerId, 'u1');
      expect(t.ownerName, 'Minh');
      expect(t.thumbUrl, 'http://avatar.jpg');
    });

    test('post uses authorId as owner and the first image as thumb', () {
      final t = ReportTarget.post(
        postId: 'p1',
        authorId: 'u2',
        authorName: 'An',
        excerpt: 'Chụp cưới',
        thumbUrl: 'http://img1.jpg',
      );
      expect(t.type, ReportTargetType.post);
      expect(t.id, 'p1');
      expect(t.ownerId, 'u2');
      expect(t.ownerName, 'An');
      expect(t.excerpt, 'Chụp cưới');
      expect(t.thumbUrl, 'http://img1.jpg');
    });

    test('message factory keeps chatId and sender', () {
      final t = ReportTarget.message(
        chatId: 'c1',
        messageId: 'm1',
        senderId: 'u3',
        senderName: 'Lan',
        text: 'Nội dung tin nhắn',
      );
      expect(t.type, ReportTargetType.message);
      expect(t.id, 'm1');
      expect(t.chatId, 'c1');
      expect(t.ownerId, 'u3');
      expect(t.ownerName, 'Lan');
      expect(t.excerpt, 'Nội dung tin nhắn');
    });

    test('event factory sets host and cover', () {
      final t = ReportTarget.event(
        eventId: 'e1',
        title: 'Workshop',
        hostId: 'h1',
        hostName: 'Host Name',
        coverUrl: 'http://cover.jpg',
      );
      expect(t.type, ReportTargetType.event);
      expect(t.id, 'e1');
      expect(t.ownerId, 'h1');
      expect(t.ownerName, 'Host Name');
      expect(t.excerpt, 'Workshop');
      expect(t.thumbUrl, 'http://cover.jpg');
    });
  });

  group('ReportReason', () {
    test('codes map properly', () {
      expect(ReportReason.fromCode('spam'), ReportReason.spam);
      expect(ReportReason.fromCode('scam'), ReportReason.scam);
      expect(ReportReason.fromCode('harassment'), ReportReason.harassment);
      expect(ReportReason.fromCode('inappropriate'), ReportReason.inappropriate);
      expect(ReportReason.fromCode('stolen_photos'), ReportReason.stolenPhotos);
      expect(ReportReason.fromCode('impersonation'), ReportReason.impersonation);
      expect(ReportReason.fromCode('other'), ReportReason.other);
      expect(ReportReason.fromCode('unknown'), isNull);
    });
  });
}
