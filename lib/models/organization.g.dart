// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Organization _$OrganizationFromJson(Map<String, dynamic> json) =>
    _Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      categories: (json['categories'] as List<dynamic>)
          .map((e) => $enumDecode(_$OrgCategoryEnumMap, e))
          .toList(),
      campus: $enumDecode(_$CampusEnumMap, json['campus']),
      logoEmoji: json['logoEmoji'] as String,
      instagramUrl: json['instagramUrl'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
      representativeId: json['representativeId'] as String?,
      status: json['status'] as String? ?? 'pending',
      proofImageUrl: json['proofImageUrl'] as String?,
      verifiedAt: json['verifiedAt'] == null
          ? null
          : DateTime.parse(json['verifiedAt'] as String),
      isOfficial: json['isOfficial'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$OrganizationToJson(_Organization instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'categories': instance.categories
          .map((e) => _$OrgCategoryEnumMap[e]!)
          .toList(),
      'campus': _$CampusEnumMap[instance.campus]!,
      'logoEmoji': instance.logoEmoji,
      'instagramUrl': instance.instagramUrl,
      'logoUrl': instance.logoUrl,
      'representativeId': instance.representativeId,
      'status': instance.status,
      'proofImageUrl': instance.proofImageUrl,
      'verifiedAt': instance.verifiedAt?.toIso8601String(),
      'isOfficial': instance.isOfficial,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$OrgCategoryEnumMap = {
  OrgCategory.all: 'all',
  OrgCategory.sports: 'sports',
  OrgCategory.culture: 'culture',
  OrgCategory.academic: 'academic',
  OrgCategory.volunteer: 'volunteer',
  OrgCategory.music: 'music',
  OrgCategory.varsity: 'varsity',
  OrgCategory.tennis: 'tennis',
  OrgCategory.event: 'event',
  OrgCategory.sportsCircle: 'sportsCircle',
  OrgCategory.it: 'it',
  OrgCategory.international: 'international',
  OrgCategory.beginner: 'beginner',
  OrgCategory.competitive: 'competitive',
  OrgCategory.enjoy: 'enjoy',
  OrgCategory.joint: 'joint',
  OrgCategory.intercollege: 'intercollege',
  OrgCategory.homey: 'homey',
  OrgCategory.large: 'large',
  OrgCategory.female: 'female',
  OrgCategory.male: 'male',
};

const _$CampusEnumMap = {
  Campus.imadegawa: 'imadegawa',
  Campus.kyotanabe: 'kyotanabe',
  Campus.both: 'both',
};
