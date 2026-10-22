// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'instant_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InstantPackage {

 String get code; int get durationMin; int get photos; int get priceVnd;
/// Create a copy of InstantPackage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstantPackageCopyWith<InstantPackage> get copyWith => _$InstantPackageCopyWithImpl<InstantPackage>(this as InstantPackage, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InstantPackage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstantPackage&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.durationMin, _this.durationMin) || other.durationMin == _this.durationMin)&&(identical(other.photos, _this.photos) || other.photos == _this.photos)&&(identical(other.priceVnd, _this.priceVnd) || other.priceVnd == _this.priceVnd));
}


@override
int get hashCode {
  final _this = this as InstantPackage;
  return Object.hash(runtimeType,_this.code,_this.durationMin,_this.photos,_this.priceVnd);
}

@override
String toString() {
  final _this = this as InstantPackage;
  return 'InstantPackage(code: ${_this.code}, durationMin: ${_this.durationMin}, photos: ${_this.photos}, priceVnd: ${_this.priceVnd})';
}


}

/// @nodoc
abstract mixin class $InstantPackageCopyWith<$Res>  {
  factory $InstantPackageCopyWith(InstantPackage value, $Res Function(InstantPackage) _then) = _$InstantPackageCopyWithImpl;
@useResult
$Res call({
 String code, int durationMin, int photos, int priceVnd
});




}
/// @nodoc
class _$InstantPackageCopyWithImpl<$Res>
    implements $InstantPackageCopyWith<$Res> {
  _$InstantPackageCopyWithImpl(this._self, this._then);

  final InstantPackage _self;
  final $Res Function(InstantPackage) _then;

/// Create a copy of InstantPackage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? durationMin = null,Object? photos = null,Object? priceVnd = null,}) {
  return _then(InstantPackage(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,durationMin: null == durationMin ? _self.durationMin : durationMin // ignore: cast_nullable_to_non_nullable
as int,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as int,priceVnd: null == priceVnd ? _self.priceVnd : priceVnd // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InstantPackage].
extension InstantPackagePatterns on InstantPackage {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstantPackage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstantPackage() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstantPackage value)  $default,){
final _that = this;
switch (_that) {
case _InstantPackage():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstantPackage value)?  $default,){
final _that = this;
switch (_that) {
case _InstantPackage() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String code,  int durationMin,  int photos,  int priceVnd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstantPackage() when $default != null:
return $default(_that.code,_that.durationMin,_that.photos,_that.priceVnd);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String code,  int durationMin,  int photos,  int priceVnd)  $default,) {final _that = this;
switch (_that) {
case _InstantPackage():
return $default(_that.code,_that.durationMin,_that.photos,_that.priceVnd);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String code,  int durationMin,  int photos,  int priceVnd)?  $default,) {final _that = this;
switch (_that) {
case _InstantPackage() when $default != null:
return $default(_that.code,_that.durationMin,_that.photos,_that.priceVnd);case _:
  return null;

}
}

}

/// @nodoc


class _InstantPackage implements InstantPackage {
  const _InstantPackage({required this.code, required this.durationMin, required this.photos, required this.priceVnd});
  

@override final  String code;
@override final  int durationMin;
@override final  int photos;
@override final  int priceVnd;

/// Create a copy of InstantPackage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstantPackageCopyWith<_InstantPackage> get copyWith => __$InstantPackageCopyWithImpl<_InstantPackage>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstantPackage&&(identical(other.code, code) || other.code == code)&&(identical(other.durationMin, durationMin) || other.durationMin == durationMin)&&(identical(other.photos, photos) || other.photos == photos)&&(identical(other.priceVnd, priceVnd) || other.priceVnd == priceVnd));
}


@override
int get hashCode {
    return Object.hash(runtimeType,code,durationMin,photos,priceVnd);
}

@override
String toString() {
    return 'InstantPackage(code: $code, durationMin: $durationMin, photos: $photos, priceVnd: $priceVnd)';
}


}

/// @nodoc
abstract mixin class _$InstantPackageCopyWith<$Res> implements $InstantPackageCopyWith<$Res> {
  factory _$InstantPackageCopyWith(_InstantPackage value, $Res Function(_InstantPackage) _then) = __$InstantPackageCopyWithImpl;
@override @useResult
$Res call({
 String code, int durationMin, int photos, int priceVnd
});




}
/// @nodoc
class __$InstantPackageCopyWithImpl<$Res>
    implements _$InstantPackageCopyWith<$Res> {
  __$InstantPackageCopyWithImpl(this._self, this._then);

  final _InstantPackage _self;
  final $Res Function(_InstantPackage) _then;

/// Create a copy of InstantPackage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? durationMin = null,Object? photos = null,Object? priceVnd = null,}) {
  return _then(_InstantPackage(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,durationMin: null == durationMin ? _self.durationMin : durationMin // ignore: cast_nullable_to_non_nullable
as int,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as int,priceVnd: null == priceVnd ? _self.priceVnd : priceVnd // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$InstantConfig {

 bool get enabled; int get priceListVersion;/// 0–10 000; 0 = the photographer gets everything (Decision 6).
 int get platformFeeBp;/// 0–100: what the photographer keeps on an `arrived` cancel (Decision 9).
 int get instantArrivedCancelPhotographerPercent; List<InstantPackage> get packages; List<String> get cityNames;
/// Create a copy of InstantConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstantConfigCopyWith<InstantConfig> get copyWith => _$InstantConfigCopyWithImpl<InstantConfig>(this as InstantConfig, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InstantConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstantConfig&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.priceListVersion, _this.priceListVersion) || other.priceListVersion == _this.priceListVersion)&&(identical(other.platformFeeBp, _this.platformFeeBp) || other.platformFeeBp == _this.platformFeeBp)&&(identical(other.instantArrivedCancelPhotographerPercent, _this.instantArrivedCancelPhotographerPercent) || other.instantArrivedCancelPhotographerPercent == _this.instantArrivedCancelPhotographerPercent)&&const DeepCollectionEquality().equals(other.packages, _this.packages)&&const DeepCollectionEquality().equals(other.cityNames, _this.cityNames));
}


@override
int get hashCode {
  final _this = this as InstantConfig;
  return Object.hash(runtimeType,_this.enabled,_this.priceListVersion,_this.platformFeeBp,_this.instantArrivedCancelPhotographerPercent,const DeepCollectionEquality().hash(_this.packages),const DeepCollectionEquality().hash(_this.cityNames));
}

@override
String toString() {
  final _this = this as InstantConfig;
  return 'InstantConfig(enabled: ${_this.enabled}, priceListVersion: ${_this.priceListVersion}, platformFeeBp: ${_this.platformFeeBp}, instantArrivedCancelPhotographerPercent: ${_this.instantArrivedCancelPhotographerPercent}, packages: ${_this.packages}, cityNames: ${_this.cityNames})';
}


}

/// @nodoc
abstract mixin class $InstantConfigCopyWith<$Res>  {
  factory $InstantConfigCopyWith(InstantConfig value, $Res Function(InstantConfig) _then) = _$InstantConfigCopyWithImpl;
@useResult
$Res call({
 bool enabled, int priceListVersion, int platformFeeBp, int instantArrivedCancelPhotographerPercent, List<InstantPackage> packages, List<String> cityNames
});




}
/// @nodoc
class _$InstantConfigCopyWithImpl<$Res>
    implements $InstantConfigCopyWith<$Res> {
  _$InstantConfigCopyWithImpl(this._self, this._then);

  final InstantConfig _self;
  final $Res Function(InstantConfig) _then;

/// Create a copy of InstantConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? priceListVersion = null,Object? platformFeeBp = null,Object? instantArrivedCancelPhotographerPercent = null,Object? packages = null,Object? cityNames = null,}) {
  return _then(InstantConfig(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,priceListVersion: null == priceListVersion ? _self.priceListVersion : priceListVersion // ignore: cast_nullable_to_non_nullable
as int,platformFeeBp: null == platformFeeBp ? _self.platformFeeBp : platformFeeBp // ignore: cast_nullable_to_non_nullable
as int,instantArrivedCancelPhotographerPercent: null == instantArrivedCancelPhotographerPercent ? _self.instantArrivedCancelPhotographerPercent : instantArrivedCancelPhotographerPercent // ignore: cast_nullable_to_non_nullable
as int,packages: null == packages ? _self.packages : packages // ignore: cast_nullable_to_non_nullable
as List<InstantPackage>,cityNames: null == cityNames ? _self.cityNames : cityNames // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [InstantConfig].
extension InstantConfigPatterns on InstantConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstantConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstantConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstantConfig value)  $default,){
final _that = this;
switch (_that) {
case _InstantConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstantConfig value)?  $default,){
final _that = this;
switch (_that) {
case _InstantConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  int priceListVersion,  int platformFeeBp,  int instantArrivedCancelPhotographerPercent,  List<InstantPackage> packages,  List<String> cityNames)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstantConfig() when $default != null:
return $default(_that.enabled,_that.priceListVersion,_that.platformFeeBp,_that.instantArrivedCancelPhotographerPercent,_that.packages,_that.cityNames);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  int priceListVersion,  int platformFeeBp,  int instantArrivedCancelPhotographerPercent,  List<InstantPackage> packages,  List<String> cityNames)  $default,) {final _that = this;
switch (_that) {
case _InstantConfig():
return $default(_that.enabled,_that.priceListVersion,_that.platformFeeBp,_that.instantArrivedCancelPhotographerPercent,_that.packages,_that.cityNames);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  int priceListVersion,  int platformFeeBp,  int instantArrivedCancelPhotographerPercent,  List<InstantPackage> packages,  List<String> cityNames)?  $default,) {final _that = this;
switch (_that) {
case _InstantConfig() when $default != null:
return $default(_that.enabled,_that.priceListVersion,_that.platformFeeBp,_that.instantArrivedCancelPhotographerPercent,_that.packages,_that.cityNames);case _:
  return null;

}
}

}

/// @nodoc


class _InstantConfig extends InstantConfig {
  const _InstantConfig({required this.enabled, required this.priceListVersion, this.platformFeeBp = 0, this.instantArrivedCancelPhotographerPercent = 50,  List<InstantPackage> packages = const <InstantPackage>[],  List<String> cityNames = const <String>[]}): _packages = packages,_cityNames = cityNames,super._();
  

@override final  bool enabled;
@override final  int priceListVersion;
/// 0–10 000; 0 = the photographer gets everything (Decision 6).
@override@JsonKey() final  int platformFeeBp;
/// 0–100: what the photographer keeps on an `arrived` cancel (Decision 9).
@override@JsonKey() final  int instantArrivedCancelPhotographerPercent;
 final  List<InstantPackage> _packages;
@override@JsonKey() List<InstantPackage> get packages {
  if (_packages is EqualUnmodifiableListView) return _packages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_packages);
}

 final  List<String> _cityNames;
@override@JsonKey() List<String> get cityNames {
  if (_cityNames is EqualUnmodifiableListView) return _cityNames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cityNames);
}


/// Create a copy of InstantConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstantConfigCopyWith<_InstantConfig> get copyWith => __$InstantConfigCopyWithImpl<_InstantConfig>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstantConfig&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.priceListVersion, priceListVersion) || other.priceListVersion == priceListVersion)&&(identical(other.platformFeeBp, platformFeeBp) || other.platformFeeBp == platformFeeBp)&&(identical(other.instantArrivedCancelPhotographerPercent, instantArrivedCancelPhotographerPercent) || other.instantArrivedCancelPhotographerPercent == instantArrivedCancelPhotographerPercent)&&const DeepCollectionEquality().equals(other.packages, _packages)&&const DeepCollectionEquality().equals(other.cityNames, _cityNames));
}


@override
int get hashCode {
    return Object.hash(runtimeType,enabled,priceListVersion,platformFeeBp,instantArrivedCancelPhotographerPercent,const DeepCollectionEquality().hash(_packages),const DeepCollectionEquality().hash(_cityNames));
}

@override
String toString() {
    return 'InstantConfig(enabled: $enabled, priceListVersion: $priceListVersion, platformFeeBp: $platformFeeBp, instantArrivedCancelPhotographerPercent: $instantArrivedCancelPhotographerPercent, packages: $packages, cityNames: $cityNames)';
}


}

/// @nodoc
abstract mixin class _$InstantConfigCopyWith<$Res> implements $InstantConfigCopyWith<$Res> {
  factory _$InstantConfigCopyWith(_InstantConfig value, $Res Function(_InstantConfig) _then) = __$InstantConfigCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, int priceListVersion, int platformFeeBp, int instantArrivedCancelPhotographerPercent, List<InstantPackage> packages, List<String> cityNames
});




}
/// @nodoc
class __$InstantConfigCopyWithImpl<$Res>
    implements _$InstantConfigCopyWith<$Res> {
  __$InstantConfigCopyWithImpl(this._self, this._then);

  final _InstantConfig _self;
  final $Res Function(_InstantConfig) _then;

/// Create a copy of InstantConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? priceListVersion = null,Object? platformFeeBp = null,Object? instantArrivedCancelPhotographerPercent = null,Object? packages = null,Object? cityNames = null,}) {
  return _then(_InstantConfig(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,priceListVersion: null == priceListVersion ? _self.priceListVersion : priceListVersion // ignore: cast_nullable_to_non_nullable
as int,platformFeeBp: null == platformFeeBp ? _self.platformFeeBp : platformFeeBp // ignore: cast_nullable_to_non_nullable
as int,instantArrivedCancelPhotographerPercent: null == instantArrivedCancelPhotographerPercent ? _self.instantArrivedCancelPhotographerPercent : instantArrivedCancelPhotographerPercent // ignore: cast_nullable_to_non_nullable
as int,packages: null == packages ? _self._packages : packages // ignore: cast_nullable_to_non_nullable
as List<InstantPackage>,cityNames: null == cityNames ? _self._cityNames : cityNames // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$InstantParty {

 String get id; String get name; String? get avatarUrl; bool get verified; int get tomatoPct; int get reviewCount; int get completedCount;
/// Create a copy of InstantParty
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstantPartyCopyWith<InstantParty> get copyWith => _$InstantPartyCopyWithImpl<InstantParty>(this as InstantParty, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InstantParty;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstantParty&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.verified, _this.verified) || other.verified == _this.verified)&&(identical(other.tomatoPct, _this.tomatoPct) || other.tomatoPct == _this.tomatoPct)&&(identical(other.reviewCount, _this.reviewCount) || other.reviewCount == _this.reviewCount)&&(identical(other.completedCount, _this.completedCount) || other.completedCount == _this.completedCount));
}


