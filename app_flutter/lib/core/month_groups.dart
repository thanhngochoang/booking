/// Items grouped by the Vietnamese month of their day key, in the order they
/// come (newest first); the order inside a month is kept. [keyOf] returns a
/// `yyyy-MM-dd` Vietnam day key (a shorter key is used as it is).
List<({String monthKey, List<T> items})> groupByVnMonth<T>(
  Iterable<T> items,
  String Function(T item) keyOf,
) {
  final order = <String>[];
  final byMonth = <String, List<T>>{};
  for (final item in items) {
    final day = keyOf(item);
    final key = day.length >= 7 ? day.substring(0, 7) : day;
    byMonth
        .putIfAbsent(key, () {
          order.add(key);
          return <T>[];
        })
        .add(item);
  }
  return [for (final k in order) (monthKey: k, items: byMonth[k]!)];
}
