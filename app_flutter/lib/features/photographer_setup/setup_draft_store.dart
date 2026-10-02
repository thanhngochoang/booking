import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/features/settings/theme_mode_controller.dart';

String _s(Object? v) => v is String ? v : '';

/// Step 1 as typed, before "Tiếp tục" saves it.
@immutable
class IntroDraft {
  const IntroDraft({
    this.displayName = '',
    this.bio = '',
    this.equipment = const [],
  });

  final String displayName;
  final String bio;
  final List<String> equipment;

  Map<String, Object> toJson() => {
    'displayName': displayName,
    'bio': bio,
    'equipment': equipment,
  };

  static IntroDraft? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final eq = raw['equipment'];
    return IntroDraft(
      displayName: _s(raw['displayName']),
      bio: _s(raw['bio']),
      equipment: [
        if (eq is List)
          for (final e in eq)
            if (e is String) e,
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IntroDraft &&
      other.displayName == displayName &&
      other.bio == bio &&
      listEquals(other.equipment, equipment);

  @override
  int get hashCode => Object.hash(displayName, bio, Object.hashAll(equipment));
}

/// The package form of step 2 as typed, before "Thêm gói này".
@immutable
class PackageDraft {
  const PackageDraft({
    this.name = '',
    this.price = '',
    this.durationMinutes,
    this.edited = '',
    this.delivery = '',
  });

  final String name;
  final String price;
  final int? durationMinutes;
  final String edited;
  final String delivery;

  bool get isEmpty =>
      name.isEmpty &&
      price.isEmpty &&
      durationMinutes == null &&
      edited.isEmpty &&
      delivery.isEmpty;

  Map<String, Object?> toJson() => {
    'name': name,
    'price': price,
    'durationMinutes': durationMinutes,
    'edited': edited,
    'delivery': delivery,
  };

  static PackageDraft? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final d = raw['durationMinutes'];
    return PackageDraft(
      name: _s(raw['name']),
      price: _s(raw['price']),
      durationMinutes: d is int ? d : null,
      edited: _s(raw['edited']),
      delivery: _s(raw['delivery']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PackageDraft &&
      other.name == name &&
      other.price == price &&
      other.durationMinutes == durationMinutes &&
      other.edited == edited &&
      other.delivery == delivery;

  @override
  int get hashCode =>
      Object.hash(name, price, durationMinutes, edited, delivery);
}

/// What the photographer typed in setup but has not saved yet, and the step
/// to come back to, kept on this device per user (spec S08.01 "lưu nháp mỗi
/// bước", "thoát và quay lại tiếp tục đúng bước"). Saved data is in the
/// backend; this never holds anything the server needs.
class SetupDraftStore {
  SetupDraftStore(this._prefs);

  final SharedPreferences _prefs;

  String _key(String what, String uid) => 'setup.$what.$uid';

  Object? _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  IntroDraft? intro(String uid) =>
      IntroDraft.fromJson(_read(_key('intro', uid)));

  Future<void> saveIntro(String uid, IntroDraft d) =>
      _prefs.setString(_key('intro', uid), jsonEncode(d.toJson()));

  Future<void> clearIntro(String uid) => _prefs.remove(_key('intro', uid));

  PackageDraft? package(String uid) =>
      PackageDraft.fromJson(_read(_key('package', uid)));

  Future<void> savePackage(String uid, PackageDraft d) =>
      _prefs.setString(_key('package', uid), jsonEncode(d.toJson()));

  Future<void> clearPackage(String uid) => _prefs.remove(_key('package', uid));

  int step(String uid) => _prefs.getInt(_key('step', uid)) ?? 1;

  Future<void> setStep(String uid, int step) =>
      _prefs.setInt(_key('step', uid), step);
}

final setupDraftStoreProvider = Provider<SetupDraftStore>(
  (ref) => SetupDraftStore(ref.watch(sharedPreferencesProvider)),
);

/// Where `/setup` resumes. Steps 3 (S08.02) and 4 (S08.05) are other plans' routes.
String setupResumePath(int step) => switch (step) {
  2 => '/setup/2',
  3 => '/setup/3',
  4 => '/setup/4',
  _ => '/setup/1',
};