@override
int get hashCode {
  final _this = this as InstantParty;
  return Object.hash(runtimeType,_this.id,_this.name,_this.avatarUrl,_this.verified,_this.tomatoPct,_this.reviewCount,_this.completedCount);
}

@override
String toString() {
  final _this = this as InstantParty;
  return 'InstantParty(id: ${_this.id}, name: ${_this.name}, avatarUrl: ${_this.avatarUrl}, verified: ${_this.verified}, tomatoPct: ${_this.tomatoPct}, reviewCount: ${_this.reviewCount}, completedCount: ${_this.completedCount})';
}


}

/// @nodoc
abstract mixin class $InstantPartyCopyWith<$Res>  {
  factory $InstantPartyCopyWith(InstantParty value, $Res Function(InstantParty) _then) = _$InstantPartyCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? avatarUrl, bool verified, int tomatoPct, int reviewCount, int completedCount
});




}
/// @nodoc
class _$InstantPartyCopyWithImpl<$Res>
    implements $InstantPartyCopyWith<$Res> {
  _$InstantPartyCopyWithImpl(this._self, this._then);

  final InstantParty _self;
  final $Res Function(InstantParty) _then;

/// Create a copy of InstantParty
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? avatarUrl = freezed,Object? verified = null,Object? tomatoPct = null,Object? reviewCount = null,Object? completedCount = null,}) {
  return _then(InstantParty(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,tomatoPct: null == tomatoPct ? _self.tomatoPct : tomatoPct // ignore: cast_nullable_to_non_nullable
as int,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InstantParty].
extension InstantPartyPatterns on InstantParty {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstantParty value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstantParty() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstantParty value)  $default,){
final _that = this;
switch (_that) {
case _InstantParty():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstantParty value)?  $default,){
final _that = this;
switch (_that) {
case _InstantParty() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? avatarUrl,  bool verified,  int tomatoPct,  int reviewCount,  int completedCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstantParty() when $default != null:
return $default(_that.id,_that.name,_that.avatarUrl,_that.verified,_that.tomatoPct,_that.reviewCount,_that.completedCount);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? avatarUrl,  bool verified,  int tomatoPct,  int reviewCount,  int completedCount)  $default,) {final _that = this;
switch (_that) {
case _InstantParty():
return $default(_that.id,_that.name,_that.avatarUrl,_that.verified,_that.tomatoPct,_that.reviewCount,_that.completedCount);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? avatarUrl,  bool verified,  int tomatoPct,  int reviewCount,  int completedCount)?  $default,) {final _that = this;
switch (_that) {
case _InstantParty() when $default != null:
return $default(_that.id,_that.name,_that.avatarUrl,_that.verified,_that.tomatoPct,_that.reviewCount,_that.completedCount);case _:
  return null;

}
}

}

/// @nodoc


class _InstantParty implements InstantParty {
  const _InstantParty({required this.id, this.name = '', this.avatarUrl, this.verified = false, this.tomatoPct = 0, this.reviewCount = 0, this.completedCount = 0});
  

@override final  String id;
@override@JsonKey() final  String name;
@override final  String? avatarUrl;
@override@JsonKey() final  bool verified;
@override@JsonKey() final  int tomatoPct;
@override@JsonKey() final  int reviewCount;
@override@JsonKey() final  int completedCount;

/// Create a copy of InstantParty
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstantPartyCopyWith<_InstantParty> get copyWith => __$InstantPartyCopyWithImpl<_InstantParty>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstantParty&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.tomatoPct, tomatoPct) || other.tomatoPct == tomatoPct)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&(identical(other.completedCount, completedCount) || other.completedCount == completedCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,avatarUrl,verified,tomatoPct,reviewCount,completedCount);
}

@override
String toString() {
    return 'InstantParty(id: $id, name: $name, avatarUrl: $avatarUrl, verified: $verified, tomatoPct: $tomatoPct, reviewCount: $reviewCount, completedCount: $completedCount)';
}


}

/// @nodoc
abstract mixin class _$InstantPartyCopyWith<$Res> implements $InstantPartyCopyWith<$Res> {
  factory _$InstantPartyCopyWith(_InstantParty value, $Res Function(_InstantParty) _then) = __$InstantPartyCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? avatarUrl, bool verified, int tomatoPct, int reviewCount, int completedCount
});




}
/// @nodoc
class __$InstantPartyCopyWithImpl<$Res>
    implements _$InstantPartyCopyWith<$Res> {
  __$InstantPartyCopyWithImpl(this._self, this._then);

  final _InstantParty _self;
  final $Res Function(_InstantParty) _then;

/// Create a copy of InstantParty
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? avatarUrl = freezed,Object? verified = null,Object? tomatoPct = null,Object? reviewCount = null,Object? completedCount = null,}) {
  return _then(_InstantParty(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,tomatoPct: null == tomatoPct ? _self.tomatoPct : tomatoPct // ignore: cast_nullable_to_non_nullable
as int,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$InstantCandidate {

 String get photographerId; String get name; String? get avatarUrl; bool get verified; int get tomatoPct; int get reviewCount; int get completedCount; double get distanceKm; int get etaMinutes; List<String> get photos;/// The reason texts (≤ 2), as the server wrote them.
 List<String> get reasons;
/// Create a copy of InstantCandidate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstantCandidateCopyWith<InstantCandidate> get copyWith => _$InstantCandidateCopyWithImpl<InstantCandidate>(this as InstantCandidate, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InstantCandidate;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstantCandidate&&(identical(other.photographerId, _this.photographerId) || other.photographerId == _this.photographerId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.verified, _this.verified) || other.verified == _this.verified)&&(identical(other.tomatoPct, _this.tomatoPct) || other.tomatoPct == _this.tomatoPct)&&(identical(other.reviewCount, _this.reviewCount) || other.reviewCount == _this.reviewCount)&&(identical(other.completedCount, _this.completedCount) || other.completedCount == _this.completedCount)&&(identical(other.distanceKm, _this.distanceKm) || other.distanceKm == _this.distanceKm)&&(identical(other.etaMinutes, _this.etaMinutes) || other.etaMinutes == _this.etaMinutes)&&const DeepCollectionEquality().equals(other.photos, _this.photos)&&const DeepCollectionEquality().equals(other.reasons, _this.reasons));
}


@override
int get hashCode {
  final _this = this as InstantCandidate;
  return Object.hash(runtimeType,_this.photographerId,_this.name,_this.avatarUrl,_this.verified,_this.tomatoPct,_this.reviewCount,_this.completedCount,_this.distanceKm,_this.etaMinutes,const DeepCollectionEquality().hash(_this.photos),const DeepCollectionEquality().hash(_this.reasons));
}

@override
String toString() {
  final _this = this as InstantCandidate;
  return 'InstantCandidate(photographerId: ${_this.photographerId}, name: ${_this.name}, avatarUrl: ${_this.avatarUrl}, verified: ${_this.verified}, tomatoPct: ${_this.tomatoPct}, reviewCount: ${_this.reviewCount}, completedCount: ${_this.completedCount}, distanceKm: ${_this.distanceKm}, etaMinutes: ${_this.etaMinutes}, photos: ${_this.photos}, reasons: ${_this.reasons})';
}


}

/// @nodoc
abstract mixin class $InstantCandidateCopyWith<$Res>  {
  factory $InstantCandidateCopyWith(InstantCandidate value, $Res Function(InstantCandidate) _then) = _$InstantCandidateCopyWithImpl;
@useResult
$Res call({
 String photographerId, String name, String? avatarUrl, bool verified, int tomatoPct, int reviewCount, int completedCount, double distanceKm, int etaMinutes, List<String> photos, List<String> reasons
});




}
/// @nodoc
class _$InstantCandidateCopyWithImpl<$Res>
    implements $InstantCandidateCopyWith<$Res> {
  _$InstantCandidateCopyWithImpl(this._self, this._then);

  final InstantCandidate _self;
  final $Res Function(InstantCandidate) _then;

/// Create a copy of InstantCandidate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? photographerId = null,Object? name = null,Object? avatarUrl = freezed,Object? verified = null,Object? tomatoPct = null,Object? reviewCount = null,Object? completedCount = null,Object? distanceKm = null,Object? etaMinutes = null,Object? photos = null,Object? reasons = null,}) {
  return _then(InstantCandidate(
photographerId: null == photographerId ? _self.photographerId : photographerId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,tomatoPct: null == tomatoPct ? _self.tomatoPct : tomatoPct // ignore: cast_nullable_to_non_nullable
as int,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,etaMinutes: null == etaMinutes ? _self.etaMinutes : etaMinutes // ignore: cast_nullable_to_non_nullable
as int,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<String>,reasons: null == reasons ? _self.reasons : reasons // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [InstantCandidate].
extension InstantCandidatePatterns on InstantCandidate {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstantCandidate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstantCandidate() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstantCandidate value)  $default,){
final _that = this;
switch (_that) {
case _InstantCandidate():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstantCandidate value)?  $default,){
final _that = this;
switch (_that) {
case _InstantCandidate() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String photographerId,  String name,  String? avatarUrl,  bool verified,  int tomatoPct,  int reviewCount,  int completedCount,  double distanceKm,  int etaMinutes,  List<String> photos,  List<String> reasons)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstantCandidate() when $default != null:
return $default(_that.photographerId,_that.name,_that.avatarUrl,_that.verified,_that.tomatoPct,_that.reviewCount,_that.completedCount,_that.distanceKm,_that.etaMinutes,_that.photos,_that.reasons);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String photographerId,  String name,  String? avatarUrl,  bool verified,  int tomatoPct,  int reviewCount,  int completedCount,  double distanceKm,  int etaMinutes,  List<String> photos,  List<String> reasons)  $default,) {final _that = this;
switch (_that) {
case _InstantCandidate():
return $default(_that.photographerId,_that.name,_that.avatarUrl,_that.verified,_that.tomatoPct,_that.reviewCount,_that.completedCount,_that.distanceKm,_that.etaMinutes,_that.photos,_that.reasons);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String photographerId,  String name,  String? avatarUrl,  bool verified,  int tomatoPct,  int reviewCount,  int completedCount,  double distanceKm,  int etaMinutes,  List<String> photos,  List<String> reasons)?  $default,) {final _that = this;
switch (_that) {
case _InstantCandidate() when $default != null:
return $default(_that.photographerId,_that.name,_that.avatarUrl,_that.verified,_that.tomatoPct,_that.reviewCount,_that.completedCount,_that.distanceKm,_that.etaMinutes,_that.photos,_that.reasons);case _:
  return null;

}
}

}

/// @nodoc


class _InstantCandidate implements InstantCandidate {
  const _InstantCandidate({required this.photographerId, this.name = '', this.avatarUrl, this.verified = false, this.tomatoPct = 0, this.reviewCount = 0, this.completedCount = 0, this.distanceKm = 0, this.etaMinutes = 1,  List<String> photos = const <String>[],  List<String> reasons = const <String>[]}): _photos = photos,_reasons = reasons;
  

@override final  String photographerId;
@override@JsonKey() final  String name;
@override final  String? avatarUrl;
@override@JsonKey() final  bool verified;
@override@JsonKey() final  int tomatoPct;
@override@JsonKey() final  int reviewCount;
@override@JsonKey() final  int completedCount;
@override@JsonKey() final  double distanceKm;
@override@JsonKey() final  int etaMinutes;
 final  List<String> _photos;
@override@JsonKey() List<String> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}

/// The reason texts (≤ 2), as the server wrote them.
 final  List<String> _reasons;
/// The reason texts (≤ 2), as the server wrote them.
@override@JsonKey() List<String> get reasons {
  if (_reasons is EqualUnmodifiableListView) return _reasons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reasons);
}


/// Create a copy of InstantCandidate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstantCandidateCopyWith<_InstantCandidate> get copyWith => __$InstantCandidateCopyWithImpl<_InstantCandidate>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstantCandidate&&(identical(other.photographerId, photographerId) || other.photographerId == photographerId)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.tomatoPct, tomatoPct) || other.tomatoPct == tomatoPct)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&(identical(other.completedCount, completedCount) || other.completedCount == completedCount)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.etaMinutes, etaMinutes) || other.etaMinutes == etaMinutes)&&const DeepCollectionEquality().equals(other.photos, _photos)&&const DeepCollectionEquality().equals(other.reasons, _reasons));
}


@override
int get hashCode {
    return Object.hash(runtimeType,photographerId,name,avatarUrl,verified,tomatoPct,reviewCount,completedCount,distanceKm,etaMinutes,const DeepCollectionEquality().hash(_photos),const DeepCollectionEquality().hash(_reasons));
}

@override
String toString() {
    return 'InstantCandidate(photographerId: $photographerId, name: $name, avatarUrl: $avatarUrl, verified: $verified, tomatoPct: $tomatoPct, reviewCount: $reviewCount, completedCount: $completedCount, distanceKm: $distanceKm, etaMinutes: $etaMinutes, photos: $photos, reasons: $reasons)';
}


}

