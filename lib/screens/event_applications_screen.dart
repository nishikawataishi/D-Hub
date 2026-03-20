import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/event_application.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// 団体側：イベント申し込み一覧・承認管理画面
class EventApplicationsScreen extends StatelessWidget {
  final Event event;

  const EventApplicationsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${event.startAt.year}/${event.startAt.month}/${event.startAt.day} '
        '${event.startAt.hour}:${event.startAt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('参加申し込み管理'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // イベント情報ヘッダー
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      event.campus.label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // 申し込み一覧
          Expanded(
            child: StreamBuilder<List<EventApplication>>(
              stream:
                  FirestoreService().getApplicationsForEvent(event.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'データの取得に失敗しました\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  );
                }

                final applications = snapshot.data ?? [];

                if (applications.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'まだ申し込みはありません',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 集計
                final total = applications.length;
                final accepted = applications
                    .where(
                      (a) => a.status == ApplicationStatus.accepted,
                    )
                    .length;
                final pending = applications
                    .where(
                      (a) => a.status == ApplicationStatus.applied,
                    )
                    .length;
                final rejected = applications
                    .where(
                      (a) => a.status == ApplicationStatus.rejected,
                    )
                    .length;

                return Column(
                  children: [
                    // 統計バー
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: AppTheme.surface,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatChip(
                            label: '合計',
                            count: total,
                            color: AppTheme.primary,
                          ),
                          _StatChip(
                            label: '審査中',
                            count: pending,
                            color: Colors.orange,
                          ),
                          _StatChip(
                            label: '承認',
                            count: accepted,
                            color: Colors.green,
                          ),
                          _StatChip(
                            label: '却下',
                            count: rejected,
                            color: AppTheme.error,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.border),

                    // 申し込みリスト
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: applications.length,
                        separatorBuilder: (_, _i) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final application = applications[index];
                          return _ApplicationCard(
                            application: application,
                            eventId: event.id,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 統計チップ
class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 申し込みカード
class _ApplicationCard extends StatefulWidget {
  final EventApplication application;
  final String eventId;

  const _ApplicationCard({
    required this.application,
    required this.eventId,
  });

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  bool _isLoading = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _isLoading = true);
    try {
      await FirestoreService().updateApplicationStatus(
        eventId: widget.eventId,
        applicationId: widget.application.id,
        status: status,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showConfirmDialog(String status) async {
    final isAccept = status == 'accepted';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAccept ? '参加を承認しますか？' : '参加を却下しますか？'),
        content: Text(
          '${widget.application.studentName} さんの申し込みを'
          '${isAccept ? '承認' : '却下'}します。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isAccept ? Colors.green : AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(isAccept ? '承認する' : '却下する'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateStatus(status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final status = app.status;

    final appliedStr =
        '${app.appliedAt.month}/${app.appliedAt.day} '
        '${app.appliedAt.hour}:${app.appliedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // アイコン
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                backgroundImage: app.studentIconUrl != null
                    ? NetworkImage(app.studentIconUrl!)
                    : null,
                child: app.studentIconUrl == null
                    ? Text(
                        app.studentName.isNotEmpty
                            ? app.studentName[0]
                            : '?',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // 学生情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.studentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${app.studentFaculty} ${app.studentGrade}年',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // ステータスバッジ
              _StatusBadge(status: status),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            '申し込み日時: $appliedStr',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),

          // ボタン（审査中のみ表示）
          if (status == ApplicationStatus.applied) ...[
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: SizedBox(
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showConfirmDialog('rejected'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('却下'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showConfirmDialog('accepted'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('承認'),
                    ),
                  ),
                ],
              ),
          ],

          // 承認/却下済みの場合は応答日時を表示
          if (status != ApplicationStatus.applied &&
              app.respondedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '応答日時: ${app.respondedAt!.month}/${app.respondedAt!.day} '
              '${app.respondedAt!.hour}:${app.respondedAt!.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ステータスバッジ
class _StatusBadge extends StatelessWidget {
  final ApplicationStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ApplicationStatus.accepted:
        color = Colors.green;
      case ApplicationStatus.rejected:
        color = AppTheme.error;
      case ApplicationStatus.applied:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
