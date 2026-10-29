// test/features/organizer/spot_claim_screen_test.dart
//
// S30.02 "Nhận quản lý điểm" (mock #S30.02).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_repository.dart';

import '../../support/organizer_world.dart';

Finder _key(String k) => find.byKey(Key(k));

const _f1 = PickedImage(
  path: '/tmp/gpkd.jpg',
  name: 'gpkd.jpg',
  sizeBytes: 1258291,
);
const _f2 = PickedImage(path: '/tmp/hd.jpg', name: 'hop-dong.jpg');

OrganizerWorld _world({List<List<PickedImage>> picks = const []}) {
  final w = OrganizerWorld()..picker = FakeImagePicker(picks);
  w.organizers.putOrganizer(makeOrganizer(managedSpotIds: const []));
  w.seedSpot(makeSpot());
  w.seedSpot(makeSpot(id: 'bv', name: 'Bãi đá Ba Vì', managedBy: 'other'));
  return w;
}

SpotClaim _claim(SpotClaimStatus status, {String? reason}) => SpotClaim(
  id: 'c1',
  spotId: 'bd',
  organizerId: 'org1',
  status: status,
  proofPaths: const ['spot_claims/org1/f/0.jpg'],
  reason: reason,
  createdAt: organizerNow.subtract(const Duration(hours: 3)),
);

Future<void> _search(WidgetTester tester, String q) async {
  await tester.enterText(_key('claim-search'), q);
  await settleOrganizer(tester);
}

void main() {
  testWidgets('managed spots are dimmed with "đã có chủ quản lý"', (
    tester,
  ) async {
    final w = _world();
    await w.pump(tester, location: '/organizer/spots/claim');
    await _search(tester, 'bãi đá');

    expect(find.text('Hà Nội · chưa có chủ quản lý'), findsOneWidget);
    expect(find.text('Hà Nội · đã có chủ quản lý'), findsOneWidget);
    expect(
      tester.widget<AppOptionTile>(_key('claim-spot-bv')).enabled,
      isFalse,
    );
    expect(tester.widget<AppOptionTile>(_key('claim-spot-bd')).enabled, isTrue);
    expect(
      find.text('Không thấy địa điểm của bạn? Gửi đề xuất điểm mới'),
      findsOneWidget,
    );
  });

  testWidgets('no file → "Thêm ít nhất một tệp"', (tester) async {
    final w = _world();
    await w.pump(tester, location: '/organizer/spots/claim');
    await _search(tester, 'sông hồng');
    await tapOrganizer(tester, _key('claim-spot-bd'));
    await tapOrganizer(tester, _key('claim-submit'));

    expect(find.text('Thêm ít nhất một tệp'), findsOneWidget);
    expect(w.organizers.calls, isEmpty);
  });

  testWidgets('submit with 2 files calls claimSpot, then the pending band', (
    tester,
  ) async {
    final w = _world(
      picks: [
        [_f1, _f2],
      ],
    );
    await w.pump(tester, location: '/organizer/spots/claim');
    await _search(tester, 'sông hồng');
    await tapOrganizer(tester, _key('claim-spot-bd'));
    await tapOrganizer(tester, _key('claim-add-file'));

    expect(find.text('gpkd.jpg'), findsOneWidget);
    expect(find.text('hop-dong.jpg'), findsOneWidget);
    expect(find.text('1,2 MB · chỉ bạn và staff xem'), findsOneWidget);
    expect(w.picker.requestedMax.single, 3);

    await tapOrganizer(tester, _key('claim-submit'));
    final (name, payload) = w.organizers.calls.single;
    expect(name, 'claimSpot');
    expect(payload['spotId'], 'bd');
    expect(payload['proofPaths'], hasLength(2));
    expect(find.text('Đang chờ staff duyệt'), findsOneWidget);
  });

  testWidgets('a spot_managed refusal shows the support line', (tester) async {
    final w = _world(
      picks: [
        [_f1],
      ],
    );
    await w.pump(tester, location: '/organizer/spots/claim');
    await _search(tester, 'sông hồng');
    await tapOrganizer(tester, _key('claim-spot-bd'));
    await tapOrganizer(tester, _key('claim-add-file'));
    w.organizers.nextError = const OrganizerError('spot_managed');
    await tapOrganizer(tester, _key('claim-submit'));

    expect(
      find.text(
        'Điểm này đã có chủ quản lý. Liên hệ hỗ trợ nếu bạn là ban quản lý.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('pending → read-only', (tester) async {
    final w = _world();
    w.organizers.putClaim(_claim(SpotClaimStatus.pending));
    await w.pump(tester, location: '/organizer/spots/claim');

    expect(find.text('Đang chờ staff duyệt'), findsOneWidget);
    expect(find.text('Bãi đá sông Hồng'), findsOneWidget);
    expect(_key('claim-search'), findsNothing);
    expect(_key('claim-add-file'), findsNothing);
    expect(tester.widget<AppButton>(_key('claim-submit')).onPressed, isNull);
  });

  testWidgets('rejected shows reason and "Gửi lại"', (tester) async {
    final w = _world();
    w.organizers.putClaim(
      _claim(SpotClaimStatus.rejected, reason: 'Giấy tờ không rõ'),
    );
    await w.pump(tester, location: '/organizer/spots/claim');

    expect(find.text('Bị từ chối: Giấy tờ không rõ'), findsOneWidget);
    expect(_key('claim-search'), findsNothing);
    await tapOrganizer(tester, _key('claim-resend'));
    expect(_key('claim-search'), findsOneWidget);
  });

  testWidgets('propose sheet sends name + address', (tester) async {
    final w = _world(
      picks: [
        [_f1],
      ],
    );
    await w.pump(tester, location: '/organizer/spots/claim');
    await tapOrganizer(tester, _key('claim-propose'));
    await tester.enterText(_key('propose-name'), 'Vườn cúc Nhật Tân');
    await tester.enterText(_key('propose-address'), 'Phú Thượng, Tây Hồ');
    await tapOrganizer(tester, _key('propose-send'));

    expect(find.text('Đề xuất: Vườn cúc Nhật Tân'), findsOneWidget);
    await tapOrganizer(tester, _key('claim-add-file'));
    await tapOrganizer(tester, _key('claim-submit'));

    final (name, payload) = w.organizers.calls.single;
    expect(name, 'claimSpot');
    expect(payload['spotId'], isNull);
    expect(payload['proposal'], {
      'name': 'Vườn cúc Nhật Tân',
      'address': 'Phú Thượng, Tây Hồ',
    });
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320 dp at 1.3× text ($b)', (tester) async {
      final w = _world(
        picks: [
          [_f1, _f2],
        ],
      );
      await w.pump(
        tester,
        location: '/organizer/spots/claim',
        width: 320,
        height: 700,
        textScale: 1.3,
        brightness: b,
      );
      await _search(tester, 'bãi đá');
      await tapOrganizer(tester, _key('claim-spot-bd'));
      await tapOrganizer(tester, _key('claim-add-file'));
      expect(tester.takeException(), isNull);
      expect(_key('claim-submit'), findsOneWidget);
    });
  }
}
