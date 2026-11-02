// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_group.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PaymentGroupLine {

 String get paymentId; PaymentLineKind get kind;/// `booking` or `event_registration`.
 String get subjectType; String get subjectId;/// Who receives this line (the photographer, the venue's organizer, …).
 String get payeeId;/// Integer VND.
 int get amount;
/// Create a copy of PaymentGroupLine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentGroupLineCopyWith<PaymentGroupLine> get copyWith => _$PaymentGroupLineCopyWithImpl<PaymentGroupLine>(this as PaymentGroupLine, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PaymentGroupLine;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentGroupLine&&(identical(other.paymentId, _this.paymentId) || other.paymentId == _this.paymentId)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.subjectType, _this.subjectType) || other.subjectType == _this.subjectType)&&(identical(other.subjectId, _this.subjectId) || other.subjectId == _this.subjectId)&&(identical(other.payeeId, _this.payeeId) || other.payeeId == _this.payeeId)&&(identical(other.amount, _this.amount) || other.amount == _this.amount));
}


@override
int get hashCode {
  final _this = this as PaymentGroupLine;
  return Object.hash(runtimeType,_this.paymentId,_this.kind,_this.subjectType,_this.subjectId,_this.payeeId,_this.amount);
}

@override
String toString() {
  final _this = this as PaymentGroupLine;
  return 'PaymentGroupLine(paymentId: ${_this.paymentId}, kind: ${_this.kind}, subjectType: ${_this.subjectType}, subjectId: ${_this.subjectId}, payeeId: ${_this.payeeId}, amount: ${_this.amount})';
}


}

/// @nodoc
abstract mixin class $PaymentGroupLineCopyWith<$Res>  {
  factory $PaymentGroupLineCopyWith(PaymentGroupLine value, $Res Function(PaymentGroupLine) _then) = _$PaymentGroupLineCopyWithImpl;
@useResult
$Res call({
 String paymentId, PaymentLineKind kind, String subjectType, String subjectId, String payeeId, int amount
});




}
/// @nodoc
class _$PaymentGroupLineCopyWithImpl<$Res>
    implements $PaymentGroupLineCopyWith<$Res> {
  _$PaymentGroupLineCopyWithImpl(this._self, this._then);

  final PaymentGroupLine _self;
  final $Res Function(PaymentGroupLine) _then;

/// Create a copy of PaymentGroupLine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? paymentId = null,Object? kind = null,Object? subjectType = null,Object? subjectId = null,Object? payeeId = null,Object? amount = null,}) {
  return _then(PaymentGroupLine(
paymentId: null == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as PaymentLineKind,subjectType: null == subjectType ? _self.subjectType : subjectType // ignore: cast_nullable_to_non_nullable
as String,subjectId: null == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String,payeeId: null == payeeId ? _self.payeeId : payeeId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentGroupLine].
extension PaymentGroupLinePatterns on PaymentGroupLine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentGroupLine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentGroupLine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentGroupLine value)  $default,){
final _that = this;
switch (_that) {
case _PaymentGroupLine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentGroupLine value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentGroupLine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String paymentId,  PaymentLineKind kind,  String subjectType,  String subjectId,  String payeeId,  int amount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentGroupLine() when $default != null:
return $default(_that.paymentId,_that.kind,_that.subjectType,_that.subjectId,_that.payeeId,_that.amount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String paymentId,  PaymentLineKind kind,  String subjectType,  String subjectId,  String payeeId,  int amount)  $default,) {final _that = this;
switch (_that) {
case _PaymentGroupLine():
return $default(_that.paymentId,_that.kind,_that.subjectType,_that.subjectId,_that.payeeId,_that.amount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String paymentId,  PaymentLineKind kind,  String subjectType,  String subjectId,  String payeeId,  int amount)?  $default,) {final _that = this;
switch (_that) {
case _PaymentGroupLine() when $default != null:
return $default(_that.paymentId,_that.kind,_that.subjectType,_that.subjectId,_that.payeeId,_that.amount);case _:
  return null;

}
}

}

/// @nodoc


class _PaymentGroupLine implements PaymentGroupLine {
  const _PaymentGroupLine({required this.paymentId, required this.kind, required this.subjectType, required this.subjectId, required this.payeeId, required this.amount});
  

@override final  String paymentId;
@override final  PaymentLineKind kind;
/// `booking` or `event_registration`.
@override final  String subjectType;
@override final  String subjectId;
/// Who receives this line (the photographer, the venue's organizer, …).
@override final  String payeeId;
/// Integer VND.
@override final  int amount;

/// Create a copy of PaymentGroupLine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentGroupLineCopyWith<_PaymentGroupLine> get copyWith => __$PaymentGroupLineCopyWithImpl<_PaymentGroupLine>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentGroupLine&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.subjectType, subjectType) || other.subjectType == subjectType)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.payeeId, payeeId) || other.payeeId == payeeId)&&(identical(other.amount, amount) || other.amount == amount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,paymentId,kind,subjectType,subjectId,payeeId,amount);
}

@override
String toString() {
    return 'PaymentGroupLine(paymentId: $paymentId, kind: $kind, subjectType: $subjectType, subjectId: $subjectId, payeeId: $payeeId, amount: $amount)';
}


}

