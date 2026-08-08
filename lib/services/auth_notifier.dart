import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'auth_service.dart';

/// 認証状態を表すEnum
enum AuthStatus {
  unknown,           // 初期状態（アプリ起動直後）
  unauthenticated,   // 未ログイン → LoginScreen
  loading,           // Firestore確認中 → ローディング表示
  studentUnverified, // 学生・未認証 → StudentVerifyScreen
  studentVerified,   // 学生・認証済み → MainScreen
  organization,      // 団体アカウント → OrgDashboardScreen
  admin,             // 管理者 → AdminDashboardScreen
  error,             // エラー → リトライ画面
}

/// アプリ全体の認証状態を管理するNotifier
///
/// Firebase AuthのストリームとFirestoreのユーザーデータを統合し、
/// 単一のAuthStatusとして公開する。
/// レースコンディションを防ぐため、signUp/signIn時は
/// Firestoreドキュメント作成完了後にのみ状態を通知する。
class AuthNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  StreamSubscription<User?>? _authSub;
  bool _isManualAuthAction = false;

  AuthStatus get status => _status;
  User? get user => _user;

  AuthNotifier() {
    _authSub = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// Firebase Authストリームのリスナー
  /// コールドスタート（既存セッション）やsignOut時に発火する。
  /// signUp/signIn実行中は _isManualAuthAction で無視する。
  void _onAuthStateChanged(User? user) async {
    if (_isManualAuthAction) return;

    if (user == null) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // コールドスタート: 既存セッションのユーザーを検出
    _user = user;
    _status = AuthStatus.loading;
    notifyListeners();
    await _resolveUserStatus(user.uid);
  }

  /// Firestoreからアカウント種別と認証状態を判定
  Future<void> _resolveUserStatus(String uid) async {
    // カスタムクレームで管理者チェック（IDトークンを強制更新して最新クレームを取得）
    try {
      final idTokenResult = await _user?.getIdTokenResult(true);
      if (idTokenResult?.claims?['admin'] == true) {
        _status = AuthStatus.admin;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('AuthNotifier: custom claims check error: $e');
    }

    // 最大2回試行（初回 + 1秒後にリトライ）
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        // 団体アカウントかチェック
        final orgDoc =
            await _firestore.collection('organizations').doc(uid).get();
        if (orgDoc.exists) {
          _status = AuthStatus.organization;
          notifyListeners();
          return;
        }

        // 学生アカウントかチェック
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final isVerified = userDoc.data()?['isStudentVerified'] == true;
          _status = isVerified
              ? AuthStatus.studentVerified
              : AuthStatus.studentUnverified;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('AuthNotifier._resolveUserStatus error: $e');
      }

      // ドキュメントが見つからない場合、1秒待ってリトライ
      if (attempt < 1) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    // タイムアウト: エラー状態にする
    _status = AuthStatus.error;
    notifyListeners();
  }

  // ─── 第1層: アカウント認証（Firebase Auth） ───

  /// 新規登録（メール + パスワード）
  /// レースコンディション対策: createUser → ドキュメント作成 → status設定 → notify
  Future<AuthResult> signUp({
    required String email,
    required String password,
    bool isOrganization = false,
  }) async {
    _isManualAuthAction = true;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _user = _auth.currentUser;

      // Firestoreドキュメント作成を完了させてから状態を更新
      await _createUserDocument(isOrganization: isOrganization);

      _status = isOrganization
          ? AuthStatus.organization
          : AuthStatus.studentUnverified;
      notifyListeners();
      return AuthResult.success(
        isOrganization ? '団体アカウントを作成しました' : 'アカウントを作成しました',
      );
    } on FirebaseAuthException catch (e) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _isManualAuthAction = false;
      notifyListeners();
      return AuthResult.failure(_mapFirebaseError(e.code));
    } catch (e) {
      // Firestoreドキュメント作成失敗: AuthアカウントをサインアウトしてUIに通知する前に
      // エラーメッセージを返す（notifyListeners前にreturnすることでSnackBarを表示できる）
      debugPrint('signUp error: $e');
      await _auth.signOut();
      _user = null;
      _isManualAuthAction = false;
      final errorMessage = 'アカウント作成に失敗しました: $e';
      // 次フレームで状態更新（先にSnackBarを表示させるため）
      Future.microtask(() {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      });
      return AuthResult.failure(errorMessage);
    } finally {
      _isManualAuthAction = false;
    }
  }

  /// ログイン（メール + パスワード）
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    _isManualAuthAction = true;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _user = _auth.currentUser;

      // Firestoreからアカウント種別を判定
      await _resolveUserStatus(_user!.uid);
      return AuthResult.success('ログインしました');
    } on FirebaseAuthException catch (e) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return AuthResult.failure(_mapFirebaseError(e.code));
    } catch (e) {
      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return AuthResult.failure('ログインに失敗しました');
    } finally {
      _isManualAuthAction = false;
    }
  }

  /// ログアウト
  Future<void> signOut() async {
    await _auth.signOut();
    // _onAuthStateChanged が自動的に unauthenticated を設定
  }

  /// ログイン中のユーザーのパスワードを変更
  Future<AuthResult> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return AuthResult.failure('ログインが必要です');
    }

    try {
      // 現在のパスワードで再認証
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // パスワード更新
      await user.updatePassword(newPassword);
      return AuthResult.success('パスワードを変更しました');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e.code));
    } catch (e) {
      return AuthResult.failure('パスワードの変更に失敗しました');
    }
  }

  /// アカウント削除（退会）
  ///
  /// 再認証したうえで Cloud Function `deleteMyAccount` を呼ぶだけ。
  /// Firestore・Storage・Auth の削除はすべてサーバー側（Admin SDK）で行う。
  ///
  /// クライアントで逐次削除していた頃は、規約第14条2「登録データは削除されます」を
  /// 満たせていなかった。学生は自分の申し込み（events/{id}/applications）を
  /// 列挙できず（list ルールが主催団体のみ）、Storage の画像も消せないため。
  /// さらに逐次削除は途中で失敗しても続行していたので、Auth ユーザーだけ消えて
  /// 誰も再試行できない孤児データが残りうる状態だった。
  Future<AuthResult> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return AuthResult.failure('ログインが必要です');
    }

    try {
      // 再認証
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // 再認証後の auth_time を反映したトークンに更新してから呼ぶ。
      // サーバー側が直近の再認証を必須にしているため、これを省くと弾かれる。
      await user.getIdToken(true);

      await FirebaseFunctions.instance.httpsCallable('deleteMyAccount').call();

      // Auth ユーザーはサーバー側で削除済み。ローカルの状態だけ落とす。
      await _auth.signOut();

      _user = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return AuthResult.success('アカウントを削除しました');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e.code));
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        return AuthResult.failure(
          'セキュリティのため、もう一度パスワードを入力してやり直してください',
        );
      }
      return AuthResult.failure(e.message ?? 'アカウントの削除に失敗しました');
    } catch (e) {
      return AuthResult.failure('アカウントの削除に失敗しました');
    }
  }

  /// パスワードリセットメールを送信
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(
        'パスワードリセットメールを送信しました。\nメールを確認してください。',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e.code));
    }
  }

  /// 学生認証完了時に呼び出す
  /// StudentVerifyScreenから呼ばれ、AuthGateがMainScreenに切り替わる
  void completeVerification() {
    _status = AuthStatus.studentVerified;
    notifyListeners();
  }

  /// エラー状態からリトライ
  Future<void> retry() async {
    if (_user != null) {
      _status = AuthStatus.loading;
      notifyListeners();
      await _resolveUserStatus(_user!.uid);
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // ─── ユーティリティ ───

  /// Firestoreにユーザードキュメントを作成
  Future<void> _createUserDocument({bool isOrganization = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (isOrganization) {
      // 団体アカウントとして作成（get()を省略してset()に直接）
      await _firestore.collection('organizations').doc(user.uid).set({
        'name': '団体名未設定',
        'description': '',
        'categories': ['culture'],
        'campus': 'both',
        'logoEmoji': '🎨',
        'instagramUrl': '',
        'groupLineUrl': '',
        'isOfficial': false,
        'photoUrls': [],
        'status': 'pending',
        'representativeId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // 学生アカウントの初期化
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        // emailはFirebase Auth側で管理（usersドキュメントは団体に公開されるため保存しない）
        await _firestore.collection('users').doc(user.uid).set({
          'isStudentVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  /// Firebaseのエラーコードを日本語メッセージに変換
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'このメールアドレスは既に登録されています';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      case 'user-not-found':
        return 'このメールアドレスは登録されていません';
      case 'wrong-password':
        return 'パスワードが間違っています';
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが間違っています';
      case 'weak-password':
        return 'パスワードが弱すぎます。6文字以上にしてください';
      case 'too-many-requests':
        return 'ログイン試行回数が多すぎるため、アカウントが一時的にロックされました。\nしばらく時間をおいてから再試行するか、パスワードリセットをご利用ください。';
      case 'user-disabled':
        return 'このアカウントは無効化されています';
      case 'network-request-failed':
        return 'ネットワーク接続を確認してください';
      default:
        return 'エラーが発生しました（$code）';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
