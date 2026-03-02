import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/student_verify_screen.dart';
import 'screens/org_dashboard_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

/// D.scout アプリのエントリーポイント
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    try {
      // Android Emulatorの場合は '10.0.2.2'、iOS/Webの場合は 'localhost' に適宜変更してください。
      // 実機テストの場合はPCのローカルIPアドレスを設定します。
      const host = 'localhost';
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      debugPrint('Cloud Functions Emulator configured to use $host:5001');
    } catch (e) {
      debugPrint('Failed to configure Cloud Functions Emulator: $e');
    }
  }

  runApp(const DScoutApp());
}

/// アプリケーションルート
class DScoutApp extends StatelessWidget {
  const DScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D.scout',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
        '/verify': (context) => const StudentVerifyScreen(),
        '/org_dashboard': (context) => const OrgDashboardScreen(),
      },
    );
  }
}

/// 認証状態を監視し、画面を切り替える
/// 未ログイン → ログイン画面
/// ログイン済み＆学生未認証 → 学生認証画面
/// ログイン済み＆学生認証済み → メイン画面
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  Future<Map<String, dynamic>> _checkUserStatus(String uid) async {
    // データ登録までにラグがある可能性を考慮して最大10回（計5秒）リトライする
    for (int i = 0; i < 10; i++) {
      // 団体アカウントかチェック
      try {
        final isOrg = await _firestoreService.getOrganization(uid) != null;
        if (isOrg) {
          return {'isOrg': true, 'isVerified': false};
        }
      } catch (e) {
        // 例外時は無視して続行
      }

      // 一般ユーザーのドキュメントが存在するかチェック（学生認証フラグ取得のため）
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists) {
          final isVerified = await _authService.isStudentVerified();
          return {'isOrg': false, 'isVerified': isVerified};
        }
      } catch (e) {
        // 例外時は無視してリトライ
      }

      // どちらのデータも見つからない場合は作成中とみなして待機
      if (i < 9) await Future.delayed(const Duration(milliseconds: 500));
    }

    // タイムアウトした場合はデフォルトで未認証の学生として扱う（フェイルセーフ）
    return {'isOrg': false, 'isVerified': false};
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 読み込み中
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 未ログイン → ログイン画面
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // ログイン済み → 学生認証チェック
        // 毎回新しいFutureを生成してキャッシュを防ぐ
        return FutureBuilder<Map<String, dynamic>>(
          key: ValueKey(snapshot.data?.uid),
          future: _checkUserStatus(snapshot.data!.uid),
          builder: (context, statusSnapshot) {
            if (statusSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final status = statusSnapshot.data;
            if (status?['isOrg'] == true) {
              return const OrgDashboardScreen();
            }

            // 学生認証済み → メイン画面
            if (status?['isVerified'] == true) {
              return const MainScreen();
            }

            // 学生未認証 → 学生認証画面
            return const StudentVerifyScreen();
          },
        );
      },
    );
  }
}