/// @nodoc
abstract mixin class _$InstantCandidateCopyWith<$Res> implements $InstantCandidateCopyWith<$Res> {
  factory _$InstantCandidateCopyWith(_InstantCandidate value, $Res Function(_InstantCandidate) _then) = __$InstantCandidateCopyWithImpl;
@override @useResult
$Res call({
 String photographerId, String name, String? avatarUrl, bool verified, int tomatoPct, int reviewCount, int completedCount, double distanceKm, int etaMinutes, List<String> photos, List<String> reasons
});




}
/// @nodoc
class __$InstantCandidateCopyWithImpl<$Res>
    implements _$InstantCandidateCopyWith<$Res> {
  __$InstantCandidateCopyWithImpl(this._self, this._then);

  final _InstantCandidate _self;
  final $Res Function(_InstantCandidate) _then;

/// Create a copy of InstantCandidate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? photographerId = null,Object? name = null,Object? avatarUrl = freezed,Object? verified = null,Object? tomatoPct = null,Object? reviewCount = null,Object? completedCount = null,Object? distanceKm = null,Object? etaMinutes = null,Object? photos = null,Object? reasons = null,}) {
  return _then(_InstantCandidate(
photographerId: null == photographerId ? _self.photographerId : photographerId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,tomatoPct: null == tomatoPct ? _self.tomatoPct : tomatoPct // ignore: cast_nullable_to_non_nullable
as int,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,etaMinutes: null == etaMinutes ? _self.etaMinutes : etaMinutes // ignore: cast_nullable_to_non_nullable
as int,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<String>,reasons: null == reasons ? _self._reasons : reasons // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$InstantOfferRow {

 String get photographerId; String get name; String? get avatarUrl; int get tomatoPct; int get reviewCount; int get etaMinutes; OfferOutcome get outcome; DateTime? get expiresAt;
/// Create a copy of InstantOfferRow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstantOfferRowCopyWith<InstantOfferRow> get copyWith => _$InstantOfferRowCopyWithImpl<InstantOfferRow>(this as InstantOfferRow, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InstantOfferRow;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstantOfferRow&&(identical(other.photographerId, _this.photographerId) || other.photographerId == _this.photographerId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.tomatoPct, _this.tomatoPct) || other.tomatoPct == _this.tomatoPct)&&(identical(other.reviewCount, _this.reviewCount) || other.reviewCount == _this.reviewCount)&&(identical(other.etaMinutes, _this.etaMinutes) || other.etaMinutes == _this.etaMinutes)&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt));
}


@override
int get hashCode {
  final _this = this as InstantOfferRow;
  return Object.hash(runtimeType,_this.photographerId,_this.name,_this.avatarUrl,_this.tomatoPct,_this.reviewCount,_this.etaMinutes,_this.outcome,_this.expiresAt);
}

@override
String toString() {
  final _this = this as InstantOfferRow;
  return 'InstantOfferRow(photographerId: ${_this.photographerId}, name: ${_this.name}, avatarUrl: ${_this.avatarUrl}, tomatoPct: ${_this.tomatoPct}, reviewCount: ${_this.reviewCount}, etaMinutes: ${_this.etaMinutes}, outcome: ${_this.outcome}, expiresAt: ${_this.expiresAt})';
}


}

/// @nodoc
abstract mixin class $InstantOfferRowCopyWith<$Res>  {
  factory $InstantOfferRowCopyWith(InstantOfferRow value, $Res Function(InstantOfferRow) _then) = _$InstantOfferRowCopyWithImpl;
@useResult
$Res call({
 String photographerId, String name, String? avatarUrl, int tomatoPct, int reviewCount, int etaMinutes, OfferOutcome outcome, DateTime? expiresAt
});




}
/// @nodoc
class _$InstantOfferRowCopyWithImpl<$Res>
    implements $InstantOfferRowCopyWith<$Res> {
  _$InstantOfferRowCopyWithImpl(this._self, this._then);

  final InstantOfferRow _self;
  final $Res Function(InstantOfferRow) _then;

/// Create a copy of InstantOfferRow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? photographerId = null,Object? name = null,Object? avatarUrl = freezed,Object? tomatoPct = null,Object? reviewCount = null,Object? etaMinutes = null,Object? outcome = null,Object? expiresAt = freezed,}) {
  return _then(InstantOfferRow(
photographerId: null == photographerId ? _self.photographerId : photographerId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,tomatoPct: null == tomatoPct ? _self.tomatoPct : tomatoPct // ignore: cast_nullable_to_non_nullable
as int,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,etaMinutes: null == etaMinutes ? _self.etaMinutes : etaMinutes // ignore: cast_nullable_to_non_nullable
as int,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as OfferOutcome,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [InstantOfferRow].
extension InstantOfferRowPatterns on InstantOfferRow {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstantOfferRow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstantOfferRow() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstantOfferRow value)  $default,){
final _that = this;
switch (_that) {
case _InstantOfferRow():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstantOfferRow value)?  $default,){
final _that = this;
switch (_that) {
case _InstantOfferRow() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String photographerId,  String name,  String? avatarUrl,  int tomatoPct,  int reviewCount,  int etaMinutes,  OfferOutcome outcome,  DateTime? expiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstantOfferRow() when $default != null:
return $default(_that.photographerId,_that.name,_that.avatarUrl,_that.tomatoPct,_that.reviewCount,_that.etaMinutes,_that.outcome,_that.expiresAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String photographerId,  String name,  String? avatarUrl,  int tomatoPct,  int reviewCount,  int etaMinutes,  OfferOutcome outcome,  DateTime? expiresAt)  $default,) {final _that = this;
switch (_that) {
case _InstantOfferRow():
return $default(_that.photographerId,_that.name,_that.avatarUrl,_that.tomatoPct,_that.reviewCount,_that.etaMinutes,_that.outcome,_that.expiresAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String photographerId,  String name,  String? avatarUrl,  int tomatoPct,  int reviewCount,  int etaMinutes,  OfferOutcome outcome,  DateTime? expiresAt)?  $default,) {final _that = this;
switch (_that) {
case _InstantOfferRow() when $default != null:
return $default(_that.photographerId,_that.name,_that.avatarUrl,_that.tomatoPct,_that.reviewCount,_that.etaMinutes,_that.outcome,_that.expiresAt);case _:
  return null;

}
}

}

/// @nodoc


class _InstantOfferRow implements InstantOfferRow {
  const _InstantOfferRow({required this.photographerId, this.name = '', this.avatarUrl, this.tomatoPct = 0, this.reviewCount = 0, this.etaMinutes = 1, required this.outcome, this.expiresAt});
  

@override final  String photographerId;
@override@JsonKey() final  String name;
@override final  String? avatarUrl;
@override@JsonKey() final  int tomatoPct;
@override@JsonKey() final  int reviewCount;
@override@JsonKey() final  int etaMinutes;
@override final  OfferOutcome outcome;
@override final  DateTime? expiresAt;

/// Create a copy of InstantOfferRow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstantOfferRowCopyWith<_InstantOfferRow> get copyWith => __$InstantOfferRowCopyWithImpl<_InstantOfferRow>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstantOfferRow&&(identical(other.photographerId, photographerId) || other.photographerId == photographerId)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.tomatoPct, tomatoPct) || other.tomatoPct == tomatoPct)&&(identical(other.reviewCount, reviewCount) || other.reviewCount == reviewCount)&&(identical(other.etaMinutes, etaMinutes) || other.etaMinutes == etaMinutes)&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,photographerId,name,avatarUrl,tomatoPct,reviewCount,etaMinutes,outcome,expiresAt);
}

@override
String toString() {
    return 'InstantOfferRow(photographerId: $photographerId, name: $name, avatarUrl: $avatarUrl, tomatoPct: $tomatoPct, reviewCount: $reviewCount, etaMinutes: $etaMinutes, outcome: $outcome, expiresAt: $expiresAt)';
}


}

/// @nodoc
abstract mixin class _$InstantOfferRowCopyWith<$Res> implements $InstantOfferRowCopyWith<$Res> {
  factory _$InstantOfferRowCopyWith(_InstantOfferRow value, $Res Function(_InstantOfferRow) _then) = __$InstantOfferRowCopyWithImpl;
@override @useResult
$Res call({
 String photographerId, String name, String? avatarUrl, int tomatoPct, int reviewCount, int etaMinutes, OfferOutcome outcome, DateTime? expiresAt
});




}
/// @nodoc
class __$InstantOfferRowCopyWithImpl<$Res>
    implements _$InstantOfferRowCopyWith<$Res> {
  __$InstantOfferRowCopyWithImpl(this._self, this._then);

  final _InstantOfferRow _self;
  final $Res Function(_InstantOfferRow) _then;

/// Create a copy of InstantOfferRow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? photographerId = null,Object? name = null,Object? avatarUrl = freezed,Object? tomatoPct = null,Object? reviewCount = null,Object? etaMinutes = null,Object? outcome = null,Object? expiresAt = freezed,}) {
  return _then(_InstantOfferRow(
photographerId: null == photographerId ? _self.photographerId : photographerId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,tomatoPct: null == tomatoPct ? _self.tomatoPct : tomatoPct // ignore: cast_nullable_to_non_nullable
as int,reviewCount: null == reviewCount ? _self.reviewCount : reviewCount // ignore: cast_nullable_to_non_nullable
as int,etaMinutes: null == etaMinutes ? _self.etaMinutes : etaMinutes // ignore: cast_nullable_to_non_nullable
as int,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as OfferOutcome,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

/// @nodoc
mixin _$InstantMeetPoint {

 double get lat; double get lng; String get name;
/// Create a copy of InstantMeetPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstantMeetPointCopyWith<InstantMeetPoint> get copyWith => _$InstantMeetPointCopyWithImpl<InstantMeetPoint>(this as InstantMeetPoint, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InstantMeetPoint;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstantMeetPoint&&(identical(other.lat, _this.lat) || other.lat == _this.lat)&&(identical(other.lng, _this.lng) || other.lng == _this.lng)&&(identical(other.name, _this.name) || other.name == _this.name));
}


@override
int get hashCode {
  final _this = this as InstantMeetPoint;
  return Object.hash(runtimeType,_this.lat,_this.lng,_this.name);
}

@override
String toString() {
  final _this = this as InstantMeetPoint;
  return 'InstantMeetPoint(lat: ${_this.lat}, lng: ${_this.lng}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $InstantMeetPointCopyWith<$Res>  {
  factory $InstantMeetPointCopyWith(InstantMeetPoint value, $Res Function(InstantMeetPoint) _then) = _$InstantMeetPointCopyWithImpl;
@useResult
$Res call({
 double lat, double lng, String name
});




}
/// @nodoc
class _$InstantMeetPointCopyWithImpl<$Res>
    implements $InstantMeetPointCopyWith<$Res> {
  _$InstantMeetPointCopyWithImpl(this._self, this._then);

  final InstantMeetPoint _self;
  final $Res Function(InstantMeetPoint) _then;

/// Create a copy of InstantMeetPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lat = null,Object? lng = null,Object? name = null,}) {
  return _then(InstantMeetPoint(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [InstantMeetPoint].
extension InstantMeetPointPatterns on InstantMeetPoint {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstantMeetPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstantMeetPoint() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstantMeetPoint value)  $default,){
final _that = this;
switch (_that) {
case _InstantMeetPoint():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstantMeetPoint value)?  $default,){
final _that = this;
switch (_that) {
case _InstantMeetPoint() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double lat,  double lng,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstantMeetPoint() when $default != null:
return $default(_that.lat,_that.lng,_that.name);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double lat,  double lng,  String name)  $default,) {final _that = this;
switch (_that) {
case _InstantMeetPoint():
return $default(_that.lat,_that.lng,_that.name);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double lat,  double lng,  String name)?  $default,) {final _that = this;
switch (_that) {
case _InstantMeetPoint() when $default != null:
return $default(_that.lat,_that.lng,_that.name);case _:
  return null;

}
}

}

/// @nodoc


class _InstantMeetPoint implements InstantMeetPoint {
  const _InstantMeetPoint({required this.lat, required this.lng, this.name = ''});
  

@override final  double lat;
@override final  double lng;
@override@JsonKey() final  String name;

/// Create a copy of InstantMeetPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstantMeetPointCopyWith<_InstantMeetPoint> get copyWith => __$InstantMeetPointCopyWithImpl<_InstantMeetPoint>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstantMeetPoint&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode {
    return Object.hash(runtimeType,lat,lng,name);
}

@override
String toString() {
    return 'InstantMeetPoint(lat: $lat, lng: $lng, name: $name)';
}


}

/// @nodoc
abstract mixin class _$InstantMeetPointCopyWith<$Res> implements $InstantMeetPointCopyWith<$Res> {
  factory _$InstantMeetPointCopyWith(_InstantMeetPoint value, $Res Function(_InstantMeetPoint) _then) = __$InstantMeetPointCopyWithImpl;
@override @useResult
$Res call({
 double lat, double lng, String name
});




}
/// @nodoc
class __$InstantMeetPointCopyWithImpl<$Res>
    implements _$InstantMeetPointCopyWith<$Res> {
  __$InstantMeetPointCopyWithImpl(this._self, this._then);

  final _InstantMeetPoint _self;
  final $Res Function(_InstantMeetPoint) _then;

/// Create a copy of InstantMeetPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lat = null,Object? lng = null,Object? name = null,}) {
  return _then(_InstantMeetPoint(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$InstantRequest {

 String get id; String get customerId; String get customerName; String? get customerAvatarUrl; InstantStatus get status; String get packageCode; int get durationMin; int get photos; InstantGenre get genre; String get note; InstantMeetPoint get meetPoint; String get areaLabel; int get amountVnd; int get earningVnd; int get platformFeeBp; int get arrivedCancelPhotographerPercent; PayMethod? get payMethod;/// `paidAt != null` (never in #140).
 bool get paid;/// `committedAt != null`: offers went out at least once.
 bool get committed; int get round; int get invitedTotal; int get roundsWithInvites; List<InstantCandidate> get candidates; List<InstantOfferRow> get offers; bool get roundEnded; String? get photographerId; InstantParty? get photographer; String? get chatId; int? get etaMinutes; DateTime? get assignedAt; DateTime? get freeCancelUntil; DateTime? get lateDeadlineAt; DateTime? get startedRouteAt; DateTime? get arrivedAt; DateTime? get startedAt; DateTime? get shootEndsAt; DateTime? get finishedAt; DateTime? get completedAt; DateTime? get cancelledAt; InstantParticipant? get cancelledBy; InstantCancelRule? get cancelRule; int? get refundPercent; int? get feeVnd; DateTime? get searchDeadlineAt; DateTime? get paymentDeadlineAt;
/// Create a copy of InstantRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstantRequestCopyWith<InstantRequest> get copyWith => _$InstantRequestCopyWithImpl<InstantRequest>(this as InstantRequest, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InstantRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstantRequest&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.customerId, _this.customerId) || other.customerId == _this.customerId)&&(identical(other.customerName, _this.customerName) || other.customerName == _this.customerName)&&(identical(other.customerAvatarUrl, _this.customerAvatarUrl) || other.customerAvatarUrl == _this.customerAvatarUrl)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.packageCode, _this.packageCode) || other.packageCode == _this.packageCode)&&(identical(other.durationMin, _this.durationMin) || other.durationMin == _this.durationMin)&&(identical(other.photos, _this.photos) || other.photos == _this.photos)&&(identical(other.genre, _this.genre) || other.genre == _this.genre)&&(identical(other.note, _this.note) || other.note == _this.note)&&(identical(other.meetPoint, _this.meetPoint) || other.meetPoint == _this.meetPoint)&&(identical(other.areaLabel, _this.areaLabel) || other.areaLabel == _this.areaLabel)&&(identical(other.amountVnd, _this.amountVnd) || other.amountVnd == _this.amountVnd)&&(identical(other.earningVnd, _this.earningVnd) || other.earningVnd == _this.earningVnd)&&(identical(other.platformFeeBp, _this.platformFeeBp) || other.platformFeeBp == _this.platformFeeBp)&&(identical(other.arrivedCancelPhotographerPercent, _this.arrivedCancelPhotographerPercent) || other.arrivedCancelPhotographerPercent == _this.arrivedCancelPhotographerPercent)&&(identical(other.payMethod, _this.payMethod) || other.payMethod == _this.payMethod)&&(identical(other.paid, _this.paid) || other.paid == _this.paid)&&(identical(other.committed, _this.committed) || other.committed == _this.committed)&&(identical(other.round, _this.round) || other.round == _this.round)&&(identical(other.invitedTotal, _this.invitedTotal) || other.invitedTotal == _this.invitedTotal)&&(identical(other.roundsWithInvites, _this.roundsWithInvites) || other.roundsWithInvites == _this.roundsWithInvites)&&const DeepCollectionEquality().equals(other.candidates, _this.candidates)&&const DeepCollectionEquality().equals(other.offers, _this.offers)&&(identical(other.roundEnded, _this.roundEnded) || other.roundEnded == _this.roundEnded)&&(identical(other.photographerId, _this.photographerId) || other.photographerId == _this.photographerId)&&(identical(other.photographer, _this.photographer) || other.photographer == _this.photographer)&&(identical(other.chatId, _this.chatId) || other.chatId == _this.chatId)&&(identical(other.etaMinutes, _this.etaMinutes) || other.etaMinutes == _this.etaMinutes)&&(identical(other.assignedAt, _this.assignedAt) || other.assignedAt == _this.assignedAt)&&(identical(other.freeCancelUntil, _this.freeCancelUntil) || other.freeCancelUntil == _this.freeCancelUntil)&&(identical(other.lateDeadlineAt, _this.lateDeadlineAt) || other.lateDeadlineAt == _this.lateDeadlineAt)&&(identical(other.startedRouteAt, _this.startedRouteAt) || other.startedRouteAt == _this.startedRouteAt)&&(identical(other.arrivedAt, _this.arrivedAt) || other.arrivedAt == _this.arrivedAt)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.shootEndsAt, _this.shootEndsAt) || other.shootEndsAt == _this.shootEndsAt)&&(identical(other.finishedAt, _this.finishedAt) || other.finishedAt == _this.finishedAt)&&(identical(other.completedAt, _this.completedAt) || other.completedAt == _this.completedAt)&&(identical(other.cancelledAt, _this.cancelledAt) || other.cancelledAt == _this.cancelledAt)&&(identical(other.cancelledBy, _this.cancelledBy) || other.cancelledBy == _this.cancelledBy)&&(identical(other.cancelRule, _this.cancelRule) || other.cancelRule == _this.cancelRule)&&(identical(other.refundPercent, _this.refundPercent) || other.refundPercent == _this.refundPercent)&&(identical(other.feeVnd, _this.feeVnd) || other.feeVnd == _this.feeVnd)&&(identical(other.searchDeadlineAt, _this.searchDeadlineAt) || other.searchDeadlineAt == _this.searchDeadlineAt)&&(identical(other.paymentDeadlineAt, _this.paymentDeadlineAt) || other.paymentDeadlineAt == _this.paymentDeadlineAt));
}


@override
int get hashCode {
  final _this = this as InstantRequest;
  return Object.hashAll([runtimeType,_this.id,_this.customerId,_this.customerName,_this.customerAvatarUrl,_this.status,_this.packageCode,_this.durationMin,_this.photos,_this.genre,_this.note,_this.meetPoint,_this.areaLabel,_this.amountVnd,_this.earningVnd,_this.platformFeeBp,_this.arrivedCancelPhotographerPercent,_this.payMethod,_this.paid,_this.committed,_this.round,_this.invitedTotal,_this.roundsWithInvites,const DeepCollectionEquality().hash(_this.candidates),const DeepCollectionEquality().hash(_this.offers),_this.roundEnded,_this.photographerId,_this.photographer,_this.chatId,_this.etaMinutes,_this.assignedAt,_this.freeCancelUntil,_this.lateDeadlineAt,_this.startedRouteAt,_this.arrivedAt,_this.startedAt,_this.shootEndsAt,_this.finishedAt,_this.completedAt,_this.cancelledAt,_this.cancelledBy,_this.cancelRule,_this.refundPercent,_this.feeVnd,_this.searchDeadlineAt,_this.paymentDeadlineAt]);
}

@override
String toString() {
  final _this = this as InstantRequest;
  return 'InstantRequest(id: ${_this.id}, customerId: ${_this.customerId}, customerName: ${_this.customerName}, customerAvatarUrl: ${_this.customerAvatarUrl}, status: ${_this.status}, packageCode: ${_this.packageCode}, durationMin: ${_this.durationMin}, photos: ${_this.photos}, genre: ${_this.genre}, note: ${_this.note}, meetPoint: ${_this.meetPoint}, areaLabel: ${_this.areaLabel}, amountVnd: ${_this.amountVnd}, earningVnd: ${_this.earningVnd}, platformFeeBp: ${_this.platformFeeBp}, arrivedCancelPhotographerPercent: ${_this.arrivedCancelPhotographerPercent}, payMethod: ${_this.payMethod}, paid: ${_this.paid}, committed: ${_this.committed}, round: ${_this.round}, invitedTotal: ${_this.invitedTotal}, roundsWithInvites: ${_this.roundsWithInvites}, candidates: ${_this.candidates}, offers: ${_this.offers}, roundEnded: ${_this.roundEnded}, photographerId: ${_this.photographerId}, photographer: ${_this.photographer}, chatId: ${_this.chatId}, etaMinutes: ${_this.etaMinutes}, assignedAt: ${_this.assignedAt}, freeCancelUntil: ${_this.freeCancelUntil}, lateDeadlineAt: ${_this.lateDeadlineAt}, startedRouteAt: ${_this.startedRouteAt}, arrivedAt: ${_this.arrivedAt}, startedAt: ${_this.startedAt}, shootEndsAt: ${_this.shootEndsAt}, finishedAt: ${_this.finishedAt}, completedAt: ${_this.completedAt}, cancelledAt: ${_this.cancelledAt}, cancelledBy: ${_this.cancelledBy}, cancelRule: ${_this.cancelRule}, refundPercent: ${_this.refundPercent}, feeVnd: ${_this.feeVnd}, searchDeadlineAt: ${_this.searchDeadlineAt}, paymentDeadlineAt: ${_this.paymentDeadlineAt})';
}


}

/// @nodoc
abstract mixin class $InstantRequestCopyWith<$Res>  {
  factory $InstantRequestCopyWith(InstantRequest value, $Res Function(InstantRequest) _then) = _$InstantRequestCopyWithImpl;
@useResult
$Res call({
 String id, String customerId, String customerName, String? customerAvatarUrl, InstantStatus status, String packageCode, int durationMin, int photos, InstantGenre genre, String note, InstantMeetPoint meetPoint, String areaLabel, int amountVnd, int earningVnd, int platformFeeBp, int arrivedCancelPhotographerPercent, PayMethod? payMethod, bool paid, bool committed, int round, int invitedTotal, int roundsWithInvites, List<InstantCandidate> candidates, List<InstantOfferRow> offers, bool roundEnded, String? photographerId, InstantParty? photographer, String? chatId, int? etaMinutes, DateTime? assignedAt, DateTime? freeCancelUntil, DateTime? lateDeadlineAt, DateTime? startedRouteAt, DateTime? arrivedAt, DateTime? startedAt, DateTime? shootEndsAt, DateTime? finishedAt, DateTime? completedAt, DateTime? cancelledAt, InstantParticipant? cancelledBy, InstantCancelRule? cancelRule, int? refundPercent, int? feeVnd, DateTime? searchDeadlineAt, DateTime? paymentDeadlineAt
});


$InstantMeetPointCopyWith<$Res> get meetPoint;$InstantPartyCopyWith<$Res>? get photographer;

}
/// @nodoc
class _$InstantRequestCopyWithImpl<$Res>
    implements $InstantRequestCopyWith<$Res> {
  _$InstantRequestCopyWithImpl(this._self, this._then);

  final InstantRequest _self;
  final $Res Function(InstantRequest) _then;

/// Create a copy of InstantRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? customerId = null,Object? customerName = null,Object? customerAvatarUrl = freezed,Object? status = null,Object? packageCode = null,Object? durationMin = null,Object? photos = null,Object? genre = null,Object? note = null,Object? meetPoint = null,Object? areaLabel = null,Object? amountVnd = null,Object? earningVnd = null,Object? platformFeeBp = null,Object? arrivedCancelPhotographerPercent = null,Object? payMethod = freezed,Object? paid = null,Object? committed = null,Object? round = null,Object? invitedTotal = null,Object? roundsWithInvites = null,Object? candidates = null,Object? offers = null,Object? roundEnded = null,Object? photographerId = freezed,Object? photographer = freezed,Object? chatId = freezed,Object? etaMinutes = freezed,Object? assignedAt = freezed,Object? freeCancelUntil = freezed,Object? lateDeadlineAt = freezed,Object? startedRouteAt = freezed,Object? arrivedAt = freezed,Object? startedAt = freezed,Object? shootEndsAt = freezed,Object? finishedAt = freezed,Object? completedAt = freezed,Object? cancelledAt = freezed,Object? cancelledBy = freezed,Object? cancelRule = freezed,Object? refundPercent = freezed,Object? feeVnd = freezed,Object? searchDeadlineAt = freezed,Object? paymentDeadlineAt = freezed,}) {
  return _then(InstantRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerAvatarUrl: freezed == customerAvatarUrl ? _self.customerAvatarUrl : customerAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as InstantStatus,packageCode: null == packageCode ? _self.packageCode : packageCode // ignore: cast_nullable_to_non_nullable
as String,durationMin: null == durationMin ? _self.durationMin : durationMin // ignore: cast_nullable_to_non_nullable
as int,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as int,genre: null == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as InstantGenre,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,meetPoint: null == meetPoint ? _self.meetPoint : meetPoint // ignore: cast_nullable_to_non_nullable
as InstantMeetPoint,areaLabel: null == areaLabel ? _self.areaLabel : areaLabel // ignore: cast_nullable_to_non_nullable
as String,amountVnd: null == amountVnd ? _self.amountVnd : amountVnd // ignore: cast_nullable_to_non_nullable
as int,earningVnd: null == earningVnd ? _self.earningVnd : earningVnd // ignore: cast_nullable_to_non_nullable
as int,platformFeeBp: null == platformFeeBp ? _self.platformFeeBp : platformFeeBp // ignore: cast_nullable_to_non_nullable
as int,arrivedCancelPhotographerPercent: null == arrivedCancelPhotographerPercent ? _self.arrivedCancelPhotographerPercent : arrivedCancelPhotographerPercent // ignore: cast_nullable_to_non_nullable
as int,payMethod: freezed == payMethod ? _self.payMethod : payMethod // ignore: cast_nullable_to_non_nullable
as PayMethod?,paid: null == paid ? _self.paid : paid // ignore: cast_nullable_to_non_nullable
as bool,committed: null == committed ? _self.committed : committed // ignore: cast_nullable_to_non_nullable
as bool,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,invitedTotal: null == invitedTotal ? _self.invitedTotal : invitedTotal // ignore: cast_nullable_to_non_nullable
as int,roundsWithInvites: null == roundsWithInvites ? _self.roundsWithInvites : roundsWithInvites // ignore: cast_nullable_to_non_nullable
as int,candidates: null == candidates ? _self.candidates : candidates // ignore: cast_nullable_to_non_nullable
as List<InstantCandidate>,offers: null == offers ? _self.offers : offers // ignore: cast_nullable_to_non_nullable
as List<InstantOfferRow>,roundEnded: null == roundEnded ? _self.roundEnded : roundEnded // ignore: cast_nullable_to_non_nullable
as bool,photographerId: freezed == photographerId ? _self.photographerId : photographerId // ignore: cast_nullable_to_non_nullable
as String?,photographer: freezed == photographer ? _self.photographer : photographer // ignore: cast_nullable_to_non_nullable
as InstantParty?,chatId: freezed == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String?,etaMinutes: freezed == etaMinutes ? _self.etaMinutes : etaMinutes // ignore: cast_nullable_to_non_nullable
as int?,assignedAt: freezed == assignedAt ? _self.assignedAt : assignedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,freeCancelUntil: freezed == freeCancelUntil ? _self.freeCancelUntil : freeCancelUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,lateDeadlineAt: freezed == lateDeadlineAt ? _self.lateDeadlineAt : lateDeadlineAt // ignore: cast_nullable_to_non_nullable
as DateTime?,startedRouteAt: freezed == startedRouteAt ? _self.startedRouteAt : startedRouteAt // ignore: cast_nullable_to_non_nullable
as DateTime?,arrivedAt: freezed == arrivedAt ? _self.arrivedAt : arrivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,shootEndsAt: freezed == shootEndsAt ? _self.shootEndsAt : shootEndsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledBy: freezed == cancelledBy ? _self.cancelledBy : cancelledBy // ignore: cast_nullable_to_non_nullable
as InstantParticipant?,cancelRule: freezed == cancelRule ? _self.cancelRule : cancelRule // ignore: cast_nullable_to_non_nullable
as InstantCancelRule?,refundPercent: freezed == refundPercent ? _self.refundPercent : refundPercent // ignore: cast_nullable_to_non_nullable
as int?,feeVnd: freezed == feeVnd ? _self.feeVnd : feeVnd // ignore: cast_nullable_to_non_nullable
as int?,searchDeadlineAt: freezed == searchDeadlineAt ? _self.searchDeadlineAt : searchDeadlineAt // ignore: cast_nullable_to_non_nullable
as DateTime?,paymentDeadlineAt: freezed == paymentDeadlineAt ? _self.paymentDeadlineAt : paymentDeadlineAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of InstantRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InstantMeetPointCopyWith<$Res> get meetPoint {
  
  return $InstantMeetPointCopyWith<$Res>(_self.meetPoint, (value) {
    return _then(_self.copyWith(meetPoint: value));
  });
}/// Create a copy of InstantRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InstantPartyCopyWith<$Res>? get photographer {
    if (_self.photographer == null) {
    return null;
  }

  return $InstantPartyCopyWith<$Res>(_self.photographer!, (value) {
    return _then(_self.copyWith(photographer: value));
  });
}
}


/// Adds pattern-matching-related methods to [InstantRequest].
extension InstantRequestPatterns on InstantRequest {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstantRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstantRequest() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstantRequest value)  $default,){
final _that = this;
switch (_that) {
case _InstantRequest():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstantRequest value)?  $default,){
final _that = this;
switch (_that) {
case _InstantRequest() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String customerId,  String customerName,  String? customerAvatarUrl,  InstantStatus status,  String packageCode,  int durationMin,  int photos,  InstantGenre genre,  String note,  InstantMeetPoint meetPoint,  String areaLabel,  int amountVnd,  int earningVnd,  int platformFeeBp,  int arrivedCancelPhotographerPercent,  PayMethod? payMethod,  bool paid,  bool committed,  int round,  int invitedTotal,  int roundsWithInvites,  List<InstantCandidate> candidates,  List<InstantOfferRow> offers,  bool roundEnded,  String? photographerId,  InstantParty? photographer,  String? chatId,  int? etaMinutes,  DateTime? assignedAt,  DateTime? freeCancelUntil,  DateTime? lateDeadlineAt,  DateTime? startedRouteAt,  DateTime? arrivedAt,  DateTime? startedAt,  DateTime? shootEndsAt,  DateTime? finishedAt,  DateTime? completedAt,  DateTime? cancelledAt,  InstantParticipant? cancelledBy,  InstantCancelRule? cancelRule,  int? refundPercent,  int? feeVnd,  DateTime? searchDeadlineAt,  DateTime? paymentDeadlineAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstantRequest() when $default != null:
return $default(_that.id,_that.customerId,_that.customerName,_that.customerAvatarUrl,_that.status,_that.packageCode,_that.durationMin,_that.photos,_that.genre,_that.note,_that.meetPoint,_that.areaLabel,_that.amountVnd,_that.earningVnd,_that.platformFeeBp,_that.arrivedCancelPhotographerPercent,_that.payMethod,_that.paid,_that.committed,_that.round,_that.invitedTotal,_that.roundsWithInvites,_that.candidates,_that.offers,_that.roundEnded,_that.photographerId,_that.photographer,_that.chatId,_that.etaMinutes,_that.assignedAt,_that.freeCancelUntil,_that.lateDeadlineAt,_that.startedRouteAt,_that.arrivedAt,_that.startedAt,_that.shootEndsAt,_that.finishedAt,_that.completedAt,_that.cancelledAt,_that.cancelledBy,_that.cancelRule,_that.refundPercent,_that.feeVnd,_that.searchDeadlineAt,_that.paymentDeadlineAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String customerId,  String customerName,  String? customerAvatarUrl,  InstantStatus status,  String packageCode,  int durationMin,  int photos,  InstantGenre genre,  String note,  InstantMeetPoint meetPoint,  String areaLabel,  int amountVnd,  int earningVnd,  int platformFeeBp,  int arrivedCancelPhotographerPercent,  PayMethod? payMethod,  bool paid,  bool committed,  int round,  int invitedTotal,  int roundsWithInvites,  List<InstantCandidate> candidates,  List<InstantOfferRow> offers,  bool roundEnded,  String? photographerId,  InstantParty? photographer,  String? chatId,  int? etaMinutes,  DateTime? assignedAt,  DateTime? freeCancelUntil,  DateTime? lateDeadlineAt,  DateTime? startedRouteAt,  DateTime? arrivedAt,  DateTime? startedAt,  DateTime? shootEndsAt,  DateTime? finishedAt,  DateTime? completedAt,  DateTime? cancelledAt,  InstantParticipant? cancelledBy,  InstantCancelRule? cancelRule,  int? refundPercent,  int? feeVnd,  DateTime? searchDeadlineAt,  DateTime? paymentDeadlineAt)  $default,) {final _that = this;
switch (_that) {
case _InstantRequest():
return $default(_that.id,_that.customerId,_that.customerName,_that.customerAvatarUrl,_that.status,_that.packageCode,_that.durationMin,_that.photos,_that.genre,_that.note,_that.meetPoint,_that.areaLabel,_that.amountVnd,_that.earningVnd,_that.platformFeeBp,_that.arrivedCancelPhotographerPercent,_that.payMethod,_that.paid,_that.committed,_that.round,_that.invitedTotal,_that.roundsWithInvites,_that.candidates,_that.offers,_that.roundEnded,_that.photographerId,_that.photographer,_that.chatId,_that.etaMinutes,_that.assignedAt,_that.freeCancelUntil,_that.lateDeadlineAt,_that.startedRouteAt,_that.arrivedAt,_that.startedAt,_that.shootEndsAt,_that.finishedAt,_that.completedAt,_that.cancelledAt,_that.cancelledBy,_that.cancelRule,_that.refundPercent,_that.feeVnd,_that.searchDeadlineAt,_that.paymentDeadlineAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String customerId,  String customerName,  String? customerAvatarUrl,  InstantStatus status,  String packageCode,  int durationMin,  int photos,  InstantGenre genre,  String note,  InstantMeetPoint meetPoint,  String areaLabel,  int amountVnd,  int earningVnd,  int platformFeeBp,  int arrivedCancelPhotographerPercent,  PayMethod? payMethod,  bool paid,  bool committed,  int round,  int invitedTotal,  int roundsWithInvites,  List<InstantCandidate> candidates,  List<InstantOfferRow> offers,  bool roundEnded,  String? photographerId,  InstantParty? photographer,  String? chatId,  int? etaMinutes,  DateTime? assignedAt,  DateTime? freeCancelUntil,  DateTime? lateDeadlineAt,  DateTime? startedRouteAt,  DateTime? arrivedAt,  DateTime? startedAt,  DateTime? shootEndsAt,  DateTime? finishedAt,  DateTime? completedAt,  DateTime? cancelledAt,  InstantParticipant? cancelledBy,  InstantCancelRule? cancelRule,  int? refundPercent,  int? feeVnd,  DateTime? searchDeadlineAt,  DateTime? paymentDeadlineAt)?  $default,) {final _that = this;
switch (_that) {
case _InstantRequest() when $default != null:
return $default(_that.id,_that.customerId,_that.customerName,_that.customerAvatarUrl,_that.status,_that.packageCode,_that.durationMin,_that.photos,_that.genre,_that.note,_that.meetPoint,_that.areaLabel,_that.amountVnd,_that.earningVnd,_that.platformFeeBp,_that.arrivedCancelPhotographerPercent,_that.payMethod,_that.paid,_that.committed,_that.round,_that.invitedTotal,_that.roundsWithInvites,_that.candidates,_that.offers,_that.roundEnded,_that.photographerId,_that.photographer,_that.chatId,_that.etaMinutes,_that.assignedAt,_that.freeCancelUntil,_that.lateDeadlineAt,_that.startedRouteAt,_that.arrivedAt,_that.startedAt,_that.shootEndsAt,_that.finishedAt,_that.completedAt,_that.cancelledAt,_that.cancelledBy,_that.cancelRule,_that.refundPercent,_that.feeVnd,_that.searchDeadlineAt,_that.paymentDeadlineAt);case _:
  return null;

}
}

}

/// @nodoc


class _InstantRequest implements InstantRequest {
  const _InstantRequest({required this.id, required this.customerId, this.customerName = '', this.customerAvatarUrl, required this.status, required this.packageCode, this.durationMin = 0, this.photos = 0, required this.genre, this.note = '', required this.meetPoint, this.areaLabel = '', this.amountVnd = 0, this.earningVnd = 0, this.platformFeeBp = 0, this.arrivedCancelPhotographerPercent = 50, this.payMethod, this.paid = false, this.committed = false, this.round = 1, this.invitedTotal = 0, this.roundsWithInvites = 0,  List<InstantCandidate> candidates = const <InstantCandidate>[],  List<InstantOfferRow> offers = const <InstantOfferRow>[], this.roundEnded = false, this.photographerId, this.photographer, this.chatId, this.etaMinutes, this.assignedAt, this.freeCancelUntil, this.lateDeadlineAt, this.startedRouteAt, this.arrivedAt, this.startedAt, this.shootEndsAt, this.finishedAt, this.completedAt, this.cancelledAt, this.cancelledBy, this.cancelRule, this.refundPercent, this.feeVnd, this.searchDeadlineAt, this.paymentDeadlineAt}): _candidates = candidates,_offers = offers;
  

@override final  String id;
@override final  String customerId;
@override@JsonKey() final  String customerName;
@override final  String? customerAvatarUrl;
@override final  InstantStatus status;
@override final  String packageCode;
@override@JsonKey() final  int durationMin;
@override@JsonKey() final  int photos;
@override final  InstantGenre genre;
@override@JsonKey() final  String note;
@override final  InstantMeetPoint meetPoint;
@override@JsonKey() final  String areaLabel;
@override@JsonKey() final  int amountVnd;
@override@JsonKey() final  int earningVnd;
@override@JsonKey() final  int platformFeeBp;
@override@JsonKey() final  int arrivedCancelPhotographerPercent;
@override final  PayMethod? payMethod;
/// `paidAt != null` (never in #140).
@override@JsonKey() final  bool paid;
/// `committedAt != null`: offers went out at least once.
@override@JsonKey() final  bool committed;
@override@JsonKey() final  int round;
@override@JsonKey() final  int invitedTotal;
@override@JsonKey() final  int roundsWithInvites;
 final  List<InstantCandidate> _candidates;
@override@JsonKey() List<InstantCandidate> get candidates {
  if (_candidates is EqualUnmodifiableListView) return _candidates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_candidates);
}

 final  List<InstantOfferRow> _offers;
@override@JsonKey() List<InstantOfferRow> get offers {
  if (_offers is EqualUnmodifiableListView) return _offers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_offers);
}

@override@JsonKey() final  bool roundEnded;
@override final  String? photographerId;
@override final  InstantParty? photographer;
@override final  String? chatId;
@override final  int? etaMinutes;
@override final  DateTime? assignedAt;
@override final  DateTime? freeCancelUntil;
@override final  DateTime? lateDeadlineAt;
@override final  DateTime? startedRouteAt;
@override final  DateTime? arrivedAt;
@override final  DateTime? startedAt;
@override final  DateTime? shootEndsAt;
@override final  DateTime? finishedAt;
@override final  DateTime? completedAt;
@override final  DateTime? cancelledAt;
@override final  InstantParticipant? cancelledBy;
@override final  InstantCancelRule? cancelRule;
@override final  int? refundPercent;
@override final  int? feeVnd;
@override final  DateTime? searchDeadlineAt;
@override final  DateTime? paymentDeadlineAt;

/// Create a copy of InstantRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstantRequestCopyWith<_InstantRequest> get copyWith => __$InstantRequestCopyWithImpl<_InstantRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstantRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.customerName, customerName) || other.customerName == customerName)&&(identical(other.customerAvatarUrl, customerAvatarUrl) || other.customerAvatarUrl == customerAvatarUrl)&&(identical(other.status, status) || other.status == status)&&(identical(other.packageCode, packageCode) || other.packageCode == packageCode)&&(identical(other.durationMin, durationMin) || other.durationMin == durationMin)&&(identical(other.photos, photos) || other.photos == photos)&&(identical(other.genre, genre) || other.genre == genre)&&(identical(other.note, note) || other.note == note)&&(identical(other.meetPoint, meetPoint) || other.meetPoint == meetPoint)&&(identical(other.areaLabel, areaLabel) || other.areaLabel == areaLabel)&&(identical(other.amountVnd, amountVnd) || other.amountVnd == amountVnd)&&(identical(other.earningVnd, earningVnd) || other.earningVnd == earningVnd)&&(identical(other.platformFeeBp, platformFeeBp) || other.platformFeeBp == platformFeeBp)&&(identical(other.arrivedCancelPhotographerPercent, arrivedCancelPhotographerPercent) || other.arrivedCancelPhotographerPercent == arrivedCancelPhotographerPercent)&&(identical(other.payMethod, payMethod) || other.payMethod == payMethod)&&(identical(other.paid, paid) || other.paid == paid)&&(identical(other.committed, committed) || other.committed == committed)&&(identical(other.round, round) || other.round == round)&&(identical(other.invitedTotal, invitedTotal) || other.invitedTotal == invitedTotal)&&(identical(other.roundsWithInvites, roundsWithInvites) || other.roundsWithInvites == roundsWithInvites)&&const DeepCollectionEquality().equals(other.candidates, _candidates)&&const DeepCollectionEquality().equals(other.offers, _offers)&&(identical(other.roundEnded, roundEnded) || other.roundEnded == roundEnded)&&(identical(other.photographerId, photographerId) || other.photographerId == photographerId)&&(identical(other.photographer, photographer) || other.photographer == photographer)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.etaMinutes, etaMinutes) || other.etaMinutes == etaMinutes)&&(identical(other.assignedAt, assignedAt) || other.assignedAt == assignedAt)&&(identical(other.freeCancelUntil, freeCancelUntil) || other.freeCancelUntil == freeCancelUntil)&&(identical(other.lateDeadlineAt, lateDeadlineAt) || other.lateDeadlineAt == lateDeadlineAt)&&(identical(other.startedRouteAt, startedRouteAt) || other.startedRouteAt == startedRouteAt)&&(identical(other.arrivedAt, arrivedAt) || other.arrivedAt == arrivedAt)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.shootEndsAt, shootEndsAt) || other.shootEndsAt == shootEndsAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancelledBy, cancelledBy) || other.cancelledBy == cancelledBy)&&(identical(other.cancelRule, cancelRule) || other.cancelRule == cancelRule)&&(identical(other.refundPercent, refundPercent) || other.refundPercent == refundPercent)&&(identical(other.feeVnd, feeVnd) || other.feeVnd == feeVnd)&&(identical(other.searchDeadlineAt, searchDeadlineAt) || other.searchDeadlineAt == searchDeadlineAt)&&(identical(other.paymentDeadlineAt, paymentDeadlineAt) || other.paymentDeadlineAt == paymentDeadlineAt));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,id,customerId,customerName,customerAvatarUrl,status,packageCode,durationMin,photos,genre,note,meetPoint,areaLabel,amountVnd,earningVnd,platformFeeBp,arrivedCancelPhotographerPercent,payMethod,paid,committed,round,invitedTotal,roundsWithInvites,const DeepCollectionEquality().hash(_candidates),const DeepCollectionEquality().hash(_offers),roundEnded,photographerId,photographer,chatId,etaMinutes,assignedAt,freeCancelUntil,lateDeadlineAt,startedRouteAt,arrivedAt,startedAt,shootEndsAt,finishedAt,completedAt,cancelledAt,cancelledBy,cancelRule,refundPercent,feeVnd,searchDeadlineAt,paymentDeadlineAt]);
}

@override
String toString() {
    return 'InstantRequest(id: $id, customerId: $customerId, customerName: $customerName, customerAvatarUrl: $customerAvatarUrl, status: $status, packageCode: $packageCode, durationMin: $durationMin, photos: $photos, genre: $genre, note: $note, meetPoint: $meetPoint, areaLabel: $areaLabel, amountVnd: $amountVnd, earningVnd: $earningVnd, platformFeeBp: $platformFeeBp, arrivedCancelPhotographerPercent: $arrivedCancelPhotographerPercent, payMethod: $payMethod, paid: $paid, committed: $committed, round: $round, invitedTotal: $invitedTotal, roundsWithInvites: $roundsWithInvites, candidates: $candidates, offers: $offers, roundEnded: $roundEnded, photographerId: $photographerId, photographer: $photographer, chatId: $chatId, etaMinutes: $etaMinutes, assignedAt: $assignedAt, freeCancelUntil: $freeCancelUntil, lateDeadlineAt: $lateDeadlineAt, startedRouteAt: $startedRouteAt, arrivedAt: $arrivedAt, startedAt: $startedAt, shootEndsAt: $shootEndsAt, finishedAt: $finishedAt, completedAt: $completedAt, cancelledAt: $cancelledAt, cancelledBy: $cancelledBy, cancelRule: $cancelRule, refundPercent: $refundPercent, feeVnd: $feeVnd, searchDeadlineAt: $searchDeadlineAt, paymentDeadlineAt: $paymentDeadlineAt)';
}


}

/// @nodoc
abstract mixin class _$InstantRequestCopyWith<$Res> implements $InstantRequestCopyWith<$Res> {
  factory _$InstantRequestCopyWith(_InstantRequest value, $Res Function(_InstantRequest) _then) = __$InstantRequestCopyWithImpl;
@override @useResult
$Res call({
 String id, String customerId, String customerName, String? customerAvatarUrl, InstantStatus status, String packageCode, int durationMin, int photos, InstantGenre genre, String note, InstantMeetPoint meetPoint, String areaLabel, int amountVnd, int earningVnd, int platformFeeBp, int arrivedCancelPhotographerPercent, PayMethod? payMethod, bool paid, bool committed, int round, int invitedTotal, int roundsWithInvites, List<InstantCandidate> candidates, List<InstantOfferRow> offers, bool roundEnded, String? photographerId, InstantParty? photographer, String? chatId, int? etaMinutes, DateTime? assignedAt, DateTime? freeCancelUntil, DateTime? lateDeadlineAt, DateTime? startedRouteAt, DateTime? arrivedAt, DateTime? startedAt, DateTime? shootEndsAt, DateTime? finishedAt, DateTime? completedAt, DateTime? cancelledAt, InstantParticipant? cancelledBy, InstantCancelRule? cancelRule, int? refundPercent, int? feeVnd, DateTime? searchDeadlineAt, DateTime? paymentDeadlineAt
});


@override $InstantMeetPointCopyWith<$Res> get meetPoint;@override $InstantPartyCopyWith<$Res>? get photographer;

}
/// @nodoc
class __$InstantRequestCopyWithImpl<$Res>
    implements _$InstantRequestCopyWith<$Res> {
  __$InstantRequestCopyWithImpl(this._self, this._then);

  final _InstantRequest _self;
  final $Res Function(_InstantRequest) _then;

/// Create a copy of InstantRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? customerId = null,Object? customerName = null,Object? customerAvatarUrl = freezed,Object? status = null,Object? packageCode = null,Object? durationMin = null,Object? photos = null,Object? genre = null,Object? note = null,Object? meetPoint = null,Object? areaLabel = null,Object? amountVnd = null,Object? earningVnd = null,Object? platformFeeBp = null,Object? arrivedCancelPhotographerPercent = null,Object? payMethod = freezed,Object? paid = null,Object? committed = null,Object? round = null,Object? invitedTotal = null,Object? roundsWithInvites = null,Object? candidates = null,Object? offers = null,Object? roundEnded = null,Object? photographerId = freezed,Object? photographer = freezed,Object? chatId = freezed,Object? etaMinutes = freezed,Object? assignedAt = freezed,Object? freeCancelUntil = freezed,Object? lateDeadlineAt = freezed,Object? startedRouteAt = freezed,Object? arrivedAt = freezed,Object? startedAt = freezed,Object? shootEndsAt = freezed,Object? finishedAt = freezed,Object? completedAt = freezed,Object? cancelledAt = freezed,Object? cancelledBy = freezed,Object? cancelRule = freezed,Object? refundPercent = freezed,Object? feeVnd = freezed,Object? searchDeadlineAt = freezed,Object? paymentDeadlineAt = freezed,}) {
  return _then(_InstantRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,customerName: null == customerName ? _self.customerName : customerName // ignore: cast_nullable_to_non_nullable
as String,customerAvatarUrl: freezed == customerAvatarUrl ? _self.customerAvatarUrl : customerAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as InstantStatus,packageCode: null == packageCode ? _self.packageCode : packageCode // ignore: cast_nullable_to_non_nullable
as String,durationMin: null == durationMin ? _self.durationMin : durationMin // ignore: cast_nullable_to_non_nullable
as int,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as int,genre: null == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as InstantGenre,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,meetPoint: null == meetPoint ? _self.meetPoint : meetPoint // ignore: cast_nullable_to_non_nullable
as InstantMeetPoint,areaLabel: null == areaLabel ? _self.areaLabel : areaLabel // ignore: cast_nullable_to_non_nullable
as String,amountVnd: null == amountVnd ? _self.amountVnd : amountVnd // ignore: cast_nullable_to_non_nullable
as int,earningVnd: null == earningVnd ? _self.earningVnd : earningVnd // ignore: cast_nullable_to_non_nullable
as int,platformFeeBp: null == platformFeeBp ? _self.platformFeeBp : platformFeeBp // ignore: cast_nullable_to_non_nullable
as int,arrivedCancelPhotographerPercent: null == arrivedCancelPhotographerPercent ? _self.arrivedCancelPhotographerPercent : arrivedCancelPhotographerPercent // ignore: cast_nullable_to_non_nullable
as int,payMethod: freezed == payMethod ? _self.payMethod : payMethod // ignore: cast_nullable_to_non_nullable
as PayMethod?,paid: null == paid ? _self.paid : paid // ignore: cast_nullable_to_non_nullable
as bool,committed: null == committed ? _self.committed : committed // ignore: cast_nullable_to_non_nullable
as bool,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,invitedTotal: null == invitedTotal ? _self.invitedTotal : invitedTotal // ignore: cast_nullable_to_non_nullable
as int,roundsWithInvites: null == roundsWithInvites ? _self.roundsWithInvites : roundsWithInvites // ignore: cast_nullable_to_non_nullable
as int,candidates: null == candidates ? _self._candidates : candidates // ignore: cast_nullable_to_non_nullable
as List<InstantCandidate>,offers: null == offers ? _self._offers : offers // ignore: cast_nullable_to_non_nullable
as List<InstantOfferRow>,roundEnded: null == roundEnded ? _self.roundEnded : roundEnded // ignore: cast_nullable_to_non_nullable
as bool,photographerId: freezed == photographerId ? _self.photographerId : photographerId // ignore: cast_nullable_to_non_nullable
as String?,photographer: freezed == photographer ? _self.photographer : photographer // ignore: cast_nullable_to_non_nullable
as InstantParty?,chatId: freezed == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String?,etaMinutes: freezed == etaMinutes ? _self.etaMinutes : etaMinutes // ignore: cast_nullable_to_non_nullable
as int?,assignedAt: freezed == assignedAt ? _self.assignedAt : assignedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,freeCancelUntil: freezed == freeCancelUntil ? _self.freeCancelUntil : freeCancelUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,lateDeadlineAt: freezed == lateDeadlineAt ? _self.lateDeadlineAt : lateDeadlineAt // ignore: cast_nullable_to_non_nullable
as DateTime?,startedRouteAt: freezed == startedRouteAt ? _self.startedRouteAt : startedRouteAt // ignore: cast_nullable_to_non_nullable
as DateTime?,arrivedAt: freezed == arrivedAt ? _self.arrivedAt : arrivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,shootEndsAt: freezed == shootEndsAt ? _self.shootEndsAt : shootEndsAt // ignore: cast_nullable_to_non_nullable
as DateTime?,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledBy: freezed == cancelledBy ? _self.cancelledBy : cancelledBy // ignore: cast_nullable_to_non_nullable
as InstantParticipant?,cancelRule: freezed == cancelRule ? _self.cancelRule : cancelRule // ignore: cast_nullable_to_non_nullable
as InstantCancelRule?,refundPercent: freezed == refundPercent ? _self.refundPercent : refundPercent // ignore: cast_nullable_to_non_nullable
as int?,feeVnd: freezed == feeVnd ? _self.feeVnd : feeVnd // ignore: cast_nullable_to_non_nullable
as int?,searchDeadlineAt: freezed == searchDeadlineAt ? _self.searchDeadlineAt : searchDeadlineAt // ignore: cast_nullable_to_non_nullable
as DateTime?,paymentDeadlineAt: freezed == paymentDeadlineAt ? _self.paymentDeadlineAt : paymentDeadlineAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of InstantRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InstantMeetPointCopyWith<$Res> get meetPoint {
  
  return $InstantMeetPointCopyWith<$Res>(_self.meetPoint, (value) {
    return _then(_self.copyWith(meetPoint: value));
  });
}/// Create a copy of InstantRequest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$InstantPartyCopyWith<$Res>? get photographer {
    if (_self.photographer == null) {
    return null;
  }

  return $InstantPartyCopyWith<$Res>(_self.photographer!, (value) {
    return _then(_self.copyWith(photographer: value));
  });
}
}

/// @nodoc
mixin _$InstantOffer {

 String get id; String get requestId; int get round; DateTime get offeredAt; DateTime get expiresAt; OfferOutcome get outcome; String get packageCode; int get durationMin; int get photos; InstantGenre get genre; String get areaLabel; double get distanceKm; int get etaMinutes; int get earningVnd; String get note; int get invitedCount;
/// Create a copy of InstantOffer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstantOfferCopyWith<InstantOffer> get copyWith => _$InstantOfferCopyWithImpl<InstantOffer>(this as InstantOffer, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InstantOffer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstantOffer&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.requestId, _this.requestId) || other.requestId == _this.requestId)&&(identical(other.round, _this.round) || other.round == _this.round)&&(identical(other.offeredAt, _this.offeredAt) || other.offeredAt == _this.offeredAt)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.outcome, _this.outcome) || other.outcome == _this.outcome)&&(identical(other.packageCode, _this.packageCode) || other.packageCode == _this.packageCode)&&(identical(other.durationMin, _this.durationMin) || other.durationMin == _this.durationMin)&&(identical(other.photos, _this.photos) || other.photos == _this.photos)&&(identical(other.genre, _this.genre) || other.genre == _this.genre)&&(identical(other.areaLabel, _this.areaLabel) || other.areaLabel == _this.areaLabel)&&(identical(other.distanceKm, _this.distanceKm) || other.distanceKm == _this.distanceKm)&&(identical(other.etaMinutes, _this.etaMinutes) || other.etaMinutes == _this.etaMinutes)&&(identical(other.earningVnd, _this.earningVnd) || other.earningVnd == _this.earningVnd)&&(identical(other.note, _this.note) || other.note == _this.note)&&(identical(other.invitedCount, _this.invitedCount) || other.invitedCount == _this.invitedCount));
}


@override
int get hashCode {
  final _this = this as InstantOffer;
  return Object.hash(runtimeType,_this.id,_this.requestId,_this.round,_this.offeredAt,_this.expiresAt,_this.outcome,_this.packageCode,_this.durationMin,_this.photos,_this.genre,_this.areaLabel,_this.distanceKm,_this.etaMinutes,_this.earningVnd,_this.note,_this.invitedCount);
}

@override
String toString() {
  final _this = this as InstantOffer;
  return 'InstantOffer(id: ${_this.id}, requestId: ${_this.requestId}, round: ${_this.round}, offeredAt: ${_this.offeredAt}, expiresAt: ${_this.expiresAt}, outcome: ${_this.outcome}, packageCode: ${_this.packageCode}, durationMin: ${_this.durationMin}, photos: ${_this.photos}, genre: ${_this.genre}, areaLabel: ${_this.areaLabel}, distanceKm: ${_this.distanceKm}, etaMinutes: ${_this.etaMinutes}, earningVnd: ${_this.earningVnd}, note: ${_this.note}, invitedCount: ${_this.invitedCount})';
}


}

/// @nodoc
abstract mixin class $InstantOfferCopyWith<$Res>  {
  factory $InstantOfferCopyWith(InstantOffer value, $Res Function(InstantOffer) _then) = _$InstantOfferCopyWithImpl;
@useResult
$Res call({
 String id, String requestId, int round, DateTime offeredAt, DateTime expiresAt, OfferOutcome outcome, String packageCode, int durationMin, int photos, InstantGenre genre, String areaLabel, double distanceKm, int etaMinutes, int earningVnd, String note, int invitedCount
});




}
/// @nodoc
class _$InstantOfferCopyWithImpl<$Res>
    implements $InstantOfferCopyWith<$Res> {
  _$InstantOfferCopyWithImpl(this._self, this._then);

  final InstantOffer _self;
  final $Res Function(InstantOffer) _then;

/// Create a copy of InstantOffer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? requestId = null,Object? round = null,Object? offeredAt = null,Object? expiresAt = null,Object? outcome = null,Object? packageCode = null,Object? durationMin = null,Object? photos = null,Object? genre = null,Object? areaLabel = null,Object? distanceKm = null,Object? etaMinutes = null,Object? earningVnd = null,Object? note = null,Object? invitedCount = null,}) {
  return _then(InstantOffer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,offeredAt: null == offeredAt ? _self.offeredAt : offeredAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as OfferOutcome,packageCode: null == packageCode ? _self.packageCode : packageCode // ignore: cast_nullable_to_non_nullable
as String,durationMin: null == durationMin ? _self.durationMin : durationMin // ignore: cast_nullable_to_non_nullable
as int,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as int,genre: null == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as InstantGenre,areaLabel: null == areaLabel ? _self.areaLabel : areaLabel // ignore: cast_nullable_to_non_nullable
as String,distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,etaMinutes: null == etaMinutes ? _self.etaMinutes : etaMinutes // ignore: cast_nullable_to_non_nullable
as int,earningVnd: null == earningVnd ? _self.earningVnd : earningVnd // ignore: cast_nullable_to_non_nullable
as int,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,invitedCount: null == invitedCount ? _self.invitedCount : invitedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InstantOffer].
extension InstantOfferPatterns on InstantOffer {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstantOffer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstantOffer() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstantOffer value)  $default,){
final _that = this;
switch (_that) {
case _InstantOffer():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstantOffer value)?  $default,){
final _that = this;
switch (_that) {
case _InstantOffer() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String requestId,  int round,  DateTime offeredAt,  DateTime expiresAt,  OfferOutcome outcome,  String packageCode,  int durationMin,  int photos,  InstantGenre genre,  String areaLabel,  double distanceKm,  int etaMinutes,  int earningVnd,  String note,  int invitedCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstantOffer() when $default != null:
return $default(_that.id,_that.requestId,_that.round,_that.offeredAt,_that.expiresAt,_that.outcome,_that.packageCode,_that.durationMin,_that.photos,_that.genre,_that.areaLabel,_that.distanceKm,_that.etaMinutes,_that.earningVnd,_that.note,_that.invitedCount);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String requestId,  int round,  DateTime offeredAt,  DateTime expiresAt,  OfferOutcome outcome,  String packageCode,  int durationMin,  int photos,  InstantGenre genre,  String areaLabel,  double distanceKm,  int etaMinutes,  int earningVnd,  String note,  int invitedCount)  $default,) {final _that = this;
switch (_that) {
case _InstantOffer():
return $default(_that.id,_that.requestId,_that.round,_that.offeredAt,_that.expiresAt,_that.outcome,_that.packageCode,_that.durationMin,_that.photos,_that.genre,_that.areaLabel,_that.distanceKm,_that.etaMinutes,_that.earningVnd,_that.note,_that.invitedCount);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String requestId,  int round,  DateTime offeredAt,  DateTime expiresAt,  OfferOutcome outcome,  String packageCode,  int durationMin,  int photos,  InstantGenre genre,  String areaLabel,  double distanceKm,  int etaMinutes,  int earningVnd,  String note,  int invitedCount)?  $default,) {final _that = this;
switch (_that) {
case _InstantOffer() when $default != null:
return $default(_that.id,_that.requestId,_that.round,_that.offeredAt,_that.expiresAt,_that.outcome,_that.packageCode,_that.durationMin,_that.photos,_that.genre,_that.areaLabel,_that.distanceKm,_that.etaMinutes,_that.earningVnd,_that.note,_that.invitedCount);case _:
  return null;

}
}

}

/// @nodoc


class _InstantOffer implements InstantOffer {
  const _InstantOffer({required this.id, required this.requestId, this.round = 1, required this.offeredAt, required this.expiresAt, required this.outcome, this.packageCode = '', this.durationMin = 0, this.photos = 0, required this.genre, this.areaLabel = '', this.distanceKm = 0, this.etaMinutes = 1, this.earningVnd = 0, this.note = '', this.invitedCount = 1});
  

@override final  String id;
@override final  String requestId;
@override@JsonKey() final  int round;
@override final  DateTime offeredAt;
@override final  DateTime expiresAt;
@override final  OfferOutcome outcome;
@override@JsonKey() final  String packageCode;
@override@JsonKey() final  int durationMin;
@override@JsonKey() final  int photos;
@override final  InstantGenre genre;
@override@JsonKey() final  String areaLabel;
@override@JsonKey() final  double distanceKm;
@override@JsonKey() final  int etaMinutes;
@override@JsonKey() final  int earningVnd;
@override@JsonKey() final  String note;
@override@JsonKey() final  int invitedCount;

/// Create a copy of InstantOffer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstantOfferCopyWith<_InstantOffer> get copyWith => __$InstantOfferCopyWithImpl<_InstantOffer>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstantOffer&&(identical(other.id, id) || other.id == id)&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.round, round) || other.round == round)&&(identical(other.offeredAt, offeredAt) || other.offeredAt == offeredAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.outcome, outcome) || other.outcome == outcome)&&(identical(other.packageCode, packageCode) || other.packageCode == packageCode)&&(identical(other.durationMin, durationMin) || other.durationMin == durationMin)&&(identical(other.photos, photos) || other.photos == photos)&&(identical(other.genre, genre) || other.genre == genre)&&(identical(other.areaLabel, areaLabel) || other.areaLabel == areaLabel)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.etaMinutes, etaMinutes) || other.etaMinutes == etaMinutes)&&(identical(other.earningVnd, earningVnd) || other.earningVnd == earningVnd)&&(identical(other.note, note) || other.note == note)&&(identical(other.invitedCount, invitedCount) || other.invitedCount == invitedCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,requestId,round,offeredAt,expiresAt,outcome,packageCode,durationMin,photos,genre,areaLabel,distanceKm,etaMinutes,earningVnd,note,invitedCount);
}

@override
String toString() {
    return 'InstantOffer(id: $id, requestId: $requestId, round: $round, offeredAt: $offeredAt, expiresAt: $expiresAt, outcome: $outcome, packageCode: $packageCode, durationMin: $durationMin, photos: $photos, genre: $genre, areaLabel: $areaLabel, distanceKm: $distanceKm, etaMinutes: $etaMinutes, earningVnd: $earningVnd, note: $note, invitedCount: $invitedCount)';
}


}

/// @nodoc
abstract mixin class _$InstantOfferCopyWith<$Res> implements $InstantOfferCopyWith<$Res> {
  factory _$InstantOfferCopyWith(_InstantOffer value, $Res Function(_InstantOffer) _then) = __$InstantOfferCopyWithImpl;
@override @useResult
$Res call({
 String id, String requestId, int round, DateTime offeredAt, DateTime expiresAt, OfferOutcome outcome, String packageCode, int durationMin, int photos, InstantGenre genre, String areaLabel, double distanceKm, int etaMinutes, int earningVnd, String note, int invitedCount
});




}
/// @nodoc
class __$InstantOfferCopyWithImpl<$Res>
    implements _$InstantOfferCopyWith<$Res> {
  __$InstantOfferCopyWithImpl(this._self, this._then);

  final _InstantOffer _self;
  final $Res Function(_InstantOffer) _then;

/// Create a copy of InstantOffer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? requestId = null,Object? round = null,Object? offeredAt = null,Object? expiresAt = null,Object? outcome = null,Object? packageCode = null,Object? durationMin = null,Object? photos = null,Object? genre = null,Object? areaLabel = null,Object? distanceKm = null,Object? etaMinutes = null,Object? earningVnd = null,Object? note = null,Object? invitedCount = null,}) {
  return _then(_InstantOffer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,offeredAt: null == offeredAt ? _self.offeredAt : offeredAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,outcome: null == outcome ? _self.outcome : outcome // ignore: cast_nullable_to_non_nullable
as OfferOutcome,packageCode: null == packageCode ? _self.packageCode : packageCode // ignore: cast_nullable_to_non_nullable
as String,durationMin: null == durationMin ? _self.durationMin : durationMin // ignore: cast_nullable_to_non_nullable
as int,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as int,genre: null == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as InstantGenre,areaLabel: null == areaLabel ? _self.areaLabel : areaLabel // ignore: cast_nullable_to_non_nullable
as String,distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,etaMinutes: null == etaMinutes ? _self.etaMinutes : etaMinutes // ignore: cast_nullable_to_non_nullable
as int,earningVnd: null == earningVnd ? _self.earningVnd : earningVnd // ignore: cast_nullable_to_non_nullable
as int,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,invitedCount: null == invitedCount ? _self.invitedCount : invitedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$InstantTrack {

 double get lat; double get lng; double get accuracyM; DateTime get at;
/// Create a copy of InstantTrack
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstantTrackCopyWith<InstantTrack> get copyWith => _$InstantTrackCopyWithImpl<InstantTrack>(this as InstantTrack, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InstantTrack;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstantTrack&&(identical(other.lat, _this.lat) || other.lat == _this.lat)&&(identical(other.lng, _this.lng) || other.lng == _this.lng)&&(identical(other.accuracyM, _this.accuracyM) || other.accuracyM == _this.accuracyM)&&(identical(other.at, _this.at) || other.at == _this.at));
}


@override
int get hashCode {
  final _this = this as InstantTrack;
  return Object.hash(runtimeType,_this.lat,_this.lng,_this.accuracyM,_this.at);
}

@override
String toString() {
  final _this = this as InstantTrack;
  return 'InstantTrack(lat: ${_this.lat}, lng: ${_this.lng}, accuracyM: ${_this.accuracyM}, at: ${_this.at})';
}


}

/// @nodoc
abstract mixin class $InstantTrackCopyWith<$Res>  {
  factory $InstantTrackCopyWith(InstantTrack value, $Res Function(InstantTrack) _then) = _$InstantTrackCopyWithImpl;
@useResult
$Res call({
 double lat, double lng, double accuracyM, DateTime at
});




}
/// @nodoc
class _$InstantTrackCopyWithImpl<$Res>
    implements $InstantTrackCopyWith<$Res> {
  _$InstantTrackCopyWithImpl(this._self, this._then);

  final InstantTrack _self;
  final $Res Function(InstantTrack) _then;

/// Create a copy of InstantTrack
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lat = null,Object? lng = null,Object? accuracyM = null,Object? at = null,}) {
  return _then(InstantTrack(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,accuracyM: null == accuracyM ? _self.accuracyM : accuracyM // ignore: cast_nullable_to_non_nullable
as double,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [InstantTrack].
extension InstantTrackPatterns on InstantTrack {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstantTrack value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstantTrack() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstantTrack value)  $default,){
final _that = this;
switch (_that) {
case _InstantTrack():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstantTrack value)?  $default,){
final _that = this;
switch (_that) {
case _InstantTrack() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double lat,  double lng,  double accuracyM,  DateTime at)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstantTrack() when $default != null:
return $default(_that.lat,_that.lng,_that.accuracyM,_that.at);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double lat,  double lng,  double accuracyM,  DateTime at)  $default,) {final _that = this;
switch (_that) {
case _InstantTrack():
return $default(_that.lat,_that.lng,_that.accuracyM,_that.at);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double lat,  double lng,  double accuracyM,  DateTime at)?  $default,) {final _that = this;
switch (_that) {
case _InstantTrack() when $default != null:
return $default(_that.lat,_that.lng,_that.accuracyM,_that.at);case _:
  return null;

}
}

}

/// @nodoc


class _InstantTrack implements InstantTrack {
  const _InstantTrack({required this.lat, required this.lng, this.accuracyM = 0, required this.at});
  

@override final  double lat;
@override final  double lng;
@override@JsonKey() final  double accuracyM;
@override final  DateTime at;

/// Create a copy of InstantTrack
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstantTrackCopyWith<_InstantTrack> get copyWith => __$InstantTrackCopyWithImpl<_InstantTrack>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstantTrack&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.accuracyM, accuracyM) || other.accuracyM == accuracyM)&&(identical(other.at, at) || other.at == at));
}


