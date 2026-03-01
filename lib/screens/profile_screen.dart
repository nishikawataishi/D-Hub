import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/campus.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'profile_edit_screen.dart';

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
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  /// タグの追加
  Future<void> _addTag(String tag, UserProfile profile) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || profile.interests.contains(trimmed)) return;

    final newInterests = List<String>.from(profile.interests)..add(trimmed);
    _tagController.clear();

    // Firestore を更新
    await _firestoreService.updateUserProfile(profile.id, {
      'interests': newInterests,
    });
  }

  /// タグの削除
  Future<void> _removeTag(String tag, UserProfile profile) async {
    final newInterests = List<String>.from(profile.interests)..remove(tag);

    // Firestore を更新
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
    final user = _authService.currentUser;
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
          // アバター
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(25), // 0.1 * 255 ≈ 25
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 14),

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

          // タグ追加入力（編集モード時のみ）
          if (_isEditingTags) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: '新しい興味を追加',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (text) => _addTag(text, profile),
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
            icon: Icons.notifications_none_outlined,
            title: '通知設定',
            onTap: () {},
          ),
          const Divider(height: 1, indent: 56),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'ヘルプ・お問い合わせ',
            onTap: () {},
          ),
          const Divider(height: 1, indent: 56),
          _SettingsTile(
            icon: Icons.logout,
            title: 'ログアウト',
            onTap: () async {
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
              if (confirmed == true && mounted) {
                await _authService.signOut();
              }
            },
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
