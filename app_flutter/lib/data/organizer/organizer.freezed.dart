// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organizer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Organizer {

 String get id; String get name; String get bio; String? get avatarUrl; OrganizerStatus get status; bool get phoneVerified; bool get businessVerified; bool get payoutAccountOk; List<String> get managedSpotIds; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Organizer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizerCopyWith<Organizer> get copyWith => _$OrganizerCopyWithImpl<Organizer>(this as Organizer, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Organizer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Organizer&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.bio, _this.bio) || other.bio == _this.bio)&&(identical(other.avatarUrl, _this.avatarUrl) || other.avatarUrl == _this.avatarUrl)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.phoneVerified, _this.phoneVerified) || other.phoneVerified == _this.phoneVerified)&&(identical(other.businessVerified, _this.businessVerified) || other.businessVerified == _this.businessVerified)&&(identical(other.payoutAccountOk, _this.payoutAccountOk) || other.payoutAccountOk == _this.payoutAccountOk)&&const DeepCollectionEquality().equals(other.managedSpotIds, _this.managedSpotIds)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}


@override
int get hashCode {
  final _this = this as Organizer;
  return Object.hash(runtimeType,_this.id,_this.name,_this.bio,_this.avatarUrl,_this.status,_this.phoneVerified,_this.businessVerified,_this.payoutAccountOk,const DeepCollectionEquality().hash(_this.managedSpotIds),_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as Organizer;
  return 'Organizer(id: ${_this.id}, name: ${_this.name}, bio: ${_this.bio}, avatarUrl: ${_this.avatarUrl}, status: ${_this.status}, phoneVerified: ${_this.phoneVerified}, businessVerified: ${_this.businessVerified}, payoutAccountOk: ${_this.payoutAccountOk}, managedSpotIds: ${_this.managedSpotIds}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $OrganizerCopyWith<$Res>  {
  factory $OrganizerCopyWith(Organizer value, $Res Function(Organizer) _then) = _$OrganizerCopyWithImpl;
@useResult
$Res call({
 String id, String name, String bio, String? avatarUrl, OrganizerStatus status, bool phoneVerified, bool businessVerified, bool payoutAccountOk, List<String> managedSpotIds, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$OrganizerCopyWithImpl<$Res>
    implements $OrganizerCopyWith<$Res> {
  _$OrganizerCopyWithImpl(this._self, this._then);

  final Organizer _self;
  final $Res Function(Organizer) _then;

/// Create a copy of Organizer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? bio = null,Object? avatarUrl = freezed,Object? status = null,Object? phoneVerified = null,Object? businessVerified = null,Object? payoutAccountOk = null,Object? managedSpotIds = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(Organizer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,bio: null == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrganizerStatus,phoneVerified: null == phoneVerified ? _self.phoneVerified : phoneVerified // ignore: cast_nullable_to_non_nullable
as bool,businessVerified: null == businessVerified ? _self.businessVerified : businessVerified // ignore: cast_nullable_to_non_nullable
as bool,payoutAccountOk: null == payoutAccountOk ? _self.payoutAccountOk : payoutAccountOk // ignore: cast_nullable_to_non_nullable
as bool,managedSpotIds: null == managedSpotIds ? _self.managedSpotIds : managedSpotIds // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Organizer].
extension OrganizerPatterns on Organizer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Organizer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Organizer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Organizer value)  $default,){
final _that = this;
switch (_that) {
case _Organizer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Organizer value)?  $default,){
final _that = this;
switch (_that) {
case _Organizer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String bio,  String? avatarUrl,  OrganizerStatus status,  bool phoneVerified,  bool businessVerified,  bool payoutAccountOk,  List<String> managedSpotIds,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Organizer() when $default != null:
return $default(_that.id,_that.name,_that.bio,_that.avatarUrl,_that.status,_that.phoneVerified,_that.businessVerified,_that.payoutAccountOk,_that.managedSpotIds,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String bio,  String? avatarUrl,  OrganizerStatus status,  bool phoneVerified,  bool businessVerified,  bool payoutAccountOk,  List<String> managedSpotIds,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Organizer():
return $default(_that.id,_that.name,_that.bio,_that.avatarUrl,_that.status,_that.phoneVerified,_that.businessVerified,_that.payoutAccountOk,_that.managedSpotIds,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String bio,  String? avatarUrl,  OrganizerStatus status,  bool phoneVerified,  bool businessVerified,  bool payoutAccountOk,  List<String> managedSpotIds,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Organizer() when $default != null:
return $default(_that.id,_that.name,_that.bio,_that.avatarUrl,_that.status,_that.phoneVerified,_that.businessVerified,_that.payoutAccountOk,_that.managedSpotIds,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Organizer extends Organizer {
  const _Organizer({required this.id, required this.name, this.bio = '', this.avatarUrl, required this.status, this.phoneVerified = false, this.businessVerified = false, this.payoutAccountOk = false,  List<String> managedSpotIds = const <String>[], required this.createdAt, required this.updatedAt}): _managedSpotIds = managedSpotIds,super._();
  

@override final  String id;
@override final  String name;
@override@JsonKey() final  String bio;
@override final  String? avatarUrl;
@override final  OrganizerStatus status;
@override@JsonKey() final  bool phoneVerified;
@override@JsonKey() final  bool businessVerified;
@override@JsonKey() final  bool payoutAccountOk;
 final  List<String> _managedSpotIds;
@override@JsonKey() List<String> get managedSpotIds {
  if (_managedSpotIds is EqualUnmodifiableListView) return _managedSpotIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_managedSpotIds);
}

@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Organizer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizerCopyWith<_Organizer> get copyWith => __$OrganizerCopyWithImpl<_Organizer>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Organizer&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.status, status) || other.status == status)&&(identical(other.phoneVerified, phoneVerified) || other.phoneVerified == phoneVerified)&&(identical(other.businessVerified, businessVerified) || other.businessVerified == businessVerified)&&(identical(other.payoutAccountOk, payoutAccountOk) || other.payoutAccountOk == payoutAccountOk)&&const DeepCollectionEquality().equals(other.managedSpotIds, _managedSpotIds)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,bio,avatarUrl,status,phoneVerified,businessVerified,payoutAccountOk,const DeepCollectionEquality().hash(_managedSpotIds),createdAt,updatedAt);
}

@override
String toString() {
    return 'Organizer(id: $id, name: $name, bio: $bio, avatarUrl: $avatarUrl, status: $status, phoneVerified: $phoneVerified, businessVerified: $businessVerified, payoutAccountOk: $payoutAccountOk, managedSpotIds: $managedSpotIds, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$OrganizerCopyWith<$Res> implements $OrganizerCopyWith<$Res> {
  factory _$OrganizerCopyWith(_Organizer value, $Res Function(_Organizer) _then) = __$OrganizerCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String bio, String? avatarUrl, OrganizerStatus status, bool phoneVerified, bool businessVerified, bool payoutAccountOk, List<String> managedSpotIds, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$OrganizerCopyWithImpl<$Res>
    implements _$OrganizerCopyWith<$Res> {
  __$OrganizerCopyWithImpl(this._self, this._then);

  final _Organizer _self;
  final $Res Function(_Organizer) _then;

/// Create a copy of Organizer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? bio = null,Object? avatarUrl = freezed,Object? status = null,Object? phoneVerified = null,Object? businessVerified = null,Object? payoutAccountOk = null,Object? managedSpotIds = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Organizer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,bio: null == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as OrganizerStatus,phoneVerified: null == phoneVerified ? _self.phoneVerified : phoneVerified // ignore: cast_nullable_to_non_nullable
as bool,businessVerified: null == businessVerified ? _self.businessVerified : businessVerified // ignore: cast_nullable_to_non_nullable
as bool,payoutAccountOk: null == payoutAccountOk ? _self.payoutAccountOk : payoutAccountOk // ignore: cast_nullable_to_non_nullable
as bool,managedSpotIds: null == managedSpotIds ? _self._managedSpotIds : managedSpotIds // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$OpenHours {

 String get start; String get end;
/// Create a copy of OpenHours
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenHoursCopyWith<OpenHours> get copyWith => _$OpenHoursCopyWithImpl<OpenHours>(this as OpenHours, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as OpenHours;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenHours&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.end, _this.end) || other.end == _this.end));
}


@override
int get hashCode {
  final _this = this as OpenHours;
  return Object.hash(runtimeType,_this.start,_this.end);
}

@override
String toString() {
  final _this = this as OpenHours;
  return 'OpenHours(start: ${_this.start}, end: ${_this.end})';
}


}

/// @nodoc
abstract mixin class $OpenHoursCopyWith<$Res>  {
  factory $OpenHoursCopyWith(OpenHours value, $Res Function(OpenHours) _then) = _$OpenHoursCopyWithImpl;
@useResult
$Res call({
 String start, String end
});




}
/// @nodoc
class _$OpenHoursCopyWithImpl<$Res>
    implements $OpenHoursCopyWith<$Res> {
  _$OpenHoursCopyWithImpl(this._self, this._then);

  final OpenHours _self;
  final $Res Function(OpenHours) _then;

/// Create a copy of OpenHours
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? start = null,Object? end = null,}) {
  return _then(OpenHours(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OpenHours].
extension OpenHoursPatterns on OpenHours {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OpenHours value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OpenHours() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OpenHours value)  $default,){
final _that = this;
switch (_that) {
case _OpenHours():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OpenHours value)?  $default,){
final _that = this;
switch (_that) {
case _OpenHours() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String start,  String end)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OpenHours() when $default != null:
return $default(_that.start,_that.end);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String start,  String end)  $default,) {final _that = this;
switch (_that) {
case _OpenHours():
return $default(_that.start,_that.end);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String start,  String end)?  $default,) {final _that = this;
switch (_that) {
case _OpenHours() when $default != null:
return $default(_that.start,_that.end);case _:
  return null;

}
}

}

/// @nodoc


class _OpenHours extends OpenHours {
  const _OpenHours({required this.start, required this.end}): super._();
  

@override final  String start;
@override final  String end;

/// Create a copy of OpenHours
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenHoursCopyWith<_OpenHours> get copyWith => __$OpenHoursCopyWithImpl<_OpenHours>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenHours&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end));
}


