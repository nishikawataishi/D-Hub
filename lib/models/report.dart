import 'package:cloud_firestore/cloud_firestore.dart';
import 'account_role.dart';

/// 通報の対象種別
///
/// [id] は Firestore に保存する値で、firestore.rules のホワイトリストと
/// 一致していなければ保存が拒否される。
enum ReportTargetType {
  user('user', '学生'),
  organization('organization', '団体');

  final String id;
  final String label;
  const ReportTargetType(this.id, this.label);

  static ReportTargetType fromId(String? id) {
    return ReportTargetType.values.firstWhere(
      (e) => e.id == id,
      orElse: () => ReportTargetType.user,
    );
  }
}

/// 通報理由
///
/// 利用規約 第6条（禁止事項）の各号に対応させている。
/// [id] は firestore.rules のホワイトリストと一致させること。
enum ReportReason {
  inappropriateContent('inappropriate_content', '不適切な写真・文章'),
  impersonation('impersonation', 'なりすまし・虚偽の情報'),
  harassment('harassment', '嫌がらせ・迷惑行為'),
  dating('dating', '交際・恋愛を目的とした利用'),
  spam('spam', 'スパム・無関係な勧誘'),
  other('other', 'その他');

  final String id;
  final String label;
  const ReportReason(this.id, this.label);

  static ReportReason fromId(String? id) {
    return ReportReason.values.firstWhere(
      (e) => e.id == id,
      orElse: () => ReportReason.other,
    );
  }
}

/// 通報データモデル
///
/// 利用規約 第7条に基づき、通報を行うと対象の投稿コンテンツが [snapshot] として
/// 運営に共有される。通報者の情報（[reporterId]）は運営だけが参照でき、
/// 通報された相手には開示されない（Firestoreルールで read を管理者に限定）。
class Report {
  final String id;
  final String reporterId;
  final AccountRole reporterRole;
  final ReportTargetType targetType;
  final String targetId;

  /// 通報時点の対象の表示名。対象が退会・改名しても運営が特定できるように保持する
  final String targetName;

  final ReportReason reason;

  /// 通報者が任意で書き添える補足（未入力なら空文字）
  final String detail;

  /// 通報時点の対象コンテンツ。運営が元の状態を確認するために保持する
  final Map<String, dynamic> snapshot;

  /// 'open'（未対応）または 'closed'（対応済み）
  final String status;

  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const Report({
    required this.id,
    required this.reporterId,
    required this.reporterRole,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.reason,
    required this.detail,
    required this.snapshot,
    required this.status,
    this.createdAt,
    this.reviewedAt,
  });

  factory Report.fromFirestore(Map<String, dynamic> data, String id) {
    return Report(
      id: id,
      reporterId: data['reporterId'] as String? ?? '',
      reporterRole: AccountRole.fromId(data['reporterRole'] as String?),
      targetType: ReportTargetType.fromId(data['targetType'] as String?),
      targetId: data['targetId'] as String? ?? '',
      targetName: data['targetName'] as String? ?? '（不明）',
      reason: ReportReason.fromId(data['reason'] as String?),
      detail: data['detail'] as String? ?? '',
      snapshot: Map<String, dynamic>.from(
        data['snapshot'] as Map? ?? const {},
      ),
      status: data['status'] as String? ?? 'open',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }
}
