import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// 学生認証（2層認証の第2層）の認証サービス
///
/// 第1層（Firebase Auth: signUp/signIn/signOut）は AuthNotifier に移動済み。
/// このクラスは大学メールへの確認コード送信・検証のみを担当する。
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

  /// 確認コードを生成し、Firestoreに保存してCloud Functionsで送信
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
      // 6桁ランダムコードを生成
      final code = _generateVerificationCode();

      // Firestoreにコードを保存（有効期限: 30分）
      await _firestore.collection('users').doc(user.uid).set({
        'verificationCode': code,
        'universityEmail': universityEmail.trim().toLowerCase(),
        'codeExpiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 30)),
        ),
        'isStudentVerified': false,
      }, SetOptions(merge: true));

      // Cloud Functionsでメール送信
      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendVerificationCode',
      );
      await callable.call({
        'email': universityEmail.trim().toLowerCase(),
        'code': code,
      });

      return AuthResult.success(
        '確認コードを送信しました\n大学のメールボックス（迷惑メールフォルダ等も）を確認してください',
      );
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        return AuthResult.failure('メールの送信に失敗しました: ${e.message}');
      }
      return AuthResult.failure('確認コードの生成・送信に失敗しました');
    }
  }

  /// 確認コードを検証し、学生認証を完了
  Future<AuthResult> verifyCode(String inputCode) async {
    final user = _auth.currentUser;
    if (user == null) {
      return AuthResult.failure('ログインが必要です');
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        return AuthResult.failure('認証情報が見つかりません');
      }

      final data = doc.data()!;
      final savedCode = data['verificationCode'] as String?;
      final expiresAt = (data['codeExpiresAt'] as Timestamp?)?.toDate();

      // コードの有効期限チェック
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        return AuthResult.failure('確認コードの有効期限が切れました。\n再度コードを送信してください。');
      }

      // コード一致チェック
      if (savedCode != inputCode.trim()) {
        return AuthResult.failure('確認コードが一致しません');
      }

      // 学生認証完了！
      await _firestore.collection('users').doc(user.uid).set({
        'isStudentVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verificationCode': FieldValue.delete(), // コード削除
        'codeExpiresAt': FieldValue.delete(),
      }, SetOptions(merge: true));

      return AuthResult.success('学生認証が完了しました！🎉');
    } catch (e) {
      return AuthResult.failure('認証処理に失敗しました');
    }
  }

  // ─── ユーティリティ ───

  /// 6桁のランダム確認コードを生成
  String _generateVerificationCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }
}

/// 認証結果のクラス
class AuthResult {
  final bool isSuccess;
  final String message;
  final String? verificationCode; // MVP: コードを画面表示用に返す

  AuthResult._({
    required this.isSuccess,
    required this.message,
    this.verificationCode,
  });

  factory AuthResult.success(String message) =>
      AuthResult._(isSuccess: true, message: message);

  factory AuthResult.failure(String message) =>
      AuthResult._(isSuccess: false, message: message);

  factory AuthResult.successWithCode(String message, String code) =>
      AuthResult._(isSuccess: true, message: message, verificationCode: code);
}
