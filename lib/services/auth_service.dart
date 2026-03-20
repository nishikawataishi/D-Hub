import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// 学生認証（2層認証の第2層）の認証サービス
///
/// 第1層（Firebase Auth: signUp/signIn/signOut）は AuthNotifier に移動済み。
/// このクラスは大学メールへの確認コード送信・検証のみを担当する。
/// コード生成・ハッシュ化・検証はすべてCloud Function（サーバー側）で実行される。
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 同志社・同女大メールの正規表現
  /// @mail.doshisha.ac.jp, @mail2.doshisha.ac.jp, @dwc.doshisha.ac.jp 等
  static final RegExp doshishaEmailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@(mail\d*\.doshisha\.ac\.jp|dwc\.doshisha\.ac\.jp)$',
    caseSensitive: false,
  );

  // ─── 第2層: 学生認証（大学メール確認コード） ───

  /// 大学メールアドレスの形式を検証
  static bool isDoshishaEmail(String email) {
    return doshishaEmailRegex.hasMatch(email.trim().toLowerCase());
  }

  /// 学生認証済みかどうかを確認
  Future<bool> isStudentVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;
      return doc.data()?['isStudentVerified'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Cloud Functionを呼び出して確認コードを生成・送信
  /// コード生成・ハッシュ化・保存はすべてサーバー側で実行される
  Future<AuthResult> sendVerificationCode(String universityEmail) async {
    final user = _auth.currentUser;
    if (user == null) {
      return AuthResult.failure('ログインが必要です');
    }

    if (!isDoshishaEmail(universityEmail)) {
      return AuthResult.failure(
        '同志社大学または同志社女子大学のメールアドレスを入力してください\n'
        '（例: xxx@mail2.doshisha.ac.jp, xxx@dwc.doshisha.ac.jp）',
      );
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendVerificationCode',
      );
      await callable.call({
        'email': universityEmail.trim().toLowerCase(),
      });

      return AuthResult.success(
        '確認コードを送信しました\n大学のメールボックス（迷惑メールフォルダ等も）を確認してください',
      );
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        if (e.code == 'resource-exhausted') {
          return AuthResult.failure('コード送信回数の上限に達しました。\nしばらくしてから再度お試しください。');
        }
        return AuthResult.failure('メールの送信に失敗しました: ${e.message}');
      }
      return AuthResult.failure('確認コードの送信に失敗しました');
    }
  }

  /// Cloud Functionを呼び出して確認コードを検証
  /// ハッシュ比較・試行回数制限はすべてサーバー側で実行される
  Future<AuthResult> verifyCode(String inputCode) async {
    final user = _auth.currentUser;
    if (user == null) {
      return AuthResult.failure('ログインが必要です');
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifyCode',
      );
      final result = await callable.call({
        'code': inputCode.trim(),
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return AuthResult.success('学生認証が完了しました！');
      } else {
        return AuthResult.failure(data['message'] as String? ?? '確認コードが一致しません');
      }
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        if (e.code == 'resource-exhausted') {
          return AuthResult.failure('認証コードの試行回数上限に達しました。\n新しいコードを送信してください。');
        }
        if (e.code == 'deadline-exceeded') {
          return AuthResult.failure('確認コードの有効期限が切れました。\n再度コードを送信してください。');
        }
        return AuthResult.failure(e.message ?? '認証処理に失敗しました');
      }
      return AuthResult.failure('認証処理に失敗しました');
    }
  }
}

/// 認証結果のクラス
class AuthResult {
  final bool isSuccess;
  final String message;

  AuthResult._({
    required this.isSuccess,
    required this.message,
  });

  factory AuthResult.success(String message) =>
      AuthResult._(isSuccess: true, message: message);

  factory AuthResult.failure(String message) =>
      AuthResult._(isSuccess: false, message: message);
}
