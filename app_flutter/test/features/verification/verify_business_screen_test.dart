// test/features/verification/verify_business_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_repository.dart';

import '../../support/verification_world.dart';

final _at = DateTime.utc(2026, 10, 15, 2, 12);

/// An approved verification; [business] adds the S21.04 sub-record.
Map<String, dynamic> _doc({Map<String, dynamic>? business}) => {
  'uid': 'u',
  'status': 'approved',
  'kind': 'studio',
  'steps': {
    'phone': {'doneAt': _at},
    'identity': {
      'method': 'vneid',
      'checkedAt': _at,
      'result': 'passed',
      'failure': null,
      'maskedName': 'NGUYỄN M** T**',
    },
    'rules': {'acceptedAt': _at, 'version': '2026-10-06'},
  },
  'submittedAt': _at,
  'decidedAt': _at,
  'freeResubmitsLeft': 1,
  'business': ?business,
};

Map<String, dynamic> _business(
  String status, {
  String kind = 'company',
  String? reject,
}) => {
  'status': status,
  'kind': kind,
  'taxCode': '0312345678',
  'name': 'CÔNG TY TNHH STUDIO MÂY',
  'address': '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
  'registryStatus': 'active',
  'docPath': null,
  'submittedAt': _at,
  'rejectReason': reject == null ? null : {'code': reject, 'text': null},
};

