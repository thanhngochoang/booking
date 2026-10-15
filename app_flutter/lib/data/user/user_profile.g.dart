// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => _UserProfile(
  uid: json['uid'] as String,
  role: $enumDecodeNullable(_$UserRoleEnumMap, json['role']),
  displayName: json['displayName'] as String,
  avatarUrl: json['avatarUrl'] as String?,
  email: json['email'] as String?,
);

Map<String, dynamic> _$UserProfileToJson(_UserProfile instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'role': _$UserRoleEnumMap[instance.role],
      'displayName': instance.displayName,
      'avatarUrl': instance.avatarUrl,
      'email': instance.email,
    };

const _$UserRoleEnumMap = {
  UserRole.customer: 'customer',
  UserRole.photographer: 'photographer',
};