@override
int get hashCode {
    return Object.hash(runtimeType,start,end);
}

@override
String toString() {
    return 'OpenHours(start: $start, end: $end)';
}


}

/// @nodoc
abstract mixin class _$OpenHoursCopyWith<$Res> implements $OpenHoursCopyWith<$Res> {
  factory _$OpenHoursCopyWith(_OpenHours value, $Res Function(_OpenHours) _then) = __$OpenHoursCopyWithImpl;
@override @useResult
$Res call({
 String start, String end
});




}
/// @nodoc
class __$OpenHoursCopyWithImpl<$Res>
    implements _$OpenHoursCopyWith<$Res> {
  __$OpenHoursCopyWithImpl(this._self, this._then);

  final _OpenHours _self;
  final $Res Function(_OpenHours) _then;

/// Create a copy of OpenHours
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? start = null,Object? end = null,}) {
  return _then(_OpenHours(
start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String,end: null == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$AccessFee {

 String get label; int get amountVnd;
/// Create a copy of AccessFee
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccessFeeCopyWith<AccessFee> get copyWith => _$AccessFeeCopyWithImpl<AccessFee>(this as AccessFee, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AccessFee;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccessFee&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.amountVnd, _this.amountVnd) || other.amountVnd == _this.amountVnd));
}


@override
int get hashCode {
  final _this = this as AccessFee;
  return Object.hash(runtimeType,_this.label,_this.amountVnd);
}

@override
String toString() {
  final _this = this as AccessFee;
  return 'AccessFee(label: ${_this.label}, amountVnd: ${_this.amountVnd})';
}


}

/// @nodoc
abstract mixin class $AccessFeeCopyWith<$Res>  {
  factory $AccessFeeCopyWith(AccessFee value, $Res Function(AccessFee) _then) = _$AccessFeeCopyWithImpl;
@useResult
$Res call({
 String label, int amountVnd
});




}
/// @nodoc
class _$AccessFeeCopyWithImpl<$Res>
    implements $AccessFeeCopyWith<$Res> {
  _$AccessFeeCopyWithImpl(this._self, this._then);

  final AccessFee _self;
  final $Res Function(AccessFee) _then;

/// Create a copy of AccessFee
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? amountVnd = null,}) {
  return _then(AccessFee(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,amountVnd: null == amountVnd ? _self.amountVnd : amountVnd // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AccessFee].
extension AccessFeePatterns on AccessFee {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccessFee value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccessFee() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccessFee value)  $default,){
final _that = this;
switch (_that) {
case _AccessFee():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccessFee value)?  $default,){
final _that = this;
switch (_that) {
case _AccessFee() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  int amountVnd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccessFee() when $default != null:
return $default(_that.label,_that.amountVnd);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  int amountVnd)  $default,) {final _that = this;
switch (_that) {
case _AccessFee():
return $default(_that.label,_that.amountVnd);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  int amountVnd)?  $default,) {final _that = this;
switch (_that) {
case _AccessFee() when $default != null:
return $default(_that.label,_that.amountVnd);case _:
  return null;

}
}

}

/// @nodoc


class _AccessFee extends AccessFee {
  const _AccessFee({required this.label, required this.amountVnd}): super._();
  

@override final  String label;
@override final  int amountVnd;

/// Create a copy of AccessFee
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccessFeeCopyWith<_AccessFee> get copyWith => __$AccessFeeCopyWithImpl<_AccessFee>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccessFee&&(identical(other.label, label) || other.label == label)&&(identical(other.amountVnd, amountVnd) || other.amountVnd == amountVnd));
}


@override
int get hashCode {
    return Object.hash(runtimeType,label,amountVnd);
}

@override
String toString() {
    return 'AccessFee(label: $label, amountVnd: $amountVnd)';
}


}

/// @nodoc
abstract mixin class _$AccessFeeCopyWith<$Res> implements $AccessFeeCopyWith<$Res> {
  factory _$AccessFeeCopyWith(_AccessFee value, $Res Function(_AccessFee) _then) = __$AccessFeeCopyWithImpl;
@override @useResult
$Res call({
 String label, int amountVnd
});




}
/// @nodoc
class __$AccessFeeCopyWithImpl<$Res>
    implements _$AccessFeeCopyWith<$Res> {
  __$AccessFeeCopyWithImpl(this._self, this._then);

  final _AccessFee _self;
  final $Res Function(_AccessFee) _then;

/// Create a copy of AccessFee
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? amountVnd = null,}) {
  return _then(_AccessFee(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,amountVnd: null == amountVnd ? _self.amountVnd : amountVnd // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$SpotAccess {

 SpotAccessType get type; List<AccessFee> get fees; String get note; DateTime? get updatedAt; SpotAccessSource? get source;
/// Create a copy of SpotAccess
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpotAccessCopyWith<SpotAccess> get copyWith => _$SpotAccessCopyWithImpl<SpotAccess>(this as SpotAccess, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SpotAccess;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpotAccess&&(identical(other.type, _this.type) || other.type == _this.type)&&const DeepCollectionEquality().equals(other.fees, _this.fees)&&(identical(other.note, _this.note) || other.note == _this.note)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.source, _this.source) || other.source == _this.source));
}


@override
int get hashCode {
  final _this = this as SpotAccess;
  return Object.hash(runtimeType,_this.type,const DeepCollectionEquality().hash(_this.fees),_this.note,_this.updatedAt,_this.source);
}

@override
String toString() {
  final _this = this as SpotAccess;
  return 'SpotAccess(type: ${_this.type}, fees: ${_this.fees}, note: ${_this.note}, updatedAt: ${_this.updatedAt}, source: ${_this.source})';
}


}

/// @nodoc
abstract mixin class $SpotAccessCopyWith<$Res>  {
  factory $SpotAccessCopyWith(SpotAccess value, $Res Function(SpotAccess) _then) = _$SpotAccessCopyWithImpl;
@useResult
$Res call({
 SpotAccessType type, List<AccessFee> fees, String note, DateTime? updatedAt, SpotAccessSource? source
});




}
/// @nodoc
class _$SpotAccessCopyWithImpl<$Res>
    implements $SpotAccessCopyWith<$Res> {
  _$SpotAccessCopyWithImpl(this._self, this._then);

  final SpotAccess _self;
  final $Res Function(SpotAccess) _then;

/// Create a copy of SpotAccess
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? fees = null,Object? note = null,Object? updatedAt = freezed,Object? source = freezed,}) {
  return _then(SpotAccess(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SpotAccessType,fees: null == fees ? _self.fees : fees // ignore: cast_nullable_to_non_nullable
as List<AccessFee>,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as SpotAccessSource?,
  ));
}

}


/// Adds pattern-matching-related methods to [SpotAccess].
extension SpotAccessPatterns on SpotAccess {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpotAccess value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpotAccess() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpotAccess value)  $default,){
final _that = this;
switch (_that) {
case _SpotAccess():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpotAccess value)?  $default,){
final _that = this;
switch (_that) {
case _SpotAccess() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SpotAccessType type,  List<AccessFee> fees,  String note,  DateTime? updatedAt,  SpotAccessSource? source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpotAccess() when $default != null:
return $default(_that.type,_that.fees,_that.note,_that.updatedAt,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SpotAccessType type,  List<AccessFee> fees,  String note,  DateTime? updatedAt,  SpotAccessSource? source)  $default,) {final _that = this;
switch (_that) {
case _SpotAccess():
return $default(_that.type,_that.fees,_that.note,_that.updatedAt,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SpotAccessType type,  List<AccessFee> fees,  String note,  DateTime? updatedAt,  SpotAccessSource? source)?  $default,) {final _that = this;
switch (_that) {
case _SpotAccess() when $default != null:
return $default(_that.type,_that.fees,_that.note,_that.updatedAt,_that.source);case _:
  return null;

}
}

}

/// @nodoc


class _SpotAccess extends SpotAccess {
  const _SpotAccess({required this.type,  List<AccessFee> fees = const <AccessFee>[], this.note = '', this.updatedAt, this.source}): _fees = fees,super._();
  

@override final  SpotAccessType type;
 final  List<AccessFee> _fees;
@override@JsonKey() List<AccessFee> get fees {
  if (_fees is EqualUnmodifiableListView) return _fees;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_fees);
}

@override@JsonKey() final  String note;
@override final  DateTime? updatedAt;
@override final  SpotAccessSource? source;

/// Create a copy of SpotAccess
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpotAccessCopyWith<_SpotAccess> get copyWith => __$SpotAccessCopyWithImpl<_SpotAccess>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpotAccess&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.fees, _fees)&&(identical(other.note, note) || other.note == note)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode {
    return Object.hash(runtimeType,type,const DeepCollectionEquality().hash(_fees),note,updatedAt,source);
}

@override
String toString() {
    return 'SpotAccess(type: $type, fees: $fees, note: $note, updatedAt: $updatedAt, source: $source)';
}


}

/// @nodoc
abstract mixin class _$SpotAccessCopyWith<$Res> implements $SpotAccessCopyWith<$Res> {
  factory _$SpotAccessCopyWith(_SpotAccess value, $Res Function(_SpotAccess) _then) = __$SpotAccessCopyWithImpl;
@override @useResult
$Res call({
 SpotAccessType type, List<AccessFee> fees, String note, DateTime? updatedAt, SpotAccessSource? source
});




}
/// @nodoc
class __$SpotAccessCopyWithImpl<$Res>
    implements _$SpotAccessCopyWith<$Res> {
  __$SpotAccessCopyWithImpl(this._self, this._then);

  final _SpotAccess _self;
  final $Res Function(_SpotAccess) _then;

/// Create a copy of SpotAccess
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? fees = null,Object? note = null,Object? updatedAt = freezed,Object? source = freezed,}) {
  return _then(_SpotAccess(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as SpotAccessType,fees: null == fees ? _self._fees : fees // ignore: cast_nullable_to_non_nullable
as List<AccessFee>,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as SpotAccessSource?,
  ));
}


}

