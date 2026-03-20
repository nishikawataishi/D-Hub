import 'package:cloud_firestore/cloud_firestore.dart';

/// タグマスタモデル
/// Firestoreの`tags`コレクションに対応するデータクラス
class Tag {
  final String id;
  final String name;
  final DateTime createdAt;

  const Tag({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  /// Firestoreドキュメントからインスタンスを生成
  factory Tag.fromFirestore(Map<String, dynamic> data, String docId) {
    return Tag(
      id: docId,
      name: data['name'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Firestore保存用のMapに変換
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'Tag(id: $id, name: $name)';
}
