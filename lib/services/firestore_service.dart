import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/mock_data.dart';
import '../models/scout.dart';

/// Firestoreのデータ操作を行うサービス
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── 団体（Organizations） ───

  /// 単一団体を取得
  Future<Organization?> getOrganization(String id) async {
    final doc = await _db.collection('organizations').doc(id).get();
    if (!doc.exists) return null;
    return Organization.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// 団体情報を保存
  Future<void> saveOrganization(Organization org) async {
    await _db
        .collection('organizations')
        .doc(org.id)
        .set(org.toJson(), SetOptions(merge: true));
  }

  /// 全団体を取得
  Stream<List<Organization>> getOrganizations() {
    return _db
        .collection('organizations')
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
    return _db
        .collection('organizations')
        .where('category', isEqualTo: category.name)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => _organizationFromDoc(doc)).toList(),
        );
  }

  /// Firestoreドキュメント → Organizationモデル変換
  Organization _organizationFromDoc(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return Organization.empty(doc.id);
    }
    return Organization.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  // ─── スカウト（Scouts） ───

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

  /// スカウトを既読にする
  Future<void> markScoutAsRead(String scoutId) async {
    await _db.collection('scouts').doc(scoutId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  /// スカウトを送信する
  Future<void> sendScout({
    required String targetUserId,
    required Organization senderOrg,
    required String message,
  }) async {
    // 重複送信のチェック: 同じ学生に未読のスカウトが既にある場合はエラー
    final existingScouts = await _db
        .collection('scouts')
        .where('targetUserId', isEqualTo: targetUserId)
        .where('organizationId', isEqualTo: senderOrg.id)
        .where('isRead', isEqualTo: false)
        .get();

    if (existingScouts.docs.isNotEmpty) {
      throw Exception('すでにこの学生には未読のスカウトを送信済みです。');
    }

    final now = DateTime.now();
    final scoutData = Scout(
      id: '', // Firestoreが自動生成するため空でOKだが、toFirestoreでは保存されない
      targetUserId: targetUserId,
      organizationId: senderOrg.id,
      organizationName: senderOrg.name,
      organizationEmoji: senderOrg.logoEmoji,
      organizationCategory: senderOrg.category.name,
      message: message,
      isRead: false,
      sentAt: now,
      organizationInstagramUrl: senderOrg.instagramUrl,
      organizationLogoUrl: senderOrg.logoUrl,
    ).toFirestore();

    scoutData['sentAt'] = FieldValue.serverTimestamp();

    await _db.collection('scouts').add(scoutData);
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
        .where('name', isNotEqualTo: null)
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

  // ─── 初期データ投入（開発用） ───

  /// モックデータをFirestoreに投入する（1回だけ実行する開発用関数）
  Future<void> seedData() async {
    final batch = _db.batch();
    final user = _auth.currentUser;

    // 団体データを投入
    for (final org in mockOrganizations) {
      final docRef = _db.collection('organizations').doc(org.id);
      batch.set(docRef, {
        'name': org.name,
        'description': org.description,
        'category': org.category.name,
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

    // 現在ログイン中のユーザーがいれば、その人宛のテストスカウトを作成
    if (user != null) {
      final scoutDoc = _db.collection('scouts').doc('test_scout_${user.uid}');
      batch.set(scoutDoc, {
        'targetUserId': user.uid,
        'organizationId': '1',
        'organizationName': 'D-spirits',
        'organizationEmoji': '🏀',
        'organizationCategory': 'スポーツ',
        'message': 'Firestoreからのテストスカウトです！動作確認おめでとうございます！🎉',
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }

    await batch.commit();
  }
}
