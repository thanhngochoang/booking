// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'studio_booking.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StudioAssignment {

 String get assigneeId; String get assigneeKind; DateTime get at; String get by; String? get reason; bool get late;/// S27: when a collaborator's offer lapses (6 h, capped by the deadline).
 DateTime? get offerExpiresAt; DateTime? get acceptedAt; DateTime? get declinedAt;
/// Create a copy of StudioAssignment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudioAssignmentCopyWith<StudioAssignment> get copyWith => _$StudioAssignmentCopyWithImpl<StudioAssignment>(this as StudioAssignment, _$identity);

  /// Serializes this StudioAssignment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as StudioAssignment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudioAssignment&&(identical(other.assigneeId, _this.assigneeId) || other.assigneeId == _this.assigneeId)&&(identical(other.assigneeKind, _this.assigneeKind) || other.assigneeKind == _this.assigneeKind)&&(identical(other.at, _this.at) || other.at == _this.at)&&(identical(other.by, _this.by) || other.by == _this.by)&&(identical(other.reason, _this.reason) || other.reason == _this.reason)&&(identical(other.late, _this.late) || other.late == _this.late)&&(identical(other.offerExpiresAt, _this.offerExpiresAt) || other.offerExpiresAt == _this.offerExpiresAt)&&(identical(other.acceptedAt, _this.acceptedAt) || other.acceptedAt == _this.acceptedAt)&&(identical(other.declinedAt, _this.declinedAt) || other.declinedAt == _this.declinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as StudioAssignment;
  return Object.hash(runtimeType,_this.assigneeId,_this.assigneeKind,_this.at,_this.by,_this.reason,_this.late,_this.offerExpiresAt,_this.acceptedAt,_this.declinedAt);
}

@override
String toString() {
  final _this = this as StudioAssignment;
  return 'StudioAssignment(assigneeId: ${_this.assigneeId}, assigneeKind: ${_this.assigneeKind}, at: ${_this.at}, by: ${_this.by}, reason: ${_this.reason}, late: ${_this.late}, offerExpiresAt: ${_this.offerExpiresAt}, acceptedAt: ${_this.acceptedAt}, declinedAt: ${_this.declinedAt})';
}


}

