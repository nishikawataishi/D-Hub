import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../models/scout.dart';
import 'scout_detail_screen.dart';

/// スカウト画面
/// 団体からのスカウトを時系列で表示。Firestoreからリアルタイム取得。
class ScoutScreen extends StatefulWidget {
  const ScoutScreen({super.key});

  @override
  State<ScoutScreen> createState() => ScoutScreenState();
}

class ScoutScreenState extends State<ScoutScreen> {
  final _firestoreService = FirestoreService();

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

  Future<void> _navigateToDetail(Scout scout) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ScoutDetailScreen(scout: scout)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('スカウト')),
      body: StreamBuilder<List<Scout>>(
        stream: _firestoreService.getScoutsForUser(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Firestore Error (ScoutScreen): ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'データの取得に失敗しました',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

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

                return _ScoutTileFromMap(
                  scout: scout,
                  relativeTime: _formatRelativeTime(scout.sentAt),
                  onTap: () => _navigateToDetail(scout),
                );
              },
            );
          }

          // Firestoreにデータがない場合
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
        },
      ),
    );
  }
}

/// スカウトタイル（Firestoreデータ版）
class _ScoutTileFromMap extends StatelessWidget {
  final Scout scout;
  final String relativeTime;
  final VoidCallback onTap;

  const _ScoutTileFromMap({
    required this.scout,
    required this.relativeTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _buildScoutContainer(
      isRead: scout.isRead,
      orgEmoji: scout.organizationEmoji,
      orgName: scout.organizationName,
      category: scout.organizationCategory,
      message: scout.message,
      relativeTime: relativeTime,
      onTap: onTap,
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
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
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
                      child: Text(
                        orgEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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

          // 削除: インラインの「承認する」ボタンは詳細画面に集約されるため削除
        ],
      ),
    ),
  );
}
