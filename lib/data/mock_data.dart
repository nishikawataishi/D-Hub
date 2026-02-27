/// D.scout モックデータ
/// バックエンド未接続のため、固定データでUIプロトタイプを動作させる
library;

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
}

/// キャンパス
enum Campus {
  imadegawa('今出川'),
  kyotanabe('京田辺'),
  both('両キャンパス');

  final String label;
  const Campus(this.label);
}

/// 団体データモデル
class Organization {
  final String id;
  final String name;
  final String description;
  final OrgCategory category;
  final Campus campus;
  final String logoEmoji; // モック用に絵文字で代用
  final String instagramUrl;

  const Organization({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.campus,
    required this.logoEmoji,
    this.instagramUrl = 'https://www.instagram.com/',
  });
}

/// スカウトデータモデル
class Scout {
  final String id;
  final Organization organization;
  final String message;
  final DateTime sentAt;
  bool isRead;

  Scout({
    required this.id,
    required this.organization,
    required this.message,
    required this.sentAt,
    this.isRead = false,
  });
}

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
}

/// ユーザープロフィールデータモデル
class UserProfile {
  final String name;
  final String faculty;
  final int grade;
  final Campus mainCampus;
  List<String> interests;

  UserProfile({
    required this.name,
    required this.faculty,
    required this.grade,
    required this.mainCampus,
    required this.interests,
  });
}

// ============================
// モックデータインスタンス
// ============================

/// サンプル団体データ
final List<Organization> mockOrganizations = [
  const Organization(
    id: '1',
    name: 'D-spirits',
    description: '同志社大学公認バスケットボールサークル。初心者から経験者まで楽しめる！',
    category: OrgCategory.sports,
    campus: Campus.imadegawa,
    logoEmoji: '🏀',
  ),
  const Organization(
    id: '2',
    name: '写真部 f/1.4',
    description: '写真を通じて日常の美しさを切り取る。月1回の撮影会と展示会を開催。',
    category: OrgCategory.culture,
    campus: Campus.kyotanabe,
    logoEmoji: '📷',
  ),
  const Organization(
    id: '3',
    name: '国際経済ゼミ',
    description: '太田ゼミ。開発経済学を中心に、グローバルな視点で経済問題を研究。',
    category: OrgCategory.academic,
    campus: Campus.imadegawa,
    logoEmoji: '📊',
  ),
  const Organization(
    id: '4',
    name: 'D-ACE',
    description: '同志社大学最大級のダンスサークル。HipHop, Jazz, Lockなど多ジャンル！',
    category: OrgCategory.culture,
    campus: Campus.both,
    logoEmoji: '💃',
  ),
  const Organization(
    id: '5',
    name: 'Volunteer Circle CLOVER',
    description: '地域の子ども支援や環境活動を行うボランティアサークル。',
    category: OrgCategory.volunteer,
    campus: Campus.kyotanabe,
    logoEmoji: '🍀',
  ),
  const Organization(
    id: '6',
    name: 'アカペラサークル Voce',
    description: 'ハーモニーで人を繋ぐ。定期ライブやストリートライブで活動中。',
    category: OrgCategory.music,
    campus: Campus.imadegawa,
    logoEmoji: '🎵',
  ),
  const Organization(
    id: '7',
    name: 'テニスサークル STC',
    description: '毎週水曜・土曜に京田辺キャンパスで練習。合宿やBBQも！',
    category: OrgCategory.sports,
    campus: Campus.kyotanabe,
    logoEmoji: '🎾',
  ),
  const Organization(
    id: '8',
    name: '社会学ゼミ（鵜飼ゼミ）',
    description: 'メディアと社会の関係性を探る。フィールドワーク重視の実践的な研究。',
    category: OrgCategory.academic,
    campus: Campus.imadegawa,
    logoEmoji: '📚',
  ),
];

/// サンプルスカウトデータ
final List<Scout> mockScouts = [
  Scout(
    id: 's1',
    organization: mockOrganizations[0],
    message: 'スポーツが好きなあなたにぜひ！一度見学に来ませんか？🏀',
    sentAt: DateTime.now().subtract(const Duration(hours: 1)),
    isRead: false,
  ),
  Scout(
    id: 's2',
    organization: mockOrganizations[2],
    message: '商学部で国際経済に興味があるあなたへ。ゼミ説明会を開催します！',
    sentAt: DateTime.now().subtract(const Duration(hours: 5)),
    isRead: false,
  ),
  Scout(
    id: 's3',
    organization: mockOrganizations[3],
    message: 'ダンス未経験でも大歓迎！新歓公演の観覧に来てください💃',
    sentAt: DateTime.now().subtract(const Duration(days: 1)),
    isRead: true,
  ),
  Scout(
    id: 's4',
    organization: mockOrganizations[5],
    message: '歌うことが好きなら、アカペラの世界をのぞいてみませんか？🎵',
    sentAt: DateTime.now().subtract(const Duration(days: 2)),
    isRead: true,
  ),
];

/// サンプルイベントデータ
final List<Event> mockEvents = [
  Event(
    id: 'e1',
    organization: mockOrganizations[0],
    title: 'D-spirits 新歓バスケ体験会',
    description: '初心者大歓迎！一緒にバスケを楽しもう！',
    startAt: DateTime(2026, 4, 5, 14, 0),
    campus: Campus.imadegawa,
  ),
  Event(
    id: 'e2',
    organization: mockOrganizations[2],
    title: '国際経済ゼミ 説明会',
    description: '太田ゼミの研究内容と活動の紹介。質疑応答あり。',
    startAt: DateTime(2026, 4, 5, 16, 30),
    campus: Campus.imadegawa,
  ),
  Event(
    id: 'e3',
    organization: mockOrganizations[1],
    title: '写真部 春の撮影会＆作品展',
    description: '京田辺キャンパス周辺で撮影会。作品展も同時開催！',
    startAt: DateTime(2026, 4, 7, 10, 0),
    campus: Campus.kyotanabe,
  ),
  Event(
    id: 'e4',
    organization: mockOrganizations[3],
    title: 'D-ACE 新歓公演「START」',
    description: '全ジャンルのダンスが観られる年に一度の公演。入場無料！',
    startAt: DateTime(2026, 4, 10, 18, 0),
    campus: Campus.both,
  ),
  Event(
    id: 'e5',
    organization: mockOrganizations[4],
    title: 'CLOVER ボランティア体験Day',
    description: '地域の清掃活動に参加してみよう。動きやすい服装で！',
    startAt: DateTime(2026, 4, 12, 9, 0),
    campus: Campus.kyotanabe,
  ),
];

/// サンプルユーザープロフィール
final UserProfile mockUser = UserProfile(
  name: '西川 大司',
  faculty: '商学部',
  grade: 3,
  mainCampus: Campus.imadegawa,
  interests: ['プログラミング', '国際経済', 'バスケ', 'カフェ巡り', '映画鑑賞'],
);
