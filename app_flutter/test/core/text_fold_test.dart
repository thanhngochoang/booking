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

  test('decomposed (NFD) input folds too', () {
    expect(foldVietnamese('Qua\u0323n 1'), 'quan 1');
    expect(foldVietnamese('Thu\u0309 Đu\u031Bc\u0301'), 'thu duc');
    expect(foldVietnamese('e\u0302\u0301'), 'e');
  });

  test('every accented letter folds to its ASCII base', () {
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    for (final e in groups.entries) {
      for (final c in e.value.split('')) {
        expect(foldVietnamese(c), e.key, reason: c);
        expect(foldVietnamese(c.toUpperCase()), e.key, reason: c);
      }
    }
  });
}
