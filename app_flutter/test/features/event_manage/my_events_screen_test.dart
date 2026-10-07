// test/features/event_manage/my_events_screen_test.dart
//
// `/events/mine` and the ordering S06.01 shares with it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/staff_role.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/event_create/create_event_screen.dart';
import 'package:photobooking/features/event_manage/manage_event_screen.dart';
import 'package:photobooking/features/event_manage/my_events_section.dart';

import '../../support/event_world.dart';

EventDetail _event(
  String id, {
  EventStatus status = EventStatus.open,
  Duration startsIn = const Duration(days: 3),
  String createdBy = 'p1',
}) => detailOf(
  id,
  status: status,
  startsIn: startsIn,
  createdBy: createdBy,
  registered: status == EventStatus.draft ? 0 : 5,
);

EventsWorld _world(List<EventDetail> events, {StaffRole? staff}) => EventsWorld(
  uid: 'p1',
  role: staff == null ? UserRole.photographer : UserRole.customer,
  staff: staff,
  onboardingComplete: true,
  events: events,
);

Future<void> _open(
  WidgetTester tester,
  EventsWorld w, {
  Size size = const Size(390, 1400),
  double textScale = 1,
}) => w.pump(
  tester,
  path: '/events/mine',
  organizer: true,
  size: size,
  textScale: textScale,
);

double _top(WidgetTester tester, String id) =>
    tester.getTopLeft(find.byKey(Key('my-event-$id'))).dy;

void main() {
  test('upcoming first, then undated drafts, then past or cancelled', () {
    final list = [
      summaryOf(
        'past',
        status: EventStatus.completed,
        startsIn: -const Duration(days: 2),
      ),
      summaryOf('later', startsIn: const Duration(days: 9)),
      summaryOf('cancelled', status: EventStatus.cancelled),
      summaryOf('soon', startsIn: const Duration(days: 1)),
      summaryOf(
        'draft',
        status: EventStatus.draft,
        startsIn: const Duration(days: 5),
      ),
    ];
    expect(orderMyEvents(list, eventNow).map((e) => e.id), [
      'soon',
      'draft',
      'later',
      'cancelled',
      'past',
    ]);
  });

  testWidgets('lists my events, upcoming first, drafts tagged Nháp', (
    tester,
  ) async {
    final w = _world([
      _event(
        'past',
        status: EventStatus.completed,
        startsIn: -const Duration(days: 2),
      ),
      _event('later', startsIn: const Duration(days: 9)),
      _event(
        'draft',
        status: EventStatus.draft,
        startsIn: const Duration(days: 5),
      ),
      _event('soon', startsIn: const Duration(days: 1)),
      // Someone else's event is not mine.
      _event('other', createdBy: 'p2'),
    ]);
    await _open(tester, w);

    expect(find.text('Sự kiện của tôi'), findsOneWidget);
    expect(find.byKey(const Key('my-event-other')), findsNothing);
    expect(_top(tester, 'soon'), lessThan(_top(tester, 'draft')));
    expect(_top(tester, 'draft'), lessThan(_top(tester, 'later')));
    expect(_top(tester, 'later'), lessThan(_top(tester, 'past')));

    final tag = find.byKey(const Key('my-event-tag-draft'));
    expect(tag, findsOneWidget);
    expect(
      find.descendant(of: tag, matching: find.text('NHÁP')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('my-event-tag-soon')), findsNothing);
  });

  testWidgets('a draft resumes in S12.01', (tester) async {
    final w = _world([_event('draft', status: EventStatus.draft)]);
    await _open(tester, w);
    await tester.tap(find.byKey(const Key('my-event-draft')));
    await settle(tester);
    expect(w.location, '/events/new?draft=draft');
    expect(find.byType(CreateEventScreen), findsOneWidget);
  });

  testWidgets('a published event opens S12.03', (tester) async {
    final w = _world([_event('soon')]);
    await _open(tester, w);
    await tester.tap(find.byKey(const Key('my-event-soon')));
    await settle(tester);
    expect(w.location, '/events/soon/manage');
    expect(find.byType(ManageEventScreen), findsOneWidget);
  });

  testWidgets('staff see the events they created', (tester) async {
    final w = _world([_event('soon')], staff: StaffRole.sales);
    await _open(tester, w);
    expect(find.byKey(const Key('my-event-soon')), findsOneWidget);
  });

  testWidgets('no events shows the empty state with Tạo sự kiện', (
    tester,
  ) async {
    final w = _world(const []);
    await _open(tester, w);
    expect(find.text('Bạn chưa tổ chức sự kiện nào'), findsOneWidget);
    await tester.tap(find.text('Tạo sự kiện').last);
    await settle(tester);
    expect(w.location, '/events/new');
  });

  testWidgets('320 dp at 1.3× text fits', (tester) async {
    final w = _world([
      _event('soon'),
      _event('draft', status: EventStatus.draft),
    ]);
    await _open(tester, w, size: const Size(320, 640), textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('my-event-soon')), findsOneWidget);
  });
}
