import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/text_fold.dart';

void main() {
  test('removes Vietnamese diacritics and lower-cases', () {
    expect(foldVietnamese('Quận 1, TP.HCM'), 'quan 1, tp.hcm');
    expect(foldVietnamese('Đà Lạt'), 'da lat');
    expect(foldVietnamese('Thủ Đức'), 'thu duc');
    expect(foldVietnamese('HOÀN KIẾM'), 'hoan kiem');
    expect(foldVietnamese('Nguyễn Thị Phương'), 'nguyen thi phuong');
    expect(foldVietnamese('ửỡữ ẳẵ ệ ỵ ơ ư'), 'uou aa e y o u');
  });

  test('plain ASCII is only lower-cased', () {
    expect(foldVietnamese('Hello World 123'), 'hello world 123');
    expect(foldVietnamese(''), '');
  });
}