@override
int get hashCode {
    return Object.hash(runtimeType,lat,lng,accuracyM,at);
}

@override
String toString() {
    return 'InstantTrack(lat: $lat, lng: $lng, accuracyM: $accuracyM, at: $at)';
}


}

/// @nodoc
abstract mixin class _$InstantTrackCopyWith<$Res> implements $InstantTrackCopyWith<$Res> {
  factory _$InstantTrackCopyWith(_InstantTrack value, $Res Function(_InstantTrack) _then) = __$InstantTrackCopyWithImpl;
@override @useResult
$Res call({
 double lat, double lng, double accuracyM, DateTime at
});




}
/// @nodoc
class __$InstantTrackCopyWithImpl<$Res>
    implements _$InstantTrackCopyWith<$Res> {
  __$InstantTrackCopyWithImpl(this._self, this._then);

  final _InstantTrack _self;
  final $Res Function(_InstantTrack) _then;

/// Create a copy of InstantTrack
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lat = null,Object? lng = null,Object? accuracyM = null,Object? at = null,}) {
  return _then(_InstantTrack(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,accuracyM: null == accuracyM ? _self.accuracyM : accuracyM // ignore: cast_nullable_to_non_nullable
as double,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$LiveShutterState {

 bool get online; bool get helpReady;/// The price list version accepted; null = never accepted.
 int? get priceListVersion; DateTime? get heartbeatAt; String? get activeRequestId;
/// Create a copy of LiveShutterState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LiveShutterStateCopyWith<LiveShutterState> get copyWith => _$LiveShutterStateCopyWithImpl<LiveShutterState>(this as LiveShutterState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LiveShutterState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LiveShutterState&&(identical(other.online, _this.online) || other.online == _this.online)&&(identical(other.helpReady, _this.helpReady) || other.helpReady == _this.helpReady)&&(identical(other.priceListVersion, _this.priceListVersion) || other.priceListVersion == _this.priceListVersion)&&(identical(other.heartbeatAt, _this.heartbeatAt) || other.heartbeatAt == _this.heartbeatAt)&&(identical(other.activeRequestId, _this.activeRequestId) || other.activeRequestId == _this.activeRequestId));
}


@override
int get hashCode {
  final _this = this as LiveShutterState;
  return Object.hash(runtimeType,_this.online,_this.helpReady,_this.priceListVersion,_this.heartbeatAt,_this.activeRequestId);
}

@override
String toString() {
  final _this = this as LiveShutterState;
  return 'LiveShutterState(online: ${_this.online}, helpReady: ${_this.helpReady}, priceListVersion: ${_this.priceListVersion}, heartbeatAt: ${_this.heartbeatAt}, activeRequestId: ${_this.activeRequestId})';
}


}

/// @nodoc
abstract mixin class $LiveShutterStateCopyWith<$Res>  {
  factory $LiveShutterStateCopyWith(LiveShutterState value, $Res Function(LiveShutterState) _then) = _$LiveShutterStateCopyWithImpl;
@useResult
$Res call({
 bool online, bool helpReady, int? priceListVersion, DateTime? heartbeatAt, String? activeRequestId
});




}
/// @nodoc
class _$LiveShutterStateCopyWithImpl<$Res>
    implements $LiveShutterStateCopyWith<$Res> {
  _$LiveShutterStateCopyWithImpl(this._self, this._then);

  final LiveShutterState _self;
  final $Res Function(LiveShutterState) _then;

/// Create a copy of LiveShutterState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? online = null,Object? helpReady = null,Object? priceListVersion = freezed,Object? heartbeatAt = freezed,Object? activeRequestId = freezed,}) {
  return _then(LiveShutterState(
online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,helpReady: null == helpReady ? _self.helpReady : helpReady // ignore: cast_nullable_to_non_nullable
as bool,priceListVersion: freezed == priceListVersion ? _self.priceListVersion : priceListVersion // ignore: cast_nullable_to_non_nullable
as int?,heartbeatAt: freezed == heartbeatAt ? _self.heartbeatAt : heartbeatAt // ignore: cast_nullable_to_non_nullable
as DateTime?,activeRequestId: freezed == activeRequestId ? _self.activeRequestId : activeRequestId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LiveShutterState].
extension LiveShutterStatePatterns on LiveShutterState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LiveShutterState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LiveShutterState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LiveShutterState value)  $default,){
final _that = this;
switch (_that) {
case _LiveShutterState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LiveShutterState value)?  $default,){
final _that = this;
switch (_that) {
case _LiveShutterState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool online,  bool helpReady,  int? priceListVersion,  DateTime? heartbeatAt,  String? activeRequestId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LiveShutterState() when $default != null:
return $default(_that.online,_that.helpReady,_that.priceListVersion,_that.heartbeatAt,_that.activeRequestId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool online,  bool helpReady,  int? priceListVersion,  DateTime? heartbeatAt,  String? activeRequestId)  $default,) {final _that = this;
switch (_that) {
case _LiveShutterState():
return $default(_that.online,_that.helpReady,_that.priceListVersion,_that.heartbeatAt,_that.activeRequestId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool online,  bool helpReady,  int? priceListVersion,  DateTime? heartbeatAt,  String? activeRequestId)?  $default,) {final _that = this;
switch (_that) {
case _LiveShutterState() when $default != null:
return $default(_that.online,_that.helpReady,_that.priceListVersion,_that.heartbeatAt,_that.activeRequestId);case _:
  return null;

}
}

}

/// @nodoc


class _LiveShutterState extends LiveShutterState {
  const _LiveShutterState({this.online = false, this.helpReady = false, this.priceListVersion, this.heartbeatAt, this.activeRequestId}): super._();
  

@override@JsonKey() final  bool online;
@override@JsonKey() final  bool helpReady;
/// The price list version accepted; null = never accepted.
@override final  int? priceListVersion;
@override final  DateTime? heartbeatAt;
@override final  String? activeRequestId;

/// Create a copy of LiveShutterState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LiveShutterStateCopyWith<_LiveShutterState> get copyWith => __$LiveShutterStateCopyWithImpl<_LiveShutterState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LiveShutterState&&(identical(other.online, online) || other.online == online)&&(identical(other.helpReady, helpReady) || other.helpReady == helpReady)&&(identical(other.priceListVersion, priceListVersion) || other.priceListVersion == priceListVersion)&&(identical(other.heartbeatAt, heartbeatAt) || other.heartbeatAt == heartbeatAt)&&(identical(other.activeRequestId, activeRequestId) || other.activeRequestId == activeRequestId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,online,helpReady,priceListVersion,heartbeatAt,activeRequestId);
}

@override
String toString() {
    return 'LiveShutterState(online: $online, helpReady: $helpReady, priceListVersion: $priceListVersion, heartbeatAt: $heartbeatAt, activeRequestId: $activeRequestId)';
}


}

/// @nodoc
abstract mixin class _$LiveShutterStateCopyWith<$Res> implements $LiveShutterStateCopyWith<$Res> {
  factory _$LiveShutterStateCopyWith(_LiveShutterState value, $Res Function(_LiveShutterState) _then) = __$LiveShutterStateCopyWithImpl;
@override @useResult
$Res call({
 bool online, bool helpReady, int? priceListVersion, DateTime? heartbeatAt, String? activeRequestId
});




}
/// @nodoc
class __$LiveShutterStateCopyWithImpl<$Res>
    implements _$LiveShutterStateCopyWith<$Res> {
  __$LiveShutterStateCopyWithImpl(this._self, this._then);

  final _LiveShutterState _self;
  final $Res Function(_LiveShutterState) _then;

/// Create a copy of LiveShutterState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? online = null,Object? helpReady = null,Object? priceListVersion = freezed,Object? heartbeatAt = freezed,Object? activeRequestId = freezed,}) {
  return _then(_LiveShutterState(
online: null == online ? _self.online : online // ignore: cast_nullable_to_non_nullable
as bool,helpReady: null == helpReady ? _self.helpReady : helpReady // ignore: cast_nullable_to_non_nullable
as bool,priceListVersion: freezed == priceListVersion ? _self.priceListVersion : priceListVersion // ignore: cast_nullable_to_non_nullable
as int?,heartbeatAt: freezed == heartbeatAt ? _self.heartbeatAt : heartbeatAt // ignore: cast_nullable_to_non_nullable
as DateTime?,activeRequestId: freezed == activeRequestId ? _self.activeRequestId : activeRequestId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$InstantCancelQuote {

 InstantCancelRule? get rule;/// 0..100: the customer's share.
 int get refundPercent; int get refundVnd;/// What the photographer keeps.
 int get feeVnd;/// The money collected (0 while unpaid, every #140 request).
 int get amountVnd;
/// Create a copy of InstantCancelQuote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstantCancelQuoteCopyWith<InstantCancelQuote> get copyWith => _$InstantCancelQuoteCopyWithImpl<InstantCancelQuote>(this as InstantCancelQuote, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InstantCancelQuote;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstantCancelQuote&&(identical(other.rule, _this.rule) || other.rule == _this.rule)&&(identical(other.refundPercent, _this.refundPercent) || other.refundPercent == _this.refundPercent)&&(identical(other.refundVnd, _this.refundVnd) || other.refundVnd == _this.refundVnd)&&(identical(other.feeVnd, _this.feeVnd) || other.feeVnd == _this.feeVnd)&&(identical(other.amountVnd, _this.amountVnd) || other.amountVnd == _this.amountVnd));
}


@override
int get hashCode {
  final _this = this as InstantCancelQuote;
  return Object.hash(runtimeType,_this.rule,_this.refundPercent,_this.refundVnd,_this.feeVnd,_this.amountVnd);
}

@override
String toString() {
  final _this = this as InstantCancelQuote;
  return 'InstantCancelQuote(rule: ${_this.rule}, refundPercent: ${_this.refundPercent}, refundVnd: ${_this.refundVnd}, feeVnd: ${_this.feeVnd}, amountVnd: ${_this.amountVnd})';
}


}

/// @nodoc
abstract mixin class $InstantCancelQuoteCopyWith<$Res>  {
  factory $InstantCancelQuoteCopyWith(InstantCancelQuote value, $Res Function(InstantCancelQuote) _then) = _$InstantCancelQuoteCopyWithImpl;
@useResult
$Res call({
 InstantCancelRule? rule, int refundPercent, int refundVnd, int feeVnd, int amountVnd
});




}
/// @nodoc
class _$InstantCancelQuoteCopyWithImpl<$Res>
    implements $InstantCancelQuoteCopyWith<$Res> {
  _$InstantCancelQuoteCopyWithImpl(this._self, this._then);

  final InstantCancelQuote _self;
  final $Res Function(InstantCancelQuote) _then;

/// Create a copy of InstantCancelQuote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rule = freezed,Object? refundPercent = null,Object? refundVnd = null,Object? feeVnd = null,Object? amountVnd = null,}) {
  return _then(InstantCancelQuote(
rule: freezed == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as InstantCancelRule?,refundPercent: null == refundPercent ? _self.refundPercent : refundPercent // ignore: cast_nullable_to_non_nullable
as int,refundVnd: null == refundVnd ? _self.refundVnd : refundVnd // ignore: cast_nullable_to_non_nullable
as int,feeVnd: null == feeVnd ? _self.feeVnd : feeVnd // ignore: cast_nullable_to_non_nullable
as int,amountVnd: null == amountVnd ? _self.amountVnd : amountVnd // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [InstantCancelQuote].
extension InstantCancelQuotePatterns on InstantCancelQuote {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstantCancelQuote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstantCancelQuote() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstantCancelQuote value)  $default,){
final _that = this;
switch (_that) {
case _InstantCancelQuote():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstantCancelQuote value)?  $default,){
final _that = this;
switch (_that) {
case _InstantCancelQuote() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( InstantCancelRule? rule,  int refundPercent,  int refundVnd,  int feeVnd,  int amountVnd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstantCancelQuote() when $default != null:
return $default(_that.rule,_that.refundPercent,_that.refundVnd,_that.feeVnd,_that.amountVnd);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( InstantCancelRule? rule,  int refundPercent,  int refundVnd,  int feeVnd,  int amountVnd)  $default,) {final _that = this;
switch (_that) {
case _InstantCancelQuote():
return $default(_that.rule,_that.refundPercent,_that.refundVnd,_that.feeVnd,_that.amountVnd);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( InstantCancelRule? rule,  int refundPercent,  int refundVnd,  int feeVnd,  int amountVnd)?  $default,) {final _that = this;
switch (_that) {
case _InstantCancelQuote() when $default != null:
return $default(_that.rule,_that.refundPercent,_that.refundVnd,_that.feeVnd,_that.amountVnd);case _:
  return null;

}
}

}

/// @nodoc


class _InstantCancelQuote implements InstantCancelQuote {
  const _InstantCancelQuote({this.rule, this.refundPercent = 0, this.refundVnd = 0, this.feeVnd = 0, this.amountVnd = 0});
  

@override final  InstantCancelRule? rule;
/// 0..100: the customer's share.
@override@JsonKey() final  int refundPercent;
@override@JsonKey() final  int refundVnd;
/// What the photographer keeps.
@override@JsonKey() final  int feeVnd;
/// The money collected (0 while unpaid, every #140 request).
@override@JsonKey() final  int amountVnd;

/// Create a copy of InstantCancelQuote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstantCancelQuoteCopyWith<_InstantCancelQuote> get copyWith => __$InstantCancelQuoteCopyWithImpl<_InstantCancelQuote>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstantCancelQuote&&(identical(other.rule, rule) || other.rule == rule)&&(identical(other.refundPercent, refundPercent) || other.refundPercent == refundPercent)&&(identical(other.refundVnd, refundVnd) || other.refundVnd == refundVnd)&&(identical(other.feeVnd, feeVnd) || other.feeVnd == feeVnd)&&(identical(other.amountVnd, amountVnd) || other.amountVnd == amountVnd));
}


@override
int get hashCode {
    return Object.hash(runtimeType,rule,refundPercent,refundVnd,feeVnd,amountVnd);
}

@override
String toString() {
    return 'InstantCancelQuote(rule: $rule, refundPercent: $refundPercent, refundVnd: $refundVnd, feeVnd: $feeVnd, amountVnd: $amountVnd)';
}


}

/// @nodoc
abstract mixin class _$InstantCancelQuoteCopyWith<$Res> implements $InstantCancelQuoteCopyWith<$Res> {
  factory _$InstantCancelQuoteCopyWith(_InstantCancelQuote value, $Res Function(_InstantCancelQuote) _then) = __$InstantCancelQuoteCopyWithImpl;
@override @useResult
$Res call({
 InstantCancelRule? rule, int refundPercent, int refundVnd, int feeVnd, int amountVnd
});




}
/// @nodoc
class __$InstantCancelQuoteCopyWithImpl<$Res>
    implements _$InstantCancelQuoteCopyWith<$Res> {
  __$InstantCancelQuoteCopyWithImpl(this._self, this._then);

  final _InstantCancelQuote _self;
  final $Res Function(_InstantCancelQuote) _then;

/// Create a copy of InstantCancelQuote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rule = freezed,Object? refundPercent = null,Object? refundVnd = null,Object? feeVnd = null,Object? amountVnd = null,}) {
  return _then(_InstantCancelQuote(
rule: freezed == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as InstantCancelRule?,refundPercent: null == refundPercent ? _self.refundPercent : refundPercent // ignore: cast_nullable_to_non_nullable
as int,refundVnd: null == refundVnd ? _self.refundVnd : refundVnd // ignore: cast_nullable_to_non_nullable
as int,feeVnd: null == feeVnd ? _self.feeVnd : feeVnd // ignore: cast_nullable_to_non_nullable
as int,amountVnd: null == amountVnd ? _self.amountVnd : amountVnd // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