/// @nodoc
abstract mixin class $StudioAssignmentCopyWith<$Res>  {
  factory $StudioAssignmentCopyWith(StudioAssignment value, $Res Function(StudioAssignment) _then) = _$StudioAssignmentCopyWithImpl;
@useResult
$Res call({
 String assigneeId, String assigneeKind, DateTime at, String by, String? reason, bool late, DateTime? offerExpiresAt, DateTime? acceptedAt, DateTime? declinedAt
});




}
/// @nodoc
class _$StudioAssignmentCopyWithImpl<$Res>
    implements $StudioAssignmentCopyWith<$Res> {
  _$StudioAssignmentCopyWithImpl(this._self, this._then);

  final StudioAssignment _self;
  final $Res Function(StudioAssignment) _then;

/// Create a copy of StudioAssignment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? assigneeId = null,Object? assigneeKind = null,Object? at = null,Object? by = null,Object? reason = freezed,Object? late = null,Object? offerExpiresAt = freezed,Object? acceptedAt = freezed,Object? declinedAt = freezed,}) {
  return _then(StudioAssignment(
assigneeId: null == assigneeId ? _self.assigneeId : assigneeId // ignore: cast_nullable_to_non_nullable
as String,assigneeKind: null == assigneeKind ? _self.assigneeKind : assigneeKind // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,by: null == by ? _self.by : by // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,late: null == late ? _self.late : late // ignore: cast_nullable_to_non_nullable
as bool,offerExpiresAt: freezed == offerExpiresAt ? _self.offerExpiresAt : offerExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,acceptedAt: freezed == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,declinedAt: freezed == declinedAt ? _self.declinedAt : declinedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [StudioAssignment].
extension StudioAssignmentPatterns on StudioAssignment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudioAssignment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudioAssignment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudioAssignment value)  $default,){
final _that = this;
switch (_that) {
case _StudioAssignment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudioAssignment value)?  $default,){
final _that = this;
switch (_that) {
case _StudioAssignment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String assigneeId,  String assigneeKind,  DateTime at,  String by,  String? reason,  bool late,  DateTime? offerExpiresAt,  DateTime? acceptedAt,  DateTime? declinedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudioAssignment() when $default != null:
return $default(_that.assigneeId,_that.assigneeKind,_that.at,_that.by,_that.reason,_that.late,_that.offerExpiresAt,_that.acceptedAt,_that.declinedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String assigneeId,  String assigneeKind,  DateTime at,  String by,  String? reason,  bool late,  DateTime? offerExpiresAt,  DateTime? acceptedAt,  DateTime? declinedAt)  $default,) {final _that = this;
switch (_that) {
case _StudioAssignment():
return $default(_that.assigneeId,_that.assigneeKind,_that.at,_that.by,_that.reason,_that.late,_that.offerExpiresAt,_that.acceptedAt,_that.declinedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String assigneeId,  String assigneeKind,  DateTime at,  String by,  String? reason,  bool late,  DateTime? offerExpiresAt,  DateTime? acceptedAt,  DateTime? declinedAt)?  $default,) {final _that = this;
switch (_that) {
case _StudioAssignment() when $default != null:
return $default(_that.assigneeId,_that.assigneeKind,_that.at,_that.by,_that.reason,_that.late,_that.offerExpiresAt,_that.acceptedAt,_that.declinedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StudioAssignment implements StudioAssignment {
  const _StudioAssignment({required this.assigneeId, this.assigneeKind = 'member', required this.at, required this.by, this.reason, this.late = false, this.offerExpiresAt, this.acceptedAt, this.declinedAt});
  factory _StudioAssignment.fromJson(Map<String, dynamic> json) => _$StudioAssignmentFromJson(json);

@override final  String assigneeId;
@override@JsonKey() final  String assigneeKind;
@override final  DateTime at;
@override final  String by;
@override final  String? reason;
@override@JsonKey() final  bool late;
/// S27: when a collaborator's offer lapses (6 h, capped by the deadline).
@override final  DateTime? offerExpiresAt;
@override final  DateTime? acceptedAt;
@override final  DateTime? declinedAt;

/// Create a copy of StudioAssignment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudioAssignmentCopyWith<_StudioAssignment> get copyWith => __$StudioAssignmentCopyWithImpl<_StudioAssignment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudioAssignmentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudioAssignment&&(identical(other.assigneeId, assigneeId) || other.assigneeId == assigneeId)&&(identical(other.assigneeKind, assigneeKind) || other.assigneeKind == assigneeKind)&&(identical(other.at, at) || other.at == at)&&(identical(other.by, by) || other.by == by)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.late, late) || other.late == late)&&(identical(other.offerExpiresAt, offerExpiresAt) || other.offerExpiresAt == offerExpiresAt)&&(identical(other.acceptedAt, acceptedAt) || other.acceptedAt == acceptedAt)&&(identical(other.declinedAt, declinedAt) || other.declinedAt == declinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,assigneeId,assigneeKind,at,by,reason,late,offerExpiresAt,acceptedAt,declinedAt);
}

@override
String toString() {
    return 'StudioAssignment(assigneeId: $assigneeId, assigneeKind: $assigneeKind, at: $at, by: $by, reason: $reason, late: $late, offerExpiresAt: $offerExpiresAt, acceptedAt: $acceptedAt, declinedAt: $declinedAt)';
}


}

/// @nodoc
abstract mixin class _$StudioAssignmentCopyWith<$Res> implements $StudioAssignmentCopyWith<$Res> {
  factory _$StudioAssignmentCopyWith(_StudioAssignment value, $Res Function(_StudioAssignment) _then) = __$StudioAssignmentCopyWithImpl;
@override @useResult
$Res call({
 String assigneeId, String assigneeKind, DateTime at, String by, String? reason, bool late, DateTime? offerExpiresAt, DateTime? acceptedAt, DateTime? declinedAt
});




}
/// @nodoc
class __$StudioAssignmentCopyWithImpl<$Res>
    implements _$StudioAssignmentCopyWith<$Res> {
  __$StudioAssignmentCopyWithImpl(this._self, this._then);

  final _StudioAssignment _self;
  final $Res Function(_StudioAssignment) _then;

/// Create a copy of StudioAssignment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? assigneeId = null,Object? assigneeKind = null,Object? at = null,Object? by = null,Object? reason = freezed,Object? late = null,Object? offerExpiresAt = freezed,Object? acceptedAt = freezed,Object? declinedAt = freezed,}) {
  return _then(_StudioAssignment(
assigneeId: null == assigneeId ? _self.assigneeId : assigneeId // ignore: cast_nullable_to_non_nullable
as String,assigneeKind: null == assigneeKind ? _self.assigneeKind : assigneeKind // ignore: cast_nullable_to_non_nullable
as String,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,by: null == by ? _self.by : by // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,late: null == late ? _self.late : late // ignore: cast_nullable_to_non_nullable
as bool,offerExpiresAt: freezed == offerExpiresAt ? _self.offerExpiresAt : offerExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,acceptedAt: freezed == acceptedAt ? _self.acceptedAt : acceptedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,declinedAt: freezed == declinedAt ? _self.declinedAt : declinedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$StudioChangeRequest {

 DateTime get at; String? get note; DateTime get respondBy; ChangeRequestStatus get status; String? get declineReason; DateTime? get answeredAt;
/// Create a copy of StudioChangeRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudioChangeRequestCopyWith<StudioChangeRequest> get copyWith => _$StudioChangeRequestCopyWithImpl<StudioChangeRequest>(this as StudioChangeRequest, _$identity);

  /// Serializes this StudioChangeRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as StudioChangeRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudioChangeRequest&&(identical(other.at, _this.at) || other.at == _this.at)&&(identical(other.note, _this.note) || other.note == _this.note)&&(identical(other.respondBy, _this.respondBy) || other.respondBy == _this.respondBy)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.declineReason, _this.declineReason) || other.declineReason == _this.declineReason)&&(identical(other.answeredAt, _this.answeredAt) || other.answeredAt == _this.answeredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as StudioChangeRequest;
  return Object.hash(runtimeType,_this.at,_this.note,_this.respondBy,_this.status,_this.declineReason,_this.answeredAt);
}

@override
String toString() {
  final _this = this as StudioChangeRequest;
  return 'StudioChangeRequest(at: ${_this.at}, note: ${_this.note}, respondBy: ${_this.respondBy}, status: ${_this.status}, declineReason: ${_this.declineReason}, answeredAt: ${_this.answeredAt})';
}


}

/// @nodoc
abstract mixin class $StudioChangeRequestCopyWith<$Res>  {
  factory $StudioChangeRequestCopyWith(StudioChangeRequest value, $Res Function(StudioChangeRequest) _then) = _$StudioChangeRequestCopyWithImpl;
@useResult
$Res call({
 DateTime at, String? note, DateTime respondBy, ChangeRequestStatus status, String? declineReason, DateTime? answeredAt
});




}
/// @nodoc
class _$StudioChangeRequestCopyWithImpl<$Res>
    implements $StudioChangeRequestCopyWith<$Res> {
  _$StudioChangeRequestCopyWithImpl(this._self, this._then);

  final StudioChangeRequest _self;
  final $Res Function(StudioChangeRequest) _then;

/// Create a copy of StudioChangeRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? at = null,Object? note = freezed,Object? respondBy = null,Object? status = null,Object? declineReason = freezed,Object? answeredAt = freezed,}) {
  return _then(StudioChangeRequest(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,respondBy: null == respondBy ? _self.respondBy : respondBy // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChangeRequestStatus,declineReason: freezed == declineReason ? _self.declineReason : declineReason // ignore: cast_nullable_to_non_nullable
as String?,answeredAt: freezed == answeredAt ? _self.answeredAt : answeredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [StudioChangeRequest].
extension StudioChangeRequestPatterns on StudioChangeRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudioChangeRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudioChangeRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudioChangeRequest value)  $default,){
final _that = this;
switch (_that) {
case _StudioChangeRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudioChangeRequest value)?  $default,){
final _that = this;
switch (_that) {
case _StudioChangeRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime at,  String? note,  DateTime respondBy,  ChangeRequestStatus status,  String? declineReason,  DateTime? answeredAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudioChangeRequest() when $default != null:
return $default(_that.at,_that.note,_that.respondBy,_that.status,_that.declineReason,_that.answeredAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime at,  String? note,  DateTime respondBy,  ChangeRequestStatus status,  String? declineReason,  DateTime? answeredAt)  $default,) {final _that = this;
switch (_that) {
case _StudioChangeRequest():
return $default(_that.at,_that.note,_that.respondBy,_that.status,_that.declineReason,_that.answeredAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime at,  String? note,  DateTime respondBy,  ChangeRequestStatus status,  String? declineReason,  DateTime? answeredAt)?  $default,) {final _that = this;
switch (_that) {
case _StudioChangeRequest() when $default != null:
return $default(_that.at,_that.note,_that.respondBy,_that.status,_that.declineReason,_that.answeredAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StudioChangeRequest implements StudioChangeRequest {
  const _StudioChangeRequest({required this.at, this.note, required this.respondBy, this.status = ChangeRequestStatus.pending, this.declineReason, this.answeredAt});
  factory _StudioChangeRequest.fromJson(Map<String, dynamic> json) => _$StudioChangeRequestFromJson(json);

@override final  DateTime at;
@override final  String? note;
@override final  DateTime respondBy;
@override@JsonKey() final  ChangeRequestStatus status;
@override final  String? declineReason;
@override final  DateTime? answeredAt;

/// Create a copy of StudioChangeRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudioChangeRequestCopyWith<_StudioChangeRequest> get copyWith => __$StudioChangeRequestCopyWithImpl<_StudioChangeRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudioChangeRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudioChangeRequest&&(identical(other.at, at) || other.at == at)&&(identical(other.note, note) || other.note == note)&&(identical(other.respondBy, respondBy) || other.respondBy == respondBy)&&(identical(other.status, status) || other.status == status)&&(identical(other.declineReason, declineReason) || other.declineReason == declineReason)&&(identical(other.answeredAt, answeredAt) || other.answeredAt == answeredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,at,note,respondBy,status,declineReason,answeredAt);
}

@override
String toString() {
    return 'StudioChangeRequest(at: $at, note: $note, respondBy: $respondBy, status: $status, declineReason: $declineReason, answeredAt: $answeredAt)';
}


}

/// @nodoc
abstract mixin class _$StudioChangeRequestCopyWith<$Res> implements $StudioChangeRequestCopyWith<$Res> {
  factory _$StudioChangeRequestCopyWith(_StudioChangeRequest value, $Res Function(_StudioChangeRequest) _then) = __$StudioChangeRequestCopyWithImpl;
@override @useResult
$Res call({
 DateTime at, String? note, DateTime respondBy, ChangeRequestStatus status, String? declineReason, DateTime? answeredAt
});




}
/// @nodoc
class __$StudioChangeRequestCopyWithImpl<$Res>
    implements _$StudioChangeRequestCopyWith<$Res> {
  __$StudioChangeRequestCopyWithImpl(this._self, this._then);

  final _StudioChangeRequest _self;
  final $Res Function(_StudioChangeRequest) _then;

/// Create a copy of StudioChangeRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? at = null,Object? note = freezed,Object? respondBy = null,Object? status = null,Object? declineReason = freezed,Object? answeredAt = freezed,}) {
  return _then(_StudioChangeRequest(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,respondBy: null == respondBy ? _self.respondBy : respondBy // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChangeRequestStatus,declineReason: freezed == declineReason ? _self.declineReason : declineReason // ignore: cast_nullable_to_non_nullable
as String?,answeredAt: freezed == answeredAt ? _self.answeredAt : answeredAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$StudioFault {

 StudioFaultKind get kind; DateTime get at;
/// Create a copy of StudioFault
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudioFaultCopyWith<StudioFault> get copyWith => _$StudioFaultCopyWithImpl<StudioFault>(this as StudioFault, _$identity);

  /// Serializes this StudioFault to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as StudioFault;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudioFault&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.at, _this.at) || other.at == _this.at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as StudioFault;
  return Object.hash(runtimeType,_this.kind,_this.at);
}

@override
String toString() {
  final _this = this as StudioFault;
  return 'StudioFault(kind: ${_this.kind}, at: ${_this.at})';
}


}

/// @nodoc
abstract mixin class $StudioFaultCopyWith<$Res>  {
  factory $StudioFaultCopyWith(StudioFault value, $Res Function(StudioFault) _then) = _$StudioFaultCopyWithImpl;
@useResult
$Res call({
 StudioFaultKind kind, DateTime at
});




}
/// @nodoc
class _$StudioFaultCopyWithImpl<$Res>
    implements $StudioFaultCopyWith<$Res> {
  _$StudioFaultCopyWithImpl(this._self, this._then);

  final StudioFault _self;
  final $Res Function(StudioFault) _then;

/// Create a copy of StudioFault
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? at = null,}) {
  return _then(StudioFault(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as StudioFaultKind,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [StudioFault].
extension StudioFaultPatterns on StudioFault {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudioFault value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudioFault() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudioFault value)  $default,){
final _that = this;
switch (_that) {
case _StudioFault():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudioFault value)?  $default,){
final _that = this;
switch (_that) {
case _StudioFault() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( StudioFaultKind kind,  DateTime at)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudioFault() when $default != null:
return $default(_that.kind,_that.at);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( StudioFaultKind kind,  DateTime at)  $default,) {final _that = this;
switch (_that) {
case _StudioFault():
return $default(_that.kind,_that.at);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( StudioFaultKind kind,  DateTime at)?  $default,) {final _that = this;
switch (_that) {
case _StudioFault() when $default != null:
return $default(_that.kind,_that.at);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StudioFault implements StudioFault {
  const _StudioFault({required this.kind, required this.at});
  factory _StudioFault.fromJson(Map<String, dynamic> json) => _$StudioFaultFromJson(json);

@override final  StudioFaultKind kind;
@override final  DateTime at;

/// Create a copy of StudioFault
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudioFaultCopyWith<_StudioFault> get copyWith => __$StudioFaultCopyWithImpl<_StudioFault>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudioFaultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudioFault&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.at, at) || other.at == at));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,at);
}

@override
String toString() {
    return 'StudioFault(kind: $kind, at: $at)';
}


}

/// @nodoc
abstract mixin class _$StudioFaultCopyWith<$Res> implements $StudioFaultCopyWith<$Res> {
  factory _$StudioFaultCopyWith(_StudioFault value, $Res Function(_StudioFault) _then) = __$StudioFaultCopyWithImpl;
@override @useResult
$Res call({
 StudioFaultKind kind, DateTime at
});




}
/// @nodoc
class __$StudioFaultCopyWithImpl<$Res>
    implements _$StudioFaultCopyWith<$Res> {
  __$StudioFaultCopyWithImpl(this._self, this._then);

  final _StudioFault _self;
  final $Res Function(_StudioFault) _then;

/// Create a copy of StudioFault
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? at = null,}) {
  return _then(_StudioFault(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as StudioFaultKind,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$StudioBookingInfo {

/// Who shoots; kept after "Trả việc" until the studio reassigns. For a
/// collaborator (S27) it is set at offer time, with [assigneeAccepted]
/// false until they accept (`assignStatus` stays unassigned meanwhile).
 String? get assigneeId; String? get assigneeKind; bool get assigneeAccepted; StudioAssignStatus get assignStatus; DateTime get assignDeadline;/// Set once by the sweep when the deadline passed unassigned; stays as
/// history after a late assignment.
 bool get assignOverdue; DateTime? get assignedAt; List<StudioAssignment> get assignments;/// Reminders the studio got (`h48`, `h26`), for "Đã nhắc … lúc …".
 List<String> get remindersSent; StudioChangeRequest? get changeRequest; StudioFault? get studioFault;/// "Trả việc": when and why the assignee handed the job back.
 DateTime? get returnedAt; String? get returnReason;
/// Create a copy of StudioBookingInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudioBookingInfoCopyWith<StudioBookingInfo> get copyWith => _$StudioBookingInfoCopyWithImpl<StudioBookingInfo>(this as StudioBookingInfo, _$identity);

  /// Serializes this StudioBookingInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as StudioBookingInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StudioBookingInfo&&(identical(other.assigneeId, _this.assigneeId) || other.assigneeId == _this.assigneeId)&&(identical(other.assigneeKind, _this.assigneeKind) || other.assigneeKind == _this.assigneeKind)&&(identical(other.assigneeAccepted, _this.assigneeAccepted) || other.assigneeAccepted == _this.assigneeAccepted)&&(identical(other.assignStatus, _this.assignStatus) || other.assignStatus == _this.assignStatus)&&(identical(other.assignDeadline, _this.assignDeadline) || other.assignDeadline == _this.assignDeadline)&&(identical(other.assignOverdue, _this.assignOverdue) || other.assignOverdue == _this.assignOverdue)&&(identical(other.assignedAt, _this.assignedAt) || other.assignedAt == _this.assignedAt)&&const DeepCollectionEquality().equals(other.assignments, _this.assignments)&&const DeepCollectionEquality().equals(other.remindersSent, _this.remindersSent)&&(identical(other.changeRequest, _this.changeRequest) || other.changeRequest == _this.changeRequest)&&(identical(other.studioFault, _this.studioFault) || other.studioFault == _this.studioFault)&&(identical(other.returnedAt, _this.returnedAt) || other.returnedAt == _this.returnedAt)&&(identical(other.returnReason, _this.returnReason) || other.returnReason == _this.returnReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as StudioBookingInfo;
  return Object.hash(runtimeType,_this.assigneeId,_this.assigneeKind,_this.assigneeAccepted,_this.assignStatus,_this.assignDeadline,_this.assignOverdue,_this.assignedAt,const DeepCollectionEquality().hash(_this.assignments),const DeepCollectionEquality().hash(_this.remindersSent),_this.changeRequest,_this.studioFault,_this.returnedAt,_this.returnReason);
}

@override
String toString() {
  final _this = this as StudioBookingInfo;
  return 'StudioBookingInfo(assigneeId: ${_this.assigneeId}, assigneeKind: ${_this.assigneeKind}, assigneeAccepted: ${_this.assigneeAccepted}, assignStatus: ${_this.assignStatus}, assignDeadline: ${_this.assignDeadline}, assignOverdue: ${_this.assignOverdue}, assignedAt: ${_this.assignedAt}, assignments: ${_this.assignments}, remindersSent: ${_this.remindersSent}, changeRequest: ${_this.changeRequest}, studioFault: ${_this.studioFault}, returnedAt: ${_this.returnedAt}, returnReason: ${_this.returnReason})';
}


}

/// @nodoc
abstract mixin class $StudioBookingInfoCopyWith<$Res>  {
  factory $StudioBookingInfoCopyWith(StudioBookingInfo value, $Res Function(StudioBookingInfo) _then) = _$StudioBookingInfoCopyWithImpl;
@useResult
$Res call({
 String? assigneeId, String? assigneeKind, bool assigneeAccepted, StudioAssignStatus assignStatus, DateTime assignDeadline, bool assignOverdue, DateTime? assignedAt, List<StudioAssignment> assignments, List<String> remindersSent, StudioChangeRequest? changeRequest, StudioFault? studioFault, DateTime? returnedAt, String? returnReason
});


$StudioChangeRequestCopyWith<$Res>? get changeRequest;$StudioFaultCopyWith<$Res>? get studioFault;

}
/// @nodoc
class _$StudioBookingInfoCopyWithImpl<$Res>
    implements $StudioBookingInfoCopyWith<$Res> {
  _$StudioBookingInfoCopyWithImpl(this._self, this._then);

  final StudioBookingInfo _self;
  final $Res Function(StudioBookingInfo) _then;

/// Create a copy of StudioBookingInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? assigneeId = freezed,Object? assigneeKind = freezed,Object? assigneeAccepted = null,Object? assignStatus = null,Object? assignDeadline = null,Object? assignOverdue = null,Object? assignedAt = freezed,Object? assignments = null,Object? remindersSent = null,Object? changeRequest = freezed,Object? studioFault = freezed,Object? returnedAt = freezed,Object? returnReason = freezed,}) {
  return _then(StudioBookingInfo(
assigneeId: freezed == assigneeId ? _self.assigneeId : assigneeId // ignore: cast_nullable_to_non_nullable
as String?,assigneeKind: freezed == assigneeKind ? _self.assigneeKind : assigneeKind // ignore: cast_nullable_to_non_nullable
as String?,assigneeAccepted: null == assigneeAccepted ? _self.assigneeAccepted : assigneeAccepted // ignore: cast_nullable_to_non_nullable
as bool,assignStatus: null == assignStatus ? _self.assignStatus : assignStatus // ignore: cast_nullable_to_non_nullable
as StudioAssignStatus,assignDeadline: null == assignDeadline ? _self.assignDeadline : assignDeadline // ignore: cast_nullable_to_non_nullable
as DateTime,assignOverdue: null == assignOverdue ? _self.assignOverdue : assignOverdue // ignore: cast_nullable_to_non_nullable
as bool,assignedAt: freezed == assignedAt ? _self.assignedAt : assignedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,assignments: null == assignments ? _self.assignments : assignments // ignore: cast_nullable_to_non_nullable
as List<StudioAssignment>,remindersSent: null == remindersSent ? _self.remindersSent : remindersSent // ignore: cast_nullable_to_non_nullable
as List<String>,changeRequest: freezed == changeRequest ? _self.changeRequest : changeRequest // ignore: cast_nullable_to_non_nullable
as StudioChangeRequest?,studioFault: freezed == studioFault ? _self.studioFault : studioFault // ignore: cast_nullable_to_non_nullable
as StudioFault?,returnedAt: freezed == returnedAt ? _self.returnedAt : returnedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,returnReason: freezed == returnReason ? _self.returnReason : returnReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of StudioBookingInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioChangeRequestCopyWith<$Res>? get changeRequest {
    if (_self.changeRequest == null) {
    return null;
  }

  return $StudioChangeRequestCopyWith<$Res>(_self.changeRequest!, (value) {
    return _then(_self.copyWith(changeRequest: value));
  });
}/// Create a copy of StudioBookingInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioFaultCopyWith<$Res>? get studioFault {
    if (_self.studioFault == null) {
    return null;
  }

  return $StudioFaultCopyWith<$Res>(_self.studioFault!, (value) {
    return _then(_self.copyWith(studioFault: value));
  });
}
}


/// Adds pattern-matching-related methods to [StudioBookingInfo].
extension StudioBookingInfoPatterns on StudioBookingInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StudioBookingInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StudioBookingInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StudioBookingInfo value)  $default,){
final _that = this;
switch (_that) {
case _StudioBookingInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StudioBookingInfo value)?  $default,){
final _that = this;
switch (_that) {
case _StudioBookingInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? assigneeId,  String? assigneeKind,  bool assigneeAccepted,  StudioAssignStatus assignStatus,  DateTime assignDeadline,  bool assignOverdue,  DateTime? assignedAt,  List<StudioAssignment> assignments,  List<String> remindersSent,  StudioChangeRequest? changeRequest,  StudioFault? studioFault,  DateTime? returnedAt,  String? returnReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StudioBookingInfo() when $default != null:
return $default(_that.assigneeId,_that.assigneeKind,_that.assigneeAccepted,_that.assignStatus,_that.assignDeadline,_that.assignOverdue,_that.assignedAt,_that.assignments,_that.remindersSent,_that.changeRequest,_that.studioFault,_that.returnedAt,_that.returnReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? assigneeId,  String? assigneeKind,  bool assigneeAccepted,  StudioAssignStatus assignStatus,  DateTime assignDeadline,  bool assignOverdue,  DateTime? assignedAt,  List<StudioAssignment> assignments,  List<String> remindersSent,  StudioChangeRequest? changeRequest,  StudioFault? studioFault,  DateTime? returnedAt,  String? returnReason)  $default,) {final _that = this;
switch (_that) {
case _StudioBookingInfo():
return $default(_that.assigneeId,_that.assigneeKind,_that.assigneeAccepted,_that.assignStatus,_that.assignDeadline,_that.assignOverdue,_that.assignedAt,_that.assignments,_that.remindersSent,_that.changeRequest,_that.studioFault,_that.returnedAt,_that.returnReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? assigneeId,  String? assigneeKind,  bool assigneeAccepted,  StudioAssignStatus assignStatus,  DateTime assignDeadline,  bool assignOverdue,  DateTime? assignedAt,  List<StudioAssignment> assignments,  List<String> remindersSent,  StudioChangeRequest? changeRequest,  StudioFault? studioFault,  DateTime? returnedAt,  String? returnReason)?  $default,) {final _that = this;
switch (_that) {
case _StudioBookingInfo() when $default != null:
return $default(_that.assigneeId,_that.assigneeKind,_that.assigneeAccepted,_that.assignStatus,_that.assignDeadline,_that.assignOverdue,_that.assignedAt,_that.assignments,_that.remindersSent,_that.changeRequest,_that.studioFault,_that.returnedAt,_that.returnReason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StudioBookingInfo extends StudioBookingInfo {
  const _StudioBookingInfo({this.assigneeId, this.assigneeKind, this.assigneeAccepted = false, this.assignStatus = StudioAssignStatus.unassigned, required this.assignDeadline, this.assignOverdue = false, this.assignedAt,  List<StudioAssignment> assignments = const <StudioAssignment>[],  List<String> remindersSent = const <String>[], this.changeRequest, this.studioFault, this.returnedAt, this.returnReason}): _assignments = assignments,_remindersSent = remindersSent,super._();
  factory _StudioBookingInfo.fromJson(Map<String, dynamic> json) => _$StudioBookingInfoFromJson(json);

/// Who shoots; kept after "Trả việc" until the studio reassigns. For a
/// collaborator (S27) it is set at offer time, with [assigneeAccepted]
/// false until they accept (`assignStatus` stays unassigned meanwhile).
@override final  String? assigneeId;
@override final  String? assigneeKind;
@override@JsonKey() final  bool assigneeAccepted;
@override@JsonKey() final  StudioAssignStatus assignStatus;
@override final  DateTime assignDeadline;
/// Set once by the sweep when the deadline passed unassigned; stays as
/// history after a late assignment.
@override@JsonKey() final  bool assignOverdue;
@override final  DateTime? assignedAt;
 final  List<StudioAssignment> _assignments;
@override@JsonKey() List<StudioAssignment> get assignments {
  if (_assignments is EqualUnmodifiableListView) return _assignments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_assignments);
}

/// Reminders the studio got (`h48`, `h26`), for "Đã nhắc … lúc …".
 final  List<String> _remindersSent;
/// Reminders the studio got (`h48`, `h26`), for "Đã nhắc … lúc …".
@override@JsonKey() List<String> get remindersSent {
  if (_remindersSent is EqualUnmodifiableListView) return _remindersSent;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_remindersSent);
}

@override final  StudioChangeRequest? changeRequest;
@override final  StudioFault? studioFault;
/// "Trả việc": when and why the assignee handed the job back.
@override final  DateTime? returnedAt;
@override final  String? returnReason;

/// Create a copy of StudioBookingInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudioBookingInfoCopyWith<_StudioBookingInfo> get copyWith => __$StudioBookingInfoCopyWithImpl<_StudioBookingInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudioBookingInfoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StudioBookingInfo&&(identical(other.assigneeId, assigneeId) || other.assigneeId == assigneeId)&&(identical(other.assigneeKind, assigneeKind) || other.assigneeKind == assigneeKind)&&(identical(other.assigneeAccepted, assigneeAccepted) || other.assigneeAccepted == assigneeAccepted)&&(identical(other.assignStatus, assignStatus) || other.assignStatus == assignStatus)&&(identical(other.assignDeadline, assignDeadline) || other.assignDeadline == assignDeadline)&&(identical(other.assignOverdue, assignOverdue) || other.assignOverdue == assignOverdue)&&(identical(other.assignedAt, assignedAt) || other.assignedAt == assignedAt)&&const DeepCollectionEquality().equals(other.assignments, _assignments)&&const DeepCollectionEquality().equals(other.remindersSent, _remindersSent)&&(identical(other.changeRequest, changeRequest) || other.changeRequest == changeRequest)&&(identical(other.studioFault, studioFault) || other.studioFault == studioFault)&&(identical(other.returnedAt, returnedAt) || other.returnedAt == returnedAt)&&(identical(other.returnReason, returnReason) || other.returnReason == returnReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,assigneeId,assigneeKind,assigneeAccepted,assignStatus,assignDeadline,assignOverdue,assignedAt,const DeepCollectionEquality().hash(_assignments),const DeepCollectionEquality().hash(_remindersSent),changeRequest,studioFault,returnedAt,returnReason);
}

@override
String toString() {
    return 'StudioBookingInfo(assigneeId: $assigneeId, assigneeKind: $assigneeKind, assigneeAccepted: $assigneeAccepted, assignStatus: $assignStatus, assignDeadline: $assignDeadline, assignOverdue: $assignOverdue, assignedAt: $assignedAt, assignments: $assignments, remindersSent: $remindersSent, changeRequest: $changeRequest, studioFault: $studioFault, returnedAt: $returnedAt, returnReason: $returnReason)';
}


}

/// @nodoc
abstract mixin class _$StudioBookingInfoCopyWith<$Res> implements $StudioBookingInfoCopyWith<$Res> {
  factory _$StudioBookingInfoCopyWith(_StudioBookingInfo value, $Res Function(_StudioBookingInfo) _then) = __$StudioBookingInfoCopyWithImpl;
@override @useResult
$Res call({
 String? assigneeId, String? assigneeKind, bool assigneeAccepted, StudioAssignStatus assignStatus, DateTime assignDeadline, bool assignOverdue, DateTime? assignedAt, List<StudioAssignment> assignments, List<String> remindersSent, StudioChangeRequest? changeRequest, StudioFault? studioFault, DateTime? returnedAt, String? returnReason
});


@override $StudioChangeRequestCopyWith<$Res>? get changeRequest;@override $StudioFaultCopyWith<$Res>? get studioFault;

}
/// @nodoc
class __$StudioBookingInfoCopyWithImpl<$Res>
    implements _$StudioBookingInfoCopyWith<$Res> {
  __$StudioBookingInfoCopyWithImpl(this._self, this._then);

  final _StudioBookingInfo _self;
  final $Res Function(_StudioBookingInfo) _then;

/// Create a copy of StudioBookingInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? assigneeId = freezed,Object? assigneeKind = freezed,Object? assigneeAccepted = null,Object? assignStatus = null,Object? assignDeadline = null,Object? assignOverdue = null,Object? assignedAt = freezed,Object? assignments = null,Object? remindersSent = null,Object? changeRequest = freezed,Object? studioFault = freezed,Object? returnedAt = freezed,Object? returnReason = freezed,}) {
  return _then(_StudioBookingInfo(
assigneeId: freezed == assigneeId ? _self.assigneeId : assigneeId // ignore: cast_nullable_to_non_nullable
as String?,assigneeKind: freezed == assigneeKind ? _self.assigneeKind : assigneeKind // ignore: cast_nullable_to_non_nullable
as String?,assigneeAccepted: null == assigneeAccepted ? _self.assigneeAccepted : assigneeAccepted // ignore: cast_nullable_to_non_nullable
as bool,assignStatus: null == assignStatus ? _self.assignStatus : assignStatus // ignore: cast_nullable_to_non_nullable
as StudioAssignStatus,assignDeadline: null == assignDeadline ? _self.assignDeadline : assignDeadline // ignore: cast_nullable_to_non_nullable
as DateTime,assignOverdue: null == assignOverdue ? _self.assignOverdue : assignOverdue // ignore: cast_nullable_to_non_nullable
as bool,assignedAt: freezed == assignedAt ? _self.assignedAt : assignedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,assignments: null == assignments ? _self._assignments : assignments // ignore: cast_nullable_to_non_nullable
as List<StudioAssignment>,remindersSent: null == remindersSent ? _self._remindersSent : remindersSent // ignore: cast_nullable_to_non_nullable
as List<String>,changeRequest: freezed == changeRequest ? _self.changeRequest : changeRequest // ignore: cast_nullable_to_non_nullable
as StudioChangeRequest?,studioFault: freezed == studioFault ? _self.studioFault : studioFault // ignore: cast_nullable_to_non_nullable
as StudioFault?,returnedAt: freezed == returnedAt ? _self.returnedAt : returnedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,returnReason: freezed == returnReason ? _self.returnReason : returnReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of StudioBookingInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioChangeRequestCopyWith<$Res>? get changeRequest {
    if (_self.changeRequest == null) {
    return null;
  }

  return $StudioChangeRequestCopyWith<$Res>(_self.changeRequest!, (value) {
    return _then(_self.copyWith(changeRequest: value));
  });
}/// Create a copy of StudioBookingInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudioFaultCopyWith<$Res>? get studioFault {
    if (_self.studioFault == null) {
    return null;
  }

  return $StudioFaultCopyWith<$Res>(_self.studioFault!, (value) {
    return _then(_self.copyWith(studioFault: value));
  });
}
}

// dart format on
