import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_notifier.dart';
import '../services/firestore_service.dart';
import '../models/organization.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'password_change_screen.dart';

/// 管理者用ダッシュボード画面
/// 団体の審査承認・却下、ユーザー一覧を行う
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_currentTab) {
          0 => '団体管理',
          1 => 'ユーザー管理',
          _ => 'お問い合わせ',
        }),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            tooltip: 'パスワード変更',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PasswordChangeScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthNotifier>().signOut(),
          ),
        ],
      ),
      body: switch (_currentTab) {
        0 => const _OrganizationManagementTab(),
        1 => const _UserManagementTab(),
        _ => const _ContactManagementTab(),
      },
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        selectedItemColor: AppTheme.primary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: '団体管理',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'ユーザー管理',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail_outline),
            label: 'お問い合わせ',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 団体管理タブ
// ============================================================

class _OrganizationManagementTab extends StatefulWidget {
  const _OrganizationManagementTab();

  @override
  State<_OrganizationManagementTab> createState() =>
      _OrganizationManagementTabState();
}

class _OrganizationManagementTabState
    extends State<_OrganizationManagementTab> {
  final FirestoreService _firestoreService = FirestoreService();
  String _filter = 'pending';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterChips(),
        Expanded(child: _buildOrganizationList()),
      ],
    );
  }

  Widget _buildFilterChips() {
    const filters = {
      'pending': '審査待ち',
      'rejected': '却下',
      'verified': '承認済み',
      'suspended': '停止中',
      'all': '全件',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: filters.entries.map((e) {
          final isSelected = _filter == e.key;
          return FilterChip(
            label: Text(e.value),
            selected: isSelected,
            onSelected: (_) => setState(() => _filter = e.key),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrganizationList() {
    final stream = _filter == 'all'
        ? _firestoreService.getAllOrganizationsForAdmin()
        : _firestoreService.getOrganizationsByStatus(_filter);

    return StreamBuilder<List<Organization>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラー: ${snapshot.error}'));
        }
        final orgs = snapshot.data ?? [];
        if (orgs.isEmpty) {
          return const Center(
            child:
                Text('該当する団体はありません', style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: orgs.length,
          itemBuilder: (context, index) => _OrgReviewCard(
            org: orgs[index],
            onApprove: () => _updateStatus(orgs[index], 'verified'),
            onReject: () => _updateStatus(orgs[index], 'rejected'),
            onSuspend: () => _updateStatus(orgs[index], 'suspended'),
            onViewDetail: () => _showOrgDetail(context, orgs[index]),
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(Organization org, String newStatus) async {
    final label = switch (newStatus) {
      'verified' => '承認',
      'rejected' => '却下',
      'suspended' => '承認取り消し',
      _ => newStatus,
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$labelの確認'),
        content: Text('「${org.name}」を$labelしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _firestoreService.updateOrganizationStatus(org.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${org.name}」を$labelしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  void _showOrgDetail(BuildContext context, Organization org) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ロゴ + 名前 + ステータス
                Row(
                  children: [
                    org.logoUrl != null
                        ? CircleAvatar(
                            radius: 30,
                            backgroundImage:
                                CachedNetworkImageProvider(org.logoUrl!),
                          )
                        : CircleAvatar(
                            radius: 30,
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.1),
                            child: Text(org.logoEmoji,
                                style: const TextStyle(fontSize: 24)),
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(org.name,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          _StatusBadge(status: org.status),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _DetailRow(label: 'カテゴリ',
                    value: org.categories.map((c) => c.label).join(', ')),
                _DetailRow(label: 'キャンパス', value: org.campus.label),
                if (org.instagramUrl.isNotEmpty)
                  _DetailRow(label: 'Instagram', value: org.instagramUrl),
                if (org.groupLineUrl.isNotEmpty)
                  _DetailRow(label: 'グループLINE', value: org.groupLineUrl),
                _DetailRow(
                    label: '代表者UID',
                    value: org.representativeId ?? '不明'),
                if (org.createdAt != null)
                  _DetailRow(
                      label: '申請日',
                      value: _formatDate(org.createdAt!)),
                if (org.verifiedAt != null)
                  _DetailRow(
                      label: '承認日',
                      value: _formatDate(org.verifiedAt!)),
                const SizedBox(height: 12),
                const Text('紹介文',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey)),
                const SizedBox(height: 6),
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(org.description,
                      style:
                          const TextStyle(fontSize: 13, height: 1.5)),
                ),
                // 証明画像
                if (org.proofImageUrl != null &&
                    org.proofImageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('証明画像',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      org.proofImageUrl!,
                      width: double.maxFinite,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ],
                // 写真ギャラリー
                if (org.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('写真',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: org.photoUrls.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 6),
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          org.photoUrls[i],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteOrg(context, org);
            },
            child: const Text('アカウント削除',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrg(BuildContext context, Organization org) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('団体アカウント削除'),
        content: Text(
            '「${org.name}」のアカウントを削除しますか？\n\nこの操作は取り消せません。Firestoreのデータが削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _firestoreService.deleteOrganizationAccount(org.id);
      messenger.showSnackBar(
          SnackBar(content: Text('「${org.name}」を削除しました')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('エラー: $e')));
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}

// ============================================================
// ユーザー管理タブ
// ============================================================

class _UserManagementTab extends StatefulWidget {
  const _UserManagementTab();

  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 検索バー
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '名前・学部で検索',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
          ),
        ),
        // ユーザー一覧
        Expanded(
          child: StreamBuilder<List<UserProfile>>(
            stream: _firestoreService.getAllUsersForAdmin(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('エラー: ${snapshot.error}'));
              }
              final allUsers = snapshot.data ?? [];
              final users = _searchQuery.isEmpty
                  ? allUsers
                  : allUsers.where((u) {
                      final q = _searchQuery.toLowerCase();
                      return u.name.toLowerCase().contains(q) ||
                          u.faculty.toLowerCase().contains(q);
                    }).toList();

              if (users.isEmpty) {
                return const Center(
                  child: Text('該当するユーザーはいません',
                      style: TextStyle(color: Colors.grey)),
                );
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withAlpha(25),
                      backgroundImage: user.iconUrl != null
                          ? CachedNetworkImageProvider(user.iconUrl!)
                          : null,
                      child: user.iconUrl == null
                          ? const Icon(Icons.person,
                              color: AppTheme.primary, size: 20)
                          : null,
                    ),
                    title: Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${user.faculty} / ${user.grade}年 / ${user.mainCampus.label}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: Colors.grey[400]),
                    onTap: () => _showUserDetail(context, user),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showUserDetail(BuildContext context, UserProfile user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.name),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // アイコン
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.primary.withAlpha(25),
                  backgroundImage: user.iconUrl != null
                      ? CachedNetworkImageProvider(user.iconUrl!)
                      : null,
                  child: user.iconUrl == null
                      ? const Icon(Icons.person,
                          color: AppTheme.primary, size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(label: '学部', value: user.faculty),
              _DetailRow(label: '学年', value: '${user.grade}年'),
              _DetailRow(label: 'キャンパス', value: user.mainCampus.label),
              _DetailRow(label: 'UID', value: user.id),
              if (user.interests.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('興味・関心',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: user.interests
                      .map((tag) => Chip(
                            label: Text(tag,
                                style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: AppTheme.primary.withAlpha(20),
                            side: BorderSide.none,
                          ))
                      .toList(),
                ),
              ],
              // 写真ギャラリー
              if (user.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('写真',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: user.photoUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        user.photoUrls[index],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, _) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(context, user);
            },
            child: const Text('アカウント削除',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(BuildContext context, UserProfile user) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('学生アカウント削除'),
        content: Text(
            '「${user.name}」のアカウントを削除しますか？\n\nこの操作は取り消せません。Firestoreのデータが削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _firestoreService.deleteStudentAccount(user.id);
      messenger.showSnackBar(
          SnackBar(content: Text('「${user.name}」を削除しました')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('エラー: $e')));
    }
  }
}

// ============================================================
// 共通ウィジェット
// ============================================================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// 団体審査カード
class _OrgReviewCard extends StatelessWidget {
  final Organization org;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onSuspend;
  final VoidCallback onViewDetail;

  const _OrgReviewCard({
    required this.org,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー: 団体名 + ステータスバッジ
            Row(
              children: [
                Text(
                  org.logoEmoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        org.categories.map((c) => c.label).join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: org.status),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  color: Colors.grey[500],
                  tooltip: '詳細を見る',
                  onPressed: onViewDetail,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 詳細情報
            _InfoRow(icon: Icons.location_on, text: org.campus.label),
            if (org.instagramUrl.isNotEmpty)
              _InfoRow(icon: Icons.link, text: org.instagramUrl),
            if (org.createdAt != null)
              _InfoRow(
                icon: Icons.calendar_today,
                text: '申請日: ${_formatDate(org.createdAt!)}',
              ),
            // 証明画像
            if (org.proofImageUrl != null &&
                org.proofImageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '証明画像:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _showFullImage(context, org.proofImageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    org.proofImageUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, _) => Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              ),
            ],
            // アクションボタン
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (org.status) {
      case 'pending':
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('却下'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onApprove,
                child: const Text('承認'),
              ),
            ],
          ),
        );
      case 'verified':
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: onSuspend,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('承認取り消し'),
              ),
            ],
          ),
        );
      case 'rejected':
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: onApprove,
                child: const Text('承認'),
              ),
            ],
          ),
        );
      case 'suspended':
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('却下'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onApprove,
                child: const Text('再承認'),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('審査待ち', Colors.orange),
      'verified' => ('承認済み', Colors.green),
      'rejected' => ('却下', Colors.red),
      'suspended' => ('停止中', Colors.grey),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// お問い合わせ管理タブ
// ============================================================

class _ContactManagementTab extends StatefulWidget {
  const _ContactManagementTab();

  @override
  State<_ContactManagementTab> createState() => _ContactManagementTabState();
}

class _ContactManagementTabState extends State<_ContactManagementTab> {
  final FirestoreService _firestoreService = FirestoreService();
  String _filter = 'open';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // フィルターチップ
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                label: '未対応',
                selected: _filter == 'open',
                onTap: () => setState(() => _filter = 'open'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '対応済み',
                selected: _filter == 'closed',
                onTap: () => setState(() => _filter = 'closed'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestoreService.getContactsForAdmin(status: _filter),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('エラー: ${snapshot.error}'));
              }
              final contacts = snapshot.data ?? [];
              if (contacts.isEmpty) {
                return Center(
                  child: Text(
                    _filter == 'open' ? '未対応のお問い合わせはありません' : '対応済みのお問い合わせはありません',
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return _ContactCard(
                    contact: contact,
                    onTap: () => _showContactDetail(context, contact),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showContactDetail(
      BuildContext context, Map<String, dynamic> contact) {
    final createdAt = contact['createdAt'];
    final dateStr = createdAt != null
        ? _formatTimestamp(createdAt)
        : '不明';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(contact['category'] ?? 'お問い合わせ'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: '送信日時', value: dateStr),
                _DetailRow(
                    label: 'ユーザーID', value: contact['userId'] ?? '不明'),
                const SizedBox(height: 12),
                const Text(
                  'お問い合わせ内容',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    contact['message'] ?? '',
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          if (contact['status'] == 'open')
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                await _firestoreService.updateContactStatus(
                    contact['id'], 'closed');
                messenger.showSnackBar(
                  const SnackBar(content: Text('対応済みにしました')),
                );
              },
              child: const Text('対応済みにする'),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    try {
      final dt = (ts as dynamic).toDate() as DateTime;
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '不明';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  final VoidCallback onTap;

  const _ContactCard({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final createdAt = contact['createdAt'];
    String dateStr = '';
    if (createdAt != null) {
      try {
        final dt = (createdAt as dynamic).toDate() as DateTime;
        dateStr =
            '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            contact['category'] ?? '',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          contact['message'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: dateStr.isNotEmpty
            ? Text(
                dateStr,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey[500]),
              )
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
