import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/auth_notifier.dart';

/// 学生認証画面（2層認証の第2層）
/// 同志社・同女の大学メールに確認コードを送信して学生であることを証明する
class StudentVerifyScreen extends StatefulWidget {
  const StudentVerifyScreen({super.key});

  @override
  State<StudentVerifyScreen> createState() => _StudentVerifyScreenState();
}

class _StudentVerifyScreenState extends State<StudentVerifyScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isCodeSent = false;

  /// 確認コードを送信
  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('大学メールアドレスを入力してください', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.sendVerificationCode(email);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _isCodeSent = true;
      });
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
    _emailController.dispose();
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
              const Center(
                child: Text(
                  'D.scoutは同志社大学・同志社女子大学の\n学生専用サービスです。\n大学メールで在籍を確認します（初回のみ）。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ステップ1: 大学メール入力
              _buildStepHeader(1, '大学メールアドレスを入力'),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isCodeSent,
                decoration: const InputDecoration(
                  hintText: 'xxx@mail2.doshisha.ac.jp',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // 対応ドメインの説明
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '対応ドメイン:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• @mail.doshisha.ac.jp（同志社大学）\n'
                      '• @mail2.doshisha.ac.jp 等（同志社大学）\n'
                      '• @dwc.doshisha.ac.jp（同志社女子大学）',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (!_isCodeSent) ...[
                // コード送信ボタン
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendCode,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('確認コードを送信'),
                  ),
                ),
              ],

              if (_isCodeSent) ...[
                const SizedBox(height: 24),

                // ステップ2: コード入力
                _buildStepHeader(2, '確認コードを入力'),
                const SizedBox(height: 12),
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
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isCodeSent = false;
                              _codeController.clear();
                            });
                          },
                    child: const Text(
                      'メールアドレスを変更する / コードを再送信',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
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
  Widget _buildStepHeader(int step, String label) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              '$step',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
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
