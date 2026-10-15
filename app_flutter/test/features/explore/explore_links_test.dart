// test/features/explore/explore_links_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/explore/explore_links.dart';

void main() {
  test('plain and filtered Find links', () {
    expect(findPhotographersPath(), '/action');
    expect(
      findPhotographersPath(specialty: 'portrait'),
      '/action?specialty=portrait',
    );
    expect(findPhotographersPath(style: 'film'), '/action?style=film');
    expect(findPhotographersPath(area: 'hcm-q1'), '/action?area=hcm-q1');
    expect(
      findPhotographersPath(specialty: 'wedding', area: 'hn-hoan-kiem'),
      '/action?specialty=wedding&area=hn-hoan-kiem',
    );
  });
}
