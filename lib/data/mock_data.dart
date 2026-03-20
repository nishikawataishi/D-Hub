/// D.scout モックデータ
/// バックエンド未接続のため、固定データでUIプロトタイプを動作させる
library;

import '../models/campus.dart';
import '../models/user_profile.dart';
import '../models/organization.dart';
import '../models/event.dart';
import '../models/tag.dart';

import '../models/scout.dart';

export '../models/campus.dart';
export '../models/user_profile.dart';
export '../models/organization.dart';
export '../models/event.dart';
export '../models/tag.dart';

// ============================
// モックデータインスタンス
// ============================

/// サンプル団体データ
final List<Organization> mockOrganizations = [
  const Organization(
    id: '1',
    name: 'D-spirits',
    description: '同志社大学公認バスケットボールサークル。初心者から経験者まで楽しめる！',
    categories: [OrgCategory.sports],
    campus: Campus.imadegawa,
    logoEmoji: '🏀',
  ),
  const Organization(
    id: '2',
    name: '写真部 f/1.4',
    description: '写真を通じて日常の美しさを切り取る。月1回の撮影会と展示会を開催。',
    categories: [OrgCategory.culture],
    campus: Campus.kyotanabe,
    logoEmoji: '📷',
  ),
  const Organization(
    id: '3',
    name: '国際経済ゼミ',
    description: '太田ゼミ。開発経済学を中心に、グローバルな視点で経済問題を研究。',
    categories: [OrgCategory.academic],
    campus: Campus.imadegawa,
    logoEmoji: '📊',
  ),
  const Organization(
    id: '4',
    name: 'D-ACE',
    description: '同志社大学最大級のダンスサークル。HipHop, Jazz, Lockなど多ジャンル！',
    categories: [OrgCategory.culture],
    campus: Campus.both,
    logoEmoji: '💃',
  ),
  const Organization(
    id: '5',
    name: 'Volunteer Circle CLOVER',
    description: '地域の子ども支援や環境活動を行うボランティアサークル。',
    categories: [OrgCategory.volunteer],
    campus: Campus.kyotanabe,
    logoEmoji: '🍀',
  ),
  const Organization(
    id: '6',
    name: 'アカペラサークル Voce',
    description: 'ハーモニーで人を繋ぐ。定期ライブやストリートライブで活動中。',
    categories: [OrgCategory.music],
    campus: Campus.imadegawa,
    logoEmoji: '🎵',
  ),
  const Organization(
    id: '7',
    name: 'テニスサークル STC',
    description: '毎週水曜・土曜に京田辺キャンパスで練習。合宿やBBQも！',
    categories: [OrgCategory.sports],
    campus: Campus.kyotanabe,
    logoEmoji: '🎾',
  ),
  const Organization(
    id: '8',
    name: '社会学ゼミ（鵜飼ゼミ）',
    description: 'メディアと社会の関係性を探る。フィールドワーク重視の実践的な研究。',
    categories: [OrgCategory.academic],
    campus: Campus.imadegawa,
    logoEmoji: '📚',
  ),
];

/// サンプルスカウトデータ
final List<Scout> mockScouts = [
  Scout(
    id: 's1',
    targetUserId: 'mock_user_id',
    organizationId: mockOrganizations[0].id,
    organizationName: mockOrganizations[0].name,
    organizationEmoji: mockOrganizations[0].logoEmoji,
    organizationCategory: mockOrganizations[0].categories.first.name,
    message: 'スポーツが好きなあなたにぜひ！一度見学に来ませんか？🏀',
    sentAt: DateTime.now().subtract(const Duration(hours: 1)),
    isRead: false,
  ),
  Scout(
    id: 's2',
    targetUserId: 'mock_user_id',
    organizationId: mockOrganizations[2].id,
    organizationName: mockOrganizations[2].name,
    organizationEmoji: mockOrganizations[2].logoEmoji,
    organizationCategory: mockOrganizations[2].categories.first.name,
    message: '商学部で国際経済に興味があるあなたへ。ゼミ説明会を開催します！',
    sentAt: DateTime.now().subtract(const Duration(hours: 5)),
    isRead: false,
  ),
  Scout(
    id: 's3',
    targetUserId: 'mock_user_id',
    organizationId: mockOrganizations[3].id,
    organizationName: mockOrganizations[3].name,
    organizationEmoji: mockOrganizations[3].logoEmoji,
    organizationCategory: mockOrganizations[3].categories.first.name,
    message: 'ダンス未経験でも大歓迎！新歓公演の観覧に来てください💃',
    sentAt: DateTime.now().subtract(const Duration(days: 1)),
    isRead: true,
  ),
  Scout(
    id: 's4',
    targetUserId: 'mock_user_id',
    organizationId: mockOrganizations[5].id,
    organizationName: mockOrganizations[5].name,
    organizationEmoji: mockOrganizations[5].logoEmoji,
    organizationCategory: mockOrganizations[5].categories.first.name,
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
  id: 'mock_user_id',
  name: '西川 大司',
  faculty: '商学部',
  grade: 3,
  mainCampus: Campus.imadegawa,
  interests: ['プログラミング', '国際経済', 'バスケ', 'カフェ巡り', '映画鑑賞'],
);

/// サンプルタグマスタデータ
final List<Tag> mockTags = [
  Tag(id: 't1', name: 'プログラミング', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't2', name: '国際経済', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't3', name: 'バスケ', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't4', name: 'カフェ巡り', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't5', name: '映画鑑賞', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't6', name: 'サッカー', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't7', name: 'テニス', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't8', name: 'ダンス', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't9', name: '音楽', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't10', name: 'ボランティア', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't11', name: '写真', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't12', name: '読書', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't13', name: '旅行', createdAt: DateTime(2026, 1, 1)),
  Tag(id: 't14', name: '料理', createdAt: DateTime(2026, 1, 1)),
];
