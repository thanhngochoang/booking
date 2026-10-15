import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

/// Group of a skills catalogue item (`taxonomy/skills/items/{id}.group`).
enum SkillGroup {
  specialty('specialty'),
  style('style'),
  extra('extra'),
  language('language'),
  audience('audience');

  const SkillGroup(this.code);

  /// Stable string code used in data and rules.
  final String code;

  static SkillGroup? fromCode(String? code) {
    for (final g in values) {
      if (g.code == code) return g;
    }
    return null;
  }
}

/// One catalogue entry. A retired entry (`active: false`) still renders on
/// old profiles but cannot be chosen again (spec 3e.2).
class TaxonomyItem {
  const TaxonomyItem({
    required this.id,
    required this.group,
    required this.labelVi,
    required this.order,
    this.active = true,
  });

  final String id;
  final SkillGroup group;
  final String labelVi;
  final int order;
  final bool active;
}

/// The skills catalogue, keyed by `(group, id)` because a code may exist in
/// two groups (`couple` is a specialty and an audience).
class TaxonomyCatalog {
  TaxonomyCatalog(Iterable<TaxonomyItem> items)
    : _items = {for (final i in items) (i.group, i.id): i};

  final Map<(SkillGroup, String), TaxonomyItem> _items;

  TaxonomyItem? item(SkillGroup group, String id) => _items[(group, id)];

  bool isKnown(SkillGroup group, String id) => _items.containsKey((group, id));

  bool isSelectable(SkillGroup group, String id) =>
      _items[(group, id)]?.active ?? false;

  /// Vietnamese label; the code itself for unknown ids, so old data renders.
  String label(SkillGroup group, String id) =>
      _items[(group, id)]?.labelVi ?? id;

  /// What a picker shows: active items plus the retired ones in [keep]
  /// (already chosen), in catalogue order.
  List<TaxonomyItem> options(
    SkillGroup group, {
    Iterable<String> keep = const [],
  }) {
    final kept = keep.toSet();
    return _items.values
        .where((i) => i.group == group && (i.active || kept.contains(i.id)))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Active ids of [group], in catalogue order.
  List<String> ids(SkillGroup group) => [for (final i in options(group)) i.id];
}

Iterable<TaxonomyItem> _fromOptions(
  SkillGroup group,
  List<TaxonomyOption> options,
) sync* {
  for (var i = 0; i < options.length; i++) {
    yield TaxonomyItem(
      id: options[i].id,
      group: group,
      labelVi: options[i].labelVi,
      order: i,
    );
  }
}

/// Built-in mirror of `taxonomy/skills` (seed list in relational-schema.md
/// §6). A remote catalogue can replace it through `skillCatalogProvider`.
final TaxonomyCatalog builtInSkillCatalog = TaxonomyCatalog([
  ..._fromOptions(SkillGroup.specialty, kSpecialties),
  ..._fromOptions(SkillGroup.style, kStyles),
  ..._fromOptions(SkillGroup.extra, kExtras),
  ..._fromOptions(SkillGroup.language, kLanguages),
  ..._fromOptions(SkillGroup.audience, kAudiences),
]);
