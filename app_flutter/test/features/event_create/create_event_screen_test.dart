import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/staff_role.dart';
import 'package:photobooking/data/events/event_card_data_of.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/event_create/create_event_controller.dart';
import 'package:photobooking/features/event_create/create_event_screen.dart';
import 'package:photobooking/features/event_create/event_draft_store.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import '../../support/event_world.dart';

const _size = Size(390, 900);
const _args = CreateEventArgs();
const _cover = PickedImage(path: '/tmp/cover.jpg', name: 'cover.jpg');
const _cover2 = PickedImage(path: '/tmp/cover2.jpg', name: 'cover2.jpg');

EventsWorld _photographer({
  bool onboarded = true,
  StaffRole? staff,
  Map<String, Object> prefs = const {},
  List<List<PickedImage>> covers = const [
    [_cover],
  ],
}) => EventsWorld(
  role: staff == null ? UserRole.photographer : UserRole.customer,
  onboardingComplete: onboarded,
  staff: staff,
  prefsValues: prefs,
  pickerAnswers: covers,
);

Future<void> _open(
  WidgetTester tester,
  EventsWorld w, {
  String path = '/events/new',
  double textScale = 1,
  Size size = _size,
}) => w.pump(
  tester,
  path: path,
  organizer: true,
  textScale: textScale,
  size: size,
);

CreateEventController _ctl(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CreateEventScreen)))
        .read(createEventControllerProvider(_args).notifier);

CreateEventState _state(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CreateEventScreen)))
        .read(createEventControllerProvider(_args));

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<AppButton>(find.byKey(Key(key))).onPressed != null;

Future<void> _stepOne(WidgetTester tester, {bool cover = true}) async {
  if (cover) {
    await tester.tap(find.byKey(const Key('create-event-cover')));
    await settle(tester);
  }
  await tester.enterText(
    find.byKey(const Key('create-event-title')),
    'Photo walk phố cổ',
  );
  await tester.scrollUntilVisible(
    find.byKey(const Key('create-event-type-photo_walk')),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(
    find.byKey(const Key('create-event-type-photo_walk')),
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('create-event-type-photo_walk')));
  await settle(tester);
  // S29: "Không thuộc điểm chụp nào" (the sheet has its own tests).
  _ctl(tester).setSpot(null);
  await settle(tester);
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('create-event-next')));
  await settle(tester);
}

/// Step 2 filled so that it can be published: 13 Oct 2026 09:00–12:00.
Future<void> _fillStepTwo(
  WidgetTester tester, {
  int? price = 250000,
  int capacity = 20,
}) async {
  final c = _ctl(tester);
  c.setDay(DateTime.utc(2026, 10, 13));
  c.setStart(9 * 60);
  c.setEnd(12 * 60);
  c.setCapacity(capacity);
  if (price != null) {
    c.setPrice(price);
  }
  c.setPlaceText(name: 'Hồ Hoàn Kiếm', meetingPoint: 'Cổng đền Ngọc Sơn');
  c.chooseArea('hn-hoan-kiem', lat: 21.0285, lng: 105.8542);
  await settle(tester);
}

