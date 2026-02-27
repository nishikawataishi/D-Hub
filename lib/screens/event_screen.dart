import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';

/// イベント画面
/// 新歓・説明会のスケジュールを日付別に表示。Firestoreからリアルタイム取得。
class EventScreen extends StatelessWidget {
  EventScreen({super.key});

  final _firestoreService = FirestoreService();

  /// キャンパスに応じたカラーを返す
  Color _campusColor(Campus campus) {
    switch (campus) {
      case Campus.imadegawa:
        return AppTheme.campusImadegawa;
      case Campus.kyotanabe:
        return AppTheme.campusKyotanabe;
      case Campus.both:
        return AppTheme.campusBoth;
    }
  }

  /// イベントデータ（Map）を日付ごとにグループ化
  Map<String, List<Map<String, dynamic>>> _groupByDate(
    List<Map<String, dynamic>> events,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final event in events) {
      final startAt = (event['startAt'] as Timestamp).toDate();
      final dateKey =
          '${startAt.year}/${startAt.month.toString().padLeft(2, '0')}/${startAt.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(dateKey, () => []).add(event);
    }
    return grouped;
  }

  /// 曜日を日本語に変換
  String _weekdayLabel(DateTime date) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return weekdays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('イベント')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getUpcomingEvents(),
        builder: (context, snapshot) {
          // Firestoreデータがあればそれを使用、なければモックデータ
          List<Map<String, dynamic>> eventData;
          bool isFirestore = snapshot.hasData && snapshot.data!.isNotEmpty;

          if (isFirestore) {
            eventData = snapshot.data!;
          } else {
            // モックデータをMap形式に変換
            eventData = mockEvents
                .map(
                  (e) => {
                    'id': e.id,
                    'title': e.title,
                    'description': e.description,
                    'organizationName': e.organization.name,
                    'organizationEmoji': e.organization.logoEmoji,
                    'startAt': Timestamp.fromDate(e.startAt),
                    'campus': e.campus.name,
                  },
                )
                .toList();
          }

          final grouped = _groupByDate(eventData);
          final dateKeys = grouped.keys.toList()..sort();

          if (dateKeys.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 48,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'イベントはまだありません',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dateKeys.length,
            itemBuilder: (context, index) {
              final dateKey = dateKeys[index];
              final events = grouped[dateKey]!;
              final firstStartAt = (events.first['startAt'] as Timestamp)
                  .toDate();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) const SizedBox(height: 20),

                  // 日付ヘッダー
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${firstStartAt.month}/${firstStartAt.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_weekdayLabel(firstStartAt)}曜日',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // イベントカードリスト
                  ...events.map((event) {
                    final startAt = (event['startAt'] as Timestamp).toDate();
                    final campusStr = event['campus'] as String? ?? 'both';
                    final campus = Campus.values.firstWhere(
                      (c) => c.name == campusStr,
                      orElse: () => Campus.both,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EventCard(
                        title: event['title'] ?? '',
                        description: event['description'] ?? '',
                        orgName: event['organizationName'] ?? '',
                        orgEmoji: event['organizationEmoji'] ?? '🏫',
                        startAt: startAt,
                        campus: campus,
                        campusColor: _campusColor(campus),
                        onCalendarTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '📅 「${event['title']}」をカレンダーに追加しました',
                              ),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// イベントカード
class _EventCard extends StatelessWidget {
  final String title;
  final String description;
  final String orgName;
  final String orgEmoji;
  final DateTime startAt;
  final Campus campus;
  final Color campusColor;
  final VoidCallback onCalendarTap;

  const _EventCard({
    required this.title,
    required this.description,
    required this.orgName,
    required this.orgEmoji,
    required this.startAt,
    required this.campus,
    required this.campusColor,
    required this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 時間表示
          Column(
            children: [
              Text(
                '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: campusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  campus.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // イベント情報
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(orgEmoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      orgName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // カレンダー追加ボタン
          IconButton(
            onPressed: onCalendarTap,
            icon: const Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: AppTheme.primary,
            ),
            tooltip: 'カレンダーに追加',
          ),
        ],
      ),
    );
  }
}
