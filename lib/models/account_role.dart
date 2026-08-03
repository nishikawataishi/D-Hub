/// アプリを使っているアカウントの立場。
///
/// 通報者の記録とブロック情報の保存先の両方で使う。D-Hubでは通報・ブロックは
/// 常に学生↔団体の間で行われるため、立場が決まれば相手の種別も決まる。
enum AccountRole {
  /// 学生。ブロックは `users/{uid}/blocks/{団体ID}` に保存する
  student('student', 'users', '団体'),

  /// 団体。ブロックは `organizations/{uid}/blocks/{学生ID}` に保存する
  organization('organization', 'organizations', '学生');

  /// Firestore に保存する値。firestore.rules のホワイトリストと一致させること
  final String id;

  /// ブロック情報を保存する親コレクション
  final String blocksParentCollection;

  /// この立場から見た相手の呼称（UIの文言に使う）
  final String counterpartLabel;

  const AccountRole(this.id, this.blocksParentCollection, this.counterpartLabel);

  static AccountRole fromId(String? id) {
    return AccountRole.values.firstWhere(
      (e) => e.id == id,
      orElse: () => AccountRole.student,
    );
  }
}
