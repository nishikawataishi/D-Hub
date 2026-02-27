import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/mock_data.dart';

/// Firestoreのデータ操作を行うサービス
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── 団体（Organizations） ───

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
    final data = doc.data() as Map<String, dynamic>;
    return Organization(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: OrgCategory.values.firstWhere(
        (c) => c.name == data['category'],
        orElse: () => OrgCategory.all,
      ),
      campus: Campus.values.firstWhere(
        (c) => c.name == data['campus'],
        orElse: () => Campus.both,
      ),
      logoEmoji: data['logoEmoji'] ?? '🏫',
      instagramUrl: data['instagramUrl'] ?? 'https://www.instagram.com/',
    );
  }

  // ─── スカウト（Scouts） ───

  /// 特定ユーザー宛のスカウトを取得
  Stream<List<Map<String, dynamic>>> getScoutsForUser(String userId) {
    return _db
        .collection('scouts')
        .where('targetUserId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// スカウトを既読にする
  Future<void> markScoutAsRead(String scoutId) async {
    await _db.collection('scouts').doc(scoutId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── イベント（Events） ───

  /// 今後のイベントを取得
  Stream<List<Map<String, dynamic>>> getUpcomingEvents() {
    return _db
        .collection('events')
        .where('startAt', isGreaterThan: Timestamp.now())
        .orderBy('startAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  // ─── ユーザープロフィール ───

  /// ユーザープロフィールを取得
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return doc.data();
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
