import 'package:flutter/foundation.dart';

import 'package:photobooking/data/photographer/provider_repository.dart';
import 'package:photobooking/l10n/app_localizations.dart';

const kStudioLineMin = 5;
const kStudioLineMax = 120;
const kStudioWardMax = 60;
const kStudioAreaMin = 2;
const kStudioAreaMax = 60;

enum StudioAddressField { line, ward, district, city }

enum StudioAddressError {
  lineInvalid,
  wardTooLong,
  districtInvalid,
  cityInvalid,
}

/// The raw state of the studio address block of S08.05.
@immutable
class StudioAddressForm {
  const StudioAddressForm({
    this.line = '',
    this.ward = '',
    this.district = '',
    this.city = '',
  });

  final String line;
  final String ward;
  final String district;
  final String city;
}

@immutable
class StudioAddressResult {
  const StudioAddressResult(this.errors, this.address);

  final Map<StudioAddressField, StudioAddressError> errors;

  /// Set when [ok].
  final StudioAddressInput? address;

  bool get ok => errors.isEmpty && address != null;
}

/// Same limits as the server (`setStudioAddress`): line 5–120, ward ≤ 60,
/// district and city 2–60, all trimmed.
StudioAddressResult validateStudioAddress(
  StudioAddressForm f, {
  double? lat,
  double? lng,
}) {
  final line = f.line.trim();
  final ward = f.ward.trim();
  final district = f.district.trim();
  final city = f.city.trim();
  final errors = <StudioAddressField, StudioAddressError>{};
  if (line.length < kStudioLineMin || line.length > kStudioLineMax) {
    errors[StudioAddressField.line] = StudioAddressError.lineInvalid;
  }
  if (ward.length > kStudioWardMax) {
    errors[StudioAddressField.ward] = StudioAddressError.wardTooLong;
  }
  if (district.length < kStudioAreaMin || district.length > kStudioAreaMax) {
    errors[StudioAddressField.district] = StudioAddressError.districtInvalid;
  }
  if (city.length < kStudioAreaMin || city.length > kStudioAreaMax) {
    errors[StudioAddressField.city] = StudioAddressError.cityInvalid;
  }
  if (errors.isNotEmpty) {
    return StudioAddressResult(errors, null);
  }
  return StudioAddressResult(
    const {},
    StudioAddressInput(
      line: line,
      ward: ward.isEmpty ? null : ward,
      district: district,
      city: city,
      lat: lat,
      lng: lng,
    ),
  );
}

String studioAddressErrorText(StudioAddressError e, AppLocalizations l) =>
    switch (e) {
      StudioAddressError.lineInvalid => l.setupStudioLineError,
      StudioAddressError.wardTooLong => l.setupStudioWardError,
      StudioAddressError.districtInvalid => l.setupStudioDistrictError,
      StudioAddressError.cityInvalid => l.setupStudioCityError,
    };
