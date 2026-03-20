import 'package:cloud_firestore/cloud_firestore.dart';
import 'campus.dart';
import 'organization.dart';

/// イベントデータモデル
class Event {
  final String id;
  final Organization organization;
  final String title;
  final String description;
  final DateTime startAt;
  final Campus campus;
  final String? organizationLogoUrl;
  final String? fee;           // 参加費
  final String? capacity;      // 人数
  final String? location;      // 場所
  final String? groupLineUrl;  // グループLINE URL

  const Event({
    required this.id,
    required this.organization,
    required this.title,
    required this.description,
    required this.startAt,
    required this.campus,
    this.organizationLogoUrl,
    this.fee,
    this.capacity,
    this.location,
    this.groupLineUrl,
  });

  Event copyWith({
    String? id,
    Organization? organization,
    String? title,
    String? description,
    DateTime? startAt,
    Campus? campus,
    String? organizationLogoUrl,
    String? fee,
    String? capacity,
    String? location,
    String? groupLineUrl,
  }) {
    return Event(
      id: id ?? this.id,
      organization: organization ?? this.organization,
      title: title ?? this.title,
      description: description ?? this.description,
      startAt: startAt ?? this.startAt,
      campus: campus ?? this.campus,
      organizationLogoUrl: organizationLogoUrl ?? this.organizationLogoUrl,
      fee: fee ?? this.fee,
      capacity: capacity ?? this.capacity,
      location: location ?? this.location,
      groupLineUrl: groupLineUrl ?? this.groupLineUrl,
    );
  }

  factory Event.fromFirestore(Map<String, dynamic> data, String id) {
    // 互換性と表示のため、organizationの各フィールドから簡易的なOrganizationオブジェクトを復元する
    final org = Organization(
      id: data['organizationId'] as String? ?? '',
      name: data['organizationName'] as String? ?? 'Unknown',
      logoEmoji: data['organizationEmoji'] as String? ?? '🏫',
      description: '',
      categories:
          (data['categories'] as List?)
              ?.map((e) => OrgCategory.fromString(e as String))
              .toList() ??
          [
            OrgCategory.fromString(
              data['organizationCategory'] as String? ?? '',
            ),
          ],
      campus: Campus.both,
      logoUrl: data['organizationLogoUrl'] as String?,
    );

    final startAtTimestamp = data['startAt'] as Timestamp?;

    return Event(
      id: id,
      organization: org,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      startAt: startAtTimestamp?.toDate() ?? DateTime.now(),
      campus: Campus.fromString(data['campus'] as String? ?? ''),
      organizationLogoUrl: data['organizationLogoUrl'] as String?,
      fee: data['fee'] as String?,
      capacity: data['capacity'] as String?,
      location: data['location'] as String?,
      groupLineUrl: data['groupLineUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organization.id,
      'organizationName': organization.name,
      'organizationEmoji': organization.logoEmoji,
      'organizationCategory': organization.categories.isNotEmpty
          ? organization.categories.first.label
          : OrgCategory.all.label,
      'title': title,
      'description': description,
      'startAt': Timestamp.fromDate(startAt),
      'campus': campus.name,
      if (organizationLogoUrl != null)
        'organizationLogoUrl': organizationLogoUrl,
      'fee': fee,
      'capacity': capacity,
      'location': location,
      if (groupLineUrl != null && groupLineUrl!.isNotEmpty)
        'groupLineUrl': groupLineUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