/// @nodoc
abstract mixin class _$PaymentGroupLineCopyWith<$Res> implements $PaymentGroupLineCopyWith<$Res> {
  factory _$PaymentGroupLineCopyWith(_PaymentGroupLine value, $Res Function(_PaymentGroupLine) _then) = __$PaymentGroupLineCopyWithImpl;
@override @useResult
$Res call({
 String paymentId, PaymentLineKind kind, String subjectType, String subjectId, String payeeId, int amount
});




}
/// @nodoc
class __$PaymentGroupLineCopyWithImpl<$Res>
    implements _$PaymentGroupLineCopyWith<$Res> {
  __$PaymentGroupLineCopyWithImpl(this._self, this._then);

  final _PaymentGroupLine _self;
  final $Res Function(_PaymentGroupLine) _then;

/// Create a copy of PaymentGroupLine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? paymentId = null,Object? kind = null,Object? subjectType = null,Object? subjectId = null,Object? payeeId = null,Object? amount = null,}) {
  return _then(_PaymentGroupLine(
paymentId: null == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as PaymentLineKind,subjectType: null == subjectType ? _self.subjectType : subjectType // ignore: cast_nullable_to_non_nullable
as String,subjectId: null == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String,payeeId: null == payeeId ? _self.payeeId : payeeId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$PaymentGroup {

 String get id; String get payerId; List<PaymentGroupLine> get lines; int get total; PaymentGroupStatus get status; DateTime? get expiresAt; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of PaymentGroup
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentGroupCopyWith<PaymentGroup> get copyWith => _$PaymentGroupCopyWithImpl<PaymentGroup>(this as PaymentGroup, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PaymentGroup;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentGroup&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.payerId, _this.payerId) || other.payerId == _this.payerId)&&const DeepCollectionEquality().equals(other.lines, _this.lines)&&(identical(other.total, _this.total) || other.total == _this.total)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}


@override
int get hashCode {
  final _this = this as PaymentGroup;
  return Object.hash(runtimeType,_this.id,_this.payerId,const DeepCollectionEquality().hash(_this.lines),_this.total,_this.status,_this.expiresAt,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as PaymentGroup;
  return 'PaymentGroup(id: ${_this.id}, payerId: ${_this.payerId}, lines: ${_this.lines}, total: ${_this.total}, status: ${_this.status}, expiresAt: ${_this.expiresAt}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $PaymentGroupCopyWith<$Res>  {
  factory $PaymentGroupCopyWith(PaymentGroup value, $Res Function(PaymentGroup) _then) = _$PaymentGroupCopyWithImpl;
@useResult
$Res call({
 String id, String payerId, List<PaymentGroupLine> lines, int total, PaymentGroupStatus status, DateTime? expiresAt, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$PaymentGroupCopyWithImpl<$Res>
    implements $PaymentGroupCopyWith<$Res> {
  _$PaymentGroupCopyWithImpl(this._self, this._then);

  final PaymentGroup _self;
  final $Res Function(PaymentGroup) _then;

/// Create a copy of PaymentGroup
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? payerId = null,Object? lines = null,Object? total = null,Object? status = null,Object? expiresAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(PaymentGroup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,payerId: null == payerId ? _self.payerId : payerId // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<PaymentGroupLine>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentGroupStatus,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentGroup].
extension PaymentGroupPatterns on PaymentGroup {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentGroup value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentGroup() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentGroup value)  $default,){
final _that = this;
switch (_that) {
case _PaymentGroup():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentGroup value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentGroup() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String payerId,  List<PaymentGroupLine> lines,  int total,  PaymentGroupStatus status,  DateTime? expiresAt,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentGroup() when $default != null:
return $default(_that.id,_that.payerId,_that.lines,_that.total,_that.status,_that.expiresAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String payerId,  List<PaymentGroupLine> lines,  int total,  PaymentGroupStatus status,  DateTime? expiresAt,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _PaymentGroup():
return $default(_that.id,_that.payerId,_that.lines,_that.total,_that.status,_that.expiresAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String payerId,  List<PaymentGroupLine> lines,  int total,  PaymentGroupStatus status,  DateTime? expiresAt,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _PaymentGroup() when $default != null:
return $default(_that.id,_that.payerId,_that.lines,_that.total,_that.status,_that.expiresAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _PaymentGroup extends PaymentGroup {
  const _PaymentGroup({required this.id, required this.payerId, required  List<PaymentGroupLine> lines, required this.total, required this.status, this.expiresAt, this.createdAt, this.updatedAt}): _lines = lines,super._();
  

@override final  String id;
@override final  String payerId;
 final  List<PaymentGroupLine> _lines;
@override List<PaymentGroupLine> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

@override final  int total;
@override final  PaymentGroupStatus status;
@override final  DateTime? expiresAt;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of PaymentGroup
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentGroupCopyWith<_PaymentGroup> get copyWith => __$PaymentGroupCopyWithImpl<_PaymentGroup>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentGroup&&(identical(other.id, id) || other.id == id)&&(identical(other.payerId, payerId) || other.payerId == payerId)&&const DeepCollectionEquality().equals(other.lines, _lines)&&(identical(other.total, total) || other.total == total)&&(identical(other.status, status) || other.status == status)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,payerId,const DeepCollectionEquality().hash(_lines),total,status,expiresAt,createdAt,updatedAt);
}

@override
String toString() {
    return 'PaymentGroup(id: $id, payerId: $payerId, lines: $lines, total: $total, status: $status, expiresAt: $expiresAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$PaymentGroupCopyWith<$Res> implements $PaymentGroupCopyWith<$Res> {
  factory _$PaymentGroupCopyWith(_PaymentGroup value, $Res Function(_PaymentGroup) _then) = __$PaymentGroupCopyWithImpl;
@override @useResult
$Res call({
 String id, String payerId, List<PaymentGroupLine> lines, int total, PaymentGroupStatus status, DateTime? expiresAt, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$PaymentGroupCopyWithImpl<$Res>
    implements _$PaymentGroupCopyWith<$Res> {
  __$PaymentGroupCopyWithImpl(this._self, this._then);

  final _PaymentGroup _self;
  final $Res Function(_PaymentGroup) _then;

/// Create a copy of PaymentGroup
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? payerId = null,Object? lines = null,Object? total = null,Object? status = null,Object? expiresAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_PaymentGroup(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,payerId: null == payerId ? _self.payerId : payerId // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<PaymentGroupLine>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as PaymentGroupStatus,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
