import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_notifier.dart';
import '../services/firestore_service.dart';
import '../models/organization.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';

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
        title: Text(_currentTab == 0 ? '団体管理' : 'ユーザー管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthNotifier>().signOut(),
          ),
        ],
      ),
      body: _currentTab == 0
          ? const _OrganizationManagementTab()
          : const _UserManagementTab(),
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
        content: SingleChildScrollView(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
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

  const _OrgReviewCard({
    required this.org,
    required this.onApprove,
    required this.onReject,
    required this.onSuspend,
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