/// @nodoc
mixin _$Resident {

 String get providerId; bool get waivesProvider; bool get waivesGuests; int? get maxGuests;/// Last valid Vietnam day `yyyy-MM-dd`; null = no end.
 String? get validUntil; DateTime? get addedAt; String? get addedBy;
/// Create a copy of Resident
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResidentCopyWith<Resident> get copyWith => _$ResidentCopyWithImpl<Resident>(this as Resident, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Resident;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Resident&&(identical(other.providerId, _this.providerId) || other.providerId == _this.providerId)&&(identical(other.waivesProvider, _this.waivesProvider) || other.waivesProvider == _this.waivesProvider)&&(identical(other.waivesGuests, _this.waivesGuests) || other.waivesGuests == _this.waivesGuests)&&(identical(other.maxGuests, _this.maxGuests) || other.maxGuests == _this.maxGuests)&&(identical(other.validUntil, _this.validUntil) || other.validUntil == _this.validUntil)&&(identical(other.addedAt, _this.addedAt) || other.addedAt == _this.addedAt)&&(identical(other.addedBy, _this.addedBy) || other.addedBy == _this.addedBy));
}


@override
int get hashCode {
  final _this = this as Resident;
  return Object.hash(runtimeType,_this.providerId,_this.waivesProvider,_this.waivesGuests,_this.maxGuests,_this.validUntil,_this.addedAt,_this.addedBy);
}

@override
String toString() {
  final _this = this as Resident;
  return 'Resident(providerId: ${_this.providerId}, waivesProvider: ${_this.waivesProvider}, waivesGuests: ${_this.waivesGuests}, maxGuests: ${_this.maxGuests}, validUntil: ${_this.validUntil}, addedAt: ${_this.addedAt}, addedBy: ${_this.addedBy})';
}


}

/// @nodoc
abstract mixin class $ResidentCopyWith<$Res>  {
  factory $ResidentCopyWith(Resident value, $Res Function(Resident) _then) = _$ResidentCopyWithImpl;
@useResult
$Res call({
 String providerId, bool waivesProvider, bool waivesGuests, int? maxGuests, String? validUntil, DateTime? addedAt, String? addedBy
});




}
/// @nodoc
class _$ResidentCopyWithImpl<$Res>
    implements $ResidentCopyWith<$Res> {
  _$ResidentCopyWithImpl(this._self, this._then);

  final Resident _self;
  final $Res Function(Resident) _then;

/// Create a copy of Resident
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? providerId = null,Object? waivesProvider = null,Object? waivesGuests = null,Object? maxGuests = freezed,Object? validUntil = freezed,Object? addedAt = freezed,Object? addedBy = freezed,}) {
  return _then(Resident(
providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,waivesProvider: null == waivesProvider ? _self.waivesProvider : waivesProvider // ignore: cast_nullable_to_non_nullable
as bool,waivesGuests: null == waivesGuests ? _self.waivesGuests : waivesGuests // ignore: cast_nullable_to_non_nullable
as bool,maxGuests: freezed == maxGuests ? _self.maxGuests : maxGuests // ignore: cast_nullable_to_non_nullable
as int?,validUntil: freezed == validUntil ? _self.validUntil : validUntil // ignore: cast_nullable_to_non_nullable
as String?,addedAt: freezed == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,addedBy: freezed == addedBy ? _self.addedBy : addedBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Resident].
extension ResidentPatterns on Resident {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Resident value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Resident() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Resident value)  $default,){
final _that = this;
switch (_that) {
case _Resident():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Resident value)?  $default,){
final _that = this;
switch (_that) {
case _Resident() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String providerId,  bool waivesProvider,  bool waivesGuests,  int? maxGuests,  String? validUntil,  DateTime? addedAt,  String? addedBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Resident() when $default != null:
return $default(_that.providerId,_that.waivesProvider,_that.waivesGuests,_that.maxGuests,_that.validUntil,_that.addedAt,_that.addedBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String providerId,  bool waivesProvider,  bool waivesGuests,  int? maxGuests,  String? validUntil,  DateTime? addedAt,  String? addedBy)  $default,) {final _that = this;
switch (_that) {
case _Resident():
return $default(_that.providerId,_that.waivesProvider,_that.waivesGuests,_that.maxGuests,_that.validUntil,_that.addedAt,_that.addedBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String providerId,  bool waivesProvider,  bool waivesGuests,  int? maxGuests,  String? validUntil,  DateTime? addedAt,  String? addedBy)?  $default,) {final _that = this;
switch (_that) {
case _Resident() when $default != null:
return $default(_that.providerId,_that.waivesProvider,_that.waivesGuests,_that.maxGuests,_that.validUntil,_that.addedAt,_that.addedBy);case _:
  return null;

}
}

}

/// @nodoc


class _Resident extends Resident {
  const _Resident({required this.providerId, required this.waivesProvider, required this.waivesGuests, this.maxGuests, this.validUntil, this.addedAt, this.addedBy}): super._();
  

@override final  String providerId;
@override final  bool waivesProvider;
@override final  bool waivesGuests;
@override final  int? maxGuests;
/// Last valid Vietnam day `yyyy-MM-dd`; null = no end.
@override final  String? validUntil;
@override final  DateTime? addedAt;
@override final  String? addedBy;

/// Create a copy of Resident
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResidentCopyWith<_Resident> get copyWith => __$ResidentCopyWithImpl<_Resident>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Resident&&(identical(other.providerId, providerId) || other.providerId == providerId)&&(identical(other.waivesProvider, waivesProvider) || other.waivesProvider == waivesProvider)&&(identical(other.waivesGuests, waivesGuests) || other.waivesGuests == waivesGuests)&&(identical(other.maxGuests, maxGuests) || other.maxGuests == maxGuests)&&(identical(other.validUntil, validUntil) || other.validUntil == validUntil)&&(identical(other.addedAt, addedAt) || other.addedAt == addedAt)&&(identical(other.addedBy, addedBy) || other.addedBy == addedBy));
}


@override
int get hashCode {
    return Object.hash(runtimeType,providerId,waivesProvider,waivesGuests,maxGuests,validUntil,addedAt,addedBy);
}

@override
String toString() {
    return 'Resident(providerId: $providerId, waivesProvider: $waivesProvider, waivesGuests: $waivesGuests, maxGuests: $maxGuests, validUntil: $validUntil, addedAt: $addedAt, addedBy: $addedBy)';
}


}

