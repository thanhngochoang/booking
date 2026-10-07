// test/features/event_chat/event_chat_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/events/event_chat.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

import '../../support/event_world.dart';

const _sw = Size(390, 900);

Finder _byKey(String k) => find.byKey(Key(k));

GroupChatThread _thread({
  bool modOnly = false,
  DateTime? readOnlyAt,
  int members = 18,
}) => GroupChatThread(
  id: 'event_ev1',
  eventId: 'ev1',
  title: 'Photo walk phố cổ',
  memberCount: members,
  moderators: const ['p1'],
  moderatorsOnly: modOnly,
  readOnlyAt: readOnlyAt,
);

ChatMessage _msg(
  String id,
  String? from,
  String name,
  String body, {
  int minutesAgo = 1,
  MessageType type = MessageType.text,
  String? imagePath,
  DateTime? deletedAt,
  SystemPayload? system,
}) => ChatMessage(
  id: id,
  senderId: from,
  senderName: name,
  type: type,
  body: body.isEmpty ? null : body,
  imagePath: imagePath,
  system: system,
  deletedAt: deletedAt,
  createdAt: eventNow.subtract(Duration(minutes: minutesAgo)),
);

EventsWorld _world({
  String uid = 'u1',
  GroupMemberState? me = const GroupMemberState(role: GroupRole.member),
  GroupChatThread? chat,
  bool noChat = false,
  List<ChatMessage>? messages,
  PinnedMessage? pin,
  List<List<PickedImage>> picks = const [],
}) {
  final w = EventsWorld(
    uid: uid,
    events: [detailOf('ev1', priceVnd: 0)],
    registrations: [registrationOf('r1', 'ev1', userId: uid)],
    pickerAnswers: picks,
  );
  w.chat
    ..setChat(noChat ? null : (chat ?? _thread()))
    ..setMe(me)
    ..setMessages(
      messages ??
          [
            _msg('m1', 'u2', 'Lan Anh', 'Mình đến sớm 10 phút', minutesAgo: 5),
            _msg(
              'm2',
              'u3',
              'Minh Khoa',
              'Mình ạ, hẹn gặp ở cổng',
              minutesAgo: 4,
            ),
            _msg('m3', uid, 'Tôi', 'Cảm ơn mọi người!', minutesAgo: 3),
          ],
    )
    ..setPin(pin);
  return w;
}

final _pin = PinnedMessage(
  messageId: 'm0',
  body: 'Điểm hẹn 06:00 cổng đền Ngọc Sơn, mang nước và pin dự phòng.',
  senderName: 'Quốc Bảo',
  pinnedAt: eventNow,
);

