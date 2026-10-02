import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

void main() {
  final l = AppLocalizationsVi();
  test('duration in hours, Vietnamese decimal comma', () {
    expect(durationLabel(120, l), '2 giờ');
    expect(durationLabel(90, l), '1,5 giờ');
  });
  test('package line joins only what is known', () {
    expect(
      packageMeta(l, durationMinutes: 120, editedCount: 40, deliveryDays: 3),
      '2 giờ · 40 ảnh · giao 3 ngày',
    );
    expect(packageMeta(l, durationMinutes: 240), '4 giờ');
    expect(
      packageMeta(l, durationMinutes: 60, deliveryDays: 0),
      '1 giờ · giao trong ngày',
    );
  });
}
