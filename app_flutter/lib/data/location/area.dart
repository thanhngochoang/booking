import 'package:photobooking/core/core.dart';

/// A district or city the user can pick when location is off (S36).
class AreaOption {
  const AreaOption({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;

  /// Centre of the district; a public constant, not the user's position.
  final double lat;
  final double lng;

  String get geohash5 => encodeGeohash(lat, lng, precision: 5);

  SavedArea toSaved() => SavedArea(id: id, name: name, geohash5: geohash5);

  @override
  bool operator ==(Object other) =>
      other is AreaOption &&
      other.id == id &&
      other.name == name &&
      other.lat == lat &&
      other.lng == lng;

  @override
  int get hashCode => Object.hash(id, name, lat, lng);
}

/// What is remembered on the device: the area's name and its geohash cell.
class SavedArea {
  const SavedArea({
    required this.id,
    required this.name,
    required this.geohash5,
  });

  final String id;
  final String name;
  final String geohash5;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'geohash5': geohash5,
  };

  factory SavedArea.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final hash = json['geohash5'];
    if (id is! String || name is! String || hash is! String) {
      throw const FormatException('saved area is incomplete');
    }
    if (hash.length != 5) {
      throw const FormatException('geohash5 must have 5 characters');
    }
    try {
      decodeGeohash(hash);
    } on ArgumentError {
      throw const FormatException('geohash5 is not a geohash');
    }
    return SavedArea(id: id, name: name, geohash5: hash);
  }

  /// Centre of the cell, used as the origin for distances.
  ({double lat, double lng}) get center => decodeGeohash(geohash5);

  @override
  bool operator ==(Object other) =>
      other is SavedArea &&
      other.id == id &&
      other.name == name &&
      other.geohash5 == geohash5;

  @override
  int get hashCode => Object.hash(id, name, geohash5);
}

abstract class AreaRepository {
  Future<List<AreaOption>> list();
}

class BuiltInAreaRepository implements AreaRepository {
  const BuiltInAreaRepository();

  @override
  Future<List<AreaOption>> list() async => builtInAreas;
}

/// Used when the `taxonomy/areas` list cannot be loaded (spec S36, "lỗi tải
/// danh sách → dùng danh sách tích hợp sẵn").
const List<AreaOption> builtInAreas = [
  AreaOption(id: 'hcm-q1', name: 'Quận 1, TP.HCM', lat: 10.7769, lng: 106.7009),
  AreaOption(id: 'hcm-q3', name: 'Quận 3, TP.HCM', lat: 10.7840, lng: 106.6842),
  AreaOption(id: 'hcm-q7', name: 'Quận 7, TP.HCM', lat: 10.7340, lng: 106.7219),
  AreaOption(
    id: 'hcm-binh-thanh',
    name: 'Bình Thạnh, TP.HCM',
    lat: 10.8106,
    lng: 106.7091,
  ),
  AreaOption(
    id: 'hcm-thu-duc',
    name: 'Thủ Đức, TP.HCM',
    lat: 10.8494,
    lng: 106.7537,
  ),
  AreaOption(
    id: 'hn-hoan-kiem',
    name: 'Hoàn Kiếm, Hà Nội',
    lat: 21.0285,
    lng: 105.8542,
  ),
  AreaOption(
    id: 'hn-ba-dinh',
    name: 'Ba Đình, Hà Nội',
    lat: 21.0340,
    lng: 105.8190,
  ),
  AreaOption(
    id: 'hn-cau-giay',
    name: 'Cầu Giấy, Hà Nội',
    lat: 21.0333,
    lng: 105.7940,
  ),
  AreaOption(
    id: 'dn-hai-chau',
    name: 'Hải Châu, Đà Nẵng',
    lat: 16.0471,
    lng: 108.2208,
  ),
  AreaOption(id: 'hue', name: 'Huế', lat: 16.4637, lng: 107.5909),
  AreaOption(id: 'da-lat', name: 'Đà Lạt', lat: 11.9404, lng: 108.4583),
  AreaOption(id: 'nha-trang', name: 'Nha Trang', lat: 12.2388, lng: 109.1967),
];
