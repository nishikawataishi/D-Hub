import 'package:freezed_annotation/freezed_annotation.dart';
import 'campus.dart';

part 'organization.freezed.dart';
part 'organization.g.dart';

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

@freezed
abstract class Organization with _$Organization {
  const Organization._();

  const factory Organization({
    required String id,
    required String name,
    required String description,
    required List<OrgCategory> categories,
    required Campus campus,
    required String logoEmoji,
    @Default('') String instagramUrl,
    String? logoUrl,
    // 追加フィールド
    String? representativeId,
    @Default('pending') String status, // 'pending', 'verified', 'rejected'
    String? proofImageUrl,
    DateTime? verifiedAt,
    @Default(false) bool isOfficial,
    DateTime? createdAt,
  }) = _Organization;

  factory Organization.fromJson(Map<String, dynamic> json) =>
      _$OrganizationFromJson(json);

  /// 手動デコード用（FirestoreのドキュメントIDをIDフィールドにセットするため）
  factory Organization.fromFirestore(Map<String, dynamic> json, String id) {
    // カテゴリの古い形式への対応
    List<dynamic> categoriesJson = [];
    if (json['categories'] != null) {
      categoriesJson = json['categories'] as List;
    } else if (json['category'] != null) {
      categoriesJson = [json['category']];
    }

    return Organization.fromJson({
      ...json,
      'id': id,
      'categories': categoriesJson,
      // TimestampをDateTimeに変換
      if (json['verifiedAt'] != null)
        'verifiedAt': (json['verifiedAt'] as dynamic)
            .toDate()
            .toIso8601String(),
      if (json['createdAt'] != null)
        'createdAt': (json['createdAt'] as dynamic).toDate().toIso8601String(),
    });
  }

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
}
