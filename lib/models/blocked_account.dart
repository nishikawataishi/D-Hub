import 'package:cloud_firestore/cloud_firestore.dart';

/// ブロックしたアカウント1件
///
/// 保存先は [AccountRole.blocksParentCollection] を参照。学生側のブロックは
/// Firestoreルールがスカウト作成時に参照しており、ブロックした団体からは
/// スカウトが届かない（利用規約 第8条2）。
class BlockedAccount {
  /// ブロックした相手のUID（ドキュメントIDと同じ）
  final String id;

  /// ブロック時点の相手の表示名。相手が改名・退会しても一覧に出せるよう保持する
  final String name;

  final DateTime? blockedAt;

  const BlockedAccount({
    required this.id,
    required this.name,
    this.blockedAt,
  });

  factory BlockedAccount.fromFirestore(Map<String, dynamic> data, String id) {
    return BlockedAccount(
      id: id,
      name: data['targetName'] as String? ?? '（不明）',
      blockedAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
