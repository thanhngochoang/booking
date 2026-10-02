import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/photographer_setup/package_logic.dart';

void main() {
  test('a complete form becomes an input with whole VND', () {
    final c = validatePackage(
      const PackageForm(
        name: ' Chân dung 2 giờ ',
        priceText: '1.500.000',
        durationMinutes: 120,
        editedText: '40',
        deliveryText: '3',
      ),
    );
    expect(c.ok, isTrue);
    expect(
      c.input,
      const ServicePackageInput(
        name: 'Chân dung 2 giờ',
        priceVnd: 1500000,
        durationMinutes: 120,
        editedCount: 40,
        deliveryDays: 3,
      ),
    );
  });

  test('every rule has its own message', () {
    expect(validatePackage(const PackageForm()).errors, {
      PackageField.name: PackageError.nameLength,
      PackageField.price: PackageError.priceRequired,
      PackageField.duration: PackageError.durationRequired,
    });
    PackageCheck one(PackageForm f) => validatePackage(f);
    const ok = PackageForm(name: 'Gói', priceText: '1', durationMinutes: 60);
    expect(
      one(const PackageForm(name: 'G', priceText: '1', durationMinutes: 60))
          .errors
          .keys,
      [PackageField.name],
    );
    expect(
      one(PackageForm(name: 'x' * 61, priceText: '1', durationMinutes: 60))
          .errors
          .keys,
      [PackageField.name],
    );
    expect(
      one(const PackageForm(name: 'Gói', priceText: '0', durationMinutes: 60))
          .errors,
      {PackageField.price: PackageError.priceRequired},
    );
    expect(
      one(
        const PackageForm(
          name: 'Gói',
          priceText: '1.000.000.001',
          durationMinutes: 60,
        ),
      ).errors,
      {PackageField.price: PackageError.priceTooHigh},
    );
    expect(
      one(const PackageForm(name: 'Gói', priceText: '1', durationMinutes: 90))
          .errors,
      {PackageField.duration: PackageError.durationRequired},
    );
    expect(
      one(
        const PackageForm(
          name: 'Gói',
          priceText: '1',
          durationMinutes: 60,
          editedText: '2001',
        ),
      ).errors,
      {PackageField.edited: PackageError.countInvalid},
    );
    expect(
      one(
        const PackageForm(
          name: 'Gói',
          priceText: '1',
          durationMinutes: 60,
          deliveryText: '91',
        ),
      ).errors,
      {PackageField.delivery: PackageError.daysInvalid},
    );
    expect(one(ok).ok, isTrue);
  });

  test('editing starts from the stored values', () {
    final f = packageFormOf(
      const ServicePackage(
        id: 's1',
        name: 'Cặp đôi',
        priceVnd: 3200000,
        durationMinutes: 240,
        editedCount: 80,
      ),
    );
    expect(
      (f.name, f.priceText, f.durationMinutes, f.editedText, f.deliveryText),
      ('Cặp đôi', '3.200.000', 240, '80', ''),
    );
  });
}