Future<VerificationWorld> _world(
  WidgetTester tester, {
  ProviderType type = ProviderType.studio,
  bool verified = true,
  Map<String, dynamic>? business,
  double width = 390,
  double height = 844,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = VerificationWorld(startScreen: true);
  await w.init();
  w.seedDoc(_doc(business: business));
  w.seedIntro(
    PhotographerIntro(
      onboardingComplete: true,
      verified: verified,
      acceptingOrders: verified,
      providerType: type,
    ),
  );
  return w;
}

Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(
  VerificationWorld w,
  WidgetTester tester, {
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    w.app(location: '/verify/business', textScale: textScale),
  );
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

final _field = find.byKey(const Key('verify-biz-tax-code'));
final _lookup = find.byKey(const Key('verify-biz-lookup'));
final _upload = find.byKey(const Key('verify-biz-doc'));
final _submit = find.byKey(const Key('verify-biz-submit'));

Future<void> _lookUp(WidgetTester tester, String code) async {
  await tester.enterText(_field, code);
  await tester.pump();
  await _tap(tester, _lookup);
}

AppButton _submitButton(WidgetTester tester) =>
    tester.widget<AppButton>(_submit);

const _needsIdentity = 'Xác minh danh tính chủ studio trước.';

void main() {
  testWidgets('only a verified studio sees the form; others see '
      'verifyBizNeedsIdentity', (tester) async {
    final studio = await _world(tester);
    await _open(studio, tester);
    expect(find.text('Xác minh doanh nghiệp'), findsOneWidget);
    expect(
      find.text(
        'Cần cho con dấu Studio, hơn 3 thành viên và tài khoản nhận tiền '
        'đứng tên công ty. Không cần để nhận đơn.',
      ),
      findsOneWidget,
    );
    expect(_field, findsOneWidget);
    expect(find.text('Mã số thuế'), findsOneWidget);
    expect(find.text(_needsIdentity), findsNothing);
    final code = tester.widget<ScreenCode>(find.byType(ScreenCode));
    expect(code.code, ScreenCodes.verifyBusiness);

    for (final (type, verified) in [
      (ProviderType.studio, false),
      (ProviderType.individual, true),
    ]) {
      final other = await _world(tester, type: type, verified: verified);
      await _open(other, tester);
      expect(find.text(_needsIdentity), findsOneWidget);
      expect(_field, findsNothing);
      expect(_submit, findsNothing);
    }
  });

  testWidgets('an invalid code shows verifyBizInvalid', (tester) async {
    final w = await _world(tester);
    await _open(w, tester);
    await _lookUp(tester, '031234');

    expect(find.text('Mã số thuế gồm 10 hoặc 12 chữ số.'), findsOneWidget);
    expect(w.repo.calls, isEmpty);
  });

  testWidgets('Tra cứu shows name, address and Đang hoạt động', (tester) async {
    final w = await _world(tester);
    await _open(w, tester);
    expect(_submitButton(tester).onPressed, isNull);
    await _lookUp(tester, '0312345678');

    expect(w.repo.calls.single.name, 'lookupTaxCode');
    expect(w.repo.calls.single.data, {'taxCode': '0312345678'});
    expect(find.text('Tên'), findsOneWidget);
    expect(find.text('CÔNG TY TNHH STUDIO THỬ 5678'), findsOneWidget);
    expect(find.text('Địa chỉ'), findsOneWidget);
    expect(
      find.text('12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh'),
      findsOneWidget,
    );
    expect(find.text('Tình trạng'), findsOneWidget);
    expect(find.text('Đang hoạt động'), findsOneWidget);
    expect(
      find.text('Người đại diện: cần ảnh giấy đăng ký kinh doanh'),
      findsOneWidget,
    );
    expect(
      find.text('Staff đối chiếu người đại diện với chủ studio đã xác minh'),
      findsOneWidget,
    );
  });

  testWidgets('a branch code (10 digits, dash, 3 digits) is looked up', (
    tester,
  ) async {
    final w = await _world(tester);
    await _open(w, tester);
    await _lookUp(tester, '0312345678-001');
    expect(w.repo.calls.single.data, {'taxCode': '0312345678-001'});
  });

  testWidgets('an unknown code shows verifyBizNotFound', (tester) async {
    final w = await _world(tester);
    w.repo.lookupFailWith = 'not_found';
    await _open(w, tester);
    await _lookUp(tester, '0312345678');
    expect(find.text('Không tìm thấy mã số thuế này.'), findsOneWidget);
  });

  testWidgets('an inactive company shows Ngừng hoạt động and disables Gửi '
      'duyệt', (tester) async {
    final w = await _world(tester);
    w.repo.taxInfo = const TaxCodeInfo(
      name: 'CÔNG TY TNHH STUDIO THỬ 0000',
      address: '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
      active: false,
      kind: 'company',
    );
    await _open(w, tester);
    await _lookUp(tester, '0312340000');

    expect(find.text('Ngừng hoạt động'), findsOneWidget);
    expect(find.text('Đang hoạt động'), findsNothing);
    expect(_upload, findsNothing);
    expect(_submitButton(tester).onPressed, isNull);
  });

  testWidgets('a company needs a photo before Gửi duyệt; the photo uploads '
      'to businessDocs/{uid}/', (tester) async {
    final w = await _world(tester);
    await _open(w, tester);
    await _lookUp(tester, '0312345678');
    expect(_submitButton(tester).onPressed, isNull);

    await _tap(tester, _upload);
    expect(w.uploader.uploaded, hasLength(1));
    final path = w.uploader.uploaded.single;
    expect(path, startsWith('businessDocs/${w.uid}/'));
    expect(path, endsWith('.jpg'));
    expect(
      RegExp(r'^businessDocs/[^/]+/[0-9A-HJKMNP-TV-Z]{26}\.jpg$')
          .hasMatch(path),
      isTrue,
    );
    expect(w.uploader.purposes[path], ImagePurpose.document);
    expect(_submitButton(tester).onPressed, isNotNull);

    await _tap(tester, _submit);
    expect(w.repo.calls.last.name, 'submitBusinessVerification');
    expect(w.repo.calls.last.data, {'taxCode': '0312345678', 'docPath': path});
    expect(find.text('Đang chờ duyệt · trong 24 giờ'), findsOneWidget);
    expect(_submit, findsNothing);
  });

  testWidgets('a 12-digit code hides the upload and shows the household note', (
    tester,
  ) async {
    final w = await _world(tester);
    w.repo.taxInfo = const TaxCodeInfo(
      name: 'HỘ KINH DOANH NGUYỄN MINH TRÍ',
      address: '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
      active: true,
      kind: 'household',
    );
    w.repo.businessResult = BusinessStatus.approved;
    await _open(w, tester);
    await _lookUp(tester, '079095012345');

    expect(find.text('HỘ KINH DOANH NGUYỄN MINH TRÍ'), findsOneWidget);
    expect(_upload, findsNothing);
    expect(
      find.text(
        'Hộ kinh doanh: mã số thuế là số định danh của chủ, tự khớp, không '
        'cần tải giấy.',
      ),
      findsOneWidget,
    );
    expect(_submitButton(tester).onPressed, isNotNull);

    await _tap(tester, _submit);
    expect(w.repo.calls.last.data, {'taxCode': '079095012345'});
    expect(w.uploader.uploaded, isEmpty);
    expect(find.text('Đã xác minh doanh nghiệp'), findsOneWidget);
  });

  testWidgets('approved, pending and rejected states read from the listener', (
    tester,
  ) async {
    final w = await _world(tester, business: _business('submitted'));
    await _open(w, tester);
    expect(find.text('Đang chờ duyệt · trong 24 giờ'), findsOneWidget);
    expect(find.text('CÔNG TY TNHH STUDIO MÂY'), findsOneWidget);
    expect(_field, findsNothing);
    expect(_submit, findsNothing);

    w.repo.seed(w.uid, _doc(business: _business('approved')));
    await _settle(tester);
    expect(find.text('Đã xác minh doanh nghiệp'), findsOneWidget);
    expect(find.text('Đang chờ duyệt · trong 24 giờ'), findsNothing);
    expect(_submit, findsNothing);

    w.repo.seed(
      w.uid,
      _doc(business: _business('rejected', reject: 'representative_mismatch')),
    );
    await _settle(tester);
    expect(
      find.text(
        'Chưa được duyệt: Mã số thuế không khớp với danh tính chủ studio.',
      ),
      findsOneWidget,
    );
    // A rejected record can be sent again.
    expect(_field, findsOneWidget);
    expect(_submit, findsOneWidget);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    final w = await _world(tester, width: 320, height: 640);
    await _open(w, tester, textScale: 1.3);
    expect(tester.takeException(), isNull);
    await _lookUp(tester, '0312345678');
    expect(tester.takeException(), isNull);
    await _tap(tester, _upload);
    expect(tester.takeException(), isNull);
    expect(find.text('Đang hoạt động'), findsOneWidget);
  });
}
