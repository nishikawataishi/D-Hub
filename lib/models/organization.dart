import 'campus.dart';

enum OrgCategory {
  all('すべて'),
  sports('スポーツ'),
  culture('文化系'),
  academic('学術・ゼミ'),
  volunteer('ボランティア'),
  music('音楽'),
  varsity('体育会'),
  tennis('テニスサークル'),
  event('イベントサークル'),
  sportsCircle('スポーツサークル'),
  it('IT・プログラミング'),
  international('国際交流'),
  beginner('初心者歓迎'),
  competitive('ガチ勢'),
  enjoy('ゆるめ・エンジョイ'),
  joint('兼サーOK'),
  intercollege('インカレ'),
  homey('アットホーム'),
  large('大規模サークル'),
  female('女子多め'),
  male('男子多め');

  final String label;
  const OrgCategory(this.label);

  static OrgCategory fromString(String category) {
    return OrgCategory.values.firstWhere(
      (e) => e.name == category,
      orElse: () => OrgCategory.all,
    );
  }
}

class Organization {
  final String id;
  final String name;
  final String description;
  final List<OrgCategory> categories;
  final Campus campus;
  final String logoEmoji;
  final String instagramUrl;
  final String? logoUrl;

  const Organization({
    required this.id,
    required this.name,
    required this.description,
    required this.categories,
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
      categories: const [OrgCategory.culture],
      campus: Campus.both,
      logoEmoji: '🎨',
      instagramUrl: '',
    );
  }

  /// Firestoreドキュメントからの変換
  factory Organization.fromJson(Map<String, dynamic> json, String id) {
    List<OrgCategory> categories = [];
    if (json['categories'] != null) {
      categories = (json['categories'] as List)
          .map((e) => OrgCategory.fromString(e as String))
          .toList();
    } else if (json['category'] != null) {
      // 後方互換性：単一のcategoryフィールドがある場合
      categories = [OrgCategory.fromString(json['category'] as String)];
    }

    if (categories.isEmpty) {
      categories = [OrgCategory.culture];
    }

    return Organization(
      id: id,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      categories: categories,
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
      'categories': categories.map((e) => e.name).toList(),
      'campus': campus.name,
      'logoEmoji': logoEmoji,
      'instagramUrl': instagramUrl,
      if (logoUrl != null) 'logoUrl': logoUrl,
    };
  }
}
