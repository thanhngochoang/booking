import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

void main() {
  test('ids are unique stable codes and labels are Vietnamese text', () {
    for (final list in [kSpecialties, kStyles]) {
      expect(list.map((o) => o.id).toSet(), hasLength(list.length));
      for (final o in list) {
        expect(o.id, matches(RegExp(r'^[a-z_]+$')));
        expect(o.labelVi.trim(), isNotEmpty);
      }
    }
  });

  test('label lookups fall back to the code for unknown ids', () {
    expect(specialtyLabel('portrait'), 'Chân dung');
    expect(specialtyLabel('wedding'), 'Cưới');
    expect(specialtyLabel('underwater'), 'underwater');
    expect(styleLabel('natural_light'), 'Ánh sáng tự nhiên');
    expect(styleLabel('nope'), 'nope');
  });

  test('specialty codes match the data model catalogue', () {
    expect(kSpecialties.map((o) => o.id), [
      'portrait',
      'wedding',
      'couple',
      'family',
      'graduation',
      'event',
      'product',
      'travel',
      'fashion',
      'food',
      'real_estate',
      'newborn',
      'street',
      'commercial',
    ]);
  });
}
