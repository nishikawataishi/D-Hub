import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/student_verify_screen.dart';
import 'services/auth_service.dart';

/// D.scout アプリのエントリーポイント
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        return FutureBuilder<bool>(
          key: ValueKey(snapshot.data?.uid),
          future: _authService.isStudentVerified(),
          builder: (context, verifySnapshot) {
            if (verifySnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // 学生認証済み → メイン画面
            if (verifySnapshot.data == true) {
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
