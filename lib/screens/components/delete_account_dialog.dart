import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_notifier.dart';
import '../../theme/app_theme.dart';

/// 退会（アカウント削除）ダイアログ
///
/// App Store Review Guideline 5.1.1(v) は「アプリ内でアカウントを作成できる
/// なら、アプリ内で削除もできること」を必須にしている。学生・団体のどちらの
/// アカウントからも同じ導線で退会できるよう、確認 → 再認証 → 削除の流れを
/// ここに集約している。
///
/// [deletedItems] には、そのアカウント種別で実際に削除されるものを渡す。
/// 削除されないデータを「削除される」と書かないこと（同意の前提が崩れる）。
Future<void> showDeleteAccountDialog(
  BuildContext context, {
  required List<String> deletedItems,
}) async {
  final itemLines = deletedItems.map((e) => '・$e').join('\n');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('退会の確認'),
      content: Text(
        'アカウントを削除すると、以下のデータが即座に完全削除されます。\n\n'
        '$itemLines\n\n'
        '削除後の復元はできません。また、同じメールアドレスで再登録することは可能です。\n\n'
        '本当に退会しますか？',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('次へ', style: TextStyle(color: AppTheme.error)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // パスワード再認証ダイアログ
  final passwordController = TextEditingController();
  final password = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      bool obscure = true;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('パスワードを確認'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('退会するには現在のパスワードを入力してください。'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, passwordController.text),
              child: const Text(
                '退会する',
                style: TextStyle(color: AppTheme.error),
              ),
            ),
          ],
        ),
      );
    },
  );
  passwordController.dispose();

  if (password == null || password.isEmpty || !context.mounted) return;

  final authNotifier = context.read<AuthNotifier>();
  final result = await authNotifier.deleteAccount(password);

  if (!context.mounted) return;
  if (!result.isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: AppTheme.error,
      ),
    );
  }
  // 成功時はAuthNotifierがunauthenticatedに遷移するのでAuthGateが自動的にLoginScreenへ
}
