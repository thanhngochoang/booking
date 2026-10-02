// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'booking.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookingServiceSnapshot {

 String get name; int get price; int get durationMinutes;
/// Create a copy of BookingServiceSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingServiceSnapshotCopyWith<BookingServiceSnapshot> get copyWith => _$BookingServiceSnapshotCopyWithImpl<BookingServiceSnapshot>(this as BookingServiceSnapshot, _$identity);

  /// Serializes this BookingServiceSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BookingServiceSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingServiceSnapshot&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.price, _this.price) || other.price == _this.price)&&(identical(other.durationMinutes, _this.durationMinutes) || other.durationMinutes == _this.durationMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BookingServiceSnapshot;
  return Object.hash(runtimeType,_this.name,_this.price,_this.durationMinutes);
}

@override
String toString() {
  final _this = this as BookingServiceSnapshot;
  return 'BookingServiceSnapshot(name: ${_this.name}, price: ${_this.price}, durationMinutes: ${_this.durationMinutes})';
}


}

/// @nodoc
abstract mixin class $BookingServiceSnapshotCopyWith<$Res>  {
  factory $BookingServiceSnapshotCopyWith(BookingServiceSnapshot value, $Res Function(BookingServiceSnapshot) _then) = _$BookingServiceSnapshotCopyWithImpl;
@useResult
$Res call({
 String name, int price, int durationMinutes
});




}
/// @nodoc
class _$BookingServiceSnapshotCopyWithImpl<$Res>
    implements $BookingServiceSnapshotCopyWith<$Res> {
  _$BookingServiceSnapshotCopyWithImpl(this._self, this._then);

  final BookingServiceSnapshot _self;
  final $Res Function(BookingServiceSnapshot) _then;

/// Create a copy of BookingServiceSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? price = null,Object? durationMinutes = null,}) {
  return _then(BookingServiceSnapshot(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as int,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BookingServiceSnapshot].
extension BookingServiceSnapshotPatterns on BookingServiceSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingServiceSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingServiceSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingServiceSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _BookingServiceSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingServiceSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _BookingServiceSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int price,  int durationMinutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingServiceSnapshot() when $default != null:
return $default(_that.name,_that.price,_that.durationMinutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int price,  int durationMinutes)  $default,) {final _that = this;
switch (_that) {
case _BookingServiceSnapshot():
return $default(_that.name,_that.price,_that.durationMinutes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int price,  int durationMinutes)?  $default,) {final _that = this;
switch (_that) {
case _BookingServiceSnapshot() when $default != null:
return $default(_that.name,_that.price,_that.durationMinutes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookingServiceSnapshot implements BookingServiceSnapshot {
  const _BookingServiceSnapshot({required this.name, required this.price, required this.durationMinutes});
  factory _BookingServiceSnapshot.fromJson(Map<String, dynamic> json) => _$BookingServiceSnapshotFromJson(json);

@override final  String name;
@override final  int price;
@override final  int durationMinutes;

/// Create a copy of BookingServiceSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingServiceSnapshotCopyWith<_BookingServiceSnapshot> get copyWith => __$BookingServiceSnapshotCopyWithImpl<_BookingServiceSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingServiceSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingServiceSnapshot&&(identical(other.name, name) || other.name == name)&&(identical(other.price, price) || other.price == price)&&(identical(other.durationMinutes, durationMinutes) || other.durationMinutes == durationMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,price,durationMinutes);
}

@override
String toString() {
    return 'BookingServiceSnapshot(name: $name, price: $price, durationMinutes: $durationMinutes)';
}


}

/// @nodoc
abstract mixin class _$BookingServiceSnapshotCopyWith<$Res> implements $BookingServiceSnapshotCopyWith<$Res> {
  factory _$BookingServiceSnapshotCopyWith(_BookingServiceSnapshot value, $Res Function(_BookingServiceSnapshot) _then) = __$BookingServiceSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String name, int price, int durationMinutes
});




}
/// @nodoc
class __$BookingServiceSnapshotCopyWithImpl<$Res>
    implements _$BookingServiceSnapshotCopyWith<$Res> {
  __$BookingServiceSnapshotCopyWithImpl(this._self, this._then);

  final _BookingServiceSnapshot _self;
  final $Res Function(_BookingServiceSnapshot) _then;

/// Create a copy of BookingServiceSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? price = null,Object? durationMinutes = null,}) {
  return _then(_BookingServiceSnapshot(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as int,durationMinutes: null == durationMinutes ? _self.durationMinutes : durationMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$BookingPlace {

 String get name; double? get lat; double? get lng;
/// Create a copy of BookingPlace
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingPlaceCopyWith<BookingPlace> get copyWith => _$BookingPlaceCopyWithImpl<BookingPlace>(this as BookingPlace, _$identity);

  /// Serializes this BookingPlace to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BookingPlace;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingPlace&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.lat, _this.lat) || other.lat == _this.lat)&&(identical(other.lng, _this.lng) || other.lng == _this.lng));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BookingPlace;
  return Object.hash(runtimeType,_this.name,_this.lat,_this.lng);
}

@override
String toString() {
  final _this = this as BookingPlace;
  return 'BookingPlace(name: ${_this.name}, lat: ${_this.lat}, lng: ${_this.lng})';
}


}

/// @nodoc
abstract mixin class $BookingPlaceCopyWith<$Res>  {
  factory $BookingPlaceCopyWith(BookingPlace value, $Res Function(BookingPlace) _then) = _$BookingPlaceCopyWithImpl;
@useResult
$Res call({
 String name, double? lat, double? lng
});




}
/// @nodoc
class _$BookingPlaceCopyWithImpl<$Res>
    implements $BookingPlaceCopyWith<$Res> {
  _$BookingPlaceCopyWithImpl(this._self, this._then);

  final BookingPlace _self;
  final $Res Function(BookingPlace) _then;

/// Create a copy of BookingPlace
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? lat = freezed,Object? lng = freezed,}) {
  return _then(BookingPlace(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [BookingPlace].
extension BookingPlacePatterns on BookingPlace {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingPlace value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingPlace() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingPlace value)  $default,){
final _that = this;
switch (_that) {
case _BookingPlace():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingPlace value)?  $default,){
final _that = this;
switch (_that) {
case _BookingPlace() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  double? lat,  double? lng)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingPlace() when $default != null:
return $default(_that.name,_that.lat,_that.lng);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  double? lat,  double? lng)  $default,) {final _that = this;
switch (_that) {
case _BookingPlace():
return $default(_that.name,_that.lat,_that.lng);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  double? lat,  double? lng)?  $default,) {final _that = this;
switch (_that) {
case _BookingPlace() when $default != null:
return $default(_that.name,_that.lat,_that.lng);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookingPlace implements BookingPlace {
  const _BookingPlace({required this.name, this.lat, this.lng});
  factory _BookingPlace.fromJson(Map<String, dynamic> json) => _$BookingPlaceFromJson(json);

@override final  String name;
@override final  double? lat;
@override final  double? lng;

/// Create a copy of BookingPlace
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingPlaceCopyWith<_BookingPlace> get copyWith => __$BookingPlaceCopyWithImpl<_BookingPlace>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingPlaceToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingPlace&&(identical(other.name, name) || other.name == name)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,lat,lng);
}

@override
String toString() {
    return 'BookingPlace(name: $name, lat: $lat, lng: $lng)';
}


}

/// @nodoc
abstract mixin class _$BookingPlaceCopyWith<$Res> implements $BookingPlaceCopyWith<$Res> {
  factory _$BookingPlaceCopyWith(_BookingPlace value, $Res Function(_BookingPlace) _then) = __$BookingPlaceCopyWithImpl;
@override @useResult
$Res call({
 String name, double? lat, double? lng
});




}
/// @nodoc
class __$BookingPlaceCopyWithImpl<$Res>
    implements _$BookingPlaceCopyWith<$Res> {
  __$BookingPlaceCopyWithImpl(this._self, this._then);

  final _BookingPlace _self;
  final $Res Function(_BookingPlace) _then;

/// Create a copy of BookingPlace
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? lat = freezed,Object? lng = freezed,}) {
  return _then(_BookingPlace(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$BookingCancel {

 String get by; String? get reason; DateTime get at; int get refundPercent;
/// Create a copy of BookingCancel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingCancelCopyWith<BookingCancel> get copyWith => _$BookingCancelCopyWithImpl<BookingCancel>(this as BookingCancel, _$identity);

  /// Serializes this BookingCancel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BookingCancel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingCancel&&(identical(other.by, _this.by) || other.by == _this.by)&&(identical(other.reason, _this.reason) || other.reason == _this.reason)&&(identical(other.at, _this.at) || other.at == _this.at)&&(identical(other.refundPercent, _this.refundPercent) || other.refundPercent == _this.refundPercent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BookingCancel;
  return Object.hash(runtimeType,_this.by,_this.reason,_this.at,_this.refundPercent);
}

@override
String toString() {
  final _this = this as BookingCancel;
  return 'BookingCancel(by: ${_this.by}, reason: ${_this.reason}, at: ${_this.at}, refundPercent: ${_this.refundPercent})';
}


}

/// @nodoc
abstract mixin class $BookingCancelCopyWith<$Res>  {
  factory $BookingCancelCopyWith(BookingCancel value, $Res Function(BookingCancel) _then) = _$BookingCancelCopyWithImpl;
@useResult
$Res call({
 String by, String? reason, DateTime at, int refundPercent
});




}
/// @nodoc
class _$BookingCancelCopyWithImpl<$Res>
    implements $BookingCancelCopyWith<$Res> {
  _$BookingCancelCopyWithImpl(this._self, this._then);

  final BookingCancel _self;
  final $Res Function(BookingCancel) _then;

/// Create a copy of BookingCancel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? by = null,Object? reason = freezed,Object? at = null,Object? refundPercent = null,}) {
  return _then(BookingCancel(
by: null == by ? _self.by : by // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,refundPercent: null == refundPercent ? _self.refundPercent : refundPercent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BookingCancel].
extension BookingCancelPatterns on BookingCancel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingCancel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingCancel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingCancel value)  $default,){
final _that = this;
switch (_that) {
case _BookingCancel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingCancel value)?  $default,){
final _that = this;
switch (_that) {
case _BookingCancel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String by,  String? reason,  DateTime at,  int refundPercent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingCancel() when $default != null:
return $default(_that.by,_that.reason,_that.at,_that.refundPercent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String by,  String? reason,  DateTime at,  int refundPercent)  $default,) {final _that = this;
switch (_that) {
case _BookingCancel():
return $default(_that.by,_that.reason,_that.at,_that.refundPercent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String by,  String? reason,  DateTime at,  int refundPercent)?  $default,) {final _that = this;
switch (_that) {
case _BookingCancel() when $default != null:
return $default(_that.by,_that.reason,_that.at,_that.refundPercent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookingCancel implements BookingCancel {
  const _BookingCancel({required this.by, this.reason, required this.at, required this.refundPercent});
  factory _BookingCancel.fromJson(Map<String, dynamic> json) => _$BookingCancelFromJson(json);

@override final  String by;
@override final  String? reason;
@override final  DateTime at;
@override final  int refundPercent;

/// Create a copy of BookingCancel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingCancelCopyWith<_BookingCancel> get copyWith => __$BookingCancelCopyWithImpl<_BookingCancel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingCancelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingCancel&&(identical(other.by, by) || other.by == by)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.at, at) || other.at == at)&&(identical(other.refundPercent, refundPercent) || other.refundPercent == refundPercent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,by,reason,at,refundPercent);
}

@override
String toString() {
    return 'BookingCancel(by: $by, reason: $reason, at: $at, refundPercent: $refundPercent)';
}


}

/// @nodoc
abstract mixin class _$BookingCancelCopyWith<$Res> implements $BookingCancelCopyWith<$Res> {
  factory _$BookingCancelCopyWith(_BookingCancel value, $Res Function(_BookingCancel) _then) = __$BookingCancelCopyWithImpl;
@override @useResult
$Res call({
 String by, String? reason, DateTime at, int refundPercent
});




}
/// @nodoc
class __$BookingCancelCopyWithImpl<$Res>
    implements _$BookingCancelCopyWith<$Res> {
  __$BookingCancelCopyWithImpl(this._self, this._then);

  final _BookingCancel _self;
  final $Res Function(_BookingCancel) _then;

/// Create a copy of BookingCancel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? by = null,Object? reason = freezed,Object? at = null,Object? refundPercent = null,}) {
  return _then(_BookingCancel(
by: null == by ? _self.by : by // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,refundPercent: null == refundPercent ? _self.refundPercent : refundPercent // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$BookingContactSnapshot {

 String get name; String? get phone; bool get allowZalo; bool get allowWhatsApp; DateTime? get redactedAt;
/// Create a copy of BookingContactSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingContactSnapshotCopyWith<BookingContactSnapshot> get copyWith => _$BookingContactSnapshotCopyWithImpl<BookingContactSnapshot>(this as BookingContactSnapshot, _$identity);

  /// Serializes this BookingContactSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BookingContactSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingContactSnapshot&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.phone, _this.phone) || other.phone == _this.phone)&&(identical(other.allowZalo, _this.allowZalo) || other.allowZalo == _this.allowZalo)&&(identical(other.allowWhatsApp, _this.allowWhatsApp) || other.allowWhatsApp == _this.allowWhatsApp)&&(identical(other.redactedAt, _this.redactedAt) || other.redactedAt == _this.redactedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BookingContactSnapshot;
  return Object.hash(runtimeType,_this.name,_this.phone,_this.allowZalo,_this.allowWhatsApp,_this.redactedAt);
}

@override
String toString() {
  final _this = this as BookingContactSnapshot;
  return 'BookingContactSnapshot(name: ${_this.name}, phone: ${_this.phone}, allowZalo: ${_this.allowZalo}, allowWhatsApp: ${_this.allowWhatsApp}, redactedAt: ${_this.redactedAt})';
}


}

/// @nodoc
abstract mixin class $BookingContactSnapshotCopyWith<$Res>  {
  factory $BookingContactSnapshotCopyWith(BookingContactSnapshot value, $Res Function(BookingContactSnapshot) _then) = _$BookingContactSnapshotCopyWithImpl;
@useResult
$Res call({
 String name, String? phone, bool allowZalo, bool allowWhatsApp, DateTime? redactedAt
});




}
/// @nodoc
class _$BookingContactSnapshotCopyWithImpl<$Res>
    implements $BookingContactSnapshotCopyWith<$Res> {
  _$BookingContactSnapshotCopyWithImpl(this._self, this._then);

  final BookingContactSnapshot _self;
  final $Res Function(BookingContactSnapshot) _then;

/// Create a copy of BookingContactSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? phone = freezed,Object? allowZalo = null,Object? allowWhatsApp = null,Object? redactedAt = freezed,}) {
  return _then(BookingContactSnapshot(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,allowZalo: null == allowZalo ? _self.allowZalo : allowZalo // ignore: cast_nullable_to_non_nullable
as bool,allowWhatsApp: null == allowWhatsApp ? _self.allowWhatsApp : allowWhatsApp // ignore: cast_nullable_to_non_nullable
as bool,redactedAt: freezed == redactedAt ? _self.redactedAt : redactedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [BookingContactSnapshot].
extension BookingContactSnapshotPatterns on BookingContactSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingContactSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingContactSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingContactSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _BookingContactSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingContactSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _BookingContactSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String? phone,  bool allowZalo,  bool allowWhatsApp,  DateTime? redactedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingContactSnapshot() when $default != null:
return $default(_that.name,_that.phone,_that.allowZalo,_that.allowWhatsApp,_that.redactedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String? phone,  bool allowZalo,  bool allowWhatsApp,  DateTime? redactedAt)  $default,) {final _that = this;
switch (_that) {
case _BookingContactSnapshot():
return $default(_that.name,_that.phone,_that.allowZalo,_that.allowWhatsApp,_that.redactedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String? phone,  bool allowZalo,  bool allowWhatsApp,  DateTime? redactedAt)?  $default,) {final _that = this;
switch (_that) {
case _BookingContactSnapshot() when $default != null:
return $default(_that.name,_that.phone,_that.allowZalo,_that.allowWhatsApp,_that.redactedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookingContactSnapshot implements BookingContactSnapshot {
  const _BookingContactSnapshot({required this.name, this.phone, this.allowZalo = true, this.allowWhatsApp = false, this.redactedAt});
  factory _BookingContactSnapshot.fromJson(Map<String, dynamic> json) => _$BookingContactSnapshotFromJson(json);

@override final  String name;
@override final  String? phone;
@override@JsonKey() final  bool allowZalo;
@override@JsonKey() final  bool allowWhatsApp;
@override final  DateTime? redactedAt;

/// Create a copy of BookingContactSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingContactSnapshotCopyWith<_BookingContactSnapshot> get copyWith => __$BookingContactSnapshotCopyWithImpl<_BookingContactSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingContactSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingContactSnapshot&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.allowZalo, allowZalo) || other.allowZalo == allowZalo)&&(identical(other.allowWhatsApp, allowWhatsApp) || other.allowWhatsApp == allowWhatsApp)&&(identical(other.redactedAt, redactedAt) || other.redactedAt == redactedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,phone,allowZalo,allowWhatsApp,redactedAt);
}

@override
String toString() {
    return 'BookingContactSnapshot(name: $name, phone: $phone, allowZalo: $allowZalo, allowWhatsApp: $allowWhatsApp, redactedAt: $redactedAt)';
}


}

/// @nodoc
abstract mixin class _$BookingContactSnapshotCopyWith<$Res> implements $BookingContactSnapshotCopyWith<$Res> {
  factory _$BookingContactSnapshotCopyWith(_BookingContactSnapshot value, $Res Function(_BookingContactSnapshot) _then) = __$BookingContactSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String name, String? phone, bool allowZalo, bool allowWhatsApp, DateTime? redactedAt
});




}
/// @nodoc
class __$BookingContactSnapshotCopyWithImpl<$Res>
    implements _$BookingContactSnapshotCopyWith<$Res> {
  __$BookingContactSnapshotCopyWithImpl(this._self, this._then);

  final _BookingContactSnapshot _self;
  final $Res Function(_BookingContactSnapshot) _then;

/// Create a copy of BookingContactSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? phone = freezed,Object? allowZalo = null,Object? allowWhatsApp = null,Object? redactedAt = freezed,}) {
  return _then(_BookingContactSnapshot(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,allowZalo: null == allowZalo ? _self.allowZalo : allowZalo // ignore: cast_nullable_to_non_nullable
as bool,allowWhatsApp: null == allowWhatsApp ? _self.allowWhatsApp : allowWhatsApp // ignore: cast_nullable_to_non_nullable
as bool,redactedAt: freezed == redactedAt ? _self.redactedAt : redactedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$BookingEventRecord {

 String get id; String get bookingId; BookingStatus get status; DateTime get at; String? get actorId;
/// Create a copy of BookingEventRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingEventRecordCopyWith<BookingEventRecord> get copyWith => _$BookingEventRecordCopyWithImpl<BookingEventRecord>(this as BookingEventRecord, _$identity);

  /// Serializes this BookingEventRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BookingEventRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookingEventRecord&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.bookingId, _this.bookingId) || other.bookingId == _this.bookingId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.at, _this.at) || other.at == _this.at)&&(identical(other.actorId, _this.actorId) || other.actorId == _this.actorId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BookingEventRecord;
  return Object.hash(runtimeType,_this.id,_this.bookingId,_this.status,_this.at,_this.actorId);
}

@override
String toString() {
  final _this = this as BookingEventRecord;
  return 'BookingEventRecord(id: ${_this.id}, bookingId: ${_this.bookingId}, status: ${_this.status}, at: ${_this.at}, actorId: ${_this.actorId})';
}


}

/// @nodoc
abstract mixin class $BookingEventRecordCopyWith<$Res>  {
  factory $BookingEventRecordCopyWith(BookingEventRecord value, $Res Function(BookingEventRecord) _then) = _$BookingEventRecordCopyWithImpl;
@useResult
$Res call({
 String id, String bookingId, BookingStatus status, DateTime at, String? actorId
});




}
/// @nodoc
class _$BookingEventRecordCopyWithImpl<$Res>
    implements $BookingEventRecordCopyWith<$Res> {
  _$BookingEventRecordCopyWithImpl(this._self, this._then);

  final BookingEventRecord _self;
  final $Res Function(BookingEventRecord) _then;

/// Create a copy of BookingEventRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookingId = null,Object? status = null,Object? at = null,Object? actorId = freezed,}) {
  return _then(BookingEventRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BookingStatus,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,actorId: freezed == actorId ? _self.actorId : actorId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [BookingEventRecord].
extension BookingEventRecordPatterns on BookingEventRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookingEventRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookingEventRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookingEventRecord value)  $default,){
final _that = this;
switch (_that) {
case _BookingEventRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookingEventRecord value)?  $default,){
final _that = this;
switch (_that) {
case _BookingEventRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String bookingId,  BookingStatus status,  DateTime at,  String? actorId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookingEventRecord() when $default != null:
return $default(_that.id,_that.bookingId,_that.status,_that.at,_that.actorId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String bookingId,  BookingStatus status,  DateTime at,  String? actorId)  $default,) {final _that = this;
switch (_that) {
case _BookingEventRecord():
return $default(_that.id,_that.bookingId,_that.status,_that.at,_that.actorId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String bookingId,  BookingStatus status,  DateTime at,  String? actorId)?  $default,) {final _that = this;
switch (_that) {
case _BookingEventRecord() when $default != null:
return $default(_that.id,_that.bookingId,_that.status,_that.at,_that.actorId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookingEventRecord implements BookingEventRecord {
  const _BookingEventRecord({required this.id, required this.bookingId, required this.status, required this.at, this.actorId});
  factory _BookingEventRecord.fromJson(Map<String, dynamic> json) => _$BookingEventRecordFromJson(json);

@override final  String id;
@override final  String bookingId;
@override final  BookingStatus status;
@override final  DateTime at;
@override final  String? actorId;

/// Create a copy of BookingEventRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingEventRecordCopyWith<_BookingEventRecord> get copyWith => __$BookingEventRecordCopyWithImpl<_BookingEventRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingEventRecordToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookingEventRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.status, status) || other.status == status)&&(identical(other.at, at) || other.at == at)&&(identical(other.actorId, actorId) || other.actorId == actorId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,bookingId,status,at,actorId);
}

@override
String toString() {
    return 'BookingEventRecord(id: $id, bookingId: $bookingId, status: $status, at: $at, actorId: $actorId)';
}


}

/// @nodoc
abstract mixin class _$BookingEventRecordCopyWith<$Res> implements $BookingEventRecordCopyWith<$Res> {
  factory _$BookingEventRecordCopyWith(_BookingEventRecord value, $Res Function(_BookingEventRecord) _then) = __$BookingEventRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String bookingId, BookingStatus status, DateTime at, String? actorId
});




}
/// @nodoc
class __$BookingEventRecordCopyWithImpl<$Res>
    implements _$BookingEventRecordCopyWith<$Res> {
  __$BookingEventRecordCopyWithImpl(this._self, this._then);

  final _BookingEventRecord _self;
  final $Res Function(_BookingEventRecord) _then;

/// Create a copy of BookingEventRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookingId = null,Object? status = null,Object? at = null,Object? actorId = freezed,}) {
  return _then(_BookingEventRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BookingStatus,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,actorId: freezed == actorId ? _self.actorId : actorId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Booking {

 String get id; String get customerId; String get photographerId; String get serviceId; BookingServiceSnapshot get serviceSnapshot; String get day; String get start; String get end; BookingPlace get place; String? get note; BookingStatus get status; int get deposit; int get remaining; EscrowStatus? get escrowStatus; int? get depositRefunded; String? get depositProvider; DateTime? get depositPaidAt; DateTime? get depositRefundedAt; DateTime? get acceptDeadline; BookingCancel? get cancel; DateTime? get completedAt; DateTime? get reviewedAt; String? get chatId; int get version; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookingCopyWith<Booking> get copyWith => _$BookingCopyWithImpl<Booking>(this as Booking, _$identity);

  /// Serializes this Booking to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Booking;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Booking&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.customerId, _this.customerId) || other.customerId == _this.customerId)&&(identical(other.photographerId, _this.photographerId) || other.photographerId == _this.photographerId)&&(identical(other.serviceId, _this.serviceId) || other.serviceId == _this.serviceId)&&(identical(other.serviceSnapshot, _this.serviceSnapshot) || other.serviceSnapshot == _this.serviceSnapshot)&&(identical(other.day, _this.day) || other.day == _this.day)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.end, _this.end) || other.end == _this.end)&&(identical(other.place, _this.place) || other.place == _this.place)&&(identical(other.note, _this.note) || other.note == _this.note)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.deposit, _this.deposit) || other.deposit == _this.deposit)&&(identical(other.remaining, _this.remaining) || other.remaining == _this.remaining)&&(identical(other.escrowStatus, _this.escrowStatus) || other.escrowStatus == _this.escrowStatus)&&(identical(other.depositRefunded, _this.depositRefunded) || other.depositRefunded == _this.depositRefunded)&&(identical(other.depositProvider, _this.depositProvider) || other.depositProvider == _this.depositProvider)&&(identical(other.depositPaidAt, _this.depositPaidAt) || other.depositPaidAt == _this.depositPaidAt)&&(identical(other.depositRefundedAt, _this.depositRefundedAt) || other.depositRefundedAt == _this.depositRefundedAt)&&(identical(other.acceptDeadline, _this.acceptDeadline) || other.acceptDeadline == _this.acceptDeadline)&&(identical(other.cancel, _this.cancel) || other.cancel == _this.cancel)&&(identical(other.completedAt, _this.completedAt) || other.completedAt == _this.completedAt)&&(identical(other.reviewedAt, _this.reviewedAt) || other.reviewedAt == _this.reviewedAt)&&(identical(other.chatId, _this.chatId) || other.chatId == _this.chatId)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Booking;
  return Object.hashAll([runtimeType,_this.id,_this.customerId,_this.photographerId,_this.serviceId,_this.serviceSnapshot,_this.day,_this.start,_this.end,_this.place,_this.note,_this.status,_this.deposit,_this.remaining,_this.escrowStatus,_this.depositRefunded,_this.depositProvider,_this.depositPaidAt,_this.depositRefundedAt,_this.acceptDeadline,_this.cancel,_this.completedAt,_this.reviewedAt,_this.chatId,_this.version,_this.createdAt,_this.updatedAt]);
}

@override
String toString() {
  final _this = this as Booking;
  return 'Booking(id: ${_this.id}, customerId: ${_this.customerId}, photographerId: ${_this.photographerId}, serviceId: ${_this.serviceId}, serviceSnapshot: ${_this.serviceSnapshot}, day: ${_this.day}, start: ${_this.start}, end: ${_this.end}, place: ${_this.place}, note: ${_this.note}, status: ${_this.status}, deposit: ${_this.deposit}, remaining: ${_this.remaining}, escrowStatus: ${_this.escrowStatus}, depositRefunded: ${_this.depositRefunded}, depositProvider: ${_this.depositProvider}, depositPaidAt: ${_this.depositPaidAt}, depositRefundedAt: ${_this.depositRefundedAt}, acceptDeadline: ${_this.acceptDeadline}, cancel: ${_this.cancel}, completedAt: ${_this.completedAt}, reviewedAt: ${_this.reviewedAt}, chatId: ${_this.chatId}, version: ${_this.version}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $BookingCopyWith<$Res>  {
  factory $BookingCopyWith(Booking value, $Res Function(Booking) _then) = _$BookingCopyWithImpl;
@useResult
$Res call({
 String id, String customerId, String photographerId, String serviceId, BookingServiceSnapshot serviceSnapshot, String day, String start, String end, BookingPlace place, String? note, BookingStatus status, int deposit, int remaining, EscrowStatus? escrowStatus, int? depositRefunded, String? depositProvider, DateTime? depositPaidAt, DateTime? depositRefundedAt, DateTime? acceptDeadline, BookingCancel? cancel, DateTime? completedAt, DateTime? reviewedAt, String? chatId, int version, DateTime createdAt, DateTime updatedAt
});


$BookingServiceSnapshotCopyWith<$Res> get serviceSnapshot;$BookingPlaceCopyWith<$Res> get place;$BookingCancelCopyWith<$Res>? get cancel;

}
/// @nodoc
class _$BookingCopyWithImpl<$Res>
    implements $BookingCopyWith<$Res> {
  _$BookingCopyWithImpl(this._self, this._then);

  final Booking _self;
  final $Res Function(Booking) _then;

/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? customerId = null,Object? photographerId = null,Object? serviceId = null,Object? serviceSnapshot = null,Object? day = null,Object? start = null,Object? end = null,Object? place = null,Object? note = freezed,Object? status = null,Object? deposit = null,Object? remaining = null,Object? escrowStatus = freezed,Object? depositRefunded = freezed,Object? depositProvider = freezed,Object? depositPaidAt = freezed,Object? depositRefundedAt = freezed,Object? acceptDeadline = freezed,Object? cancel = freezed,Object? completedAt = freezed,Object? reviewedAt = freezed,Object? chatId = freezed,Object? version = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(Booking(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,photographerId: null == photographerId ? _self.photographerId : photographerId // ignore: cast_nullable_to_non_nullable
as String,serviceId: null == serviceId ? _self.serviceId : serviceId // ignore: cast_nullable_to_non_nullable
as String,serviceSnapshot: null == serviceSnapshot ? _self.serviceSnapshot : serviceSnapshot // ignore: cast_nullable_to_non_nullable
as BookingServiceSnapshot,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as String,place: null == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as BookingPlace,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BookingStatus,deposit: null == deposit ? _self.deposit : deposit // ignore: cast_nullable_to_non_nullable
as int,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,escrowStatus: freezed == escrowStatus ? _self.escrowStatus : escrowStatus // ignore: cast_nullable_to_non_nullable
as EscrowStatus?,depositRefunded: freezed == depositRefunded ? _self.depositRefunded : depositRefunded // ignore: cast_nullable_to_non_nullable
as int?,depositProvider: freezed == depositProvider ? _self.depositProvider : depositProvider // ignore: cast_nullable_to_non_nullable
as String?,depositPaidAt: freezed == depositPaidAt ? _self.depositPaidAt : depositPaidAt // ignore: cast_nullable_to_non_nullable
as DateTime?,depositRefundedAt: freezed == depositRefundedAt ? _self.depositRefundedAt : depositRefundedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,acceptDeadline: freezed == acceptDeadline ? _self.acceptDeadline : acceptDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,cancel: freezed == cancel ? _self.cancel : cancel // ignore: cast_nullable_to_non_nullable
as BookingCancel?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reviewedAt: freezed == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,chatId: freezed == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String?,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookingServiceSnapshotCopyWith<$Res> get serviceSnapshot {
  
  return $BookingServiceSnapshotCopyWith<$Res>(_self.serviceSnapshot, (value) {
    return _then(_self.copyWith(serviceSnapshot: value));
  });
}/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookingPlaceCopyWith<$Res> get place {
  
  return $BookingPlaceCopyWith<$Res>(_self.place, (value) {
    return _then(_self.copyWith(place: value));
  });
}/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookingCancelCopyWith<$Res>? get cancel {
    if (_self.cancel == null) {
    return null;
  }

  return $BookingCancelCopyWith<$Res>(_self.cancel!, (value) {
    return _then(_self.copyWith(cancel: value));
  });
}
}


/// Adds pattern-matching-related methods to [Booking].
extension BookingPatterns on Booking {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Booking value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Booking() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Booking value)  $default,){
final _that = this;
switch (_that) {
case _Booking():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Booking value)?  $default,){
final _that = this;
switch (_that) {
case _Booking() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String customerId,  String photographerId,  String serviceId,  BookingServiceSnapshot serviceSnapshot,  String day,  String start,  String end,  BookingPlace place,  String? note,  BookingStatus status,  int deposit,  int remaining,  EscrowStatus? escrowStatus,  int? depositRefunded,  String? depositProvider,  DateTime? depositPaidAt,  DateTime? depositRefundedAt,  DateTime? acceptDeadline,  BookingCancel? cancel,  DateTime? completedAt,  DateTime? reviewedAt,  String? chatId,  int version,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Booking() when $default != null:
return $default(_that.id,_that.customerId,_that.photographerId,_that.serviceId,_that.serviceSnapshot,_that.day,_that.start,_that.end,_that.place,_that.note,_that.status,_that.deposit,_that.remaining,_that.escrowStatus,_that.depositRefunded,_that.depositProvider,_that.depositPaidAt,_that.depositRefundedAt,_that.acceptDeadline,_that.cancel,_that.completedAt,_that.reviewedAt,_that.chatId,_that.version,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String customerId,  String photographerId,  String serviceId,  BookingServiceSnapshot serviceSnapshot,  String day,  String start,  String end,  BookingPlace place,  String? note,  BookingStatus status,  int deposit,  int remaining,  EscrowStatus? escrowStatus,  int? depositRefunded,  String? depositProvider,  DateTime? depositPaidAt,  DateTime? depositRefundedAt,  DateTime? acceptDeadline,  BookingCancel? cancel,  DateTime? completedAt,  DateTime? reviewedAt,  String? chatId,  int version,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Booking():
return $default(_that.id,_that.customerId,_that.photographerId,_that.serviceId,_that.serviceSnapshot,_that.day,_that.start,_that.end,_that.place,_that.note,_that.status,_that.deposit,_that.remaining,_that.escrowStatus,_that.depositRefunded,_that.depositProvider,_that.depositPaidAt,_that.depositRefundedAt,_that.acceptDeadline,_that.cancel,_that.completedAt,_that.reviewedAt,_that.chatId,_that.version,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String customerId,  String photographerId,  String serviceId,  BookingServiceSnapshot serviceSnapshot,  String day,  String start,  String end,  BookingPlace place,  String? note,  BookingStatus status,  int deposit,  int remaining,  EscrowStatus? escrowStatus,  int? depositRefunded,  String? depositProvider,  DateTime? depositPaidAt,  DateTime? depositRefundedAt,  DateTime? acceptDeadline,  BookingCancel? cancel,  DateTime? completedAt,  DateTime? reviewedAt,  String? chatId,  int version,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Booking() when $default != null:
return $default(_that.id,_that.customerId,_that.photographerId,_that.serviceId,_that.serviceSnapshot,_that.day,_that.start,_that.end,_that.place,_that.note,_that.status,_that.deposit,_that.remaining,_that.escrowStatus,_that.depositRefunded,_that.depositProvider,_that.depositPaidAt,_that.depositRefundedAt,_that.acceptDeadline,_that.cancel,_that.completedAt,_that.reviewedAt,_that.chatId,_that.version,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Booking extends Booking {
  const _Booking({required this.id, required this.customerId, required this.photographerId, required this.serviceId, required this.serviceSnapshot, required this.day, required this.start, required this.end, required this.place, this.note, required this.status, required this.deposit, required this.remaining, this.escrowStatus, this.depositRefunded, this.depositProvider, this.depositPaidAt, this.depositRefundedAt, this.acceptDeadline, this.cancel, this.completedAt, this.reviewedAt, this.chatId, this.version = 1, required this.createdAt, required this.updatedAt}): super._();
  factory _Booking.fromJson(Map<String, dynamic> json) => _$BookingFromJson(json);

@override final  String id;
@override final  String customerId;
@override final  String photographerId;
@override final  String serviceId;
@override final  BookingServiceSnapshot serviceSnapshot;
@override final  String day;
@override final  String start;
@override final  String end;
@override final  BookingPlace place;
@override final  String? note;
@override final  BookingStatus status;
@override final  int deposit;
@override final  int remaining;
@override final  EscrowStatus? escrowStatus;
@override final  int? depositRefunded;
@override final  String? depositProvider;
@override final  DateTime? depositPaidAt;
@override final  DateTime? depositRefundedAt;
@override final  DateTime? acceptDeadline;
@override final  BookingCancel? cancel;
@override final  DateTime? completedAt;
@override final  DateTime? reviewedAt;
@override final  String? chatId;
@override@JsonKey() final  int version;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookingCopyWith<_Booking> get copyWith => __$BookingCopyWithImpl<_Booking>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookingToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Booking&&(identical(other.id, id) || other.id == id)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.photographerId, photographerId) || other.photographerId == photographerId)&&(identical(other.serviceId, serviceId) || other.serviceId == serviceId)&&(identical(other.serviceSnapshot, serviceSnapshot) || other.serviceSnapshot == serviceSnapshot)&&(identical(other.day, day) || other.day == day)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.place, place) || other.place == place)&&(identical(other.note, note) || other.note == note)&&(identical(other.status, status) || other.status == status)&&(identical(other.deposit, deposit) || other.deposit == deposit)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.escrowStatus, escrowStatus) || other.escrowStatus == escrowStatus)&&(identical(other.depositRefunded, depositRefunded) || other.depositRefunded == depositRefunded)&&(identical(other.depositProvider, depositProvider) || other.depositProvider == depositProvider)&&(identical(other.depositPaidAt, depositPaidAt) || other.depositPaidAt == depositPaidAt)&&(identical(other.depositRefundedAt, depositRefundedAt) || other.depositRefundedAt == depositRefundedAt)&&(identical(other.acceptDeadline, acceptDeadline) || other.acceptDeadline == acceptDeadline)&&(identical(other.cancel, cancel) || other.cancel == cancel)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.reviewedAt, reviewedAt) || other.reviewedAt == reviewedAt)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.version, version) || other.version == version)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,customerId,photographerId,serviceId,serviceSnapshot,day,start,end,place,note,status,deposit,remaining,escrowStatus,depositRefunded,depositProvider,depositPaidAt,depositRefundedAt,acceptDeadline,cancel,completedAt,reviewedAt,chatId,version,createdAt,updatedAt]);
}

@override
String toString() {
    return 'Booking(id: $id, customerId: $customerId, photographerId: $photographerId, serviceId: $serviceId, serviceSnapshot: $serviceSnapshot, day: $day, start: $start, end: $end, place: $place, note: $note, status: $status, deposit: $deposit, remaining: $remaining, escrowStatus: $escrowStatus, depositRefunded: $depositRefunded, depositProvider: $depositProvider, depositPaidAt: $depositPaidAt, depositRefundedAt: $depositRefundedAt, acceptDeadline: $acceptDeadline, cancel: $cancel, completedAt: $completedAt, reviewedAt: $reviewedAt, chatId: $chatId, version: $version, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$BookingCopyWith<$Res> implements $BookingCopyWith<$Res> {
  factory _$BookingCopyWith(_Booking value, $Res Function(_Booking) _then) = __$BookingCopyWithImpl;
@override @useResult
$Res call({
 String id, String customerId, String photographerId, String serviceId, BookingServiceSnapshot serviceSnapshot, String day, String start, String end, BookingPlace place, String? note, BookingStatus status, int deposit, int remaining, EscrowStatus? escrowStatus, int? depositRefunded, String? depositProvider, DateTime? depositPaidAt, DateTime? depositRefundedAt, DateTime? acceptDeadline, BookingCancel? cancel, DateTime? completedAt, DateTime? reviewedAt, String? chatId, int version, DateTime createdAt, DateTime updatedAt
});


@override $BookingServiceSnapshotCopyWith<$Res> get serviceSnapshot;@override $BookingPlaceCopyWith<$Res> get place;@override $BookingCancelCopyWith<$Res>? get cancel;

}
/// @nodoc
class __$BookingCopyWithImpl<$Res>
    implements _$BookingCopyWith<$Res> {
  __$BookingCopyWithImpl(this._self, this._then);

  final _Booking _self;
  final $Res Function(_Booking) _then;

/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? customerId = null,Object? photographerId = null,Object? serviceId = null,Object? serviceSnapshot = null,Object? day = null,Object? start = null,Object? end = null,Object? place = null,Object? note = freezed,Object? status = null,Object? deposit = null,Object? remaining = null,Object? escrowStatus = freezed,Object? depositRefunded = freezed,Object? depositProvider = freezed,Object? depositPaidAt = freezed,Object? depositRefundedAt = freezed,Object? acceptDeadline = freezed,Object? cancel = freezed,Object? completedAt = freezed,Object? reviewedAt = freezed,Object? chatId = freezed,Object? version = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Booking(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,photographerId: null == photographerId ? _self.photographerId : photographerId // ignore: cast_nullable_to_non_nullable
as String,serviceId: null == serviceId ? _self.serviceId : serviceId // ignore: cast_nullable_to_non_nullable
as String,serviceSnapshot: null == serviceSnapshot ? _self.serviceSnapshot : serviceSnapshot // ignore: cast_nullable_to_non_nullable
as BookingServiceSnapshot,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as String,place: null == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as BookingPlace,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BookingStatus,deposit: null == deposit ? _self.deposit : deposit // ignore: cast_nullable_to_non_nullable
as int,remaining: null == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int,escrowStatus: freezed == escrowStatus ? _self.escrowStatus : escrowStatus // ignore: cast_nullable_to_non_nullable
as EscrowStatus?,depositRefunded: freezed == depositRefunded ? _self.depositRefunded : depositRefunded // ignore: cast_nullable_to_non_nullable
as int?,depositProvider: freezed == depositProvider ? _self.depositProvider : depositProvider // ignore: cast_nullable_to_non_nullable
as String?,depositPaidAt: freezed == depositPaidAt ? _self.depositPaidAt : depositPaidAt // ignore: cast_nullable_to_non_nullable
as DateTime?,depositRefundedAt: freezed == depositRefundedAt ? _self.depositRefundedAt : depositRefundedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,acceptDeadline: freezed == acceptDeadline ? _self.acceptDeadline : acceptDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,cancel: freezed == cancel ? _self.cancel : cancel // ignore: cast_nullable_to_non_nullable
as BookingCancel?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reviewedAt: freezed == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,chatId: freezed == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String?,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookingServiceSnapshotCopyWith<$Res> get serviceSnapshot {
  
  return $BookingServiceSnapshotCopyWith<$Res>(_self.serviceSnapshot, (value) {
    return _then(_self.copyWith(serviceSnapshot: value));
  });
}/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookingPlaceCopyWith<$Res> get place {
  
  return $BookingPlaceCopyWith<$Res>(_self.place, (value) {
    return _then(_self.copyWith(place: value));
  });
}/// Create a copy of Booking
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookingCancelCopyWith<$Res>? get cancel {
    if (_self.cancel == null) {
    return null;
  }

  return $BookingCancelCopyWith<$Res>(_self.cancel!, (value) {
    return _then(_self.copyWith(cancel: value));
  });
}
}

// dart format on
