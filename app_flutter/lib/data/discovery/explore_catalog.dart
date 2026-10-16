// lib/data/discovery/explore_catalog.dart

class ExploreCategoryStat {
  const ExploreCategoryStat({
    required this.serviceCount,
    this.coverUrl,
  });

  final int serviceCount;
  final String? coverUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExploreCategoryStat &&
          runtimeType == other.runtimeType &&
          serviceCount == other.serviceCount &&
          coverUrl == other.coverUrl;

  @override
  int get hashCode => Object.hash(serviceCount, coverUrl);
}

class ExploreCatalog {
  const ExploreCatalog(this.specialties);

  final Map<String, ExploreCategoryStat> specialties;

  static const empty = ExploreCatalog({});

  ExploreCategoryStat? operator [](String specialty) => specialties[specialty];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExploreCatalog &&
          runtimeType == other.runtimeType &&
          specialties.length == other.specialties.length &&
          specialties.entries.every((e) => other.specialties[e.key] == e.value);

  @override
  int get hashCode => Object.hashAll(specialties.entries);
}
