import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_notifier.dart';
import '../services/firestore_service.dart';
import '../models/organization.dart';

/// 管理者用ダッシュボード画面
/// 団体の審査承認・却下を行う
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _filter = 'pending'; // 'pending', 'rejected', 'verified', 'all'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理画面'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthNotifier>().signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildOrganizationList()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = {
      'pending': '審査待ち',
      'rejected': '却下',
      'verified': '承認済み',
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
            child: Text('該当する団体はありません', style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: orgs.length,
          itemBuilder: (context, index) => _OrgReviewCard(
            org: orgs[index],
            onApprove: () => _updateStatus(orgs[index], 'verified'),
            onReject: () => _updateStatus(orgs[index], 'rejected'),
          ),
        );
      },
    );
  }

  Future<void> _updateStatus(Organization org, String newStatus) async {
    final label = newStatus == 'verified' ? '承認' : '却下';
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

/// 団体審査カード
class _OrgReviewCard extends StatelessWidget {
  final Organization org;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _OrgReviewCard({
    required this.org,
    required this.onApprove,
    required this.onReject,
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
            if (org.proofImageUrl != null && org.proofImageUrl!.isNotEmpty) ...[
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
                    errorBuilder: (_, _, _) => Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              ),
            ],
            // アクションボタン
            if (org.status != 'verified') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (org.status != 'rejected')
                    OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('却下'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onApprove,
                    child: const Text('承認'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
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
