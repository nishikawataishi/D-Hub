import 'package:cloud_firestore/cloud_firestore.dart';
import 'scout_template.dart';

/// スカウトデータモデル
///
/// 本文は保存せず、定型文の [templateId] と埋め込む値だけを保持する。
/// 表示用の文章は [body] が組み立てる。
class Scout {
  final String id;
  final String targetUserId;
  final String organizationId;
  final String organizationName;
  final String organizationEmoji;
  final String organizationCategory;

  /// 使用した定型文の識別子。旧形式のドキュメントでは null
  final int? templateId;

  /// 定型文に埋め込む値（タグ名・イベント名・キャンパス・学年）
  final String? templateArg;

  /// [ScoutSlot.event] の定型文で参照しているイベントのID
  final String? templateEventId;

  /// 定型文導入以前に送信されたスカウトの本文。**新規送信では使用しない**
  final String? legacyMessage;

  final bool isRead;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? organizationInstagramUrl;
  final String? organizationGroupLineUrl;
  final String? organizationLogoUrl;
  final String? targetUserIconUrl;
  final String? targetUserName;

  Scout({
    required this.id,
    required this.targetUserId,
    required this.organizationId,
    required this.organizationName,
    required this.organizationEmoji,
    required this.organizationCategory,
    required this.isRead,
    required this.sentAt,
    this.templateId,
    this.templateArg,
    this.templateEventId,
    this.legacyMessage,
    this.readAt,
    this.organizationInstagramUrl,
    this.organizationGroupLineUrl,
    this.organizationLogoUrl,
    this.targetUserIconUrl,
    this.targetUserName,
  });

  /// 表示用の本文。
  ///
  /// 定型文から組み立てる。定型文導入前に送信されたスカウトだけは
  /// 保存済みの本文をそのまま表示する。
  String get body {
    final template = ScoutTemplate.byId(templateId);
    if (template != null) return template.render(templateArg);
    return legacyMessage ?? ScoutTemplate.generic.body;
  }

  /// FirestoreドキュメントからScoutモデルを生成
  factory Scout.fromFirestore(Map<String, dynamic> data, String id) {
    return Scout(
      id: id,
      targetUserId: data['targetUserId'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      organizationName: data['organizationName'] as String? ?? '',
      organizationEmoji: data['organizationEmoji'] as String? ?? '🏫',
      organizationCategory: data['organizationCategory'] as String? ?? '',
      templateId: data['templateId'] as int?,
      templateArg: data['templateArg'] as String?,
      templateEventId: data['templateEventId'] as String?,
      legacyMessage: data['message'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      organizationInstagramUrl: data['organizationInstagramUrl'] as String?,
      organizationGroupLineUrl: data['organizationGroupLineUrl'] as String?,
      organizationLogoUrl: data['organizationLogoUrl'] as String?,
      targetUserIconUrl: data['targetUserIconUrl'] as String?,
      targetUserName: data['targetUserName'] as String?,
    );
  }

  /// ScoutモデルをFirestore用Mapに変換
  ///
  /// `message` は書き出さない。Firestoreルールが許可するキーを
  /// ホワイトリストで制限しているため、含めると保存自体が拒否される。
  Map<String, dynamic> toFirestore() {
    return {
      'targetUserId': targetUserId,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'organizationEmoji': organizationEmoji,
      'organizationCategory': organizationCategory,
      'templateId': templateId,
      if (templateArg != null) 'templateArg': templateArg,
      if (templateEventId != null) 'templateEventId': templateEventId,
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'organizationInstagramUrl': organizationInstagramUrl,
      if (organizationGroupLineUrl != null && organizationGroupLineUrl!.isNotEmpty)
        'organizationGroupLineUrl': organizationGroupLineUrl,
      if (organizationLogoUrl != null)
        'organizationLogoUrl': organizationLogoUrl,
      if (targetUserIconUrl != null) 'targetUserIconUrl': targetUserIconUrl,
      if (targetUserName != null) 'targetUserName': targetUserName,
    };
  }
}
