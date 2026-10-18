import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_providers.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/l10n/app_localizations.dart';
import 'package:photobooking/features/delivery/submit_delivery_sheet.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_delivery_repository.dart';

void main() {
  late FakeDeliveryRepository fakeRepo;
  late FakeImagePicker fakePicker;

  final testB = makeTestBooking(
    id: 'b-sheet-1',
    status: BookingStatus.shot,
    photographerId: 'p1',
    customerId: 'c1',
  );

  final revisionB = makeTestBooking(
    id: 'b-sheet-2',
    status: BookingStatus.revisionRequested,
    photographerId: 'p1',
    customerId: 'c1',
  ).copyWith(deliveryRound: 1);

  setUp(() {
    fakeRepo = FakeDeliveryRepository();
    fakePicker = FakeImagePicker([
      [
        const PickedImage(path: '/tmp/1.jpg', name: '1.jpg'),
        const PickedImage(path: '/tmp/2.jpg', name: '2.jpg'),
        const PickedImage(path: '/tmp/3.jpg', name: '3.jpg'),
      ],
    ]);
  });

  Widget buildApp(Widget child) {
    return ProviderScope(
      overrides: [
        deliveryRepositoryProvider.overrideWithValue(fakeRepo),
        imagePickerProvider.overrideWithValue(fakePicker),
        authStateProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(uid: 'p1')),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('ScreenCode is S06.07 and shows title Nộp bàn giao · vòng 1 for round 0', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(SubmitDeliverySheet(booking: testB)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is ScreenCode && w.code == ScreenCodes.submitDelivery,
      ),
      findsOneWidget,
    );
    expect(find.text('Nộp bàn giao · vòng 1'), findsOneWidget);
  });

  testWidgets('title reads Nộp bàn giao · vòng 2 for revision_requested booking and shows notes', (
    tester,
  ) async {
    fakeRepo.seedRound(
      revisionB.id,
      DeliveryRound(
        bookingId: revisionB.id,
        round: 1,
        samples: const [],
        photoCount: 50,
        linkHost: 'drive.google.com',
        submittedAt: DateTime.utc(2026, 10, 15),
        submittedBy: 'p1',
        decision: DeliveryDecision(
          kind: 'request_revision',
          note: 'Chỉnh màu sáng hơn giúp mình nhé',
          photoNotes: const [
            DeliveryPhotoNote(sampleIndex: 0, note: 'Xoá vết mờ góc trái'),
          ],
          at: DateTime.utc(2026, 10, 16),
        ),
      ),
    );

    await tester.pumpWidget(
      buildApp(SubmitDeliverySheet(booking: revisionB)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nộp bàn giao · vòng 2'), findsOneWidget);
    expect(find.text('Khách muốn chỉnh sửa vòng 1'), findsOneWidget);
    expect(find.text('Chỉnh màu sáng hơn giúp mình nhé'), findsOneWidget);
    expect(find.text('Ảnh 1: Xoá vết mờ góc trái'), findsOneWidget);
  });

  testWidgets('submit button is disabled until blocked is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(SubmitDeliverySheet(booking: testB)),
    );
    await tester.pumpAndSettle();

    final submitBtn = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Nộp bàn giao'),
    );
    expect(submitBtn.onPressed, isNull);
  });

  testWidgets('success closes sheet and returns round number', (
    tester,
  ) async {
    int? returnedRound;

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              returnedRound = await showSubmitDeliverySheet(
                context,
                booking: testB,
              );
            },
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Nộp bàn giao · vòng 1'), findsOneWidget);

    // Pick photos
    await tester.tap(find.text('Thêm ảnh mẫu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Make the 3 staged samples ready
    for (var i = 0; i < 3; i++) {
      final fileId = fakeRepo.uploadCalls[i].fileId;
      fakeRepo.seedStagedSample(
        testB.id,
        StagedSample(
          fileId: fileId,
          status: SampleStatus.ready,
          thumbPath: 'deliveries/${testB.id}/${fileId}_t.jpg',
        ),
      );
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Fill link and count
    final textFields = find.byType(TextField);
    // 0: link, 1: count, 2: note
    await tester.enterText(textFields.at(0), 'https://drive.google.com/test');
    await tester.enterText(textFields.at(1), '50');
    await tester.pumpAndSettle();

    final submitFinder = find.widgetWithText(AppButton, 'Nộp bàn giao');
    final submitBtn = tester.widget<AppButton>(submitFinder);
    expect(submitBtn.onPressed, isNotNull);

    await tester.ensureVisible(submitFinder);
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    expect(returnedRound, 1);
  });

  testWidgets('fits 320 dp at 1.3x text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.3),
        ),
        child: buildApp(SubmitDeliverySheet(booking: testB)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
