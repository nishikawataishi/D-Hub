import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:d_scout/screens/login_screen.dart';
import 'package:d_scout/services/auth_notifier.dart';
import 'package:d_scout/theme/app_theme.dart';

void main() {
  testWidgets('ログイン画面が正常に表示される', (WidgetTester tester) async {
    // AuthNotifier は lazy（ボタン押下まで生成されない）ため
    // Firebase 初期化なしで LoginScreen を構築できる
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthNotifier>(
        create: (_) => AuthNotifier(),
        lazy: true,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      ),
    );

    // ブランド名・主要UIが表示されることを確認
    expect(find.text('D-Hub'), findsOneWidget);
    expect(find.text('D-Hubへようこそ(・ω・)ノ'), findsOneWidget);
    expect(find.text('ログイン'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2)); // メール + パスワード
  });
}