void main() {
  group('S12.01', () {
    testWidgets('the empty cover tile has a dashed border (mock, O2)', (
      tester,
    ) async {
      final w = _photographer();
      await _open(tester, w);
      CustomPaint frame() => tester.widget<CustomPaint>(
        find.byKey(const Key('create-event-cover-frame')),
      );
      expect(frame().foregroundPainter, isNotNull);
      await tester.tap(find.byKey(const Key('create-event-cover')));
      await settle(tester);
      // A chosen photo keeps the plain border.
      expect(frame().foregroundPainter, isNull);
    });

    testWidgets('Tiếp tục is disabled until cover, title and type', (
      tester,
    ) async {
      final w = _photographer();
      await _open(tester, w);
      expect(find.text('Thông tin sự kiện'), findsOneWidget);
      expect(find.text('Thêm ảnh bìa 16:10'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(_enabled(tester, 'create-event-next'), isFalse);

      await tester.tap(find.byKey(const Key('create-event-cover')));
      await settle(tester);
      expect(_enabled(tester, 'create-event-next'), isFalse);
      await tester.enterText(
        find.byKey(const Key('create-event-title')),
        'Photo walk',
      );
      await tester.pump();
      expect(_enabled(tester, 'create-event-next'), isFalse);
      await tester.tap(find.byKey(const Key('create-event-type-workshop')));
      await settle(tester);
      expect(_enabled(tester, 'create-event-next'), isTrue);
    });

    testWidgets('the five event types are single-select chips', (tester) async {
      final w = _photographer();
      await _open(tester, w);
      for (final t in ['Photo walk', 'Mini session', 'Workshop', 'Cosplay']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('Khác'), findsOneWidget);
      await tester.tap(find.byKey(const Key('create-event-type-cosplay')));
      await tester.tap(find.byKey(const Key('create-event-type-other')));
      await settle(tester);
      expect(_state(tester).form.type, EventType.other);
    });

    testWidgets('the draft is restored after a restart', (tester) async {
      final w = _photographer();
      await _open(tester, w);
      await tester.enterText(
        find.byKey(const Key('create-event-title')),
        'Mini session mùa thu',
      );
      await tester.tap(find.byKey(const Key('create-event-type-mini_session')));
      await settle(tester);
      expect(w.prefs!.getString(EventDraftStore.key('u1')), isNotNull);

      // A new app run over the same storage.
      await tester.pumpWidget(const SizedBox());
      await _open(tester, w);
      expect(find.text('Mini session mùa thu'), findsOneWidget);
      expect(_state(tester).form.type, EventType.miniSession);
    });

    testWidgets('back with data asks Lưu nháp? and Lưu saves it', (
      tester,
    ) async {
      final w = _photographer();
      await _open(tester, w);
      await _stepOne(tester);
      await tester.tap(find.byKey(const Key('create-event-back')));
      await settle(tester);
      expect(find.text('Lưu nháp?'), findsOneWidget);
      expect(find.text('Lưu'), findsOneWidget);
      expect(find.text('Bỏ'), findsOneWidget);
      await tester.tap(find.byKey(const Key('create-event-keep')));
      await settle(tester);
      expect(w.repo.savedDrafts, isNotEmpty);
      expect(w.location, '/events');
    });

    testWidgets('back with data and Bỏ forgets the local draft', (
      tester,
    ) async {
      final w = _photographer();
      await _open(tester, w);
      await _stepOne(tester, cover: false);
      await tester.tap(find.byKey(const Key('create-event-back')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('create-event-discard')));
      await settle(tester);
      expect(w.prefs!.getString(EventDraftStore.key('u1')), isNull);
      expect(w.repo.savedDrafts, isEmpty);
      expect(w.location, '/events');
    });

    testWidgets('back on an empty form leaves without asking', (tester) async {
      final w = _photographer();
      await _open(tester, w);
      await tester.tap(find.byKey(const Key('create-event-back')));
      await settle(tester);
      expect(find.text('Lưu nháp?'), findsNothing);
      expect(w.location, '/events');
    });

    testWidgets('Tiếp tục saves a server draft and uploads the cover', (
      tester,
    ) async {
      final w = _photographer();
      await _open(tester, w);
      await _stepOne(tester);
      await _next(tester);

      // First save creates the draft without the cover, the second carries it.
      expect(w.repo.savedDrafts, hasLength(2));
      expect(w.repo.savedDrafts.first.coverUrl, isNull);
      expect(w.repo.savedDrafts.first.title, 'Photo walk phố cổ');
      expect(w.repo.savedDrafts.first.eventId, isNull);
      final second = w.repo.savedDrafts.last;
      expect(second.eventId, startsWith('fake-event-'));
      expect(
        second.coverUrl,
        startsWith('https://storage.test/eventCovers/u1/'),
      );
      expect(w.repo.coverPaths, hasLength(1));
      expect(find.text('Lịch và vé'), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('a failed save stays on step 1 with a message', (tester) async {
      final w = _photographer();
      await _open(tester, w);
      await _stepOne(tester);
      w.repo
        ..failWith = const EventError('network')
        ..failOnce = true;
      await _next(tester);
      expect(find.text('Thông tin sự kiện'), findsOneWidget);
      expect(
        find.text('Không lưu được nháp. Kiểm tra mạng rồi thử lại.'),
        findsWidgets,
      );
    });

    testWidgets('a replaced cover deletes the old file after the save', (
      tester,
    ) async {
      final w = _photographer(
        covers: [
          [_cover],
          [_cover2],
        ],
      );
      await _open(tester, w);
      await _stepOne(tester);
      await _next(tester);
      final firstPath = w.repo.coverPaths.values.single;
      expect(w.repo.deletedCovers, isEmpty);

      await tester.tap(find.byKey(const Key('create-event-back')));
      await settle(tester);
      expect(find.text('Thông tin sự kiện'), findsOneWidget);
      await tester.tap(find.byKey(const Key('create-event-cover')));
      await settle(tester);
      expect(w.repo.deletedCovers, isEmpty, reason: 'not before the save');
      await _next(tester);
      expect(w.repo.coverPaths, hasLength(2));
      expect(w.repo.deletedCovers, [firstPath]);
    });

    testWidgets('a failed save keeps the old cover file', (tester) async {
      final w = _photographer(
        covers: [
          [_cover],
          [_cover2],
        ],
      );
      await _open(tester, w);
      await _stepOne(tester);
      await _next(tester);
      await tester.tap(find.byKey(const Key('create-event-back')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('create-event-cover')));
      await settle(tester);
      w.repo
        ..failWith = const EventError('network')
        ..failOnce = true;
      await _next(tester);
      expect(w.repo.deletedCovers, isEmpty);
      expect(find.text('Thông tin sự kiện'), findsOneWidget);
    });

    testWidgets('staff see Tổ chức bởi Nền tảng', (tester) async {
      final staff = _photographer(staff: StaffRole.sales);
      await _open(tester, staff);
      expect(find.text('Tổ chức bởi'), findsOneWidget);
      expect(find.text('Nền tảng'), findsOneWidget);
      expect(
        find.text('Tổ chức hộ một nhiếp ảnh gia sẽ có sau.'),
        findsOneWidget,
      );
    });

    testWidgets('photographers do not see Tổ chức bởi', (tester) async {
      await _open(tester, _photographer());
      expect(find.text('Tổ chức bởi'), findsNothing);
      expect(find.text('Nền tảng'), findsNothing);
    });

    testWidgets('a photographer without onboarding is sent to setup', (
      tester,
    ) async {
      final w = _photographer(onboarded: false);
      await _open(tester, w);
      expect(find.text('Hoàn thiện hồ sơ để tạo sự kiện'), findsOneWidget);
      expect(find.byKey(const Key('create-event-title')), findsNothing);
      await tester.tap(find.text('Hoàn thiện hồ sơ'));
      await settle(tester);
      expect(w.location, '/setup');
    });

    testWidgets('a customer is told who can create events', (tester) async {
      final w = EventsWorld(role: UserRole.customer);
      await _open(tester, w);
      expect(
        find.text('Chỉ nhiếp ảnh gia và nhân viên mới tạo được sự kiện.'),
        findsOneWidget,
      );
    });

    testWidgets('fits 320dp at 1.3 text scale on both steps', (tester) async {
      final w = _photographer();
      await _open(tester, w, size: const Size(320, 640), textScale: 1.3);
      await _stepOne(tester);
      expect(tester.takeException(), isNull);
      await _next(tester);
      await _fillStepTwo(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Lịch và vé'), findsOneWidget);
    });
  });

  group('S12.02', () {
    Future<EventsWorld> toStepTwo(
      WidgetTester tester, {
      StaffRole? staff,
    }) async {
      final w = _photographer(staff: staff);
      await _open(tester, w);
      await _stepOne(tester);
      await _next(tester);
      return w;
    }

    testWidgets('shows the schedule fields and the two hints', (tester) async {
      await toStepTwo(tester);
      for (final t in [
        'Ngày',
        'Giờ bắt đầu',
        'Kết thúc',
        'Sức chứa',
        'Địa điểm',
        'Điểm hẹn',
        'Dùng vị trí hiện tại',
        'Hashtag sự kiện',
        'Giá mỗi người (₫)',
        'Hạn đăng ký',
        'Để giá bằng 0 nếu không thu phí.',
        'Tiền vé được giữ trên ứng dụng và chuyển cho bạn sau khi sự kiện kết thúc.',
        'Lưu nháp',
        'Đăng sự kiện',
      ]) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      // The server made the hashtag at the first save.
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('create-event-hashtag')))
            .controller!
            .text,
        startsWith('Event'),
      );
    });

    testWidgets('end before start shows the error under Kết thúc', (
      tester,
    ) async {
      await toStepTwo(tester);
      final c = _ctl(tester);
      c.setDay(DateTime.utc(2026, 10, 13));
      c.setStart(9 * 60);
      c.setEnd(8 * 60);
      await settle(tester);
      expect(find.text('Giờ kết thúc phải sau giờ bắt đầu'), findsOneWidget);
    });

    testWidgets('start within 2 hours is refused', (tester) async {
      await toStepTwo(tester);
      final c = _ctl(tester);
      // "Now" is 10:00 in Việt Nam; 11:30 is 1.5 hours ahead.
      c.setDay(DateTime.utc(2026, 10, 10));
      c.setStart(11 * 60 + 30);
      c.setEnd(13 * 60);
      await settle(tester);
      expect(
        find.text('Giờ bắt đầu phải sau bây giờ ít nhất 2 giờ'),
        findsOneWidget,
      );
    });

    testWidgets('deadline after start is refused', (tester) async {
      await toStepTwo(tester);
      final c = _ctl(tester);
      c.setDay(DateTime.utc(2026, 10, 13));
      c.setStart(9 * 60);
      c.setEnd(12 * 60);
      c.setDeadline(DateTime.utc(2026, 10, 14));
      await settle(tester);
      expect(find.text('Hạn đăng ký phải trước giờ bắt đầu'), findsOneWidget);
    });

    testWidgets('price 0 previews Không thu phí', (tester) async {
      await toStepTwo(tester);
      await _fillStepTwo(tester, price: 0);
      final preview = find.byKey(const Key('create-event-preview'));
      expect(preview, findsOneWidget);
      expect(
        find.descendant(of: preview, matching: find.text('Không thu phí')),
        findsOneWidget,
      );
      expect(find.text('0₫'), findsNothing);
      expect(find.text('Xem trước'), findsOneWidget);
    });

    testWidgets('a paid price previews the amount', (tester) async {
      await toStepTwo(tester);
      await _fillStepTwo(tester, price: 250000);
      final preview = find.byKey(const Key('create-event-preview'));
      expect(
        find.descendant(of: preview, matching: find.text('Không thu phí')),
        findsNothing,
      );
      expect(
        find.descendant(of: preview, matching: find.textContaining('250')),
        findsWidgets,
      );
    });

    testWidgets('the preview card equals the customer card', (tester) async {
      await toStepTwo(tester);
      await _fillStepTwo(tester);
      final shown = tester
          .widget<EventCard>(find.byKey(const Key('create-event-preview')))
          .data;
      final l = AppLocalizations.of(
        tester.element(find.byType(CreateEventScreen)),
      );
      // The card S11.01 draws for an event with these same fields.
      final published = EventSummary(
        id: shown.id,
        title: 'Photo walk phố cổ',
        hostName: 'Lan Anh',
        hostVerified: true,
        type: EventType.photoWalk,
        startsAt: DateTime.utc(2026, 10, 13, 2),
        endsAt: DateTime.utc(2026, 10, 13, 5),
        locationName: 'Hồ Hoàn Kiếm',
        lat: 21.0285,
        lng: 105.8542,
        priceVnd: 250000,
        capacity: 20,
        registeredCount: 0,
        heldCount: 0,
        status: EventStatus.open,
        createdAt: eventNow,
      );
      final customer = eventCardDataOf(published, l);
      expect(shown.title, customer.title);
      expect(shown.hostName, customer.hostName);
      expect(shown.hostVerified, customer.hostVerified);
      expect(shown.typeTag, customer.typeTag);
      expect(shown.typeLabel, customer.typeLabel);
      expect(shown.startsAt, customer.startsAt);
      expect(shown.placeName, customer.placeName);
      expect(shown.priceVnd, customer.priceVnd);
      expect(shown.seatsLeft, customer.seatsLeft);
      expect(shown.soldOut, customer.soldOut);
    });

    testWidgets('staff preview shows the platform as host', (tester) async {
      await toStepTwo(tester, staff: StaffRole.admin);
      await _fillStepTwo(tester);
      // Staff have the FAQ above it: the preview stays the last block.
      await tester.scrollUntilVisible(
        find.byKey(const Key('create-event-preview')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final shown = tester
          .widget<EventCard>(find.byKey(const Key('create-event-preview')))
          .data;
      expect(shown.hostName, 'Do ứng dụng tổ chức');
      expect(shown.hostVerified, isFalse);
    });

    testWidgets(
      'staff enter the FAQ of a platform event; rows are saved (O2)',
      (tester) async {
        final w = await toStepTwo(tester, staff: StaffRole.admin);
        await _fillStepTwo(tester);
        expect(find.text('Câu hỏi thường gặp'), findsOneWidget);
        Future<void> tap(String key) async {
          await tester.ensureVisible(find.byKey(Key(key)));
          await settle(tester);
          await tester.tap(find.byKey(Key(key)));
          await settle(tester);
        }

        await tap('create-event-faq-add');
        await tester.enterText(
          find.byKey(const Key('create-event-faq-q-0')),
          'Cần mang máy gì?',
        );
        await tester.enterText(
          find.byKey(const Key('create-event-faq-a-0')),
          'Máy bất kỳ, kể cả điện thoại.',
        );
        await tap('create-event-faq-add');
        await tester.enterText(
          find.byKey(const Key('create-event-faq-q-1')),
          'Có gửi xe không?',
        );
        await settle(tester);
        // A question without an answer is flagged under the list.
        expect(find.text('Nhập đủ cả câu hỏi và câu trả lời.'), findsOneWidget);
        await tap('create-event-faq-remove-1');
        expect(find.text('Nhập đủ cả câu hỏi và câu trả lời.'), findsNothing);
        expect(find.byKey(const Key('create-event-faq-q-1')), findsNothing);

        await tap('create-event-save');
        expect(w.repo.savedDrafts.last.faq, const [
          EventFaq(
            question: 'Cần mang máy gì?',
            answer: 'Máy bất kỳ, kể cả điện thoại.',
          ),
        ]);
      },
    );

    testWidgets('the add button stops at 10 questions', (tester) async {
      await toStepTwo(tester, staff: StaffRole.sales);
      for (var i = 0; i < 10; i++) {
        await tester.ensureVisible(
          find.byKey(const Key('create-event-faq-add')),
        );
        await settle(tester);
        await tester.tap(find.byKey(const Key('create-event-faq-add')));
        await settle(tester);
      }
      expect(find.byKey(const Key('create-event-faq-add')), findsNothing);
    });

    testWidgets('the FAQ fits 320dp at 1.3 text scale', (tester) async {
      final w = _photographer(staff: StaffRole.admin);
      await _open(tester, w, size: const Size(320, 1000), textScale: 1.3);
      await _stepOne(tester);
      await _next(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('create-event-faq-add')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('create-event-faq-add')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('create-event-faq-add')));
      await settle(tester);
      expect(find.byKey(const Key('create-event-faq-q-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('photographers have no FAQ field and send none', (
      tester,
    ) async {
      final w = await toStepTwo(tester);
      await _fillStepTwo(tester);
      expect(find.byKey(const Key('create-event-faq')), findsNothing);
      await tester.tap(find.byKey(const Key('create-event-save')));
      await settle(tester);
      expect(w.repo.savedDrafts.last.faq, isNull);
    });

    testWidgets('a taken hashtag shows the error under the field', (
      tester,
    ) async {
      final w = await toStepTwo(tester);
      await _fillStepTwo(tester);
      await tester.enterText(
        find.byKey(const Key('create-event-hashtag')),
        'PhotoWalk1013',
      );
      w.repo
        ..failWith = const EventError('conflict')
        ..failOnce = true;
      await tester.tap(find.byKey(const Key('create-event-save')));
      await settle(tester);
      expect(find.text('Hashtag này đã có sự kiện khác dùng'), findsOneWidget);
      // Editing the tag clears it.
      await tester.enterText(
        find.byKey(const Key('create-event-hashtag')),
        'PhotoWalk1014',
      );
      await settle(tester);
      expect(find.text('Hashtag này đã có sự kiện khác dùng'), findsNothing);
    });

    testWidgets('Lưu nháp saves the draft with the schedule', (tester) async {
      final w = await toStepTwo(tester);
      await _fillStepTwo(tester);
      await tester.tap(find.byKey(const Key('create-event-save')));
      await settle(tester);
      final d = w.repo.savedDrafts.last;
      expect(d.startsAt, DateTime.utc(2026, 10, 13, 2));
      expect(d.endsAt, DateTime.utc(2026, 10, 13, 5));
      expect(d.capacity, 20);
      expect(d.priceVnd, 250000);
      expect(d.place?.name, 'Hồ Hoàn Kiếm');
      expect(d.place?.areaId, 'hn-hoan-kiem');
      expect(find.text('Đã lưu nháp'), findsOneWidget);
      expect(w.repo.published, isEmpty);
    });

    testWidgets('publish failure shows the summary and focuses it', (
      tester,
    ) async {
      final w = await toStepTwo(tester);
      // Nothing of step 2 filled in.
      await tester.tap(find.byKey(const Key('create-event-publish')));
      await settle(tester);
      expect(w.repo.published, isEmpty);
      expect(find.textContaining('Cần sửa'), findsOneWidget);
      expect(find.textContaining('mục trước khi đăng'), findsOneWidget);
      expect(
        tester.binding.focusManager.primaryFocus?.debugLabel,
        'create-event-summary',
      );
      // Errors sit under their fields too.
      expect(find.text('Chọn ngày diễn ra'), findsWidgets);
      expect(find.text('Sức chứa từ 1 đến 500 người'), findsWidgets);

      // A line jumps to its field.
      await tester.tap(find.byKey(const Key('create-event-summary-capacity')));
      await settle(tester);
      expect(tester.binding.focusManager.primaryFocus?.debugLabel, 'capacity');
    });

    testWidgets('day_taken shows Bạn đã có lịch hôm đó under Ngày', (
      tester,
    ) async {
      final w = await toStepTwo(tester);
      await _fillStepTwo(tester);
      w.repo
        ..failWith = const EventError('day_taken')
        ..failOnce = true;
      await tester.tap(find.byKey(const Key('create-event-publish')));
      await settle(tester);
      expect(find.text('Bạn đã có lịch hôm đó'), findsWidgets);
      expect(w.repo.published, isEmpty);
    });

    testWidgets('publish opens S12.03 with a toast and clears the draft', (
      tester,
    ) async {
      final w = await toStepTwo(tester);
      await _fillStepTwo(tester);
      await tester.tap(find.byKey(const Key('create-event-publish')));
      await settle(tester);
      expect(w.repo.published, hasLength(1));
      expect(w.location, '/events/${w.repo.published.single}/manage');
      expect(find.text('Đã đăng sự kiện'), findsOneWidget);
      expect(w.prefs!.getString(EventDraftStore.key('u1')), isNull);
      // The draft sent at publish is complete.
      final d = w.repo.savedDrafts.last;
      expect(d.coverUrl, isNotNull);
      expect(d.title, 'Photo walk phố cổ');
    });

    testWidgets('back on step 2 returns to step 1', (tester) async {
      await toStepTwo(tester);
      await tester.tap(find.byKey(const Key('create-event-back')));
      await settle(tester);
      expect(find.text('Thông tin sự kiện'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('Dùng vị trí hiện tại puts the device point on the place', (
      tester,
    ) async {
      await toStepTwo(tester);
      await tester.enterText(
        find.byKey(const Key('place-name')),
        'Công viên Tao Đàn',
      );
      await tester.tap(find.byKey(const Key('place-use-location')));
      await settle(tester);
      final f = _state(tester).form;
      expect(f.lat, 10.8);
      expect(f.lng, 106.7);
      expect(f.areaId, isNull);
      expect(find.text('Đã lấy vị trí hiện tại'), findsOneWidget);
    });

    testWidgets('a place name without a point asks for an area', (
      tester,
    ) async {
      await toStepTwo(tester);
      await tester.enterText(find.byKey(const Key('place-name')), 'Công viên');
      await tester.tap(find.byKey(const Key('create-event-publish')));
      await settle(tester);
      expect(find.text('Chọn khu vực hoặc dùng vị trí hiện tại'), findsWidgets);
    });

    testWidgets('picking an area sets the point to its centre', (tester) async {
      await toStepTwo(tester);
      await tester.tap(find.byKey(const Key('place-area')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('place-area-hn-hoan-kiem')));
      await settle(tester);
      final f = _state(tester).form;
      expect(f.areaId, 'hn-hoan-kiem');
      expect(f.lat, closeTo(21.0285, 1e-6));
    });
  });

  group('resume', () {
    testWidgets('/events/new?draft=<id> opens the saved draft', (tester) async {
      final w = _photographer();
      w.repo.putEvent(
        detailOf(
          'ev9',
          status: EventStatus.draft,
          createdBy: 'u1',
          hostId: 'u1',
        ),
      );
      await w.pump(
        tester,
        path: '/events/new?draft=ev9',
        organizer: true,
        size: _size,
      );
      expect(find.text('Photo walk'), findsWidgets);
      expect(find.text('Thông tin sự kiện'), findsOneWidget);
    });

    testWidgets('a resumed draft has one bar; back goes 2 → 1, then asks', (
      tester,
    ) async {
      final w = _photographer();
      w.repo.putEvent(
        detailOf(
          'ev9',
          status: EventStatus.draft,
          createdBy: 'u1',
          hostId: 'u1',
          spotId: 'cau-dat',
        ),
      );
      await w.pump(
        tester,
        path: '/events/new?draft=ev9',
        organizer: true,
        size: _size,
      );
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Tạo sự kiện'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      await _next(tester);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await tester.tap(find.byKey(const Key('create-event-back')));
      await settle(tester);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(w.location, '/events/new?draft=ev9');

      await tester.tap(find.byKey(const Key('create-event-back')));
      await settle(tester);
      expect(find.text('Lưu nháp?'), findsOneWidget);
    });

    testWidgets('a published event opens the manage page instead', (
      tester,
    ) async {
      final w = _photographer();
      w.repo.putEvent(detailOf('ev9', createdBy: 'u1', hostId: 'u1'));
      await w.pump(
        tester,
        path: '/events/new?draft=ev9',
        organizer: true,
        size: _size,
      );
      await settle(tester);
      expect(w.location, '/events/ev9/manage');
    });
  });
}