/// @nodoc
abstract mixin class _$ResidentCopyWith<$Res> implements $ResidentCopyWith<$Res> {
  factory _$ResidentCopyWith(_Resident value, $Res Function(_Resident) _then) = __$ResidentCopyWithImpl;
@override @useResult
$Res call({
 String providerId, bool waivesProvider, bool waivesGuests, int? maxGuests, String? validUntil, DateTime? addedAt, String? addedBy
});




}
/// @nodoc
class __$ResidentCopyWithImpl<$Res>
    implements _$ResidentCopyWith<$Res> {
  __$ResidentCopyWithImpl(this._self, this._then);

  final _Resident _self;
  final $Res Function(_Resident) _then;

/// Create a copy of Resident
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providerId = null,Object? waivesProvider = null,Object? waivesGuests = null,Object? maxGuests = freezed,Object? validUntil = freezed,Object? addedAt = freezed,Object? addedBy = freezed,}) {
  return _then(_Resident(
providerId: null == providerId ? _self.providerId : providerId // ignore: cast_nullable_to_non_nullable
as String,waivesProvider: null == waivesProvider ? _self.waivesProvider : waivesProvider // ignore: cast_nullable_to_non_nullable
as bool,waivesGuests: null == waivesGuests ? _self.waivesGuests : waivesGuests // ignore: cast_nullable_to_non_nullable
as bool,maxGuests: freezed == maxGuests ? _self.maxGuests : maxGuests // ignore: cast_nullable_to_non_nullable
as int?,validUntil: freezed == validUntil ? _self.validUntil : validUntil // ignore: cast_nullable_to_non_nullable
as String?,addedAt: freezed == addedAt ? _self.addedAt : addedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,addedBy: freezed == addedBy ? _self.addedBy : addedBy // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$GateStaff {

 String get organizerId; String get staffUid; GateStaffStatus get status; DateTime get invitedAt; DateTime? get respondedAt;/// `scansToday {day, count}`: the count belongs to [scansDay] only.
 String? get scansDay; int get scansCount;
/// Create a copy of GateStaff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GateStaffCopyWith<GateStaff> get copyWith => _$GateStaffCopyWithImpl<GateStaff>(this as GateStaff, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GateStaff;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GateStaff&&(identical(other.organizerId, _this.organizerId) || other.organizerId == _this.organizerId)&&(identical(other.staffUid, _this.staffUid) || other.staffUid == _this.staffUid)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.invitedAt, _this.invitedAt) || other.invitedAt == _this.invitedAt)&&(identical(other.respondedAt, _this.respondedAt) || other.respondedAt == _this.respondedAt)&&(identical(other.scansDay, _this.scansDay) || other.scansDay == _this.scansDay)&&(identical(other.scansCount, _this.scansCount) || other.scansCount == _this.scansCount));
}


@override
int get hashCode {
  final _this = this as GateStaff;
  return Object.hash(runtimeType,_this.organizerId,_this.staffUid,_this.status,_this.invitedAt,_this.respondedAt,_this.scansDay,_this.scansCount);
}

@override
String toString() {
  final _this = this as GateStaff;
  return 'GateStaff(organizerId: ${_this.organizerId}, staffUid: ${_this.staffUid}, status: ${_this.status}, invitedAt: ${_this.invitedAt}, respondedAt: ${_this.respondedAt}, scansDay: ${_this.scansDay}, scansCount: ${_this.scansCount})';
}


}

/// @nodoc
abstract mixin class $GateStaffCopyWith<$Res>  {
  factory $GateStaffCopyWith(GateStaff value, $Res Function(GateStaff) _then) = _$GateStaffCopyWithImpl;
@useResult
$Res call({
 String organizerId, String staffUid, GateStaffStatus status, DateTime invitedAt, DateTime? respondedAt, String? scansDay, int scansCount
});




}
/// @nodoc
class _$GateStaffCopyWithImpl<$Res>
    implements $GateStaffCopyWith<$Res> {
  _$GateStaffCopyWithImpl(this._self, this._then);

  final GateStaff _self;
  final $Res Function(GateStaff) _then;

/// Create a copy of GateStaff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? organizerId = null,Object? staffUid = null,Object? status = null,Object? invitedAt = null,Object? respondedAt = freezed,Object? scansDay = freezed,Object? scansCount = null,}) {
  return _then(GateStaff(
organizerId: null == organizerId ? _self.organizerId : organizerId // ignore: cast_nullable_to_non_nullable
as String,staffUid: null == staffUid ? _self.staffUid : staffUid // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as GateStaffStatus,invitedAt: null == invitedAt ? _self.invitedAt : invitedAt // ignore: cast_nullable_to_non_nullable
as DateTime,respondedAt: freezed == respondedAt ? _self.respondedAt : respondedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,scansDay: freezed == scansDay ? _self.scansDay : scansDay // ignore: cast_nullable_to_non_nullable
as String?,scansCount: null == scansCount ? _self.scansCount : scansCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [GateStaff].
extension GateStaffPatterns on GateStaff {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GateStaff value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GateStaff() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GateStaff value)  $default,){
final _that = this;
switch (_that) {
case _GateStaff():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GateStaff value)?  $default,){
final _that = this;
switch (_that) {
case _GateStaff() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String organizerId,  String staffUid,  GateStaffStatus status,  DateTime invitedAt,  DateTime? respondedAt,  String? scansDay,  int scansCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GateStaff() when $default != null:
return $default(_that.organizerId,_that.staffUid,_that.status,_that.invitedAt,_that.respondedAt,_that.scansDay,_that.scansCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String organizerId,  String staffUid,  GateStaffStatus status,  DateTime invitedAt,  DateTime? respondedAt,  String? scansDay,  int scansCount)  $default,) {final _that = this;
switch (_that) {
case _GateStaff():
return $default(_that.organizerId,_that.staffUid,_that.status,_that.invitedAt,_that.respondedAt,_that.scansDay,_that.scansCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String organizerId,  String staffUid,  GateStaffStatus status,  DateTime invitedAt,  DateTime? respondedAt,  String? scansDay,  int scansCount)?  $default,) {final _that = this;
switch (_that) {
case _GateStaff() when $default != null:
return $default(_that.organizerId,_that.staffUid,_that.status,_that.invitedAt,_that.respondedAt,_that.scansDay,_that.scansCount);case _:
  return null;

}
}

}

/// @nodoc


class _GateStaff extends GateStaff {
  const _GateStaff({required this.organizerId, required this.staffUid, required this.status, required this.invitedAt, this.respondedAt, this.scansDay, this.scansCount = 0}): super._();
  

@override final  String organizerId;
@override final  String staffUid;
@override final  GateStaffStatus status;
@override final  DateTime invitedAt;
@override final  DateTime? respondedAt;
/// `scansToday {day, count}`: the count belongs to [scansDay] only.
@override final  String? scansDay;
@override@JsonKey() final  int scansCount;

/// Create a copy of GateStaff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GateStaffCopyWith<_GateStaff> get copyWith => __$GateStaffCopyWithImpl<_GateStaff>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GateStaff&&(identical(other.organizerId, organizerId) || other.organizerId == organizerId)&&(identical(other.staffUid, staffUid) || other.staffUid == staffUid)&&(identical(other.status, status) || other.status == status)&&(identical(other.invitedAt, invitedAt) || other.invitedAt == invitedAt)&&(identical(other.respondedAt, respondedAt) || other.respondedAt == respondedAt)&&(identical(other.scansDay, scansDay) || other.scansDay == scansDay)&&(identical(other.scansCount, scansCount) || other.scansCount == scansCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,organizerId,staffUid,status,invitedAt,respondedAt,scansDay,scansCount);
}

@override
String toString() {
    return 'GateStaff(organizerId: $organizerId, staffUid: $staffUid, status: $status, invitedAt: $invitedAt, respondedAt: $respondedAt, scansDay: $scansDay, scansCount: $scansCount)';
}


}

/// @nodoc
abstract mixin class _$GateStaffCopyWith<$Res> implements $GateStaffCopyWith<$Res> {
  factory _$GateStaffCopyWith(_GateStaff value, $Res Function(_GateStaff) _then) = __$GateStaffCopyWithImpl;
@override @useResult
$Res call({
 String organizerId, String staffUid, GateStaffStatus status, DateTime invitedAt, DateTime? respondedAt, String? scansDay, int scansCount
});




}
/// @nodoc
class __$GateStaffCopyWithImpl<$Res>
    implements _$GateStaffCopyWith<$Res> {
  __$GateStaffCopyWithImpl(this._self, this._then);

  final _GateStaff _self;
  final $Res Function(_GateStaff) _then;

/// Create a copy of GateStaff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? organizerId = null,Object? staffUid = null,Object? status = null,Object? invitedAt = null,Object? respondedAt = freezed,Object? scansDay = freezed,Object? scansCount = null,}) {
  return _then(_GateStaff(
organizerId: null == organizerId ? _self.organizerId : organizerId // ignore: cast_nullable_to_non_nullable
as String,staffUid: null == staffUid ? _self.staffUid : staffUid // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as GateStaffStatus,invitedAt: null == invitedAt ? _self.invitedAt : invitedAt // ignore: cast_nullable_to_non_nullable
as DateTime,respondedAt: freezed == respondedAt ? _self.respondedAt : respondedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,scansDay: freezed == scansDay ? _self.scansDay : scansDay // ignore: cast_nullable_to_non_nullable
as String?,scansCount: null == scansCount ? _self.scansCount : scansCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$SpotProposal {

 String get name; String get address;
/// Create a copy of SpotProposal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpotProposalCopyWith<SpotProposal> get copyWith => _$SpotProposalCopyWithImpl<SpotProposal>(this as SpotProposal, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SpotProposal;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpotProposal&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.address, _this.address) || other.address == _this.address));
}


@override
int get hashCode {
  final _this = this as SpotProposal;
  return Object.hash(runtimeType,_this.name,_this.address);
}

@override
String toString() {
  final _this = this as SpotProposal;
  return 'SpotProposal(name: ${_this.name}, address: ${_this.address})';
}


}

/// @nodoc
abstract mixin class $SpotProposalCopyWith<$Res>  {
  factory $SpotProposalCopyWith(SpotProposal value, $Res Function(SpotProposal) _then) = _$SpotProposalCopyWithImpl;
@useResult
$Res call({
 String name, String address
});




}
/// @nodoc
class _$SpotProposalCopyWithImpl<$Res>
    implements $SpotProposalCopyWith<$Res> {
  _$SpotProposalCopyWithImpl(this._self, this._then);

  final SpotProposal _self;
  final $Res Function(SpotProposal) _then;

/// Create a copy of SpotProposal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? address = null,}) {
  return _then(SpotProposal(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SpotProposal].
extension SpotProposalPatterns on SpotProposal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpotProposal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpotProposal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpotProposal value)  $default,){
final _that = this;
switch (_that) {
case _SpotProposal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpotProposal value)?  $default,){
final _that = this;
switch (_that) {
case _SpotProposal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String address)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpotProposal() when $default != null:
return $default(_that.name,_that.address);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String address)  $default,) {final _that = this;
switch (_that) {
case _SpotProposal():
return $default(_that.name,_that.address);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String address)?  $default,) {final _that = this;
switch (_that) {
case _SpotProposal() when $default != null:
return $default(_that.name,_that.address);case _:
  return null;

}
}

}

/// @nodoc


class _SpotProposal extends SpotProposal {
  const _SpotProposal({required this.name, required this.address}): super._();
  

@override final  String name;
@override final  String address;

/// Create a copy of SpotProposal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpotProposalCopyWith<_SpotProposal> get copyWith => __$SpotProposalCopyWithImpl<_SpotProposal>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpotProposal&&(identical(other.name, name) || other.name == name)&&(identical(other.address, address) || other.address == address));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,address);
}

@override
String toString() {
    return 'SpotProposal(name: $name, address: $address)';
}


}

/// @nodoc
abstract mixin class _$SpotProposalCopyWith<$Res> implements $SpotProposalCopyWith<$Res> {
  factory _$SpotProposalCopyWith(_SpotProposal value, $Res Function(_SpotProposal) _then) = __$SpotProposalCopyWithImpl;
@override @useResult
$Res call({
 String name, String address
});




}
/// @nodoc
class __$SpotProposalCopyWithImpl<$Res>
    implements _$SpotProposalCopyWith<$Res> {
  __$SpotProposalCopyWithImpl(this._self, this._then);

  final _SpotProposal _self;
  final $Res Function(_SpotProposal) _then;

/// Create a copy of SpotProposal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? address = null,}) {
  return _then(_SpotProposal(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$SpotClaim {

 String get id;/// Null for a proposal.
 String? get spotId; SpotProposal? get proposal; String get organizerId; SpotClaimStatus get status; List<String> get proofPaths; String get note; String? get reason; DateTime get createdAt; DateTime? get reviewedAt;
/// Create a copy of SpotClaim
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpotClaimCopyWith<SpotClaim> get copyWith => _$SpotClaimCopyWithImpl<SpotClaim>(this as SpotClaim, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SpotClaim;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpotClaim&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.spotId, _this.spotId) || other.spotId == _this.spotId)&&(identical(other.proposal, _this.proposal) || other.proposal == _this.proposal)&&(identical(other.organizerId, _this.organizerId) || other.organizerId == _this.organizerId)&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.proofPaths, _this.proofPaths)&&(identical(other.note, _this.note) || other.note == _this.note)&&(identical(other.reason, _this.reason) || other.reason == _this.reason)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.reviewedAt, _this.reviewedAt) || other.reviewedAt == _this.reviewedAt));
}


@override
int get hashCode {
  final _this = this as SpotClaim;
  return Object.hash(runtimeType,_this.id,_this.spotId,_this.proposal,_this.organizerId,_this.status,const DeepCollectionEquality().hash(_this.proofPaths),_this.note,_this.reason,_this.createdAt,_this.reviewedAt);
}

