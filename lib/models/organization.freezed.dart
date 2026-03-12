// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organization.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Organization {

 String get id; String get name; String get description; List<OrgCategory> get categories; Campus get campus; String get logoEmoji; String get instagramUrl; String? get logoUrl;// 追加フィールド
 String? get representativeId; String get status;// 'pending', 'verified', 'rejected'
 String? get proofImageUrl; DateTime? get verifiedAt; bool get isOfficial; DateTime? get createdAt; List<String> get photoUrls;
/// Create a copy of Organization
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizationCopyWith<Organization> get copyWith => _$OrganizationCopyWithImpl<Organization>(this as Organization, _$identity);

  /// Serializes this Organization to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Organization&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.categories, categories)&&(identical(other.campus, campus) || other.campus == campus)&&(identical(other.logoEmoji, logoEmoji) || other.logoEmoji == logoEmoji)&&(identical(other.instagramUrl, instagramUrl) || other.instagramUrl == instagramUrl)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.representativeId, representativeId) || other.representativeId == representativeId)&&(identical(other.status, status) || other.status == status)&&(identical(other.proofImageUrl, proofImageUrl) || other.proofImageUrl == proofImageUrl)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt)&&(identical(other.isOfficial, isOfficial) || other.isOfficial == isOfficial)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.photoUrls, photoUrls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(categories),campus,logoEmoji,instagramUrl,logoUrl,representativeId,status,proofImageUrl,verifiedAt,isOfficial,createdAt,const DeepCollectionEquality().hash(photoUrls));

@override
String toString() {
  return 'Organization(id: $id, name: $name, description: $description, categories: $categories, campus: $campus, logoEmoji: $logoEmoji, instagramUrl: $instagramUrl, logoUrl: $logoUrl, representativeId: $representativeId, status: $status, proofImageUrl: $proofImageUrl, verifiedAt: $verifiedAt, isOfficial: $isOfficial, createdAt: $createdAt, photoUrls: $photoUrls)';
}


}

/// @nodoc
abstract mixin class $OrganizationCopyWith<$Res>  {
  factory $OrganizationCopyWith(Organization value, $Res Function(Organization) _then) = _$OrganizationCopyWithImpl;
@useResult
$Res call({
 String id, String name, String description, List<OrgCategory> categories, Campus campus, String logoEmoji, String instagramUrl, String? logoUrl, String? representativeId, String status, String? proofImageUrl, DateTime? verifiedAt, bool isOfficial, DateTime? createdAt, List<String> photoUrls
});




}
/// @nodoc
class _$OrganizationCopyWithImpl<$Res>
    implements $OrganizationCopyWith<$Res> {
  _$OrganizationCopyWithImpl(this._self, this._then);

  final Organization _self;
  final $Res Function(Organization) _then;

/// Create a copy of Organization
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? description = null,Object? categories = null,Object? campus = null,Object? logoEmoji = null,Object? instagramUrl = null,Object? logoUrl = freezed,Object? representativeId = freezed,Object? status = null,Object? proofImageUrl = freezed,Object? verifiedAt = freezed,Object? isOfficial = null,Object? createdAt = freezed,Object? photoUrls = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as List<OrgCategory>,campus: null == campus ? _self.campus : campus // ignore: cast_nullable_to_non_nullable
as Campus,logoEmoji: null == logoEmoji ? _self.logoEmoji : logoEmoji // ignore: cast_nullable_to_non_nullable
as String,instagramUrl: null == instagramUrl ? _self.instagramUrl : instagramUrl // ignore: cast_nullable_to_non_nullable
as String,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,representativeId: freezed == representativeId ? _self.representativeId : representativeId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,proofImageUrl: freezed == proofImageUrl ? _self.proofImageUrl : proofImageUrl // ignore: cast_nullable_to_non_nullable
as String?,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isOfficial: null == isOfficial ? _self.isOfficial : isOfficial // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,photoUrls: null == photoUrls ? _self.photoUrls : photoUrls // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Organization].
extension OrganizationPatterns on Organization {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Organization value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Organization() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Organization value)  $default,){
final _that = this;
switch (_that) {
case _Organization():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Organization value)?  $default,){
final _that = this;
switch (_that) {
case _Organization() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String description,  List<OrgCategory> categories,  Campus campus,  String logoEmoji,  String instagramUrl,  String? logoUrl,  String? representativeId,  String status,  String? proofImageUrl,  DateTime? verifiedAt,  bool isOfficial,  DateTime? createdAt,  List<String> photoUrls)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Organization() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.categories,_that.campus,_that.logoEmoji,_that.instagramUrl,_that.logoUrl,_that.representativeId,_that.status,_that.proofImageUrl,_that.verifiedAt,_that.isOfficial,_that.createdAt,_that.photoUrls);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String description,  List<OrgCategory> categories,  Campus campus,  String logoEmoji,  String instagramUrl,  String? logoUrl,  String? representativeId,  String status,  String? proofImageUrl,  DateTime? verifiedAt,  bool isOfficial,  DateTime? createdAt,  List<String> photoUrls)  $default,) {final _that = this;
switch (_that) {
case _Organization():
return $default(_that.id,_that.name,_that.description,_that.categories,_that.campus,_that.logoEmoji,_that.instagramUrl,_that.logoUrl,_that.representativeId,_that.status,_that.proofImageUrl,_that.verifiedAt,_that.isOfficial,_that.createdAt,_that.photoUrls);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String description,  List<OrgCategory> categories,  Campus campus,  String logoEmoji,  String instagramUrl,  String? logoUrl,  String? representativeId,  String status,  String? proofImageUrl,  DateTime? verifiedAt,  bool isOfficial,  DateTime? createdAt,  List<String> photoUrls)?  $default,) {final _that = this;
switch (_that) {
case _Organization() when $default != null:
return $default(_that.id,_that.name,_that.description,_that.categories,_that.campus,_that.logoEmoji,_that.instagramUrl,_that.logoUrl,_that.representativeId,_that.status,_that.proofImageUrl,_that.verifiedAt,_that.isOfficial,_that.createdAt,_that.photoUrls);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Organization extends Organization {
  const _Organization({required this.id, required this.name, required this.description, required final  List<OrgCategory> categories, required this.campus, required this.logoEmoji, this.instagramUrl = '', this.logoUrl, this.representativeId, this.status = 'pending', this.proofImageUrl, this.verifiedAt, this.isOfficial = false, this.createdAt, final  List<String> photoUrls = const []}): _categories = categories,_photoUrls = photoUrls,super._();
  factory _Organization.fromJson(Map<String, dynamic> json) => _$OrganizationFromJson(json);

@override final  String id;
@override final  String name;
@override final  String description;
 final  List<OrgCategory> _categories;
@override List<OrgCategory> get categories {
  if (_categories is EqualUnmodifiableListView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categories);
}

@override final  Campus campus;
@override final  String logoEmoji;
@override@JsonKey() final  String instagramUrl;
@override final  String? logoUrl;
// 追加フィールド
@override final  String? representativeId;
@override@JsonKey() final  String status;
// 'pending', 'verified', 'rejected'
@override final  String? proofImageUrl;
@override final  DateTime? verifiedAt;
@override@JsonKey() final  bool isOfficial;
@override final  DateTime? createdAt;
 final  List<String> _photoUrls;
@override@JsonKey() List<String> get photoUrls {
  if (_photoUrls is EqualUnmodifiableListView) return _photoUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photoUrls);
}


/// Create a copy of Organization
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizationCopyWith<_Organization> get copyWith => __$OrganizationCopyWithImpl<_Organization>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganizationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Organization&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._categories, _categories)&&(identical(other.campus, campus) || other.campus == campus)&&(identical(other.logoEmoji, logoEmoji) || other.logoEmoji == logoEmoji)&&(identical(other.instagramUrl, instagramUrl) || other.instagramUrl == instagramUrl)&&(identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl)&&(identical(other.representativeId, representativeId) || other.representativeId == representativeId)&&(identical(other.status, status) || other.status == status)&&(identical(other.proofImageUrl, proofImageUrl) || other.proofImageUrl == proofImageUrl)&&(identical(other.verifiedAt, verifiedAt) || other.verifiedAt == verifiedAt)&&(identical(other.isOfficial, isOfficial) || other.isOfficial == isOfficial)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._photoUrls, _photoUrls));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,description,const DeepCollectionEquality().hash(_categories),campus,logoEmoji,instagramUrl,logoUrl,representativeId,status,proofImageUrl,verifiedAt,isOfficial,createdAt,const DeepCollectionEquality().hash(_photoUrls));

