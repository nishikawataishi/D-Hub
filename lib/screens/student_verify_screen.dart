import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/auth_notifier.dart';

/// 学生認証画面（確認コード入力）
/// Firebase Authの登録メール（大学メール）に確認コードを自動送信し、
/// コード入力のみで認証を完了する。
class StudentVerifyScreen extends StatefulWidget {
  const StudentVerifyScreen({super.key});

  @override
  State<StudentVerifyScreen> createState() => _StudentVerifyScreenState();
}

class _StudentVerifyScreenState extends State<StudentVerifyScreen> {
  final _codeController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isCodeSent = false;
  bool _isSendingCode = false;
  String? _universityEmail;

  @override
  void initState() {
    super.initState();
    // 画面表示時に自動でコード送信
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSendCode();
    });
  }

  /// Firebase Authのメールアドレスを使って自動でコード送信
  Future<void> _autoSendCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      _showMessage('ログイン情報が見つかりません', isError: true);
      return;
    }

    final email = user.email!;
    setState(() {
      _universityEmail = email;
      _isSendingCode = true;
    });

    final result = await _authService.sendVerificationCode(email);

    if (!mounted) return;
    setState(() => _isSendingCode = false);

    if (result.isSuccess) {
      setState(() => _isCodeSent = true);
      _showMessage(result.message, isError: false);
    } else {
      _showMessage(result.message, isError: true);
    }
  }

  /// コード再送信
  Future<void> _resendCode() async {
    if (_universityEmail == null) return;

    setState(() => _isSendingCode = true);
    final result =
        await _authService.sendVerificationCode(_universityEmail!);

    if (!mounted) return;
    setState(() => _isSendingCode = false);

    if (result.isSuccess) {
      _codeController.clear();
      _showMessage(result.message, isError: false);
    } else {
      _showMessage(result.message, isError: true);
    }
  }

  /// 確認コードを検証
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showMessage('確認コードを入力してください', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.verifyCode(code);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.isSuccess) {
      _showMessage(result.message, isError: false);
      // 学生認証完了 → AuthNotifierの状態を更新し、AuthGateがMainScreenに切り替える
      await Future.delayed(const Duration(milliseconds: 500));
      if (context.mounted) {
        context.read<AuthNotifier>().completeVerification();
      }
    } else {
      _showMessage(result.message, isError: true);
    }
  }

  /// メッセージ表示
  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('学生認証'),
        actions: [
          // ログアウトボタン
          TextButton(
            onPressed: () {
              context.read<AuthNotifier>().signOut();
            },
            child: const Text(
              'ログアウト',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダーアイコン
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    size: 40,
                    color: Colors.amber,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 説明
              const Center(
                child: Text(
                  '学生認証',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _universityEmail != null
                      ? '$_universityEmail に\n確認コードを送信しました'
                      : '大学メールに確認コードを送信しています...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // コード送信中のローディング
              if (_isSendingCode) ...[
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 16),
                      Text(
                        '確認コードを送信中...',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // コード入力（送信完了後）
              if (_isCodeSent) ...[
                _buildStepHeader('確認コードを入力'),
                const SizedBox(height: 12),

                // 対応ドメインの説明
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.mail_outline,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '大学のメールボックス（迷惑メールフォルダ等も）を確認してください',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                  ),
                  decoration: const InputDecoration(
                    hintText: '000000',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),

                // 認証ボタン
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('認証する'),
                  ),
                ),
                const SizedBox(height: 12),

                // コード再送信
                Center(
                  child: TextButton(
                    onPressed: (_isLoading || _isSendingCode)
                        ? null
                        : _resendCode,
                    child: const Text(
                      'コードを再送信する',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],

              // コード送信失敗時のリトライ
              if (!_isCodeSent && !_isSendingCode) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _autoSendCode,
                    child: const Text('確認コードを再送信'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// ステップヘッダー
  Widget _buildStepHeader(String label) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Icon(
              Icons.pin_outlined,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
