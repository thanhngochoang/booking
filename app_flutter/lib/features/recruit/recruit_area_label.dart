import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

/// S27 labels of a post's ids: `builtInAreas` and `kSpecialties` (the ids
/// the server mirrors in `recruit_areas.ts`; an unknown id shows as is).

/// The area's short name: "Quận 3" for "Quận 3, TP.HCM", "Huế" for "Huế".
String recruitAreaName(String id) {
  for (final a in builtInAreas) {
    if (a.id == id) {
      final comma = a.name.indexOf(',');
      return comma < 0 ? a.name : a.name.substring(0, comma);
    }
  }
  return id;
}

/// "Cưới" for `wedding`.
String recruitSpecialtyLabel(String id) {
  for (final s in kSpecialties) {
    if (s.id == id) return s.labelVi;
  }
  return id;
}

/// "Quận 1, Quận 3".
String recruitAreasText(List<String> ids) =>
    ids.map(recruitAreaName).join(', ');

/// "Cưới, Gia đình".
String recruitSpecialtiesText(List<String> ids) =>
    ids.map(recruitSpecialtyLabel).join(', ');