@override
String toString() {
  return 'Organization(id: $id, name: $name, description: $description, categories: $categories, campus: $campus, logoEmoji: $logoEmoji, instagramUrl: $instagramUrl, logoUrl: $logoUrl, representativeId: $representativeId, status: $status, proofImageUrl: $proofImageUrl, verifiedAt: $verifiedAt, isOfficial: $isOfficial, createdAt: $createdAt, photoUrls: $photoUrls)';
}


}

/// @nodoc
abstract mixin class _$OrganizationCopyWith<$Res> implements $OrganizationCopyWith<$Res> {
  factory _$OrganizationCopyWith(_Organization value, $Res Function(_Organization) _then) = __$OrganizationCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String description, List<OrgCategory> categories, Campus campus, String logoEmoji, String instagramUrl, String? logoUrl, String? representativeId, String status, String? proofImageUrl, DateTime? verifiedAt, bool isOfficial, DateTime? createdAt, List<String> photoUrls
});




}
/// @nodoc
class __$OrganizationCopyWithImpl<$Res>
    implements _$OrganizationCopyWith<$Res> {
  __$OrganizationCopyWithImpl(this._self, this._then);

  final _Organization _self;
  final $Res Function(_Organization) _then;

/// Create a copy of Organization
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? description = null,Object? categories = null,Object? campus = null,Object? logoEmoji = null,Object? instagramUrl = null,Object? logoUrl = freezed,Object? representativeId = freezed,Object? status = null,Object? proofImageUrl = freezed,Object? verifiedAt = freezed,Object? isOfficial = null,Object? createdAt = freezed,Object? photoUrls = null,}) {
  return _then(_Organization(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as List<OrgCategory>,campus: null == campus ? _self.campus : campus // ignore: cast_nullable_to_non_nullable
as Campus,logoEmoji: null == logoEmoji ? _self.logoEmoji : logoEmoji // ignore: cast_nullable_to_non_nullable
as String,instagramUrl: null == instagramUrl ? _self.instagramUrl : instagramUrl // ignore: cast_nullable_to_non_nullable
as String,logoUrl: freezed == logoUrl ? _self.logoUrl : logoUrl // ignore: cast_nullable_to_non_nullable
as String?,representativeId: freezed == representativeId ? _self.representativeId : representativeId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,proofImageUrl: freezed == proofImageUrl ? _self.proofImageUrl : proofImageUrl // ignore: cast_nullable_to_non_nullable
as String?,verifiedAt: freezed == verifiedAt ? _self.verifiedAt : verifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isOfficial: null == isOfficial ? _self.isOfficial : isOfficial // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,photoUrls: null == photoUrls ? _self._photoUrls : photoUrls // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
