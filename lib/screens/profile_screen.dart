import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_notifier.dart';
import '../services/firestore_service.dart';
import '../models/campus.dart';
import '../models/user_profile.dart';
import '../models/tag.dart';
import '../theme/app_theme.dart';
import 'profile_edit_screen.dart';
import 'password_change_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';
import 'contact_screen.dart';
import 'components/photo_gallery.dart';

/// マイページ画面
/// プロフィール表示、興味関心タグの編集、設定メニュー
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditingTags = false;
  final _tagController = TextEditingController();

  final _firestoreService = FirestoreService();

  /// タグマスタの一覧（ストリームから取得）
  List<Tag> _masterTags = [];

  @override
  void initState() {
    super.initState();
    // タグマスタをストリームで購読
    _firestoreService.getTags().listen((tags) {
      if (mounted) {
        setState(() => _masterTags = tags);
      }
    });
  }

  /// タグの追加（マスタにも自動登録）
  Future<void> _addTag(String tag, UserProfile profile) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || profile.interests.contains(trimmed)) return;

    final newInterests = List<String>.from(profile.interests)..add(trimmed);
    _tagController.clear();

    // Firestoreのユーザープロフィールを更新
    await _firestoreService.updateUserProfile(profile.id, {
      'interests': newInterests,
    });

    // マスタに存在しない場合は自動登録
    await _firestoreService.addTag(trimmed);
  }

  /// タグの削除
  Future<void> _removeTag(String tag, UserProfile profile) async {
    final newInterests = List<String>.from(profile.interests)..remove(tag);

    // Firestoreを更新
    await _firestoreService.updateUserProfile(profile.id, {
      'interests': newInterests,
    });
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthNotifier>().user;
    if (user == null) {
      return const Center(child: Text('ログインしていません'));
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('マイページ')),
      body: StreamBuilder<UserProfile?>(
        stream: _firestoreService.getUserProfileStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }

          // プロフィールがまだ存在しない場合のデフォルト表示
          final profile =
              snapshot.data ??
              UserProfile(
                id: user.uid,
                name: '未設定',
                faculty: '未設定',
                grade: 1,
                mainCampus: Campus.imadegawa,
                interests: [],
              );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // プロフィールカード
                _buildProfileCard(profile),
                const SizedBox(height: 20),

                // 興味・関心タグセクション
                _buildInterestSection(profile),
                const SizedBox(height: 20),

                // 設定メニュー
                _buildSettingsMenu(profile),
              ],
            ),
          );
        },
      ),
    );
  }

  /// プロフィールカード
  Widget _buildProfileCard(UserProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // 写真ギャラリー
          if (profile.photoUrls.isNotEmpty) ...[
            PhotoGallery(photoUrls: profile.photoUrls),
            const SizedBox(height: 14),
          ] else ...[
            // アバター（写真がない場合のフォールバック）
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(25),
                shape: BoxShape.circle,
                image: profile.iconUrl != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(profile.iconUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: profile.iconUrl == null
                  ? const Icon(Icons.person, size: 40, color: AppTheme.primary)
                  : null,
            ),
            const SizedBox(height: 14),
          ],

          // 名前
          Text(
            profile.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // 学部・学年・キャンパス
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoChip(icon: Icons.school_outlined, label: profile.faculty),
              const SizedBox(width: 8),
              _InfoChip(icon: Icons.badge_outlined, label: '${profile.grade}年'),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.location_on_outlined,
                label: profile.mainCampus.label,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 興味・関心セクション
  Widget _buildInterestSection(UserProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '興味・関心',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => _isEditingTags = !_isEditingTags);
                },
                icon: Icon(
                  _isEditingTags ? Icons.check : Icons.edit_outlined,
                  size: 16,
                ),
                label: Text(_isEditingTags ? '完了' : '編集'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // タグ一覧（Wrap レイアウト）
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.interests.map((tag) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Chip(
                    label: Text(tag),
                    deleteIcon: _isEditingTags
                        ? const Icon(Icons.close, size: 16)
                        : null,
                    onDeleted: _isEditingTags
                        ? () => _removeTag(tag, profile)
                        : null,
                    backgroundColor: AppTheme.primary.withAlpha(
                      20,
                    ), // 0.08 * 255 ≈ 20
                    labelStyle: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // タグ追加入力（編集モード時のみ・オートコンプリート付き）
          if (_isEditingTags) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RawAutocomplete<String>(
                    textEditingController: _tagController,
                    focusNode: FocusNode(),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return _masterTags
                          .map((tag) => tag.name)
                          .where((name) =>
                              name.toLowerCase().contains(query) &&
                              !profile.interests.contains(name))
                          .toList();
                    },
                    fieldViewBuilder: (context, controller, focusNode,
                        onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          hintText: '新しい興味を追加（候補から選択 or 自由入力）',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (text) {
                          _addTag(text, profile);
                          onFieldSubmitted();
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    option,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  leading: const Icon(
                                    Icons.tag,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                  onTap: () {
                                    onSelected(option);
                                    _addTag(option, profile);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _addTag(_tagController.text, profile),
                  icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                  tooltip: '追加',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 退会確認ダイアログ
  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退会の確認'),
        content: const Text(
          'アカウントを削除すると、プロフィールやスカウト履歴などすべてのデータが失われます。\n\nこの操作は取り消せません。本当に退会しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '次へ',
              style: TextStyle(color: AppTheme.error),
            ),
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
                onPressed: () =>
                    Navigator.pop(context, passwordController.text),
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

  /// 設定メニュー
  Widget _buildSettingsMenu(UserProfile profile) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'プロフィール編集',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileEditScreen(profile: profile),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'パスワード変更',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PasswordChangeScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _SettingsTile(
            icon: Icons.notifications_none_outlined,
            title: '通知設定',
            onTap: () {},
          ),
          const Divider(height: 1, indent: 56),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'ヘルプ・お問い合わせ',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContactScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: '利用規約',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TermsScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'プライバシーポリシー',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          _SettingsTile(
            icon: Icons.logout,
            title: 'ログアウト',
            onTap: () async {
              final authNotifier = context.read<AuthNotifier>();
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('ログアウト'),
                  content: const Text('ログアウトしますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'ログアウト',
                        style: TextStyle(color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                authNotifier.signOut();
              }
            },
            isDestructive: true,
          ),
          const Divider(height: 1, indent: 56),
          _SettingsTile(
            icon: Icons.delete_forever_outlined,
            title: '退会する',
            onTap: () => _showDeleteAccountDialog(context),
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

/// 属性チップ（学部・学年・キャンパス表示用）
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 設定メニューのタイル
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppTheme.error : AppTheme.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: isDestructive ? AppTheme.error : AppTheme.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppTheme.textSecondary.withAlpha(127), // 0.5 * 255 ≈ 127
      ),
      onTap: onTap,
    );
  }
}
