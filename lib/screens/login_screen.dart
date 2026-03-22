import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_notifier.dart';
import '../services/auth_service.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';

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
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isSignUpMode = false;
  bool _isOrganizationMode = false; // 団体アカウント登録フラグ
  bool _agreedToTerms = false; // 利用規約・PP同意フラグ

  /// メールアドレスのバリデーション
  /// 学生モード新規登録時は同志社大学ドメインを必須にする
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'メールアドレスを入力してください';
    }
    if (!value.contains('@') || !value.contains('.')) {
      return '正しいメールアドレスの形式で入力してください';
    }
    // 新規登録かつ学生モード（団体でない）場合、大学メール必須
    if (_isSignUpMode && !_isOrganizationMode) {
      if (!AuthService.isDoshishaEmail(value)) {
        return '学生登録には同志社大学・同志社女子大学の\nメールアドレスが必要です';
      }
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

    final authNotifier = context.read<AuthNotifier>();
    final email = _emailController.text;
    final password = _passwordController.text;

    AuthResult result;
    if (_isSignUpMode) {
      result = await authNotifier.signUp(
        email: email,
        password: password,
        isOrganization: _isOrganizationMode,
      );
    } else {
      result = await authNotifier.signIn(email: email, password: password);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      // Safari等にパスワード保存を促す
      TextInput.finishAutofillContext(shouldSave: true);
      if (kIsWeb) {
        js.context.callMethod('saveCredential', [email, password]);
      }
      // 成功時、手動での画面遷移は行わない。
      // AuthNotifierの状態変更 → AuthGate (Consumer) が自動的に画面を切り替える。
      if (_isSignUpMode) {
        if (_isOrganizationMode) {
          _showMessage('団体アカウントを作成しました。', isError: false);
        } else {
          _showMessage('アカウントを作成しました。次に学生認証を行います。', isError: false);
        }
      } else {
        _showMessage('ログインしました', isError: false);
      }
    } else {
      TextInput.finishAutofillContext(shouldSave: false);
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
    final authNotifier = context.read<AuthNotifier>();
    final result = await authNotifier.sendPasswordReset(email);
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
                  Image.asset(
                    'assets/images/doshisha_mark.png',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 24),

                  // タイトル
                  const Text(
                    'D-Hub',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'D-Hubへようこそ(・ω・)ノ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '団体側も学生側も完全無料！！',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '当サービスは同志社・同女生専用の学生とサークル・部活動・ゼミ等を繋ぐプラットフォームです。結構便利だよ(・ω・)ノ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // メールアドレス・パスワード入力（自動入力対応）
                  AutofillGroup(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: _validateEmail,
                          decoration: InputDecoration(
                            labelText: 'メールアドレス',
                            hintText: (_isSignUpMode && !_isOrganizationMode)
                                ? 'xxx@mail2.doshisha.ac.jp'
                                : 'example@gmail.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          autofillHints: _isSignUpMode
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
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
                      ],
                    ),
                  ),

                  // 利用規約・プライバシーポリシー同意チェックボックス（新規登録モード時のみ）
                  if (_isSignUpMode) ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreedToTerms,
                            onChanged: (value) {
                              setState(() => _agreedToTerms = value ?? false);
                            },
                            activeColor: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: '利用規約',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const TermsScreen(),
                                        ),
                                      );
                                    },
                                ),
                                const TextSpan(text: ' と '),
                                TextSpan(
                                  text: 'プライバシーポリシー',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const PrivacyPolicyScreen(),
                                        ),
                                      );
                                    },
                                ),
                                const TextSpan(text: ' に同意する'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),

                  // ログイン / 新規登録ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading || (_isSignUpMode && !_agreedToTerms)
                          ? null
                          : _handleSubmit,
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
                      setState(() {
                        _isSignUpMode = !_isSignUpMode;
                        _agreedToTerms = false;
                      });
                    },
                    child: Text(
                      _isSignUpMode ? 'すでにアカウントをお持ちの方はこちら' : '初めての方はこちら（新規登録）',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  // 団体アカウント登録のトグル（新規登録モード時のみ表示）
                  if (_isSignUpMode) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isOrganizationMode
                              ? AppTheme.primary
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: SwitchListTile(
                        title: const Text(
                          '団体として登録する',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          '※サークルや部活、ゼミなどの運営者の方',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        value: _isOrganizationMode,
                        onChanged: (bool value) {
                          setState(() {
                            _isOrganizationMode = value;
                          });
                        },
                        activeThumbColor: AppTheme.primary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ],

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

                  // 注意書き（学生新規登録モード時のみ表示）
                  if (_isSignUpMode && !_isOrganizationMode)
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
                              '学生登録には大学メールアドレスが必要です\n登録後に確認コードで在籍を認証します',
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
