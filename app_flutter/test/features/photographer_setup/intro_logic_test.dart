import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/photographer_setup/intro_logic.dart';

IntroResult _v({
  String name = 'Minh Trí',
  String bio = 'Ánh sáng tự nhiên.',
  List<String> eq = const [],
}) => validateIntro(IntroInput(displayName: name, bio: bio, equipment: eq));

void main() {
  test('a complete intro is trimmed and accepted', () {
    final r = _v(
      name: '  Minh Trí ',
      bio: ' Ánh sáng. ',
      eq: const [' Sony A7 IV '],
    );
    expect(r.ok, isTrue);
    expect((r.displayName, r.bio), ('Minh Trí', 'Ánh sáng.'));
    expect(r.equipment, ['Sony A7 IV']);
  });

  test('name and bio are required, bio at most 300 characters', () {
    expect(_v(name: ' ').errors, {IntroField.name: IntroError.nameRequired});
    expect(_v(bio: '').errors, {IntroField.bio: IntroError.bioRequired});
    expect(_v(bio: 'x' * 301).errors, {IntroField.bio: IntroError.bioTooLong});
    expect(_v(bio: 'x' * 300).ok, isTrue);
  });

  test('equipment is trimmed, de-duplicated, cut and capped', () {
    expect(cleanEquipment(['Sony A7', 'sony a7', '  ', 'Godox']), [
      'Sony A7',
      'Godox',
    ]);
    expect(cleanEquipment(['x' * 41]).single, hasLength(40));
    expect(cleanEquipment([for (var i = 0; i < 10; i++) 'M$i']), hasLength(8));
  });
}