@override
String toString() {
  final _this = this as SpotClaim;
  return 'SpotClaim(id: ${_this.id}, spotId: ${_this.spotId}, proposal: ${_this.proposal}, organizerId: ${_this.organizerId}, status: ${_this.status}, proofPaths: ${_this.proofPaths}, note: ${_this.note}, reason: ${_this.reason}, createdAt: ${_this.createdAt}, reviewedAt: ${_this.reviewedAt})';
}


}

/// @nodoc
abstract mixin class $SpotClaimCopyWith<$Res>  {
  factory $SpotClaimCopyWith(SpotClaim value, $Res Function(SpotClaim) _then) = _$SpotClaimCopyWithImpl;
@useResult
$Res call({
 String id, String? spotId, SpotProposal? proposal, String organizerId, SpotClaimStatus status, List<String> proofPaths, String note, String? reason, DateTime createdAt, DateTime? reviewedAt
});


$SpotProposalCopyWith<$Res>? get proposal;

}
/// @nodoc
class _$SpotClaimCopyWithImpl<$Res>
    implements $SpotClaimCopyWith<$Res> {
  _$SpotClaimCopyWithImpl(this._self, this._then);

  final SpotClaim _self;
  final $Res Function(SpotClaim) _then;

/// Create a copy of SpotClaim
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? spotId = freezed,Object? proposal = freezed,Object? organizerId = null,Object? status = null,Object? proofPaths = null,Object? note = null,Object? reason = freezed,Object? createdAt = null,Object? reviewedAt = freezed,}) {
  return _then(SpotClaim(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,spotId: freezed == spotId ? _self.spotId : spotId // ignore: cast_nullable_to_non_nullable
as String?,proposal: freezed == proposal ? _self.proposal : proposal // ignore: cast_nullable_to_non_nullable
as SpotProposal?,organizerId: null == organizerId ? _self.organizerId : organizerId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SpotClaimStatus,proofPaths: null == proofPaths ? _self.proofPaths : proofPaths // ignore: cast_nullable_to_non_nullable
as List<String>,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,reviewedAt: freezed == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of SpotClaim
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpotProposalCopyWith<$Res>? get proposal {
    if (_self.proposal == null) {
    return null;
  }

  return $SpotProposalCopyWith<$Res>(_self.proposal!, (value) {
    return _then(_self.copyWith(proposal: value));
  });
}
}


/// Adds pattern-matching-related methods to [SpotClaim].
extension SpotClaimPatterns on SpotClaim {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpotClaim value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpotClaim() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpotClaim value)  $default,){
final _that = this;
switch (_that) {
case _SpotClaim():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpotClaim value)?  $default,){
final _that = this;
switch (_that) {
case _SpotClaim() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? spotId,  SpotProposal? proposal,  String organizerId,  SpotClaimStatus status,  List<String> proofPaths,  String note,  String? reason,  DateTime createdAt,  DateTime? reviewedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpotClaim() when $default != null:
return $default(_that.id,_that.spotId,_that.proposal,_that.organizerId,_that.status,_that.proofPaths,_that.note,_that.reason,_that.createdAt,_that.reviewedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? spotId,  SpotProposal? proposal,  String organizerId,  SpotClaimStatus status,  List<String> proofPaths,  String note,  String? reason,  DateTime createdAt,  DateTime? reviewedAt)  $default,) {final _that = this;
switch (_that) {
case _SpotClaim():
return $default(_that.id,_that.spotId,_that.proposal,_that.organizerId,_that.status,_that.proofPaths,_that.note,_that.reason,_that.createdAt,_that.reviewedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? spotId,  SpotProposal? proposal,  String organizerId,  SpotClaimStatus status,  List<String> proofPaths,  String note,  String? reason,  DateTime createdAt,  DateTime? reviewedAt)?  $default,) {final _that = this;
switch (_that) {
case _SpotClaim() when $default != null:
return $default(_that.id,_that.spotId,_that.proposal,_that.organizerId,_that.status,_that.proofPaths,_that.note,_that.reason,_that.createdAt,_that.reviewedAt);case _:
  return null;

}
}

}

/// @nodoc


class _SpotClaim implements SpotClaim {
  const _SpotClaim({required this.id, this.spotId, this.proposal, required this.organizerId, required this.status,  List<String> proofPaths = const <String>[], this.note = '', this.reason, required this.createdAt, this.reviewedAt}): _proofPaths = proofPaths;
  

@override final  String id;
/// Null for a proposal.
@override final  String? spotId;
@override final  SpotProposal? proposal;
@override final  String organizerId;
@override final  SpotClaimStatus status;
 final  List<String> _proofPaths;
@override@JsonKey() List<String> get proofPaths {
  if (_proofPaths is EqualUnmodifiableListView) return _proofPaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_proofPaths);
}

@override@JsonKey() final  String note;
@override final  String? reason;
@override final  DateTime createdAt;
@override final  DateTime? reviewedAt;

/// Create a copy of SpotClaim
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpotClaimCopyWith<_SpotClaim> get copyWith => __$SpotClaimCopyWithImpl<_SpotClaim>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpotClaim&&(identical(other.id, id) || other.id == id)&&(identical(other.spotId, spotId) || other.spotId == spotId)&&(identical(other.proposal, proposal) || other.proposal == proposal)&&(identical(other.organizerId, organizerId) || other.organizerId == organizerId)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.proofPaths, _proofPaths)&&(identical(other.note, note) || other.note == note)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.reviewedAt, reviewedAt) || other.reviewedAt == reviewedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,spotId,proposal,organizerId,status,const DeepCollectionEquality().hash(_proofPaths),note,reason,createdAt,reviewedAt);
}

@override
String toString() {
    return 'SpotClaim(id: $id, spotId: $spotId, proposal: $proposal, organizerId: $organizerId, status: $status, proofPaths: $proofPaths, note: $note, reason: $reason, createdAt: $createdAt, reviewedAt: $reviewedAt)';
}


}

/// @nodoc
abstract mixin class _$SpotClaimCopyWith<$Res> implements $SpotClaimCopyWith<$Res> {
  factory _$SpotClaimCopyWith(_SpotClaim value, $Res Function(_SpotClaim) _then) = __$SpotClaimCopyWithImpl;
@override @useResult
$Res call({
 String id, String? spotId, SpotProposal? proposal, String organizerId, SpotClaimStatus status, List<String> proofPaths, String note, String? reason, DateTime createdAt, DateTime? reviewedAt
});


@override $SpotProposalCopyWith<$Res>? get proposal;

}
/// @nodoc
class __$SpotClaimCopyWithImpl<$Res>
    implements _$SpotClaimCopyWith<$Res> {
  __$SpotClaimCopyWithImpl(this._self, this._then);

  final _SpotClaim _self;
  final $Res Function(_SpotClaim) _then;

/// Create a copy of SpotClaim
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? spotId = freezed,Object? proposal = freezed,Object? organizerId = null,Object? status = null,Object? proofPaths = null,Object? note = null,Object? reason = freezed,Object? createdAt = null,Object? reviewedAt = freezed,}) {
  return _then(_SpotClaim(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,spotId: freezed == spotId ? _self.spotId : spotId // ignore: cast_nullable_to_non_nullable
as String?,proposal: freezed == proposal ? _self.proposal : proposal // ignore: cast_nullable_to_non_nullable
as SpotProposal?,organizerId: null == organizerId ? _self.organizerId : organizerId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SpotClaimStatus,proofPaths: null == proofPaths ? _self._proofPaths : proofPaths // ignore: cast_nullable_to_non_nullable
as List<String>,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,reviewedAt: freezed == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of SpotClaim
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpotProposalCopyWith<$Res>? get proposal {
    if (_self.proposal == null) {
    return null;
  }

  return $SpotProposalCopyWith<$Res>(_self.proposal!, (value) {
    return _then(_self.copyWith(proposal: value));
  });
}
}

/// @nodoc
mixin _$EntryTicketType {

 String get id; String get name; int get price; bool get hidden;
/// Create a copy of EntryTicketType
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntryTicketTypeCopyWith<EntryTicketType> get copyWith => _$EntryTicketTypeCopyWithImpl<EntryTicketType>(this as EntryTicketType, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as EntryTicketType;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntryTicketType&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.price, _this.price) || other.price == _this.price)&&(identical(other.hidden, _this.hidden) || other.hidden == _this.hidden));
}


@override
int get hashCode {
  final _this = this as EntryTicketType;
  return Object.hash(runtimeType,_this.id,_this.name,_this.price,_this.hidden);
}

@override
String toString() {
  final _this = this as EntryTicketType;
  return 'EntryTicketType(id: ${_this.id}, name: ${_this.name}, price: ${_this.price}, hidden: ${_this.hidden})';
}


}

/// @nodoc
abstract mixin class $EntryTicketTypeCopyWith<$Res>  {
  factory $EntryTicketTypeCopyWith(EntryTicketType value, $Res Function(EntryTicketType) _then) = _$EntryTicketTypeCopyWithImpl;
@useResult
$Res call({
 String id, String name, int price, bool hidden
});




}
/// @nodoc
class _$EntryTicketTypeCopyWithImpl<$Res>
    implements $EntryTicketTypeCopyWith<$Res> {
  _$EntryTicketTypeCopyWithImpl(this._self, this._then);

  final EntryTicketType _self;
  final $Res Function(EntryTicketType) _then;

/// Create a copy of EntryTicketType
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? price = null,Object? hidden = null,}) {
  return _then(EntryTicketType(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as int,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [EntryTicketType].
extension EntryTicketTypePatterns on EntryTicketType {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntryTicketType value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntryTicketType() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntryTicketType value)  $default,){
final _that = this;
switch (_that) {
case _EntryTicketType():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntryTicketType value)?  $default,){
final _that = this;
switch (_that) {
case _EntryTicketType() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  int price,  bool hidden)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntryTicketType() when $default != null:
return $default(_that.id,_that.name,_that.price,_that.hidden);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  int price,  bool hidden)  $default,) {final _that = this;
switch (_that) {
case _EntryTicketType():
return $default(_that.id,_that.name,_that.price,_that.hidden);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  int price,  bool hidden)?  $default,) {final _that = this;
switch (_that) {
case _EntryTicketType() when $default != null:
return $default(_that.id,_that.name,_that.price,_that.hidden);case _:
  return null;

}
}

}

