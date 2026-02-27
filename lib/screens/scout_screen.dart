import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';

/// スカウト画面
/// 団体からのスカウトを時系列で表示。Firestoreからリアルタイム取得。
class ScoutScreen extends StatefulWidget {
  const ScoutScreen({super.key});

  @override
  State<ScoutScreen> createState() => ScoutScreenState();
}

class ScoutScreenState extends State<ScoutScreen> {
  final _firestoreService = FirestoreService();

  /// 未読スカウトの数を返す（モックデータ版 - Firestoreデータが来るまでのフォールバック）
  int get unreadCount => mockScouts.where((s) => !s.isRead).length;

  /// 相対時間の表示（今日、昨日、N日前）
  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}時間前';
    } else if (diff.inDays == 0) {
      return '今日';
    } else if (diff.inDays == 1) {
      return '昨日';
    } else {
      return '${diff.inDays}日前';
    }
  }

  /// 承認アクション（Firestore版）
  void _handleApprove(Map<String, dynamic> scout) {
    final scoutId = scout['id'] as String;
    _firestoreService.markScoutAsRead(scoutId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success),
            SizedBox(width: 8),
            Expanded(child: Text('承認しました！', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(
          '${scout['organizationName']}のInstagramに移動します',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// モックスカウト承認（フォールバック用）
  void _handleMockApprove(Scout scout) {
    setState(() {
      scout.isRead = true;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success),
            SizedBox(width: 8),
            Expanded(child: Text('承認しました！', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(
          '${scout.organization.name}のInstagramに移動します\n\n'
          '${scout.organization.instagramUrl}',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('スカウト')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getScoutsForUser(userId),
        builder: (context, snapshot) {
          // Firestoreにスカウトデータがあればそれを使用
          final hasFirestoreData =
              snapshot.hasData && snapshot.data!.isNotEmpty;

          if (hasFirestoreData) {
            // Firestoreデータで表示
            final scouts = snapshot.data!;
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: scouts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final scout = scouts[index];
                final sentAt =
                    (scout['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                final isRead = scout['isRead'] == true;

                return _ScoutTileFromMap(
                  scout: scout,
                  isRead: isRead,
                  relativeTime: _formatRelativeTime(sentAt),
                  onApprove: () => _handleApprove(scout),
                );
              },
            );
          }

          // フォールバック: モックデータで表示
          if (mockScouts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 48,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'スカウトはまだ届いていません',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: mockScouts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final scout = mockScouts[index];
              return _ScoutTileFromMock(
                scout: scout,
                relativeTime: _formatRelativeTime(scout.sentAt),
                onApprove: () => _handleMockApprove(scout),
              );
            },
          );
        },
      ),
    );
  }
}

/// スカウトタイル（Firestoreデータ版）
class _ScoutTileFromMap extends StatelessWidget {
  final Map<String, dynamic> scout;
  final bool isRead;
  final String relativeTime;
  final VoidCallback onApprove;

  const _ScoutTileFromMap({
    required this.scout,
    required this.isRead,
    required this.relativeTime,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final orgName = scout['organizationName'] ?? '';
    final orgEmoji = scout['organizationEmoji'] ?? '🏫';
    final message = scout['message'] ?? '';
    final category = scout['organizationCategory'] ?? '';

    return _buildScoutContainer(
      isRead: isRead,
      orgEmoji: orgEmoji,
      orgName: orgName,
      category: category,
      message: message,
      relativeTime: relativeTime,
      onApprove: onApprove,
    );
  }
}

/// スカウトタイル（モックデータ版）
class _ScoutTileFromMock extends StatelessWidget {
  final Scout scout;
  final String relativeTime;
  final VoidCallback onApprove;

  const _ScoutTileFromMock({
    required this.scout,
    required this.relativeTime,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    return _buildScoutContainer(
      isRead: scout.isRead,
      orgEmoji: scout.organization.logoEmoji,
      orgName: scout.organization.name,
      category: scout.organization.category.label,
      message: scout.message,
      relativeTime: relativeTime,
      onApprove: onApprove,
    );
  }
}

/// スカウトカードの共通UI
Widget _buildScoutContainer({
  required bool isRead,
  required String orgEmoji,
  required String orgName,
  required String category,
  required String message,
  required String relativeTime,
  required VoidCallback onApprove,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isRead
            ? AppTheme.border
            : AppTheme.primary.withValues(alpha: 0.3),
      ),
      boxShadow: isRead
          ? null
          : [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(orgEmoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                if (!isRead)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.notification,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orgName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    relativeTime,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (category.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // メッセージ本文
        Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: isRead ? AppTheme.textSecondary : AppTheme.textPrimary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),

        // アクションボタン
        if (!isRead)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('承認して連絡する'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('承認済み'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: AppTheme.success,
                side: const BorderSide(color: AppTheme.success),
              ),
            ),
          ),
      ],
    ),
  );
}
