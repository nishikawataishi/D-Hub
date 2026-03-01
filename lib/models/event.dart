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

  const Event({
    required this.id,
    required this.organization,
    required this.title,
    required this.description,
    required this.startAt,
    required this.campus,
  });

  Event copyWith({
    String? id,
    Organization? organization,
    String? title,
    String? description,
    DateTime? startAt,
    Campus? campus,
  }) {
    return Event(
      id: id ?? this.id,
      organization: organization ?? this.organization,
      title: title ?? this.title,
      description: description ?? this.description,
      startAt: startAt ?? this.startAt,
      campus: campus ?? this.campus,
    );
  }

  factory Event.fromFirestore(Map<String, dynamic> data, String id) {
    // 互換性と表示のため、organizationの各フィールドから簡易的なOrganizationオブジェクトを復元する
    final org = Organization(
      id: data['organizationId'] as String? ?? '',
      name: data['organizationName'] as String? ?? 'Unknown',
      logoEmoji: data['organizationEmoji'] as String? ?? '🏫',
      description: '',
      category: OrgCategory.fromString(
        data['organizationCategory'] as String? ?? '',
      ),
      campus: Campus.both,
    );

    final startAtTimestamp = data['startAt'] as Timestamp?;

    return Event(
      id: id,
      organization: org,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      startAt: startAtTimestamp?.toDate() ?? DateTime.now(),
      campus: Campus.fromString(data['campus'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationId': organization.id,
      'organizationName': organization.name,
      'organizationEmoji': organization.logoEmoji,
      'organizationCategory': organization.category.name,
      'title': title,
      'description': description,
      'startAt': Timestamp.fromDate(startAt),
      'campus': campus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
