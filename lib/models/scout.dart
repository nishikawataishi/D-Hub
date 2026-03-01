import 'package:cloud_firestore/cloud_firestore.dart';

/// スカウトデータモデル
class Scout {
  final String id;
  final String targetUserId;
  final String organizationId;
  final String organizationName;
  final String organizationEmoji;
  final String organizationCategory;
  final String message;
  final bool isRead;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? organizationInstagramUrl;

  Scout({
    required this.id,
    required this.targetUserId,
    required this.organizationId,
    required this.organizationName,
    required this.organizationEmoji,
    required this.organizationCategory,
    required this.message,
    required this.isRead,
    required this.sentAt,
    this.readAt,
    this.organizationInstagramUrl,
  });

  /// FirestoreドキュメントからScoutモデルを生成
  factory Scout.fromFirestore(Map<String, dynamic> data, String id) {
    return Scout(
      id: id,
      targetUserId: data['targetUserId'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      organizationName: data['organizationName'] as String? ?? '',
      organizationEmoji: data['organizationEmoji'] as String? ?? '🏫',
      organizationCategory: data['organizationCategory'] as String? ?? '',
      message: data['message'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      organizationInstagramUrl: data['organizationInstagramUrl'] as String?,
    );
  }

  /// ScoutモデルをFirestore用Mapに変換
  Map<String, dynamic> toFirestore() {
    return {
      'targetUserId': targetUserId,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'organizationEmoji': organizationEmoji,
      'organizationCategory': organizationCategory,
      'message': message,
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'organizationInstagramUrl': organizationInstagramUrl,
    };
  }
}
