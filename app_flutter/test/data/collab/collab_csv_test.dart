import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/collab/collab_csv.dart';
import 'package:photobooking/data/collab/collaboration.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import '../../support/recruit_world.dart';

void main() {
  final l = AppLocalizationsVi();

  test('header in Vietnamese, one row per job, quotes commas and quotes, '
      'amounts as plain integers, VN dates d/M/yyyy', () {
    final csv = collabCsv([
      makeCollabJob(
        bookingId: 'b1',
        day: '2026-10-04',
        serviceName: 'Gói "Gia đình", 2 giờ',
        collaboratorName: 'Dũng',
        agreedFee: 1500000,
        payStatus: PayStatus.paidReported,
        paidOn: '2026-10-09',
        payMethod: CollabPayMethod.bank,
      ),
      makeCollabJob(
        bookingId: 'b2',
        day: '2026-10-21',
        serviceName: 'Chân dung',
        collaboratorName: 'Hòa',
        agreedFee: 600000,
        payStatus: PayStatus.due,
      ),
    ], l);
    final lines = csv.split('\r\n');
    expect(lines, [
      'Ngày chụp,Dịch vụ,Cộng tác viên,Thù lao,Trạng thái,Ngày trả,Cách trả',
      '4/10/2026,"Gói ""Gia đình"", 2 giờ",Dũng,1500000,Đã báo trả,9/10/2026,Chuyển khoản',
      '21/10/2026,Chân dung,Hòa,600000,Cần trả,,',
    ]);
  });

  test('every pay status and method has its label', () {
    final rows = [
      for (final s in PayStatus.values)
        collabCsv([makeCollabJob(payStatus: s)], l).split('\r\n')[1],
    ];
    expect(rows.map((r) => r.split(',')[4]), [
      '',
      'Cần trả',
      'Đã báo trả',
      'Đã nhận',
      'Chưa nhận',
    ]);
    for (final (m, label) in [
      (CollabPayMethod.bank, 'Chuyển khoản'),
      (CollabPayMethod.cash, 'Tiền mặt'),
      (CollabPayMethod.other, 'Khác'),
    ]) {
      final row = collabCsv([
        makeCollabJob(payMethod: m, paidOn: '2026-10-09'),
      ], l).split('\r\n')[1];
      expect(row.split(',').last, label);
    }
  });

  test('a name with a line break is quoted', () {
    final row = collabCsv([
      makeCollabJob(collaboratorName: 'Dũng\nNguyễn'),
    ], l).split('\r\n').skip(1).join('\r\n');
    expect(row, contains('"Dũng\nNguyễn"'));
  });

  test('no jobs is the header only', () {
    expect(
      collabCsv(const [], l),
      'Ngày chụp,Dịch vụ,Cộng tác viên,Thù lao,Trạng thái,Ngày trả,Cách trả',
    );
  });

  test('a cell starting with =, +, - or @ (after spaces) gets a leading '
      'quote so a spreadsheet never runs it as a formula', () {
    final row = collabCsv([
      makeCollabJob(
        serviceName: '=HYPERLINK("http://x","y")',
        collaboratorName: ' +84 Dũng',
        placeName: 'ignored',
      ),
      makeCollabJob(serviceName: '-1', collaboratorName: '@Hòa'),
      makeCollabJob(serviceName: 'Gói a=b', collaboratorName: 'Dũng'),
    ], l).split('\r\n');
    expect(row[1].split(',').sublist(0, 3), [
      '24/10/2026',
      '"\'=HYPERLINK(""http://x""',
      '""y"")"',
    ]);
    expect(row[1], contains("' +84 Dũng"));
    expect(row[2].split(',').sublist(1, 3), ["'-1", "'@Hòa"]);
    expect(row[3].split(',').sublist(1, 3), ['Gói a=b', 'Dũng']);
  });
}
