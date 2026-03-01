import 'campus.dart';

/// 団体のカテゴリ（ジャンル）
enum OrgCategory {
  all('すべて'),
  sports('スポーツ'),
  culture('文化系'),
  academic('学術・ゼミ'),
  volunteer('ボランティア'),
  music('音楽');

  final String label;
  const OrgCategory(this.label);

  static OrgCategory fromString(String category) {
    return OrgCategory.values.firstWhere(
      (e) => e.name == category,
      orElse: () => OrgCategory.all,
    );
  }
}

/// 団体データモデル
class Organization {
  final String id;
  final String name;
  final String description;
  final OrgCategory category;
  final Campus campus;
  final String logoEmoji;
  final String instagramUrl;
  final String? logoUrl;

  const Organization({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.campus,
    required this.logoEmoji,
    this.instagramUrl = '',
    this.logoUrl,
  });

  /// 認証時に初期化する空のプロファイル
  factory Organization.empty(String id) {
    return Organization(
      id: id,
      name: '団体名未設定',
      description: '',
      category: OrgCategory.culture,
      campus: Campus.both,
      logoEmoji: '🎨',
      instagramUrl: '',
    );
  }

  /// Firestoreドキュメントからの変換
  factory Organization.fromJson(Map<String, dynamic> json, String id) {
    return Organization(
      id: id,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: OrgCategory.fromString(json['category'] as String? ?? ''),
      campus: Campus.fromString(json['campus'] as String? ?? ''),
      logoEmoji: json['logoEmoji'] as String? ?? '🎨',
      instagramUrl: json['instagramUrl'] as String? ?? '',
      logoUrl: json['logoUrl'] as String?,
    );
  }

  /// Firestore保存用データの生成
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'category': category.name,
      'campus': campus.name,
      'logoEmoji': logoEmoji,
      'instagramUrl': instagramUrl,
      if (logoUrl != null) 'logoUrl': logoUrl,
    };
  }
}