/// @nodoc


class _EntryTicketType extends EntryTicketType {
  const _EntryTicketType({required this.id, required this.name, required this.price, this.hidden = false}): super._();
  

@override final  String id;
@override final  String name;
@override final  int price;
@override@JsonKey() final  bool hidden;

/// Create a copy of EntryTicketType
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntryTicketTypeCopyWith<_EntryTicketType> get copyWith => __$EntryTicketTypeCopyWithImpl<_EntryTicketType>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntryTicketType&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.price, price) || other.price == price)&&(identical(other.hidden, hidden) || other.hidden == hidden));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,price,hidden);
}

@override
String toString() {
    return 'EntryTicketType(id: $id, name: $name, price: $price, hidden: $hidden)';
}


}

/// @nodoc
abstract mixin class _$EntryTicketTypeCopyWith<$Res> implements $EntryTicketTypeCopyWith<$Res> {
  factory _$EntryTicketTypeCopyWith(_EntryTicketType value, $Res Function(_EntryTicketType) _then) = __$EntryTicketTypeCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, int price, bool hidden
});




}
/// @nodoc
class __$EntryTicketTypeCopyWithImpl<$Res>
    implements _$EntryTicketTypeCopyWith<$Res> {
  __$EntryTicketTypeCopyWithImpl(this._self, this._then);

  final _EntryTicketType _self;
  final $Res Function(_EntryTicketType) _then;

/// Create a copy of EntryTicketType
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? price = null,Object? hidden = null,}) {
  return _then(_EntryTicketType(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as int,hidden: null == hidden ? _self.hidden : hidden // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$EntryItem {

 String get ticketTypeId; int get qty;
/// Create a copy of EntryItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntryItemCopyWith<EntryItem> get copyWith => _$EntryItemCopyWithImpl<EntryItem>(this as EntryItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as EntryItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntryItem&&(identical(other.ticketTypeId, _this.ticketTypeId) || other.ticketTypeId == _this.ticketTypeId)&&(identical(other.qty, _this.qty) || other.qty == _this.qty));
}


@override
int get hashCode {
  final _this = this as EntryItem;
  return Object.hash(runtimeType,_this.ticketTypeId,_this.qty);
}

@override
String toString() {
  final _this = this as EntryItem;
  return 'EntryItem(ticketTypeId: ${_this.ticketTypeId}, qty: ${_this.qty})';
}


}

/// @nodoc
abstract mixin class $EntryItemCopyWith<$Res>  {
  factory $EntryItemCopyWith(EntryItem value, $Res Function(EntryItem) _then) = _$EntryItemCopyWithImpl;
@useResult
$Res call({
 String ticketTypeId, int qty
});




}
/// @nodoc
class _$EntryItemCopyWithImpl<$Res>
    implements $EntryItemCopyWith<$Res> {
  _$EntryItemCopyWithImpl(this._self, this._then);

  final EntryItem _self;
  final $Res Function(EntryItem) _then;

/// Create a copy of EntryItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ticketTypeId = null,Object? qty = null,}) {
  return _then(EntryItem(
ticketTypeId: null == ticketTypeId ? _self.ticketTypeId : ticketTypeId // ignore: cast_nullable_to_non_nullable
as String,qty: null == qty ? _self.qty : qty // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [EntryItem].
extension EntryItemPatterns on EntryItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntryItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntryItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntryItem value)  $default,){
final _that = this;
switch (_that) {
case _EntryItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntryItem value)?  $default,){
final _that = this;
switch (_that) {
case _EntryItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ticketTypeId,  int qty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntryItem() when $default != null:
return $default(_that.ticketTypeId,_that.qty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ticketTypeId,  int qty)  $default,) {final _that = this;
switch (_that) {
case _EntryItem():
return $default(_that.ticketTypeId,_that.qty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ticketTypeId,  int qty)?  $default,) {final _that = this;
switch (_that) {
case _EntryItem() when $default != null:
return $default(_that.ticketTypeId,_that.qty);case _:
  return null;

}
}

}

/// @nodoc


class _EntryItem extends EntryItem {
  const _EntryItem({required this.ticketTypeId, required this.qty}): super._();
  

@override final  String ticketTypeId;
@override final  int qty;

/// Create a copy of EntryItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntryItemCopyWith<_EntryItem> get copyWith => __$EntryItemCopyWithImpl<_EntryItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntryItem&&(identical(other.ticketTypeId, ticketTypeId) || other.ticketTypeId == ticketTypeId)&&(identical(other.qty, qty) || other.qty == qty));
}


@override
int get hashCode {
    return Object.hash(runtimeType,ticketTypeId,qty);
}

@override
String toString() {
    return 'EntryItem(ticketTypeId: $ticketTypeId, qty: $qty)';
}


}

/// @nodoc
abstract mixin class _$EntryItemCopyWith<$Res> implements $EntryItemCopyWith<$Res> {
  factory _$EntryItemCopyWith(_EntryItem value, $Res Function(_EntryItem) _then) = __$EntryItemCopyWithImpl;
@override @useResult
$Res call({
 String ticketTypeId, int qty
});




}
/// @nodoc
class __$EntryItemCopyWithImpl<$Res>
    implements _$EntryItemCopyWith<$Res> {
  __$EntryItemCopyWithImpl(this._self, this._then);

  final _EntryItem _self;
  final $Res Function(_EntryItem) _then;

/// Create a copy of EntryItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ticketTypeId = null,Object? qty = null,}) {
  return _then(_EntryItem(
ticketTypeId: null == ticketTypeId ? _self.ticketTypeId : ticketTypeId // ignore: cast_nullable_to_non_nullable
as String,qty: null == qty ? _self.qty : qty // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$EntryLine {

 String get ticketTypeId; String get name; int get price; int get qty;
/// Create a copy of EntryLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntryLineCopyWith<EntryLine> get copyWith => _$EntryLineCopyWithImpl<EntryLine>(this as EntryLine, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as EntryLine;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntryLine&&(identical(other.ticketTypeId, _this.ticketTypeId) || other.ticketTypeId == _this.ticketTypeId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.price, _this.price) || other.price == _this.price)&&(identical(other.qty, _this.qty) || other.qty == _this.qty));
}


@override
int get hashCode {
  final _this = this as EntryLine;
  return Object.hash(runtimeType,_this.ticketTypeId,_this.name,_this.price,_this.qty);
}

@override
String toString() {
  final _this = this as EntryLine;
  return 'EntryLine(ticketTypeId: ${_this.ticketTypeId}, name: ${_this.name}, price: ${_this.price}, qty: ${_this.qty})';
}


}

/// @nodoc
abstract mixin class $EntryLineCopyWith<$Res>  {
  factory $EntryLineCopyWith(EntryLine value, $Res Function(EntryLine) _then) = _$EntryLineCopyWithImpl;
@useResult
$Res call({
 String ticketTypeId, String name, int price, int qty
});




}
/// @nodoc
class _$EntryLineCopyWithImpl<$Res>
    implements $EntryLineCopyWith<$Res> {
  _$EntryLineCopyWithImpl(this._self, this._then);

  final EntryLine _self;
  final $Res Function(EntryLine) _then;

/// Create a copy of EntryLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ticketTypeId = null,Object? name = null,Object? price = null,Object? qty = null,}) {
  return _then(EntryLine(
ticketTypeId: null == ticketTypeId ? _self.ticketTypeId : ticketTypeId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as int,qty: null == qty ? _self.qty : qty // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [EntryLine].
extension EntryLinePatterns on EntryLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntryLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntryLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntryLine value)  $default,){
final _that = this;
switch (_that) {
case _EntryLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntryLine value)?  $default,){
final _that = this;
switch (_that) {
case _EntryLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ticketTypeId,  String name,  int price,  int qty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntryLine() when $default != null:
return $default(_that.ticketTypeId,_that.name,_that.price,_that.qty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ticketTypeId,  String name,  int price,  int qty)  $default,) {final _that = this;
switch (_that) {
case _EntryLine():
return $default(_that.ticketTypeId,_that.name,_that.price,_that.qty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ticketTypeId,  String name,  int price,  int qty)?  $default,) {final _that = this;
switch (_that) {
case _EntryLine() when $default != null:
return $default(_that.ticketTypeId,_that.name,_that.price,_that.qty);case _:
  return null;

}
}

}

/// @nodoc


class _EntryLine extends EntryLine {
  const _EntryLine({required this.ticketTypeId, required this.name, required this.price, required this.qty}): super._();
  

@override final  String ticketTypeId;
@override final  String name;
@override final  int price;
@override final  int qty;

/// Create a copy of EntryLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntryLineCopyWith<_EntryLine> get copyWith => __$EntryLineCopyWithImpl<_EntryLine>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntryLine&&(identical(other.ticketTypeId, ticketTypeId) || other.ticketTypeId == ticketTypeId)&&(identical(other.name, name) || other.name == name)&&(identical(other.price, price) || other.price == price)&&(identical(other.qty, qty) || other.qty == qty));
}


@override
int get hashCode {
    return Object.hash(runtimeType,ticketTypeId,name,price,qty);
}

@override
String toString() {
    return 'EntryLine(ticketTypeId: $ticketTypeId, name: $name, price: $price, qty: $qty)';
}


}

/// @nodoc
abstract mixin class _$EntryLineCopyWith<$Res> implements $EntryLineCopyWith<$Res> {
  factory _$EntryLineCopyWith(_EntryLine value, $Res Function(_EntryLine) _then) = __$EntryLineCopyWithImpl;
@override @useResult
$Res call({
 String ticketTypeId, String name, int price, int qty
});




}
/// @nodoc
class __$EntryLineCopyWithImpl<$Res>
    implements _$EntryLineCopyWith<$Res> {
  __$EntryLineCopyWithImpl(this._self, this._then);

  final _EntryLine _self;
  final $Res Function(_EntryLine) _then;

/// Create a copy of EntryLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ticketTypeId = null,Object? name = null,Object? price = null,Object? qty = null,}) {
  return _then(_EntryLine(
ticketTypeId: null == ticketTypeId ? _self.ticketTypeId : ticketTypeId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as int,qty: null == qty ? _self.qty : qty // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$EntryEvent {

 String get id; String get title; String get spotId; String get organizerId; String get organizerName; EventStatus get status; String get startDay; String get endDay; List<int> get closedWeekdays; List<String> get closedDays; OpenHours get openHours; List<EntryTicketType> get ticketTypes; int? get dailyCapacity; int get refundCutoffHours;
/// Create a copy of EntryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntryEventCopyWith<EntryEvent> get copyWith => _$EntryEventCopyWithImpl<EntryEvent>(this as EntryEvent, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as EntryEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntryEvent&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.spotId, _this.spotId) || other.spotId == _this.spotId)&&(identical(other.organizerId, _this.organizerId) || other.organizerId == _this.organizerId)&&(identical(other.organizerName, _this.organizerName) || other.organizerName == _this.organizerName)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.startDay, _this.startDay) || other.startDay == _this.startDay)&&(identical(other.endDay, _this.endDay) || other.endDay == _this.endDay)&&const DeepCollectionEquality().equals(other.closedWeekdays, _this.closedWeekdays)&&const DeepCollectionEquality().equals(other.closedDays, _this.closedDays)&&(identical(other.openHours, _this.openHours) || other.openHours == _this.openHours)&&const DeepCollectionEquality().equals(other.ticketTypes, _this.ticketTypes)&&(identical(other.dailyCapacity, _this.dailyCapacity) || other.dailyCapacity == _this.dailyCapacity)&&(identical(other.refundCutoffHours, _this.refundCutoffHours) || other.refundCutoffHours == _this.refundCutoffHours));
}


@override
int get hashCode {
  final _this = this as EntryEvent;
  return Object.hash(runtimeType,_this.id,_this.title,_this.spotId,_this.organizerId,_this.organizerName,_this.status,_this.startDay,_this.endDay,const DeepCollectionEquality().hash(_this.closedWeekdays),const DeepCollectionEquality().hash(_this.closedDays),_this.openHours,const DeepCollectionEquality().hash(_this.ticketTypes),_this.dailyCapacity,_this.refundCutoffHours);
}

@override
String toString() {
  final _this = this as EntryEvent;
  return 'EntryEvent(id: ${_this.id}, title: ${_this.title}, spotId: ${_this.spotId}, organizerId: ${_this.organizerId}, organizerName: ${_this.organizerName}, status: ${_this.status}, startDay: ${_this.startDay}, endDay: ${_this.endDay}, closedWeekdays: ${_this.closedWeekdays}, closedDays: ${_this.closedDays}, openHours: ${_this.openHours}, ticketTypes: ${_this.ticketTypes}, dailyCapacity: ${_this.dailyCapacity}, refundCutoffHours: ${_this.refundCutoffHours})';
}


}

/// @nodoc
abstract mixin class $EntryEventCopyWith<$Res>  {
  factory $EntryEventCopyWith(EntryEvent value, $Res Function(EntryEvent) _then) = _$EntryEventCopyWithImpl;
@useResult
$Res call({
 String id, String title, String spotId, String organizerId, String organizerName, EventStatus status, String startDay, String endDay, List<int> closedWeekdays, List<String> closedDays, OpenHours openHours, List<EntryTicketType> ticketTypes, int? dailyCapacity, int refundCutoffHours
});


$OpenHoursCopyWith<$Res> get openHours;

}
/// @nodoc
class _$EntryEventCopyWithImpl<$Res>
    implements $EntryEventCopyWith<$Res> {
  _$EntryEventCopyWithImpl(this._self, this._then);

  final EntryEvent _self;
  final $Res Function(EntryEvent) _then;

/// Create a copy of EntryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? spotId = null,Object? organizerId = null,Object? organizerName = null,Object? status = null,Object? startDay = null,Object? endDay = null,Object? closedWeekdays = null,Object? closedDays = null,Object? openHours = null,Object? ticketTypes = null,Object? dailyCapacity = freezed,Object? refundCutoffHours = null,}) {
  return _then(EntryEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,spotId: null == spotId ? _self.spotId : spotId // ignore: cast_nullable_to_non_nullable
as String,organizerId: null == organizerId ? _self.organizerId : organizerId // ignore: cast_nullable_to_non_nullable
as String,organizerName: null == organizerName ? _self.organizerName : organizerName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EventStatus,startDay: null == startDay ? _self.startDay : startDay // ignore: cast_nullable_to_non_nullable
as String,endDay: null == endDay ? _self.endDay : endDay // ignore: cast_nullable_to_non_nullable
as String,closedWeekdays: null == closedWeekdays ? _self.closedWeekdays : closedWeekdays // ignore: cast_nullable_to_non_nullable
as List<int>,closedDays: null == closedDays ? _self.closedDays : closedDays // ignore: cast_nullable_to_non_nullable
as List<String>,openHours: null == openHours ? _self.openHours : openHours // ignore: cast_nullable_to_non_nullable
as OpenHours,ticketTypes: null == ticketTypes ? _self.ticketTypes : ticketTypes // ignore: cast_nullable_to_non_nullable
as List<EntryTicketType>,dailyCapacity: freezed == dailyCapacity ? _self.dailyCapacity : dailyCapacity // ignore: cast_nullable_to_non_nullable
as int?,refundCutoffHours: null == refundCutoffHours ? _self.refundCutoffHours : refundCutoffHours // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of EntryEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OpenHoursCopyWith<$Res> get openHours {
  
  return $OpenHoursCopyWith<$Res>(_self.openHours, (value) {
    return _then(_self.copyWith(openHours: value));
  });
}
}


/// Adds pattern-matching-related methods to [EntryEvent].
extension EntryEventPatterns on EntryEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntryEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntryEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntryEvent value)  $default,){
final _that = this;
switch (_that) {
case _EntryEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntryEvent value)?  $default,){
final _that = this;
switch (_that) {
case _EntryEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String spotId,  String organizerId,  String organizerName,  EventStatus status,  String startDay,  String endDay,  List<int> closedWeekdays,  List<String> closedDays,  OpenHours openHours,  List<EntryTicketType> ticketTypes,  int? dailyCapacity,  int refundCutoffHours)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntryEvent() when $default != null:
return $default(_that.id,_that.title,_that.spotId,_that.organizerId,_that.organizerName,_that.status,_that.startDay,_that.endDay,_that.closedWeekdays,_that.closedDays,_that.openHours,_that.ticketTypes,_that.dailyCapacity,_that.refundCutoffHours);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String spotId,  String organizerId,  String organizerName,  EventStatus status,  String startDay,  String endDay,  List<int> closedWeekdays,  List<String> closedDays,  OpenHours openHours,  List<EntryTicketType> ticketTypes,  int? dailyCapacity,  int refundCutoffHours)  $default,) {final _that = this;
switch (_that) {
case _EntryEvent():
return $default(_that.id,_that.title,_that.spotId,_that.organizerId,_that.organizerName,_that.status,_that.startDay,_that.endDay,_that.closedWeekdays,_that.closedDays,_that.openHours,_that.ticketTypes,_that.dailyCapacity,_that.refundCutoffHours);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String spotId,  String organizerId,  String organizerName,  EventStatus status,  String startDay,  String endDay,  List<int> closedWeekdays,  List<String> closedDays,  OpenHours openHours,  List<EntryTicketType> ticketTypes,  int? dailyCapacity,  int refundCutoffHours)?  $default,) {final _that = this;
switch (_that) {
case _EntryEvent() when $default != null:
return $default(_that.id,_that.title,_that.spotId,_that.organizerId,_that.organizerName,_that.status,_that.startDay,_that.endDay,_that.closedWeekdays,_that.closedDays,_that.openHours,_that.ticketTypes,_that.dailyCapacity,_that.refundCutoffHours);case _:
  return null;

}
}

}

/// @nodoc


class _EntryEvent extends EntryEvent {
  const _EntryEvent({required this.id, required this.title, required this.spotId, required this.organizerId, this.organizerName = '', required this.status, required this.startDay, required this.endDay,  List<int> closedWeekdays = const <int>[],  List<String> closedDays = const <String>[], required this.openHours,  List<EntryTicketType> ticketTypes = const <EntryTicketType>[], this.dailyCapacity, this.refundCutoffHours = 48}): _closedWeekdays = closedWeekdays,_closedDays = closedDays,_ticketTypes = ticketTypes,super._();
  

@override final  String id;
@override final  String title;
@override final  String spotId;
@override final  String organizerId;
@override@JsonKey() final  String organizerName;
@override final  EventStatus status;
@override final  String startDay;
@override final  String endDay;
 final  List<int> _closedWeekdays;
@override@JsonKey() List<int> get closedWeekdays {
  if (_closedWeekdays is EqualUnmodifiableListView) return _closedWeekdays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_closedWeekdays);
}

 final  List<String> _closedDays;
@override@JsonKey() List<String> get closedDays {
  if (_closedDays is EqualUnmodifiableListView) return _closedDays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_closedDays);
}

