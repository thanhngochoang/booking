import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/l10n/app_localizations.dart';

const kPackageNameMin = 2;
const kPackageNameMax = 60;
const kPriceMaxVnd = 1000000000;
const kCountMax = 2000;
const kDeliveryMaxDays = 90;

enum PackageField { name, price, duration, edited, delivery }

enum PackageError {
  nameLength,
  priceRequired,
  priceTooHigh,
  durationRequired,
  countInvalid,
  daysInvalid,
}

/// The package form as typed.
@immutable
class PackageForm {
  const PackageForm({
    this.name = '',
    this.priceText = '',
    this.durationMinutes,
    this.editedText = '',
    this.deliveryText = '',
  });

  final String name;
  final String priceText;
  final int? durationMinutes;
  final String editedText;
  final String deliveryText;
}

@immutable
class PackageCheck {
  const PackageCheck(this.errors, this.input);

  final Map<PackageField, PackageError> errors;

  /// Set only when there are no errors.
  final ServicePackageInput? input;

  bool get ok => input != null;
}

PackageCheck validatePackage(PackageForm f) {
  final errors = <PackageField, PackageError>{};
  final name = f.name.trim();
  if (name.length < kPackageNameMin || name.length > kPackageNameMax) {
    errors[PackageField.name] = PackageError.nameLength;
  }
  final price = parseVnd(f.priceText);
  if (price == null || price <= 0) {
    errors[PackageField.price] = PackageError.priceRequired;
  } else if (price > kPriceMaxVnd) {
    errors[PackageField.price] = PackageError.priceTooHigh;
  }
  final duration = f.durationMinutes;
  if (duration == null || !kPackageDurationsMinutes.contains(duration)) {
    errors[PackageField.duration] = PackageError.durationRequired;
  }
  int? optional(String text, int max, PackageField field, PackageError error) {
    final t = text.trim();
    if (t.isEmpty) {
      return null;
    }
    final v = int.tryParse(t);
    if (v == null || v < 0 || v > max) {
      errors[field] = error;
      return null;
    }
    return v;
  }

  final edited = optional(
    f.editedText,
    kCountMax,
    PackageField.edited,
    PackageError.countInvalid,
  );
  final delivery = optional(
    f.deliveryText,
    kDeliveryMaxDays,
    PackageField.delivery,
    PackageError.daysInvalid,
  );
  if (errors.isNotEmpty) {
    return PackageCheck(errors, null);
  }
  return PackageCheck(
    const {},
    ServicePackageInput(
      name: name,
      priceVnd: price!,
      durationMinutes: duration!,
      editedCount: edited,
      deliveryDays: delivery,
    ),
  );
}

PackageForm packageFormOf(ServicePackage p) => PackageForm(
  name: p.name,
  priceText: groupVnd(p.priceVnd),
  durationMinutes: p.durationMinutes,
  editedText: p.editedCount?.toString() ?? '',
  deliveryText: p.deliveryDays?.toString() ?? '',
);

String packageErrorText(PackageError e, AppLocalizations l) => switch (e) {
  PackageError.nameLength => l.packageNameLength,
  PackageError.priceRequired => l.packagePriceRequired,
  PackageError.priceTooHigh => l.packagePriceTooHigh,
  PackageError.durationRequired => l.packageDurationRequired,
  PackageError.countInvalid => l.packageCountInvalid,
  PackageError.daysInvalid => l.packageDaysInvalid,
};
