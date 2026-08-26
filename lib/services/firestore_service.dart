import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/mock_data.dart';
import '../models/account_role.dart';
import '../models/blocked_account.dart';
import '../models/report.dart';
import '../models/scout.dart';
import '../models/scout_template.dart';
import '../models/event_application.dart';

/// Firestoreのデータ操作を行うサービス
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── 団体（Organizations） ───

  /// 単一団体を取得
  Future<Organization?> getOrganization(String id) async {
    final doc = await _db.collection('organizations').doc(id).get();
    if (!doc.exists) return null;
    return Organization.fromFirestore(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  /// 団体情報を保存（新規作成・フル上書き用）
  Future<void> saveOrganization(Organization org) async {
    await _db
        .collection('organizations')
        .doc(org.id)
        .set(org.toJson(), SetOptions(merge: true));
  }

  /// 団体プロフィールを更新（プロフィール編集用）
  /// createdAt / verifiedAt / status などの管理フィールドは書き込まない
  Future<void> updateOrgProfile(Organization org) async {
    await _db.collection('organizations').doc(org.id).update({
      'name': org.name,
      'description': org.description,
      'categories': org.categories.map((e) => e.name).toList(),
      'campus': org.campus.name,
      'logoEmoji': org.logoEmoji,
      'instagramUrl': org.instagramUrl,
      'groupLineUrl': org.groupLineUrl,
      'logoUrl': org.logoUrl,
      'photoUrls': org.photoUrls,
    });
  }

  /// 承認済み団体を取得
  /// status の絞り込みは firestore.rules の allow list と対になっている。
  /// ルールは返るドキュメント1件ずつに評価されるため、
  /// ここを外すと pending が1件混ざっただけでクエリ全体が permission-denied になる。
  Stream<List<Organization>> getOrganizations() {
    return _db
        .collection('organizations')
        .where('status', isEqualTo: 'verified')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => _organizationFromDoc(doc)).toList(),
        );
  }

  /// カテゴリで絞り込んだ団体を取得
  Stream<List<Organization>> getOrganizationsByCategory(OrgCategory category) {
    if (category == OrgCategory.all) return getOrganizations();
    // whereArrayContains を使用して、指定したカテゴリーが含まれるドキュメントを取得
    return _db
        .collection('organizations')
        .where('status', isEqualTo: 'verified')
        .where('categories', arrayContains: category.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Organization.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Firestoreドキュメント → Organizationモデル変換
  Organization _organizationFromDoc(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return Organization.empty(doc.id);
    }
    return Organization.fromFirestore(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  // ─── 管理者用（Admin） ───

  /// ステータスで絞り込んだ団体一覧を取得
  Stream<List<Organization>> getOrganizationsByStatus(String status) {
    return _db
        .collection('organizations')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => _organizationFromDoc(doc)).toList(),
        );
  }

  /// 全団体を取得（管理画面用・作成日時降順）
  Stream<List<Organization>> getAllOrganizationsForAdmin() {
    return _db
        .collection('organizations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => _organizationFromDoc(doc)).toList(),
        );
  }

  /// 団体ステータスを更新（管理者用）
  Future<void> updateOrganizationStatus(String orgId, String status) async {
    final data = <String, dynamic>{'status': status};
    if (status == 'verified') {
      data['verifiedAt'] = FieldValue.serverTimestamp();
    }
    await _db.collection('organizations').doc(orgId).update(data);
  }

  // ─── スカウト（Scouts） ───

  /// 特定団体が送信したスカウト一覧を取得（団体側履歴管理用）
  Stream<List<Scout>> getScoutsByOrganization(String orgId) {
    return _db
        .collection('scouts')
        .where('organizationId', isEqualTo: orgId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Scout.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// 特定ユーザー宛のスカウトを取得
  Stream<List<Scout>> getScoutsForUser(String userId) {
    return _db
        .collection('scouts')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Scout.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// 特定の団体から特定ユーザーへのスカウトが存在するか確認
  Future<bool> hasScouted({
    required String orgId,
    required String userId,
  }) async {
    final result = await _db
        .collection('scouts')
        .where('organizationId', isEqualTo: orgId)
        .where('targetUserId', isEqualTo: userId)
        .limit(1)
        .get();
    return result.docs.isNotEmpty;
  }

  /// スカウトを既読にする
  Future<void> markScoutAsRead(String scoutId) async {
    await _db.collection('scouts').doc(scoutId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  /// スカウトを送信する
  ///
  /// 本文は自由記述できず、[template] で選んだ定型文に限られる。
  /// [templateArg] は定型文に埋め込む値で、対象学生が実際に登録している値
  /// （タグ・キャンパス・学年）または自団体のイベント名でなければ
  /// Firestoreルール側で拒否される。
  Future<void> sendScout({
    required String targetUserId,
    required Organization senderOrg,
    required ScoutTemplate template,
    String? templateArg,
    String? templateEventId,
  }) async {
    // ルールと同じ条件をクライアント側でも検証し、分かりやすいエラーを返す
    if (template.needsArg && (templateArg == null || templateArg.isEmpty)) {
      throw Exception('この定型文には埋め込む値の選択が必要です。');
    }
    if (template.slot == ScoutSlot.event &&
        (templateEventId == null || templateEventId.isEmpty)) {
      throw Exception('招待するイベントを選択してください。');
    }

    // 学生の情報を取得してアイコンURLを保持
    final studentProfile = await getUserProfile(targetUserId);

    final now = DateTime.now();
    final scoutData = Scout(
      id: '',
      targetUserId: targetUserId,
      organizationId: senderOrg.id,
      organizationName: senderOrg.name,
      organizationEmoji: senderOrg.logoEmoji,
      organizationCategory: senderOrg.categories.isNotEmpty
          ? senderOrg.categories.first.label
          : OrgCategory.all.label,
      templateId: template.id,
      templateArg: template.needsArg ? templateArg : null,
      templateEventId: templateEventId,
      isRead: false,
      sentAt: now,
      organizationInstagramUrl: senderOrg.instagramUrl,
      organizationGroupLineUrl: senderOrg.groupLineUrl,
      organizationLogoUrl: senderOrg.logoUrl,
      targetUserIconUrl: studentProfile?.iconUrl,
      targetUserName: studentProfile?.name,
    ).toFirestore();

    scoutData['sentAt'] = FieldValue.serverTimestamp();

    // 重複チェック（Firestore WebはトランザクションでコレクションQueryを実行できないため外で実行）
    final existingScouts = await _db
        .collection('scouts')
        .where('targetUserId', isEqualTo: targetUserId)
        .where('organizationId', isEqualTo: senderOrg.id)
        .where('isRead', isEqualTo: false)
        .get();

    if (existingScouts.docs.isNotEmpty) {
      throw Exception('すでにこの学生には未読のスカウトを送信済みです。');
    }

    // スカウトを作成
    final newDocRef = _db.collection('scouts').doc();
    await newDocRef.set(scoutData);
  }

  // ─── イベント（Events） ───

  /// 今後のイベントを取得
  Stream<List<Event>> getUpcomingEvents() {
    return _db
        .collection('events')
        .where('startAt', isGreaterThan: Timestamp.now())
        .orderBy('startAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return Event.fromFirestore(data, doc.id);
          }).toList(),
        );
  }

  /// 特定団体が作成したイベント一覧を取得
  Stream<List<Event>> getEventsByOrganization(String orgId) {
    return _db
        .collection('events')
        .where('organizationId', isEqualTo: orgId)
        .orderBy('startAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Event.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// 特定団体の開催予定イベントを一度だけ取得（スカウトの招待先選択用）
  Future<List<Event>> fetchUpcomingEventsByOrganization(String orgId) async {
    final snapshot = await _db
        .collection('events')
        .where('organizationId', isEqualTo: orgId)
        .where('startAt', isGreaterThan: Timestamp.now())
        .orderBy('startAt')
        .get();
    return snapshot.docs
        .map((doc) => Event.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// イベントを作成
  Future<void> createEvent(Event event) async {
    final data = event.toFirestore();
    data['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('events').add(data);
  }

  /// イベントを更新
  Future<void> updateEvent(Event event) async {
    await _db.collection('events').doc(event.id).update(event.toFirestore());
  }

  /// イベントを削除
  Future<void> deleteEvent(String eventId) async {
    await _db.collection('events').doc(eventId).delete();
  }

  // ─── イベント申し込み（Event Applications） ───

  /// イベントに申し込む（学生用）
  /// ドキュメントIDを studentId にすることで1人1申し込みを保証
  Future<void> applyToEvent({
    required String eventId,
    required UserProfile student,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('ログインが必要です');

    final docRef = _db
        .collection('events')
        .doc(eventId)
        .collection('applications')
        .doc(user.uid);

    final existing = await docRef.get();
    if (existing.exists) {
      throw Exception('すでにこのイベントに申し込み済みです。');
    }

    await docRef.set({
      'studentId': user.uid,
      'studentName': student.name,
      'studentFaculty': student.faculty,
      'studentGrade': student.grade,
      if (student.iconUrl != null) 'studentIconUrl': student.iconUrl,
      'status': 'applied',
      'appliedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 申し込みをキャンセル（学生用）
  Future<void> cancelApplication(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('ログインが必要です');

    await _db
        .collection('events')
        .doc(eventId)
        .collection('applications')
        .doc(user.uid)
        .delete();
  }

  /// 自分のイベント申し込み状況をリアルタイム取得（学生用）
  Stream<EventApplication?> getMyApplication(String eventId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _db
        .collection('events')
        .doc(eventId)
        .collection('applications')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return EventApplication.fromFirestore(doc.data()!, doc.id, eventId);
    });
  }

  /// イベントの申し込み一覧をリアルタイム取得（団体用）
  Stream<List<EventApplication>> getApplicationsForEvent(String eventId) {
    return _db
        .collection('events')
        .doc(eventId)
        .collection('applications')
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    EventApplication.fromFirestore(doc.data(), doc.id, eventId),
              )
              .toList(),
        );
  }

  /// 申し込みのステータスを更新（団体用：承認・却下）
  Future<void> updateApplicationStatus({
    required String eventId,
    required String applicationId,
    required String status,
  }) async {
    await _db
        .collection('events')
        .doc(eventId)
        .collection('applications')
        .doc(applicationId)
        .update({
      'status': status,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── タグマスタ（Tags） ───

  /// 全タグをストリームで取得（名前順）
  Stream<List<Tag>> getTags() {
    return _db
        .collection('tags')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Tag.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// タグをマスタに追加（同名が存在しない場合のみ）
  /// 既に存在する場合は何もせず既存のタグ名を返す
  Future<void> addTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    // 同名タグが既に存在するかチェック
    final existing = await _db
        .collection('tags')
        .where('name', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return; // 既に存在する場合はスキップ

    await _db.collection('tags').add({
      'name': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// タグをマスタから削除（管理者用）
  Future<void> deleteTag(String tagId) async {
    await _db.collection('tags').doc(tagId).delete();
  }

  // ─── ユーザープロフィール ───

  /// ユーザープロフィールを取得
  Future<UserProfile?> getUserProfile(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  /// ユーザープロフィールのストリームを取得
  Stream<UserProfile?> getUserProfileStream(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    });
  }

  /// 学生一覧を取得（プロフィール設定済みのユーザーのみ）
  Stream<List<UserProfile>> getStudents() {
    return _db
        .collection('users')
        // 必要に応じて 'isStudent' フラグやプロフィール入力完了フラグでフィルタリング
        .where('name', isNull: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserProfile.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// ユーザープロフィールを更新
  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  /// 全ユーザーを取得（管理画面用）
  Stream<List<UserProfile>> getAllUsersForAdmin() {
    return _db
        .collection('users')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((doc) => doc.data()['name'] != null)
              .map((doc) => UserProfile.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  // ─── 初期データ投入（開発用） ───

  /// モックデータをFirestoreに投入する（1回だけ実行する開発用関数）
  /// 本番環境では実行不可
  Future<void> seedData() async {
    if (!kDebugMode) {
      throw StateError('seedData()はデバッグモードでのみ実行可能です');
    }
    final batch = _db.batch();
    final user = _auth.currentUser;

    // 団体データを投入
    for (final org in mockOrganizations) {
      final docRef = _db.collection('organizations').doc(org.id);
      batch.set(docRef, {
        'name': org.name,
        'description': org.description,
        'categories': org.categories.map((e) => e.name).toList(),
        'campus': org.campus.name,
        'logoEmoji': org.logoEmoji,
        'instagramUrl': org.instagramUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // イベントデータを投入
    for (final event in mockEvents) {
      final docRef = _db.collection('events').doc(event.id);
      batch.set(docRef, {
        'organizationId': event.organization.id,
        'organizationName': event.organization.name,
        'organizationEmoji': event.organization.logoEmoji,
        'title': event.title,
        'description': event.description,
        'startAt': Timestamp.fromDate(event.startAt),
        'campus': event.campus.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // タグマスタデータを投入
    for (final tag in mockTags) {
      final docRef = _db.collection('tags').doc(tag.id);
      batch.set(docRef, {
        'name': tag.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 現在ログイン中のユーザーがいれば、その人宛のテストスカウトを作成
    if (user != null) {
      final scoutDoc = _db.collection('scouts').doc('test_scout_${user.uid}');
      batch.set(scoutDoc, {
        'targetUserId': user.uid,
        'organizationId': '1',
        'organizationName': 'D-spirits',
        'organizationEmoji': '🏀',
        'organizationCategory': 'スポーツ',
        // 定型文「見学のお誘い」。埋め込む値を持たないので単体で成立する
        'templateId': ScoutTemplate.generic.id,
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }

    await batch.commit();
  }

  // ─── お問い合わせ（Contacts） ───

  /// お問い合わせを送信（contacts コレクションに保存）
  Future<void> submitContact({
    required String userId,
    required String category,
    required String message,
  }) async {
    await _db.collection('contacts').add({
      'userId': userId,
      'category': category,
      'message': message,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// お問い合わせ一覧を取得（管理者用）
  Stream<List<Map<String, dynamic>>> getContactsForAdmin({
    required String status,
  }) {
    return _db
        .collection('contacts')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// お問い合わせのステータスを更新（管理者用）
  Future<void> updateContactStatus(String contactId, String status) async {
    await _db.collection('contacts').doc(contactId).update({
      'status': status,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── 通報（Reports） ───

  /// 通報を送信する
  ///
  /// [snapshot] には通報時点の対象コンテンツを入れる。利用規約 第7条2により、
  /// 通報するとこの内容が運営に共有されることにユーザーは同意している。
  /// 保存後の通報は運営しか読めない（Firestoreルールで read を管理者に限定）ため、
  /// 誰が通報したかは相手に伝わらない（第7条4）。
  Future<void> submitReport({
    required AccountRole reporterRole,
    required ReportTargetType targetType,
    required String targetId,
    required String targetName,
    required ReportReason reason,
    String detail = '',
    Map<String, dynamic> snapshot = const {},
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('ログインが必要です');
    if (targetId == user.uid) throw Exception('自分自身は通報できません。');

    final trimmedDetail = detail.trim();
    if (trimmedDetail.length > 1000) {
      throw Exception('補足は1000文字以内で入力してください。');
    }

    await _db.collection('reports').add({
      'reporterId': user.uid,
      'reporterRole': reporterRole.id,
      'targetType': targetType.id,
      'targetId': targetId,
      'targetName': targetName,
      'reason': reason.id,
      'detail': trimmedDetail,
      'snapshot': snapshot,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 通報一覧を取得（管理者用）
  Stream<List<Report>> getReportsForAdmin({required String status}) {
    return _db
        .collection('reports')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Report.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// 通報のステータスを更新（管理者用）
  Future<void> updateReportStatus(String reportId, String status) async {
    await _db.collection('reports').doc(reportId).update({
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── ブロック（Blocks） ───

  /// ブロック情報の保存先。学生は users/{uid}/blocks、団体は organizations/{uid}/blocks
  CollectionReference<Map<String, dynamic>> _blocksRef(
    AccountRole role,
    String uid,
  ) {
    return _db
        .collection(role.blocksParentCollection)
        .doc(uid)
        .collection('blocks');
  }

  /// 相手をブロックする
  ///
  /// 学生が団体をブロックした場合、以後その団体からスカウトは届かない
  /// （利用規約 第8条2）。これはFirestoreルールが保証している。
  Future<void> blockAccount({
    required AccountRole as,
    required String targetId,
    required String targetName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('ログインが必要です');
    if (targetId == user.uid) throw Exception('自分自身はブロックできません。');

    await _blocksRef(as, user.uid).doc(targetId).set({
      'targetName': targetName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ブロックを解除する
  Future<void> unblockAccount({
    required AccountRole as,
    required String targetId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('ログインが必要です');
    await _blocksRef(as, user.uid).doc(targetId).delete();
  }

  /// 特定の相手をブロック済みか確認する
  Future<bool> isBlocked({
    required AccountRole as,
    required String targetId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _blocksRef(as, user.uid).doc(targetId).get();
    return doc.exists;
  }

  /// ブロックしたアカウントの一覧（ブロックした日時の新しい順）
  Stream<List<BlockedAccount>> getBlockedAccounts(AccountRole as) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const []);

    // createdAt はサーバー側で確定するため、書き込み直後の一時的な null で
    // 一覧から漏れないよう orderBy は使わずクライアント側で並べ替える
    return _blocksRef(as, user.uid).snapshots().map((snapshot) {
      final accounts = snapshot.docs
          .map((doc) => BlockedAccount.fromFirestore(doc.data(), doc.id))
          .toList();
      accounts.sort((a, b) {
        final aAt = a.blockedAt;
        final bAt = b.blockedAt;
        if (aAt == null) return -1;
        if (bAt == null) return 1;
        return bAt.compareTo(aAt);
      });
      return accounts;
    });
  }

  /// ブロックした相手のIDの集合（一覧画面のフィルタリング用）
  Stream<Set<String>> getBlockedIds(AccountRole as) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const {});
    return _blocksRef(as, user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  // ─── アカウント削除（管理者用） ───

  /// 団体アカウントのFirestoreデータを削除
  Future<void> deleteOrganizationAccount(String id) async {
    await _db.collection('organizations').doc(id).delete();
  }

  /// 学生アカウントのFirestoreデータを削除
  Future<void> deleteStudentAccount(String id) async {
    await _db.collection('users').doc(id).delete();
  }
}
