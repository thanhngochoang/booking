// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'delivery.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeliverySampleRef {

 String get fileId; String get path; String get thumbPath; int get width; int get height;
/// Create a copy of DeliverySampleRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeliverySampleRefCopyWith<DeliverySampleRef> get copyWith => _$DeliverySampleRefCopyWithImpl<DeliverySampleRef>(this as DeliverySampleRef, _$identity);

  /// Serializes this DeliverySampleRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeliverySampleRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliverySampleRef&&(identical(other.fileId, _this.fileId) || other.fileId == _this.fileId)&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.thumbPath, _this.thumbPath) || other.thumbPath == _this.thumbPath)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeliverySampleRef;
  return Object.hash(runtimeType,_this.fileId,_this.path,_this.thumbPath,_this.width,_this.height);
}

@override
String toString() {
  final _this = this as DeliverySampleRef;
  return 'DeliverySampleRef(fileId: ${_this.fileId}, path: ${_this.path}, thumbPath: ${_this.thumbPath}, width: ${_this.width}, height: ${_this.height})';
}


}

/// @nodoc
abstract mixin class $DeliverySampleRefCopyWith<$Res>  {
  factory $DeliverySampleRefCopyWith(DeliverySampleRef value, $Res Function(DeliverySampleRef) _then) = _$DeliverySampleRefCopyWithImpl;
@useResult
$Res call({
 String fileId, String path, String thumbPath, int width, int height
});




}
/// @nodoc
class _$DeliverySampleRefCopyWithImpl<$Res>
    implements $DeliverySampleRefCopyWith<$Res> {
  _$DeliverySampleRefCopyWithImpl(this._self, this._then);

  final DeliverySampleRef _self;
  final $Res Function(DeliverySampleRef) _then;

/// Create a copy of DeliverySampleRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fileId = null,Object? path = null,Object? thumbPath = null,Object? width = null,Object? height = null,}) {
  return _then(DeliverySampleRef(
fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,thumbPath: null == thumbPath ? _self.thumbPath : thumbPath // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DeliverySampleRef].
extension DeliverySampleRefPatterns on DeliverySampleRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeliverySampleRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeliverySampleRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeliverySampleRef value)  $default,){
final _that = this;
switch (_that) {
case _DeliverySampleRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeliverySampleRef value)?  $default,){
final _that = this;
switch (_that) {
case _DeliverySampleRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fileId,  String path,  String thumbPath,  int width,  int height)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeliverySampleRef() when $default != null:
return $default(_that.fileId,_that.path,_that.thumbPath,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fileId,  String path,  String thumbPath,  int width,  int height)  $default,) {final _that = this;
switch (_that) {
case _DeliverySampleRef():
return $default(_that.fileId,_that.path,_that.thumbPath,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fileId,  String path,  String thumbPath,  int width,  int height)?  $default,) {final _that = this;
switch (_that) {
case _DeliverySampleRef() when $default != null:
return $default(_that.fileId,_that.path,_that.thumbPath,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeliverySampleRef implements DeliverySampleRef {
  const _DeliverySampleRef({required this.fileId, required this.path, required this.thumbPath, required this.width, required this.height});
  factory _DeliverySampleRef.fromJson(Map<String, dynamic> json) => _$DeliverySampleRefFromJson(json);

@override final  String fileId;
@override final  String path;
@override final  String thumbPath;
@override final  int width;
@override final  int height;

/// Create a copy of DeliverySampleRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeliverySampleRefCopyWith<_DeliverySampleRef> get copyWith => __$DeliverySampleRefCopyWithImpl<_DeliverySampleRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeliverySampleRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeliverySampleRef&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.path, path) || other.path == path)&&(identical(other.thumbPath, thumbPath) || other.thumbPath == thumbPath)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,fileId,path,thumbPath,width,height);
}

@override
String toString() {
    return 'DeliverySampleRef(fileId: $fileId, path: $path, thumbPath: $thumbPath, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$DeliverySampleRefCopyWith<$Res> implements $DeliverySampleRefCopyWith<$Res> {
  factory _$DeliverySampleRefCopyWith(_DeliverySampleRef value, $Res Function(_DeliverySampleRef) _then) = __$DeliverySampleRefCopyWithImpl;
@override @useResult
$Res call({
 String fileId, String path, String thumbPath, int width, int height
});




}
/// @nodoc
class __$DeliverySampleRefCopyWithImpl<$Res>
    implements _$DeliverySampleRefCopyWith<$Res> {
  __$DeliverySampleRefCopyWithImpl(this._self, this._then);

  final _DeliverySampleRef _self;
  final $Res Function(_DeliverySampleRef) _then;

/// Create a copy of DeliverySampleRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fileId = null,Object? path = null,Object? thumbPath = null,Object? width = null,Object? height = null,}) {
  return _then(_DeliverySampleRef(
fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,thumbPath: null == thumbPath ? _self.thumbPath : thumbPath // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$DeliveryDecision {

 String get kind; String? get note; List<DeliveryPhotoNote> get photoNotes; DateTime get at; bool get auto; bool get extra;
/// Create a copy of DeliveryDecision
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeliveryDecisionCopyWith<DeliveryDecision> get copyWith => _$DeliveryDecisionCopyWithImpl<DeliveryDecision>(this as DeliveryDecision, _$identity);

  /// Serializes this DeliveryDecision to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeliveryDecision;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliveryDecision&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.note, _this.note) || other.note == _this.note)&&const DeepCollectionEquality().equals(other.photoNotes, _this.photoNotes)&&(identical(other.at, _this.at) || other.at == _this.at)&&(identical(other.auto, _this.auto) || other.auto == _this.auto)&&(identical(other.extra, _this.extra) || other.extra == _this.extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeliveryDecision;
  return Object.hash(runtimeType,_this.kind,_this.note,const DeepCollectionEquality().hash(_this.photoNotes),_this.at,_this.auto,_this.extra);
}

@override
String toString() {
  final _this = this as DeliveryDecision;
  return 'DeliveryDecision(kind: ${_this.kind}, note: ${_this.note}, photoNotes: ${_this.photoNotes}, at: ${_this.at}, auto: ${_this.auto}, extra: ${_this.extra})';
}


}

/// @nodoc
abstract mixin class $DeliveryDecisionCopyWith<$Res>  {
  factory $DeliveryDecisionCopyWith(DeliveryDecision value, $Res Function(DeliveryDecision) _then) = _$DeliveryDecisionCopyWithImpl;
@useResult
$Res call({
 String kind, String? note, List<DeliveryPhotoNote> photoNotes, DateTime at, bool auto, bool extra
});




}
/// @nodoc
class _$DeliveryDecisionCopyWithImpl<$Res>
    implements $DeliveryDecisionCopyWith<$Res> {
  _$DeliveryDecisionCopyWithImpl(this._self, this._then);

  final DeliveryDecision _self;
  final $Res Function(DeliveryDecision) _then;

/// Create a copy of DeliveryDecision
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? note = freezed,Object? photoNotes = null,Object? at = null,Object? auto = null,Object? extra = null,}) {
  return _then(DeliveryDecision(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,photoNotes: null == photoNotes ? _self.photoNotes : photoNotes // ignore: cast_nullable_to_non_nullable
as List<DeliveryPhotoNote>,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,auto: null == auto ? _self.auto : auto // ignore: cast_nullable_to_non_nullable
as bool,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DeliveryDecision].
extension DeliveryDecisionPatterns on DeliveryDecision {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeliveryDecision value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeliveryDecision() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeliveryDecision value)  $default,){
final _that = this;
switch (_that) {
case _DeliveryDecision():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeliveryDecision value)?  $default,){
final _that = this;
switch (_that) {
case _DeliveryDecision() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String? note,  List<DeliveryPhotoNote> photoNotes,  DateTime at,  bool auto,  bool extra)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeliveryDecision() when $default != null:
return $default(_that.kind,_that.note,_that.photoNotes,_that.at,_that.auto,_that.extra);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String? note,  List<DeliveryPhotoNote> photoNotes,  DateTime at,  bool auto,  bool extra)  $default,) {final _that = this;
switch (_that) {
case _DeliveryDecision():
return $default(_that.kind,_that.note,_that.photoNotes,_that.at,_that.auto,_that.extra);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String? note,  List<DeliveryPhotoNote> photoNotes,  DateTime at,  bool auto,  bool extra)?  $default,) {final _that = this;
switch (_that) {
case _DeliveryDecision() when $default != null:
return $default(_that.kind,_that.note,_that.photoNotes,_that.at,_that.auto,_that.extra);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeliveryDecision implements DeliveryDecision {
  const _DeliveryDecision({required this.kind, this.note,  List<DeliveryPhotoNote> photoNotes = const <DeliveryPhotoNote>[], required this.at, this.auto = false, this.extra = false}): _photoNotes = photoNotes;
  factory _DeliveryDecision.fromJson(Map<String, dynamic> json) => _$DeliveryDecisionFromJson(json);

@override final  String kind;
@override final  String? note;
 final  List<DeliveryPhotoNote> _photoNotes;
@override@JsonKey() List<DeliveryPhotoNote> get photoNotes {
  if (_photoNotes is EqualUnmodifiableListView) return _photoNotes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photoNotes);
}

@override final  DateTime at;
@override@JsonKey() final  bool auto;
@override@JsonKey() final  bool extra;

/// Create a copy of DeliveryDecision
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeliveryDecisionCopyWith<_DeliveryDecision> get copyWith => __$DeliveryDecisionCopyWithImpl<_DeliveryDecision>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeliveryDecisionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeliveryDecision&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.note, note) || other.note == note)&&const DeepCollectionEquality().equals(other.photoNotes, _photoNotes)&&(identical(other.at, at) || other.at == at)&&(identical(other.auto, auto) || other.auto == auto)&&(identical(other.extra, extra) || other.extra == extra));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,note,const DeepCollectionEquality().hash(_photoNotes),at,auto,extra);
}

@override
String toString() {
    return 'DeliveryDecision(kind: $kind, note: $note, photoNotes: $photoNotes, at: $at, auto: $auto, extra: $extra)';
}


}

/// @nodoc
abstract mixin class _$DeliveryDecisionCopyWith<$Res> implements $DeliveryDecisionCopyWith<$Res> {
  factory _$DeliveryDecisionCopyWith(_DeliveryDecision value, $Res Function(_DeliveryDecision) _then) = __$DeliveryDecisionCopyWithImpl;
@override @useResult
$Res call({
 String kind, String? note, List<DeliveryPhotoNote> photoNotes, DateTime at, bool auto, bool extra
});




}
/// @nodoc
class __$DeliveryDecisionCopyWithImpl<$Res>
    implements _$DeliveryDecisionCopyWith<$Res> {
  __$DeliveryDecisionCopyWithImpl(this._self, this._then);

  final _DeliveryDecision _self;
  final $Res Function(_DeliveryDecision) _then;

/// Create a copy of DeliveryDecision
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? note = freezed,Object? photoNotes = null,Object? at = null,Object? auto = null,Object? extra = null,}) {
  return _then(_DeliveryDecision(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,photoNotes: null == photoNotes ? _self._photoNotes : photoNotes // ignore: cast_nullable_to_non_nullable
as List<DeliveryPhotoNote>,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,auto: null == auto ? _self.auto : auto // ignore: cast_nullable_to_non_nullable
as bool,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$DeliveryPhotoNote {

 int get sampleIndex; String get note;
/// Create a copy of DeliveryPhotoNote
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeliveryPhotoNoteCopyWith<DeliveryPhotoNote> get copyWith => _$DeliveryPhotoNoteCopyWithImpl<DeliveryPhotoNote>(this as DeliveryPhotoNote, _$identity);

  /// Serializes this DeliveryPhotoNote to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeliveryPhotoNote;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliveryPhotoNote&&(identical(other.sampleIndex, _this.sampleIndex) || other.sampleIndex == _this.sampleIndex)&&(identical(other.note, _this.note) || other.note == _this.note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeliveryPhotoNote;
  return Object.hash(runtimeType,_this.sampleIndex,_this.note);
}

@override
String toString() {
  final _this = this as DeliveryPhotoNote;
  return 'DeliveryPhotoNote(sampleIndex: ${_this.sampleIndex}, note: ${_this.note})';
}


}

/// @nodoc
abstract mixin class $DeliveryPhotoNoteCopyWith<$Res>  {
  factory $DeliveryPhotoNoteCopyWith(DeliveryPhotoNote value, $Res Function(DeliveryPhotoNote) _then) = _$DeliveryPhotoNoteCopyWithImpl;
@useResult
$Res call({
 int sampleIndex, String note
});




}
/// @nodoc
class _$DeliveryPhotoNoteCopyWithImpl<$Res>
    implements $DeliveryPhotoNoteCopyWith<$Res> {
  _$DeliveryPhotoNoteCopyWithImpl(this._self, this._then);

  final DeliveryPhotoNote _self;
  final $Res Function(DeliveryPhotoNote) _then;

/// Create a copy of DeliveryPhotoNote
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sampleIndex = null,Object? note = null,}) {
  return _then(DeliveryPhotoNote(
sampleIndex: null == sampleIndex ? _self.sampleIndex : sampleIndex // ignore: cast_nullable_to_non_nullable
as int,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [DeliveryPhotoNote].
extension DeliveryPhotoNotePatterns on DeliveryPhotoNote {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeliveryPhotoNote value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeliveryPhotoNote() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeliveryPhotoNote value)  $default,){
final _that = this;
switch (_that) {
case _DeliveryPhotoNote():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeliveryPhotoNote value)?  $default,){
final _that = this;
switch (_that) {
case _DeliveryPhotoNote() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int sampleIndex,  String note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeliveryPhotoNote() when $default != null:
return $default(_that.sampleIndex,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int sampleIndex,  String note)  $default,) {final _that = this;
switch (_that) {
case _DeliveryPhotoNote():
return $default(_that.sampleIndex,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int sampleIndex,  String note)?  $default,) {final _that = this;
switch (_that) {
case _DeliveryPhotoNote() when $default != null:
return $default(_that.sampleIndex,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeliveryPhotoNote implements DeliveryPhotoNote {
  const _DeliveryPhotoNote({required this.sampleIndex, required this.note});
  factory _DeliveryPhotoNote.fromJson(Map<String, dynamic> json) => _$DeliveryPhotoNoteFromJson(json);

@override final  int sampleIndex;
@override final  String note;

/// Create a copy of DeliveryPhotoNote
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeliveryPhotoNoteCopyWith<_DeliveryPhotoNote> get copyWith => __$DeliveryPhotoNoteCopyWithImpl<_DeliveryPhotoNote>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeliveryPhotoNoteToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeliveryPhotoNote&&(identical(other.sampleIndex, sampleIndex) || other.sampleIndex == sampleIndex)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sampleIndex,note);
}

@override
String toString() {
    return 'DeliveryPhotoNote(sampleIndex: $sampleIndex, note: $note)';
}


}

/// @nodoc
abstract mixin class _$DeliveryPhotoNoteCopyWith<$Res> implements $DeliveryPhotoNoteCopyWith<$Res> {
  factory _$DeliveryPhotoNoteCopyWith(_DeliveryPhotoNote value, $Res Function(_DeliveryPhotoNote) _then) = __$DeliveryPhotoNoteCopyWithImpl;
@override @useResult
$Res call({
 int sampleIndex, String note
});




}
/// @nodoc
class __$DeliveryPhotoNoteCopyWithImpl<$Res>
    implements _$DeliveryPhotoNoteCopyWith<$Res> {
  __$DeliveryPhotoNoteCopyWithImpl(this._self, this._then);

  final _DeliveryPhotoNote _self;
  final $Res Function(_DeliveryPhotoNote) _then;

/// Create a copy of DeliveryPhotoNote
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sampleIndex = null,Object? note = null,}) {
  return _then(_DeliveryPhotoNote(
sampleIndex: null == sampleIndex ? _self.sampleIndex : sampleIndex // ignore: cast_nullable_to_non_nullable
as int,note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$DeliveryRound {

 String get bookingId; int get round; List<DeliverySampleRef> get samples; int get photoCount; String get linkHost; String? get note; DateTime get submittedAt; String get submittedBy; DeliveryDecision? get decision;
/// Create a copy of DeliveryRound
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeliveryRoundCopyWith<DeliveryRound> get copyWith => _$DeliveryRoundCopyWithImpl<DeliveryRound>(this as DeliveryRound, _$identity);

  /// Serializes this DeliveryRound to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeliveryRound;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliveryRound&&(identical(other.bookingId, _this.bookingId) || other.bookingId == _this.bookingId)&&(identical(other.round, _this.round) || other.round == _this.round)&&const DeepCollectionEquality().equals(other.samples, _this.samples)&&(identical(other.photoCount, _this.photoCount) || other.photoCount == _this.photoCount)&&(identical(other.linkHost, _this.linkHost) || other.linkHost == _this.linkHost)&&(identical(other.note, _this.note) || other.note == _this.note)&&(identical(other.submittedAt, _this.submittedAt) || other.submittedAt == _this.submittedAt)&&(identical(other.submittedBy, _this.submittedBy) || other.submittedBy == _this.submittedBy)&&(identical(other.decision, _this.decision) || other.decision == _this.decision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeliveryRound;
  return Object.hash(runtimeType,_this.bookingId,_this.round,const DeepCollectionEquality().hash(_this.samples),_this.photoCount,_this.linkHost,_this.note,_this.submittedAt,_this.submittedBy,_this.decision);
}

@override
String toString() {
  final _this = this as DeliveryRound;
  return 'DeliveryRound(bookingId: ${_this.bookingId}, round: ${_this.round}, samples: ${_this.samples}, photoCount: ${_this.photoCount}, linkHost: ${_this.linkHost}, note: ${_this.note}, submittedAt: ${_this.submittedAt}, submittedBy: ${_this.submittedBy}, decision: ${_this.decision})';
}


}

/// @nodoc
abstract mixin class $DeliveryRoundCopyWith<$Res>  {
  factory $DeliveryRoundCopyWith(DeliveryRound value, $Res Function(DeliveryRound) _then) = _$DeliveryRoundCopyWithImpl;
@useResult
$Res call({
 String bookingId, int round, List<DeliverySampleRef> samples, int photoCount, String linkHost, String? note, DateTime submittedAt, String submittedBy, DeliveryDecision? decision
});


$DeliveryDecisionCopyWith<$Res>? get decision;

}
/// @nodoc
class _$DeliveryRoundCopyWithImpl<$Res>
    implements $DeliveryRoundCopyWith<$Res> {
  _$DeliveryRoundCopyWithImpl(this._self, this._then);

  final DeliveryRound _self;
  final $Res Function(DeliveryRound) _then;

/// Create a copy of DeliveryRound
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookingId = null,Object? round = null,Object? samples = null,Object? photoCount = null,Object? linkHost = null,Object? note = freezed,Object? submittedAt = null,Object? submittedBy = null,Object? decision = freezed,}) {
  return _then(DeliveryRound(
bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,samples: null == samples ? _self.samples : samples // ignore: cast_nullable_to_non_nullable
as List<DeliverySampleRef>,photoCount: null == photoCount ? _self.photoCount : photoCount // ignore: cast_nullable_to_non_nullable
as int,linkHost: null == linkHost ? _self.linkHost : linkHost // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,submittedAt: null == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime,submittedBy: null == submittedBy ? _self.submittedBy : submittedBy // ignore: cast_nullable_to_non_nullable
as String,decision: freezed == decision ? _self.decision : decision // ignore: cast_nullable_to_non_nullable
as DeliveryDecision?,
  ));
}
/// Create a copy of DeliveryRound
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeliveryDecisionCopyWith<$Res>? get decision {
    if (_self.decision == null) {
    return null;
  }

  return $DeliveryDecisionCopyWith<$Res>(_self.decision!, (value) {
    return _then(_self.copyWith(decision: value));
  });
}
}


/// Adds pattern-matching-related methods to [DeliveryRound].
extension DeliveryRoundPatterns on DeliveryRound {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeliveryRound value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeliveryRound() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeliveryRound value)  $default,){
final _that = this;
switch (_that) {
case _DeliveryRound():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeliveryRound value)?  $default,){
final _that = this;
switch (_that) {
case _DeliveryRound() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String bookingId,  int round,  List<DeliverySampleRef> samples,  int photoCount,  String linkHost,  String? note,  DateTime submittedAt,  String submittedBy,  DeliveryDecision? decision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeliveryRound() when $default != null:
return $default(_that.bookingId,_that.round,_that.samples,_that.photoCount,_that.linkHost,_that.note,_that.submittedAt,_that.submittedBy,_that.decision);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String bookingId,  int round,  List<DeliverySampleRef> samples,  int photoCount,  String linkHost,  String? note,  DateTime submittedAt,  String submittedBy,  DeliveryDecision? decision)  $default,) {final _that = this;
switch (_that) {
case _DeliveryRound():
return $default(_that.bookingId,_that.round,_that.samples,_that.photoCount,_that.linkHost,_that.note,_that.submittedAt,_that.submittedBy,_that.decision);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String bookingId,  int round,  List<DeliverySampleRef> samples,  int photoCount,  String linkHost,  String? note,  DateTime submittedAt,  String submittedBy,  DeliveryDecision? decision)?  $default,) {final _that = this;
switch (_that) {
case _DeliveryRound() when $default != null:
return $default(_that.bookingId,_that.round,_that.samples,_that.photoCount,_that.linkHost,_that.note,_that.submittedAt,_that.submittedBy,_that.decision);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeliveryRound implements DeliveryRound {
  const _DeliveryRound({required this.bookingId, required this.round, required  List<DeliverySampleRef> samples, required this.photoCount, required this.linkHost, this.note, required this.submittedAt, required this.submittedBy, this.decision}): _samples = samples;
  factory _DeliveryRound.fromJson(Map<String, dynamic> json) => _$DeliveryRoundFromJson(json);

@override final  String bookingId;
@override final  int round;
 final  List<DeliverySampleRef> _samples;
@override List<DeliverySampleRef> get samples {
  if (_samples is EqualUnmodifiableListView) return _samples;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_samples);
}

@override final  int photoCount;
@override final  String linkHost;
@override final  String? note;
@override final  DateTime submittedAt;
@override final  String submittedBy;
@override final  DeliveryDecision? decision;

/// Create a copy of DeliveryRound
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeliveryRoundCopyWith<_DeliveryRound> get copyWith => __$DeliveryRoundCopyWithImpl<_DeliveryRound>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeliveryRoundToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeliveryRound&&(identical(other.bookingId, bookingId) || other.bookingId == bookingId)&&(identical(other.round, round) || other.round == round)&&const DeepCollectionEquality().equals(other.samples, _samples)&&(identical(other.photoCount, photoCount) || other.photoCount == photoCount)&&(identical(other.linkHost, linkHost) || other.linkHost == linkHost)&&(identical(other.note, note) || other.note == note)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.submittedBy, submittedBy) || other.submittedBy == submittedBy)&&(identical(other.decision, decision) || other.decision == decision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,bookingId,round,const DeepCollectionEquality().hash(_samples),photoCount,linkHost,note,submittedAt,submittedBy,decision);
}

@override
String toString() {
    return 'DeliveryRound(bookingId: $bookingId, round: $round, samples: $samples, photoCount: $photoCount, linkHost: $linkHost, note: $note, submittedAt: $submittedAt, submittedBy: $submittedBy, decision: $decision)';
}


}

/// @nodoc
abstract mixin class _$DeliveryRoundCopyWith<$Res> implements $DeliveryRoundCopyWith<$Res> {
  factory _$DeliveryRoundCopyWith(_DeliveryRound value, $Res Function(_DeliveryRound) _then) = __$DeliveryRoundCopyWithImpl;
@override @useResult
$Res call({
 String bookingId, int round, List<DeliverySampleRef> samples, int photoCount, String linkHost, String? note, DateTime submittedAt, String submittedBy, DeliveryDecision? decision
});


@override $DeliveryDecisionCopyWith<$Res>? get decision;

}
/// @nodoc
class __$DeliveryRoundCopyWithImpl<$Res>
    implements _$DeliveryRoundCopyWith<$Res> {
  __$DeliveryRoundCopyWithImpl(this._self, this._then);

  final _DeliveryRound _self;
  final $Res Function(_DeliveryRound) _then;

/// Create a copy of DeliveryRound
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookingId = null,Object? round = null,Object? samples = null,Object? photoCount = null,Object? linkHost = null,Object? note = freezed,Object? submittedAt = null,Object? submittedBy = null,Object? decision = freezed,}) {
  return _then(_DeliveryRound(
bookingId: null == bookingId ? _self.bookingId : bookingId // ignore: cast_nullable_to_non_nullable
as String,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,samples: null == samples ? _self._samples : samples // ignore: cast_nullable_to_non_nullable
as List<DeliverySampleRef>,photoCount: null == photoCount ? _self.photoCount : photoCount // ignore: cast_nullable_to_non_nullable
as int,linkHost: null == linkHost ? _self.linkHost : linkHost // ignore: cast_nullable_to_non_nullable
as String,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,submittedAt: null == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime,submittedBy: null == submittedBy ? _self.submittedBy : submittedBy // ignore: cast_nullable_to_non_nullable
as String,decision: freezed == decision ? _self.decision : decision // ignore: cast_nullable_to_non_nullable
as DeliveryDecision?,
  ));
}

/// Create a copy of DeliveryRound
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DeliveryDecisionCopyWith<$Res>? get decision {
    if (_self.decision == null) {
    return null;
  }

  return $DeliveryDecisionCopyWith<$Res>(_self.decision!, (value) {
    return _then(_self.copyWith(decision: value));
  });
}
}


