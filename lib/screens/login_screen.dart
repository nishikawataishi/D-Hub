import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

/// ログイン画面
/// 一般メール（Gmail等）でのログイン・新規登録（2層認証の第1層）
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isSignUpMode = false;

  /// メールアドレスのバリデーション（一般メール対応）
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'メールアドレスを入力してください';
    }
    if (!value.contains('@') || !value.contains('.')) {
      return '正しいメールアドレスの形式で入力してください';
    }
    return null;
  }

  /// パスワードのバリデーション
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'パスワードを入力してください';
    }
    if (value.length < 6) {
      return 'パスワードは6文字以上で入力してください';
    }
    return null;
  }

  /// ログインまたは新規登録処理
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text;
    final password = _passwordController.text;

    AuthResult result;
    if (_isSignUpMode) {
      result = await _authService.signUp(email: email, password: password);
    } else {
      result = await _authService.signIn(email: email, password: password);
    }

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (result.isSuccess) {
      // 学生認証済みかチェックして遷移先を決める
      final isVerified = await _authService.isStudentVerified();
      if (!mounted) return;

      if (isVerified) {
        // 学生認証済み → メイン画面
        Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      } else {
        // 学生未認証 → 学生認証画面
        if (_isSignUpMode) {
          _showMessage('アカウントを作成しました。次に学生認証を行います。', isError: false);
        }
        Navigator.pushNamedAndRemoveUntil(context, '/verify', (route) => false);
      }
    } else {
      _showMessage(result.message, isError: true);
    }
  }

  /// パスワードリセット処理
  Future<void> _handlePasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('メールアドレスを入力してからリセットボタンを押してください', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.sendPasswordReset(email);
    setState(() => _isLoading = false);

    if (!mounted) return;
    _showMessage(result.message, isError: !result.isSuccess);
  }

  /// メッセージ表示（SnackBar）
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
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ロゴ
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 40,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // タイトル
                  const Text(
                    'D.scout',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '同志社大学専用\nサークル・ゼミ スカウト',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // メールアドレス入力
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    decoration: const InputDecoration(
                      labelText: 'メールアドレス',
                      hintText: 'example@gmail.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // パスワード入力
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    validator: _validatePassword,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      hintText: '6文字以上',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ログイン / 新規登録ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(_isSignUpMode ? '新規登録' : 'ログイン'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // モード切り替え
                  TextButton(
                    onPressed: () {
                      setState(() => _isSignUpMode = !_isSignUpMode);
                    },
                    child: Text(
                      _isSignUpMode ? 'すでにアカウントをお持ちの方はこちら' : '初めての方はこちら（新規登録）',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  // パスワードリセット（ログインモード時のみ）
                  if (!_isSignUpMode)
                    TextButton(
                      onPressed: _isLoading ? null : _handlePasswordReset,
                      child: const Text(
                        'パスワードを忘れた方はこちら',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 注意書き
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ログイン後、大学メールアドレスで\n学生認証を行います（初回のみ）',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
