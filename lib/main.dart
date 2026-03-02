import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/student_verify_screen.dart';
import 'screens/org_dashboard_screen.dart';
import 'services/auth_notifier.dart';

/// D.scout アプリのエントリーポイント
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // エミュレータ接続: --dart-define=USE_EMULATOR=true のときのみ有効
  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  if (useEmulator) {
    try {
      const host = 'localhost';
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      debugPrint('Firebase Emulators configured (Firestore:8080, Auth:9099, Functions:5001)');
    } catch (e) {
      debugPrint('Failed to configure Emulators: $e');
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthNotifier(),
      child: const DScoutApp(),
    ),
  );
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
/// AuthNotifier (ChangeNotifier) の AuthStatus に応じて適切な画面を返す。
/// StreamBuilder + FutureBuilder のキャッシュ問題・レースコンディションを
/// Provider パターンで根本的に解消。
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthNotifier>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.unknown:
          case AuthStatus.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case AuthStatus.unauthenticated:
            return const LoginScreen();
          case AuthStatus.studentUnverified:
            return const StudentVerifyScreen();
          case AuthStatus.studentVerified:
            return const MainScreen();
          case AuthStatus.organization:
            return const OrgDashboardScreen();
          case AuthStatus.error:
            return _buildErrorScreen(context, auth);
        }
      },
    );
  }

  Widget _buildErrorScreen(BuildContext context, AuthNotifier auth) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'アカウント情報の取得に失敗しました',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'ネットワーク接続を確認して\nもう一度お試しください',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => auth.retry(),
                child: const Text('再試行'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => auth.signOut(),
                child: const Text('ログアウト'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