@override final  OpenHours openHours;
 final  List<EntryTicketType> _ticketTypes;
@override@JsonKey() List<EntryTicketType> get ticketTypes {
  if (_ticketTypes is EqualUnmodifiableListView) return _ticketTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ticketTypes);
}

@override final  int? dailyCapacity;
@override@JsonKey() final  int refundCutoffHours;

/// Create a copy of EntryEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntryEventCopyWith<_EntryEvent> get copyWith => __$EntryEventCopyWithImpl<_EntryEvent>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntryEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.spotId, spotId) || other.spotId == spotId)&&(identical(other.organizerId, organizerId) || other.organizerId == organizerId)&&(identical(other.organizerName, organizerName) || other.organizerName == organizerName)&&(identical(other.status, status) || other.status == status)&&(identical(other.startDay, startDay) || other.startDay == startDay)&&(identical(other.endDay, endDay) || other.endDay == endDay)&&const DeepCollectionEquality().equals(other.closedWeekdays, _closedWeekdays)&&const DeepCollectionEquality().equals(other.closedDays, _closedDays)&&(identical(other.openHours, openHours) || other.openHours == openHours)&&const DeepCollectionEquality().equals(other.ticketTypes, _ticketTypes)&&(identical(other.dailyCapacity, dailyCapacity) || other.dailyCapacity == dailyCapacity)&&(identical(other.refundCutoffHours, refundCutoffHours) || other.refundCutoffHours == refundCutoffHours));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,title,spotId,organizerId,organizerName,status,startDay,endDay,const DeepCollectionEquality().hash(_closedWeekdays),const DeepCollectionEquality().hash(_closedDays),openHours,const DeepCollectionEquality().hash(_ticketTypes),dailyCapacity,refundCutoffHours);
}