String _hint(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!.hintText!;

bool _fieldEnabled(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).enabled ?? true;

void main() {
  group('S11.06 group chat', () {
    testWidgets('shows the title, the member count and the messages', (
      tester,
    ) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(find.text('Photo walk phố cổ'), findsOneWidget);
      expect(find.text('18 thành viên'), findsOneWidget);
      expect(find.text('Mình đến sớm 10 phút'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (x) => x is ScreenCode && x.code == ScreenCodes.eventChat,
        ),
        findsOneWidget,
      );
      expect(w.chat.markedRead, greaterThan(0));
    });

    testWidgets("other people's bubbles show their names, mine does not", (
      tester,
    ) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(find.text('Lan Anh'), findsOneWidget);
      expect(find.text('Minh Khoa'), findsOneWidget);
      expect(find.text('Tôi'), findsNothing);
      expect(find.text('Cảm ơn mọi người!'), findsOneWidget);
    });

    testWidgets('pinned message shows at the top and expands on tap', (
      tester,
    ) async {
      final w = _world(pin: _pin);
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(find.text('Ghim · Quốc Bảo'), findsOneWidget);
      // Mock `.ctx .ic`: push_pin in a 30px round field-filled well.
      expect(tester.getSize(_byKey('chat-pin-icon')), const Size(30, 30));
      final well = tester.widget<Container>(_byKey('chat-pin-icon'));
      expect((well.decoration! as BoxDecoration).shape, BoxShape.circle);
      expect(
        find.descendant(
          of: _byKey('chat-pin-icon'),
          matching: find.byWidgetPredicate(
            (w) => w is AppIcon && w.icon == AppIcons.pushPin,
          ),
        ),
        findsOneWidget,
      );
      final card = tester.getTopLeft(_byKey('chat-pin')).dy;
      final first = tester.getTopLeft(find.text('Mình đến sớm 10 phút')).dy;
      expect(card, lessThan(first));
      final collapsed = tester.getSize(_byKey('chat-pin')).height;
      await tester.tap(_byKey('chat-pin'));
      await settle(tester);
      expect(
        tester.getSize(_byKey('chat-pin')).height,
        greaterThanOrEqualTo(collapsed),
      );
    });

    testWidgets('images, locations and system lines render', (tester) async {
      final w = _world(
        messages: [
          _msg(
            's1',
            null,
            '',
            '',
            type: MessageType.system,
            minutesAgo: 6,
            system: const SystemPayload(
              kind: 'member_joined',
              name: 'Thảo Vy',
              userId: 'u9',
            ),
          ),
          _msg(
            'i1',
            'u2',
            'Lan Anh',
            '',
            type: MessageType.image,
            imagePath: 'chats/event_ev1/u2/a.jpg',
            minutesAgo: 5,
          ),
          _msg(
            'l1',
            'u3',
            'Minh Khoa',
            '',
            type: MessageType.location,
            minutesAgo: 4,
          ),
        ],
      );
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(find.text('Thảo Vy đã vào nhóm'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('photo:https://storage.test/chats/event_ev1/u2/a.jpg'),
        ),
        findsOneWidget,
      );
      expect(find.text('Vị trí của Minh Khoa'), findsOneWidget);
    });

    testWidgets('a deleted message stays as a tombstone', (tester) async {
      final w = _world(
        messages: [_msg('d1', 'u2', 'Lan Anh', 'bí mật', deletedAt: eventNow)],
      );
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(find.text('Tin nhắn đã bị xoá'), findsOneWidget);
      expect(find.text('bí mật'), findsNothing);
    });

    testWidgets('a member sends text from the composer', (tester) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(_hint(tester), 'Nhắn cho nhóm…');
      await tester.enterText(find.byType(TextField), 'Xin chào cả nhóm');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Gửi tin nhắn'));
      await settle(tester);
      expect(w.chat.texts.single.text, 'Xin chào cả nhóm');
      expect(w.chat.texts.single.eventId, 'ev1');
      expect(find.text('Xin chào cả nhóm'), findsOneWidget);
    });

    testWidgets('the image button sends a photo', (tester) async {
      final w = _world(
        picks: [
          [const PickedImage(path: '/tmp/x.jpg', name: 'x.jpg')],
        ],
      );
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.tap(find.bySemanticsLabel('Chọn ảnh'));
      await settle(tester);
      expect(w.chat.images.single.image.name, 'x.jpg');
    });

    testWidgets('muted members see the disabled composer with the reason', (
      tester,
    ) async {
      final w = _world(
        me: GroupMemberState(
          role: GroupRole.member,
          mutedUntil: eventNow.add(const Duration(hours: 5)),
        ),
      );
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(_fieldEnabled(tester), isFalse);
      expect(_hint(tester), 'Bạn đang bị tắt tiếng trong nhóm');
    });

    testWidgets('an elapsed mute no longer blocks', (tester) async {
      final w = _world(
        me: GroupMemberState(
          role: GroupRole.member,
          mutedUntil: eventNow.subtract(const Duration(hours: 1)),
        ),
      );
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(_fieldEnabled(tester), isTrue);
    });

    testWidgets('moderators-only disables members but not moderators', (
      tester,
    ) async {
      final member = _world(chat: _thread(modOnly: true));
      await member.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(_fieldEnabled(tester), isFalse);
      expect(_hint(tester), 'Chỉ điều hành được nhắn');
    });

    testWidgets('moderators-only lets a moderator write', (tester) async {
      final mod = _world(
        uid: 'p1',
        me: const GroupMemberState(role: GroupRole.moderator),
        chat: _thread(modOnly: true),
      );
      await mod.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(_fieldEnabled(tester), isTrue);
    });

    testWidgets('read-only shows Nhóm đã đóng and no composer', (tester) async {
      final w = _world(
        chat: _thread(readOnlyAt: eventNow.subtract(const Duration(days: 1))),
      );
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(find.text('Nhóm đã đóng'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a moderator pins from the long-press menu', (tester) async {
      final w = _world(
        uid: 'p1',
        me: const GroupMemberState(role: GroupRole.moderator),
      );
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.longPress(find.text('Mình ạ, hẹn gặp ở cổng'));
      await settle(tester);
      await tester.tap(_byKey('msg-pin'));
      await settle(tester);
      expect(w.chat.moderations.single, isA<PinMessage>());
      expect((w.chat.moderations.single as PinMessage).messageId, 'm2');
      expect(find.text('Ghim · Minh Khoa'), findsOneWidget);
    });

    testWidgets('the pinned message offers Bỏ ghim', (tester) async {
      final w = _world(
        uid: 'p1',
        me: const GroupMemberState(role: GroupRole.moderator),
        messages: [_msg('m0', 'p1', 'Quốc Bảo', 'Điểm hẹn 06:00')],
        pin: PinnedMessage(
          messageId: 'm0',
          body: 'Điểm hẹn 06:00',
          senderName: 'Quốc Bảo',
          pinnedAt: eventNow,
        ),
      );
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.longPress(find.text('Điểm hẹn 06:00').last);
      await settle(tester);
      await tester.tap(_byKey('msg-pin'));
      await settle(tester);
      expect(w.chat.moderations.single, isA<UnpinMessage>());
      expect(find.text('Ghim · Quốc Bảo'), findsNothing);
    });

    testWidgets('a moderator deletes a message after confirming', (
      tester,
    ) async {
      final w = _world(
        uid: 'p1',
        me: const GroupMemberState(role: GroupRole.moderator),
      );
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.longPress(find.text('Mình đến sớm 10 phút'));
      await settle(tester);
      await tester.tap(_byKey('msg-delete'));
      await settle(tester);
      expect(w.chat.moderations, isEmpty);
      await tester.tap(find.widgetWithText(AppButton, 'Xoá'));
      await settle(tester);
      expect((w.chat.moderations.single as DeleteMessage).messageId, 'm1');
      expect(find.text('Tin nhắn đã bị xoá'), findsOneWidget);
    });

    testWidgets('members have no moderation menu on a long press', (
      tester,
    ) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.longPress(find.text('Mình đến sớm 10 phút'));
      await settle(tester);
      expect(_byKey('msg-pin'), findsNothing);
    });

    testWidgets('a failed send offers retry on the bubble', (tester) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      w.chat.failWith = const ChatException(ChatErrorCode.limitExceeded);
      await tester.enterText(find.byType(TextField), 'Gấp lắm');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Gửi tin nhắn'));
      await settle(tester);
      expect(find.text('Gửi lại'), findsOneWidget);
      expect(
        find.text('Bạn nhắn quá nhanh. Thử lại sau ít giây nhé.'),
        findsOneWidget,
      );
      w.chat.failWith = null;
      // Let the SnackBar go: it sits over the bottom of the list.
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      await tester.tap(find.text('Gửi lại'));
      await settle(tester);
      expect(w.chat.texts, hasLength(2));
      expect(w.chat.texts.last.clientId, w.chat.texts.first.clientId);
      expect(find.text('Gửi lại'), findsNothing);
    });

    testWidgets(
      'a refusal the screen cannot explain says the general text (M2)',
      (tester) async {
        final w = _world();
        await w.pump(tester, path: '/e/ev1/chat', size: _sw);
        // Not muted here, so not_eligible must not claim a mute.
        w.chat.failWith = const ChatException(ChatErrorCode.notEligible);
        await tester.enterText(find.byType(TextField), 'Chào');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Gửi tin nhắn'));
        await settle(tester);
        expect(find.text('Không thực hiện được. Thử lại nhé.'), findsOneWidget);
        expect(find.text('Bạn đang bị tắt tiếng trong nhóm'), findsNothing);
      },
    );

    testWidgets('a refusal after moderators-only switched on says so (M2)', (
      tester,
    ) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.enterText(find.byType(TextField), 'Chào');
      await tester.pump();
      // The switch lands while the message is on its way.
      w.chat
        ..failWith = const ChatException(ChatErrorCode.permissionDenied)
        ..setChat(_thread(modOnly: true));
      await tester.tap(find.bySemanticsLabel('Gửi tin nhắn'));
      await settle(tester);
      expect(find.text('Chỉ điều hành được nhắn'), findsWidgets);
    });

    testWidgets('non-members see Đăng ký để vào nhóm', (tester) async {
      final w = _world(noChat: true, me: null);
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(_byKey('chat-locked'), findsOneWidget);
      expect(find.text('Đăng ký để vào nhóm'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Xem sự kiện'));
      await settle(tester);
      expect(w.location, '/e/ev1');
    });

    testWidgets('a removed member is locked out', (tester) async {
      final w = _world(
        me: const GroupMemberState(role: GroupRole.member, removed: true),
      );
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      expect(_byKey('chat-locked'), findsOneWidget);
    });

    testWidgets('the member list has names and avatars and no phone', (
      tester,
    ) async {
      final w = _world();
      w.chat.setMembers(const [
        GroupMember(uid: 'p1', name: 'Quốc Bảo', role: GroupRole.moderator),
        GroupMember(uid: 'u2', name: 'Lan Anh'),
        GroupMember(uid: 'u1', name: 'Tôi'),
      ]);
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.tap(_byKey('chat-more'));
      await settle(tester);
      await tester.tap(find.text('Thành viên'));
      await settle(tester);
      expect(find.text('Quốc Bảo'), findsOneWidget);
      expect(find.text('Điều hành'), findsOneWidget);
      expect(find.text('Lan Anh'), findsWidgets);
      expect(_byKey('member-menu-u2'), findsNothing); // members cannot moderate
    });

    testWidgets('moderators mute a member for 24 hours and remove another', (
      tester,
    ) async {
      final w = _world(
        uid: 'p1',
        me: const GroupMemberState(role: GroupRole.moderator),
      );
      w.chat.setMembers(const [
        GroupMember(uid: 'p1', name: 'Quốc Bảo', role: GroupRole.moderator),
        GroupMember(uid: 'u2', name: 'Lan Anh'),
        GroupMember(uid: 'u3', name: 'Minh Khoa'),
      ]);
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.tap(_byKey('chat-more'));
      await settle(tester);
      await tester.tap(find.text('Thành viên'));
      await settle(tester);
      expect(_byKey('member-menu-p1'), findsNothing);
      await tester.tap(_byKey('member-menu-u2'));
      await settle(tester);
      await tester.tap(find.text('Tắt tiếng 24 giờ'));
      await settle(tester);
      final mute = w.chat.moderations.single as MuteMember;
      expect((mute.userId, mute.minutes), ('u2', 1440));
      await tester.tap(_byKey('member-menu-u3'));
      await settle(tester);
      await tester.tap(find.text('Gỡ khỏi nhóm'));
      await settle(tester);
      expect(w.chat.moderations, hasLength(1)); // asks first
      await tester.tap(find.widgetWithText(AppButton, 'Gỡ khỏi nhóm'));
      await settle(tester);
      expect((w.chat.moderations.last as RemoveMember).userId, 'u3');
    });

    testWidgets('moderators see Đã mời ra and restore a member (O1)', (
      tester,
    ) async {
      final w = _world(
        uid: 'p1',
        me: const GroupMemberState(role: GroupRole.moderator),
      );
      w.chat.setMembers(const [
        GroupMember(uid: 'p1', name: 'Quốc Bảo', role: GroupRole.moderator),
        GroupMember(uid: 'u2', name: 'Lan Anh'),
        GroupMember(uid: 'u9', name: 'Bị mời ra', removedByModerator: true),
      ]);
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.tap(_byKey('chat-more'));
      await settle(tester);
      await tester.tap(find.text('Thành viên'));
      await settle(tester);
      expect(_byKey('members-removed'), findsOneWidget);
      expect(find.text('Đã mời ra'), findsOneWidget);
      expect(_byKey('member-u9'), findsNothing); // not among the members
      await tester.tap(_byKey('restore-u9'));
      await settle(tester);
      expect((w.chat.moderations.single as RestoreMember).userId, 'u9');
      expect(_byKey('members-removed'), findsNothing);
      expect(_byKey('member-u9'), findsOneWidget);
    });

    testWidgets('members do not see Đã mời ra', (tester) async {
      final w = _world();
      w.chat.setMembers(const [
        GroupMember(uid: 'p1', name: 'Quốc Bảo', role: GroupRole.moderator),
        GroupMember(uid: 'u9', name: 'Bị mời ra', removedByModerator: true),
      ]);
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.tap(_byKey('chat-more'));
      await settle(tester);
      await tester.tap(find.text('Thành viên'));
      await settle(tester);
      expect(_byKey('members-removed'), findsNothing);
      expect(find.text('Bị mời ra'), findsNothing);
    });

    testWidgets('moderators switch Chỉ điều hành được nhắn in the menu', (
      tester,
    ) async {
      final w = _world(
        uid: 'p1',
        me: const GroupMemberState(role: GroupRole.moderator),
      );
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.tap(_byKey('chat-more'));
      await settle(tester);
      await tester.tap(find.text('Chỉ điều hành được nhắn'));
      await settle(tester);
      expect((w.chat.moderations.single as SetModeratorsOnly).on, isTrue);
      expect(w.chat.chat!.moderatorsOnly, isTrue);
    });

    testWidgets('members do not get the moderators-only switch', (
      tester,
    ) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.tap(_byKey('chat-more'));
      await settle(tester);
      expect(find.text('Chỉ điều hành được nhắn'), findsNothing);
      expect(find.text('Tắt tiếng nhóm'), findsOneWidget);
    });

    testWidgets('Tắt tiếng nhóm only marks this device', (tester) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/chat', size: _sw);
      await tester.tap(_byKey('chat-more'));
      await settle(tester);
      await tester.tap(find.text('Tắt tiếng nhóm'));
      await settle(tester);
      expect(w.chat.moderations, isEmpty);
      expect(find.byIcon(AppIcons.notificationsOff), findsOneWidget);
      await tester.tap(_byKey('chat-more'));
      await settle(tester);
      expect(find.text('Bật tiếng nhóm'), findsOneWidget);
    });

    testWidgets('fits 320dp at 1.3 text scale', (tester) async {
      final w = _world(pin: _pin);
      await w.pump(
        tester,
        path: '/e/ev1/chat',
        size: const Size(320, 700),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
