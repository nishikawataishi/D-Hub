import 'campus.dart';

/// 定型文に埋め込む値の種類。
///
/// いずれも「団体が自由に文字列を入力する」のではなく、既存データから
/// 選ぶ／自動で決まるようになっている。任意の文字列は Firestore ルール側で
/// 拒否されるため、自由記述は仕組みとして成立しない。
enum ScoutSlot {
  /// 対象学生が登録している興味タグから団体が選ぶ
  tag,

  /// 自団体が公開しているイベントから団体が選ぶ
  event,

  /// 対象学生の登録キャンパス（選択不要・自動で決まる）
  campus,

  /// 対象学生の学年（選択不要・自動で決まる）
  grade,

  /// 埋め込む値なし
  none,
}

/// スカウトの定型文。
///
/// 団体は本文を自由に書けず、この5種類のいずれかを選んで送信する。
/// 文面を変えたい場合は [all] の `body` を書き換えるだけでよく、
/// 保存済みのスカウトにも即座に反映される（Firestore には
/// `templateId` と埋め込む値だけを保存しているため）。
class ScoutTemplate {
  const ScoutTemplate({
    required this.id,
    required this.label,
    required this.slot,
    required this.body,
  });

  /// Firestore に保存する識別子。**既存データと対応するため変更しないこと。**
  final int id;

  /// 団体側の選択リストに表示する短い名前
  final String label;

  /// 埋め込む値の種類
  final ScoutSlot slot;

  /// 本文。`{}` が埋め込む値に置き換わる（[ScoutSlot.none] の場合はそのまま）
  final String body;

  /// 埋め込む値を持たない汎用の定型文。
  /// 値が解決できなくなった場合（イベントが削除された等）の代替にも使う。
  static const ScoutTemplate generic = ScoutTemplate(
    id: 4,
    label: '見学のお誘い',
    slot: ScoutSlot.none,
    body: 'プロフィールを見て、ぜひ一度活動を見に来てほしいと思い連絡しました。'
        '見学だけでも大歓迎です！',
  );

  /// 選択可能な定型文の一覧。**id は Firestore の値と対応するため付け替えないこと。**
  static const List<ScoutTemplate> all = [
    ScoutTemplate(
      id: 0,
      label: '興味タグに共感',
      slot: ScoutSlot.tag,
      body: 'プロフィールの「{}」を見て連絡しました。'
          '私たちの活動と近いので、きっと楽しんでもらえると思います！',
    ),
    ScoutTemplate(
      id: 1,
      label: 'イベントに招待',
      slot: ScoutSlot.event,
      body: '「{}」を開催します。'
          '少しでも気になったら、ぜひ気軽に来てみてください！',
    ),
    ScoutTemplate(
      id: 2,
      label: '同じキャンパス',
      slot: ScoutSlot.campus,
      body: '{}キャンパスを中心に活動しています。'
          '同じキャンパスなので、授業の前後にも参加しやすいと思います！',
    ),
    ScoutTemplate(
      id: 3,
      label: '学年を歓迎',
      slot: ScoutSlot.grade,
      body: '{}回生の方を歓迎しています。'
          '学年の近いメンバーも多いので、馴染みやすいと思います！',
    ),
    generic,
  ];

  /// [id] に対応する定型文を返す。未知の id の場合は null。
  static ScoutTemplate? byId(int? id) {
    if (id == null) return null;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 埋め込む値が必要かどうか
  bool get needsArg => slot != ScoutSlot.none;

  /// 本文を組み立てる。
  ///
  /// [arg] は Firestore に保存されている `templateArg`。
  /// 値が欠けている・解決できない場合は [generic] の本文にフォールバックする
  /// （イベントが削除された、キャンパス未設定などのケース）。
  String render(String? arg) {
    if (!needsArg) return body;
    final value = _display(arg);
    if (value == null || value.isEmpty) return generic.body;
    return body.replaceAll('{}', value);
  }

  /// 保存値を表示用の文字列に変換する。表示できない場合は null。
  String? _display(String? arg) {
    if (arg == null || arg.isEmpty) return null;
    switch (slot) {
      case ScoutSlot.campus:
        // Firestore には Campus の enum 名（例: imadegawa）が入っている。
        // 「両キャンパス」は文意が通らないため、この定型文では扱わない。
        final campus = Campus.fromString(arg);
        return campus == Campus.both ? null : campus.label;
      case ScoutSlot.tag:
      case ScoutSlot.event:
      case ScoutSlot.grade:
        return arg;
      case ScoutSlot.none:
        return null;
    }
  }
}