@override
String toString() {
    return 'EntryEvent(id: $id, title: $title, spotId: $spotId, organizerId: $organizerId, organizerName: $organizerName, status: $status, startDay: $startDay, endDay: $endDay, closedWeekdays: $closedWeekdays, closedDays: $closedDays, openHours: $openHours, ticketTypes: $ticketTypes, dailyCapacity: $dailyCapacity, refundCutoffHours: $refundCutoffHours)';
}


}

/// @nodoc
abstract mixin class _$EntryEventCopyWith<$Res> implements $EntryEventCopyWith<$Res> {
  factory _$EntryEventCopyWith(_EntryEvent value, $Res Function(_EntryEvent) _then) = __$EntryEventCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String spotId, String organizerId, String organizerName, EventStatus status, String startDay, String endDay, List<int> closedWeekdays, List<String> closedDays, OpenHours openHours, List<EntryTicketType> ticketTypes, int? dailyCapacity, int refundCutoffHours
});


@override $OpenHoursCopyWith<$Res> get openHours;

}
/// @nodoc
class __$EntryEventCopyWithImpl<$Res>
    implements _$EntryEventCopyWith<$Res> {
  __$EntryEventCopyWithImpl(this._self, this._then);

  final _EntryEvent _self;
  final $Res Function(_EntryEvent) _then;

/// Create a copy of EntryEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? spotId = null,Object? organizerId = null,Object? organizerName = null,Object? status = null,Object? startDay = null,Object? endDay = null,Object? closedWeekdays = null,Object? closedDays = null,Object? openHours = null,Object? ticketTypes = null,Object? dailyCapacity = freezed,Object? refundCutoffHours = null,}) {
  return _then(_EntryEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,spotId: null == spotId ? _self.spotId : spotId // ignore: cast_nullable_to_non_nullable
as String,organizerId: null == organizerId ? _self.organizerId : organizerId // ignore: cast_nullable_to_non_nullable
as String,organizerName: null == organizerName ? _self.organizerName : organizerName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as EventStatus,startDay: null == startDay ? _self.startDay : startDay // ignore: cast_nullable_to_non_nullable
as String,endDay: null == endDay ? _self.endDay : endDay // ignore: cast_nullable_to_non_nullable
as String,closedWeekdays: null == closedWeekdays ? _self._closedWeekdays : closedWeekdays // ignore: cast_nullable_to_non_nullable
as List<int>,closedDays: null == closedDays ? _self._closedDays : closedDays // ignore: cast_nullable_to_non_nullable
as List<String>,openHours: null == openHours ? _self.openHours : openHours // ignore: cast_nullable_to_non_nullable
as OpenHours,ticketTypes: null == ticketTypes ? _self._ticketTypes : ticketTypes // ignore: cast_nullable_to_non_nullable
as List<EntryTicketType>,dailyCapacity: freezed == dailyCapacity ? _self.dailyCapacity : dailyCapacity // ignore: cast_nullable_to_non_nullable
as int?,refundCutoffHours: null == refundCutoffHours ? _self.refundCutoffHours : refundCutoffHours // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of EntryEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OpenHoursCopyWith<$Res> get openHours {
  
  return $OpenHoursCopyWith<$Res>(_self.openHours, (value) {
    return _then(_self.copyWith(openHours: value));
  });
}
}

/// @nodoc
mixin _$EntryDay {

 String get eventId; String get day; int get sold; int get held; int get checkedIn; bool get closed;
/// Create a copy of EntryDay
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EntryDayCopyWith<EntryDay> get copyWith => _$EntryDayCopyWithImpl<EntryDay>(this as EntryDay, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as EntryDay;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EntryDay&&(identical(other.eventId, _this.eventId) || other.eventId == _this.eventId)&&(identical(other.day, _this.day) || other.day == _this.day)&&(identical(other.sold, _this.sold) || other.sold == _this.sold)&&(identical(other.held, _this.held) || other.held == _this.held)&&(identical(other.checkedIn, _this.checkedIn) || other.checkedIn == _this.checkedIn)&&(identical(other.closed, _this.closed) || other.closed == _this.closed));
}


@override
int get hashCode {
  final _this = this as EntryDay;
  return Object.hash(runtimeType,_this.eventId,_this.day,_this.sold,_this.held,_this.checkedIn,_this.closed);
}

@override
String toString() {
  final _this = this as EntryDay;
  return 'EntryDay(eventId: ${_this.eventId}, day: ${_this.day}, sold: ${_this.sold}, held: ${_this.held}, checkedIn: ${_this.checkedIn}, closed: ${_this.closed})';
}


}

/// @nodoc
abstract mixin class $EntryDayCopyWith<$Res>  {
  factory $EntryDayCopyWith(EntryDay value, $Res Function(EntryDay) _then) = _$EntryDayCopyWithImpl;
@useResult
$Res call({
 String eventId, String day, int sold, int held, int checkedIn, bool closed
});




}
/// @nodoc
class _$EntryDayCopyWithImpl<$Res>
    implements $EntryDayCopyWith<$Res> {
  _$EntryDayCopyWithImpl(this._self, this._then);

  final EntryDay _self;
  final $Res Function(EntryDay) _then;

/// Create a copy of EntryDay
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? eventId = null,Object? day = null,Object? sold = null,Object? held = null,Object? checkedIn = null,Object? closed = null,}) {
  return _then(EntryDay(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as String,sold: null == sold ? _self.sold : sold // ignore: cast_nullable_to_non_nullable
as int,held: null == held ? _self.held : held // ignore: cast_nullable_to_non_nullable
as int,checkedIn: null == checkedIn ? _self.checkedIn : checkedIn // ignore: cast_nullable_to_non_nullable
as int,closed: null == closed ? _self.closed : closed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [EntryDay].
extension EntryDayPatterns on EntryDay {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EntryDay value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EntryDay() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EntryDay value)  $default,){
final _that = this;
switch (_that) {
case _EntryDay():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EntryDay value)?  $default,){
final _that = this;
switch (_that) {
case _EntryDay() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String eventId,  String day,  int sold,  int held,  int checkedIn,  bool closed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EntryDay() when $default != null:
return $default(_that.eventId,_that.day,_that.sold,_that.held,_that.checkedIn,_that.closed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String eventId,  String day,  int sold,  int held,  int checkedIn,  bool closed)  $default,) {final _that = this;
switch (_that) {
case _EntryDay():
return $default(_that.eventId,_that.day,_that.sold,_that.held,_that.checkedIn,_that.closed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String eventId,  String day,  int sold,  int held,  int checkedIn,  bool closed)?  $default,) {final _that = this;
switch (_that) {
case _EntryDay() when $default != null:
return $default(_that.eventId,_that.day,_that.sold,_that.held,_that.checkedIn,_that.closed);case _:
  return null;

}
}

}

/// @nodoc


class _EntryDay extends EntryDay {
  const _EntryDay({required this.eventId, required this.day, this.sold = 0, this.held = 0, this.checkedIn = 0, this.closed = false}): super._();
  

@override final  String eventId;
@override final  String day;
@override@JsonKey() final  int sold;
@override@JsonKey() final  int held;
@override@JsonKey() final  int checkedIn;
@override@JsonKey() final  bool closed;

/// Create a copy of EntryDay
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EntryDayCopyWith<_EntryDay> get copyWith => __$EntryDayCopyWithImpl<_EntryDay>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EntryDay&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.day, day) || other.day == day)&&(identical(other.sold, sold) || other.sold == sold)&&(identical(other.held, held) || other.held == held)&&(identical(other.checkedIn, checkedIn) || other.checkedIn == checkedIn)&&(identical(other.closed, closed) || other.closed == closed));
}


@override
int get hashCode {
    return Object.hash(runtimeType,eventId,day,sold,held,checkedIn,closed);
}

@override
String toString() {
    return 'EntryDay(eventId: $eventId, day: $day, sold: $sold, held: $held, checkedIn: $checkedIn, closed: $closed)';
}


}

/// @nodoc
abstract mixin class _$EntryDayCopyWith<$Res> implements $EntryDayCopyWith<$Res> {
  factory _$EntryDayCopyWith(_EntryDay value, $Res Function(_EntryDay) _then) = __$EntryDayCopyWithImpl;
@override @useResult
$Res call({
 String eventId, String day, int sold, int held, int checkedIn, bool closed
});




}
/// @nodoc
class __$EntryDayCopyWithImpl<$Res>
    implements _$EntryDayCopyWith<$Res> {
  __$EntryDayCopyWithImpl(this._self, this._then);

  final _EntryDay _self;
  final $Res Function(_EntryDay) _then;

/// Create a copy of EntryDay
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventId = null,Object? day = null,Object? sold = null,Object? held = null,Object? checkedIn = null,Object? closed = null,}) {
  return _then(_EntryDay(
eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as String,sold: null == sold ? _self.sold : sold // ignore: cast_nullable_to_non_nullable
as int,held: null == held ? _self.held : held // ignore: cast_nullable_to_non_nullable
as int,checkedIn: null == checkedIn ? _self.checkedIn : checkedIn // ignore: cast_nullable_to_non_nullable
as int,closed: null == closed ? _self.closed : closed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
