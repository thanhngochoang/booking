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