/// @nodoc
mixin _$DeliveryLink {

 String get link; int get round; DateTime? get unlockedAt;
/// Create a copy of DeliveryLink
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeliveryLinkCopyWith<DeliveryLink> get copyWith => _$DeliveryLinkCopyWithImpl<DeliveryLink>(this as DeliveryLink, _$identity);

  /// Serializes this DeliveryLink to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DeliveryLink;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeliveryLink&&(identical(other.link, _this.link) || other.link == _this.link)&&(identical(other.round, _this.round) || other.round == _this.round)&&(identical(other.unlockedAt, _this.unlockedAt) || other.unlockedAt == _this.unlockedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DeliveryLink;
  return Object.hash(runtimeType,_this.link,_this.round,_this.unlockedAt);
}

@override
String toString() {
  final _this = this as DeliveryLink;
  return 'DeliveryLink(link: ${_this.link}, round: ${_this.round}, unlockedAt: ${_this.unlockedAt})';
}


}

/// @nodoc
abstract mixin class $DeliveryLinkCopyWith<$Res>  {
  factory $DeliveryLinkCopyWith(DeliveryLink value, $Res Function(DeliveryLink) _then) = _$DeliveryLinkCopyWithImpl;
@useResult
$Res call({
 String link, int round, DateTime? unlockedAt
});




}
/// @nodoc
class _$DeliveryLinkCopyWithImpl<$Res>
    implements $DeliveryLinkCopyWith<$Res> {
  _$DeliveryLinkCopyWithImpl(this._self, this._then);

  final DeliveryLink _self;
  final $Res Function(DeliveryLink) _then;

/// Create a copy of DeliveryLink
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? link = null,Object? round = null,Object? unlockedAt = freezed,}) {
  return _then(DeliveryLink(
link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,unlockedAt: freezed == unlockedAt ? _self.unlockedAt : unlockedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [DeliveryLink].
extension DeliveryLinkPatterns on DeliveryLink {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeliveryLink value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeliveryLink() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeliveryLink value)  $default,){
final _that = this;
switch (_that) {
case _DeliveryLink():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeliveryLink value)?  $default,){
final _that = this;
switch (_that) {
case _DeliveryLink() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String link,  int round,  DateTime? unlockedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeliveryLink() when $default != null:
return $default(_that.link,_that.round,_that.unlockedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String link,  int round,  DateTime? unlockedAt)  $default,) {final _that = this;
switch (_that) {
case _DeliveryLink():
return $default(_that.link,_that.round,_that.unlockedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String link,  int round,  DateTime? unlockedAt)?  $default,) {final _that = this;
switch (_that) {
case _DeliveryLink() when $default != null:
return $default(_that.link,_that.round,_that.unlockedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeliveryLink implements DeliveryLink {
  const _DeliveryLink({required this.link, required this.round, this.unlockedAt});
  factory _DeliveryLink.fromJson(Map<String, dynamic> json) => _$DeliveryLinkFromJson(json);

@override final  String link;
@override final  int round;
@override final  DateTime? unlockedAt;

/// Create a copy of DeliveryLink
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeliveryLinkCopyWith<_DeliveryLink> get copyWith => __$DeliveryLinkCopyWithImpl<_DeliveryLink>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeliveryLinkToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeliveryLink&&(identical(other.link, link) || other.link == link)&&(identical(other.round, round) || other.round == round)&&(identical(other.unlockedAt, unlockedAt) || other.unlockedAt == unlockedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,link,round,unlockedAt);
}

@override
String toString() {
    return 'DeliveryLink(link: $link, round: $round, unlockedAt: $unlockedAt)';
}


}

/// @nodoc
abstract mixin class _$DeliveryLinkCopyWith<$Res> implements $DeliveryLinkCopyWith<$Res> {
  factory _$DeliveryLinkCopyWith(_DeliveryLink value, $Res Function(_DeliveryLink) _then) = __$DeliveryLinkCopyWithImpl;
@override @useResult
$Res call({
 String link, int round, DateTime? unlockedAt
});




}
/// @nodoc
class __$DeliveryLinkCopyWithImpl<$Res>
    implements _$DeliveryLinkCopyWith<$Res> {
  __$DeliveryLinkCopyWithImpl(this._self, this._then);

  final _DeliveryLink _self;
  final $Res Function(_DeliveryLink) _then;

/// Create a copy of DeliveryLink
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? link = null,Object? round = null,Object? unlockedAt = freezed,}) {
  return _then(_DeliveryLink(
link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,unlockedAt: freezed == unlockedAt ? _self.unlockedAt : unlockedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$StagedSample {

 String get fileId; SampleStatus get status; String? get path; String? get thumbPath; String? get failure;
/// Create a copy of StagedSample
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StagedSampleCopyWith<StagedSample> get copyWith => _$StagedSampleCopyWithImpl<StagedSample>(this as StagedSample, _$identity);

  /// Serializes this StagedSample to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as StagedSample;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StagedSample&&(identical(other.fileId, _this.fileId) || other.fileId == _this.fileId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.thumbPath, _this.thumbPath) || other.thumbPath == _this.thumbPath)&&(identical(other.failure, _this.failure) || other.failure == _this.failure));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as StagedSample;
  return Object.hash(runtimeType,_this.fileId,_this.status,_this.path,_this.thumbPath,_this.failure);
}

@override
String toString() {
  final _this = this as StagedSample;
  return 'StagedSample(fileId: ${_this.fileId}, status: ${_this.status}, path: ${_this.path}, thumbPath: ${_this.thumbPath}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $StagedSampleCopyWith<$Res>  {
  factory $StagedSampleCopyWith(StagedSample value, $Res Function(StagedSample) _then) = _$StagedSampleCopyWithImpl;
@useResult
$Res call({
 String fileId, SampleStatus status, String? path, String? thumbPath, String? failure
});




}
/// @nodoc
class _$StagedSampleCopyWithImpl<$Res>
    implements $StagedSampleCopyWith<$Res> {
  _$StagedSampleCopyWithImpl(this._self, this._then);

  final StagedSample _self;
  final $Res Function(StagedSample) _then;

/// Create a copy of StagedSample
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fileId = null,Object? status = null,Object? path = freezed,Object? thumbPath = freezed,Object? failure = freezed,}) {
  return _then(StagedSample(
fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SampleStatus,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,thumbPath: freezed == thumbPath ? _self.thumbPath : thumbPath // ignore: cast_nullable_to_non_nullable
as String?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [StagedSample].
extension StagedSamplePatterns on StagedSample {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StagedSample value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StagedSample() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StagedSample value)  $default,){
final _that = this;
switch (_that) {
case _StagedSample():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StagedSample value)?  $default,){
final _that = this;
switch (_that) {
case _StagedSample() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fileId,  SampleStatus status,  String? path,  String? thumbPath,  String? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StagedSample() when $default != null:
return $default(_that.fileId,_that.status,_that.path,_that.thumbPath,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fileId,  SampleStatus status,  String? path,  String? thumbPath,  String? failure)  $default,) {final _that = this;
switch (_that) {
case _StagedSample():
return $default(_that.fileId,_that.status,_that.path,_that.thumbPath,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fileId,  SampleStatus status,  String? path,  String? thumbPath,  String? failure)?  $default,) {final _that = this;
switch (_that) {
case _StagedSample() when $default != null:
return $default(_that.fileId,_that.status,_that.path,_that.thumbPath,_that.failure);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StagedSample implements StagedSample {
  const _StagedSample({required this.fileId, required this.status, this.path, this.thumbPath, this.failure});
  factory _StagedSample.fromJson(Map<String, dynamic> json) => _$StagedSampleFromJson(json);

@override final  String fileId;
@override final  SampleStatus status;
@override final  String? path;
@override final  String? thumbPath;
@override final  String? failure;

/// Create a copy of StagedSample
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StagedSampleCopyWith<_StagedSample> get copyWith => __$StagedSampleCopyWithImpl<_StagedSample>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StagedSampleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _StagedSample&&(identical(other.fileId, fileId) || other.fileId == fileId)&&(identical(other.status, status) || other.status == status)&&(identical(other.path, path) || other.path == path)&&(identical(other.thumbPath, thumbPath) || other.thumbPath == thumbPath)&&(identical(other.failure, failure) || other.failure == failure));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,fileId,status,path,thumbPath,failure);
}

@override
String toString() {
    return 'StagedSample(fileId: $fileId, status: $status, path: $path, thumbPath: $thumbPath, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$StagedSampleCopyWith<$Res> implements $StagedSampleCopyWith<$Res> {
  factory _$StagedSampleCopyWith(_StagedSample value, $Res Function(_StagedSample) _then) = __$StagedSampleCopyWithImpl;
@override @useResult
$Res call({
 String fileId, SampleStatus status, String? path, String? thumbPath, String? failure
});




}
/// @nodoc
class __$StagedSampleCopyWithImpl<$Res>
    implements _$StagedSampleCopyWith<$Res> {
  __$StagedSampleCopyWithImpl(this._self, this._then);

  final _StagedSample _self;
  final $Res Function(_StagedSample) _then;

/// Create a copy of StagedSample
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fileId = null,Object? status = null,Object? path = freezed,Object? thumbPath = freezed,Object? failure = freezed,}) {
  return _then(_StagedSample(
fileId: null == fileId ? _self.fileId : fileId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SampleStatus,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,thumbPath: freezed == thumbPath ? _self.thumbPath : thumbPath // ignore: cast_nullable_to_non_nullable
as String?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
