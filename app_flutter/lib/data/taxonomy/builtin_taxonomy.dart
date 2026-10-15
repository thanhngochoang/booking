/// One entry of a stable-code catalogue (`taxonomy/skills/items/{id}`).
class TaxonomyOption {
  const TaxonomyOption(this.id, this.labelVi);
  final String id;
  final String labelVi;
}

/// Built-in copy of the specialty catalogue (data-model/domain-model.md §4).
/// The `taxonomy` repository of plan 2c supersedes it; ids never change.
const List<TaxonomyOption> kSpecialties = [
  TaxonomyOption('portrait', 'Chân dung'),
  TaxonomyOption('wedding', 'Cưới'),
  TaxonomyOption('couple', 'Cặp đôi'),
  TaxonomyOption('family', 'Gia đình'),
  TaxonomyOption('graduation', 'Kỷ yếu'),
  TaxonomyOption('event', 'Sự kiện'),
  TaxonomyOption('product', 'Sản phẩm'),
  TaxonomyOption('travel', 'Du lịch'),
  TaxonomyOption('fashion', 'Thời trang'),
  TaxonomyOption('food', 'Ẩm thực'),
  TaxonomyOption('real_estate', 'Bất động sản'),
  TaxonomyOption('newborn', 'Em bé'),
  TaxonomyOption('street', 'Đường phố'),
  TaxonomyOption('commercial', 'Thương mại'),
];

const List<TaxonomyOption> kStyles = [
  TaxonomyOption('natural_light', 'Ánh sáng tự nhiên'),
  TaxonomyOption('film', 'Film'),
  TaxonomyOption('minimal', 'Tối giản'),
  TaxonomyOption('editorial', 'Editorial'),
  TaxonomyOption('documentary', 'Tư liệu'),
];

/// Extra skills (spec 3e.2 `extras`). Mirrored in firestore.rules
/// (`skillExtraIds`); a test keeps the two lists equal.
const List<TaxonomyOption> kExtras = [
  TaxonomyOption('retouch', 'Hậu kỳ'),
  TaxonomyOption('posing', 'Chỉ đạo tạo dáng'),
  TaxonomyOption('video', 'Quay video'),
  TaxonomyOption('drone', 'Flycam'),
  TaxonomyOption('studio', 'Studio'),
  TaxonomyOption('kids', 'Chụp trẻ em'),
  TaxonomyOption('pets', 'Thú cưng'),
  TaxonomyOption('low_light', 'Thiếu sáng'),
  TaxonomyOption('outdoor', 'Ngoài trời'),
];

/// Languages a photographer works in, labelled in their own language.
const List<TaxonomyOption> kLanguages = [
  TaxonomyOption('vi', 'Tiếng Việt'),
  TaxonomyOption('en', 'English'),
  TaxonomyOption('zh', '中文'),
  TaxonomyOption('ko', '한국어'),
  TaxonomyOption('ja', '日本語'),
];

/// Suitable clients (spec 3e.2 `audiences`): matching signals, not
/// techniques. `couple` is also a specialty code; look items up by group.
const List<TaxonomyOption> kAudiences = [
  TaxonomyOption('couple', 'Cặp đôi'),
  TaxonomyOption('family_kids', 'Gia đình có bé nhỏ'),
  TaxonomyOption('business', 'Doanh nghiệp'),
  TaxonomyOption('foreigner', 'Khách nước ngoài'),
  TaxonomyOption('shy_subjects', 'Người ngại ống kính'),
];

String _label(List<TaxonomyOption> list, String id) {
  for (final o in list) {
    if (o.id == id) {
      return o.labelVi;
    }
  }
  return id;
}

String specialtyLabel(String id) => _label(kSpecialties, id);
String styleLabel(String id) => _label(kStyles, id);
String extraLabel(String id) => _label(kExtras, id);
String languageLabel(String id) => _label(kLanguages, id);
String audienceLabel(String id) => _label(kAudiences, id);
