import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../models/event.dart';
import '../models/campus.dart';
import 'event_detail_screen.dart';

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

  /// イベントデータを日付ごとにグループ化
  Map<String, List<Event>> _groupByDate(List<Event> events) {
    final grouped = <String, List<Event>>{};
    for (final event in events) {
      final startAt = event.startAt;
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
      body: StreamBuilder<List<Event>>(
        stream: _firestoreService.getUpcomingEvents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("EventScreen Error: ${snapshot.error}");
            return Center(child: Text("エラーが発生しました: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final eventData = snapshot.data ?? [];

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
              final firstStartAt = events.first.startAt;

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
                    final startAt = event.startAt;
                    final campus = event.campus;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EventCard(
                        title: event.title,
                        description: event.description,
                        orgName: event.organization.name,
                        orgEmoji: event.organization.logoEmoji,
                        orgLogoUrl: event.organizationLogoUrl,
                        startAt: startAt,
                        campus: campus,
                        campusColor: _campusColor(campus),
                        onCardTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EventDetailScreen(event: event),
                            ),
                          );
                        },
                        onCalendarTap: () async {
                          if (kIsWeb) {
                            // Web環境: Google Calendar URLを開く
                            final s = startAt.toUtc();
                            final e2 = s.add(const Duration(hours: 2));
                            String fmt(DateTime d) =>
                                '${d.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
                            final url = Uri.parse(
                              'https://calendar.google.com/calendar/render'
                              '?action=TEMPLATE'
                              '&text=${Uri.encodeComponent(event.title)}'
                              '&dates=${fmt(s)}/${fmt(e2)}'
                              '&details=${Uri.encodeComponent(event.description)}'
                              '&location=${Uri.encodeComponent(campus.label)}',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '📅 「${event.title}」をカレンダーに追加しました',
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
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
  final String? orgLogoUrl;
  final DateTime startAt;
  final Campus campus;
  final Color campusColor;
  final VoidCallback onCardTap;
  final VoidCallback onCalendarTap;

  const _EventCard({
    required this.title,
    required this.description,
    required this.orgName,
    required this.orgEmoji,
    this.orgLogoUrl,
    required this.startAt,
    required this.campus,
    required this.campusColor,
    required this.onCardTap,
    required this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCardTap,
      child: Container(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
                      if (orgLogoUrl != null)
                        CircleAvatar(
                          radius: 7,
                          backgroundColor: Colors.transparent,
                          backgroundImage: CachedNetworkImageProvider(
                            orgLogoUrl!,
                          ),
                        )
                      else
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
      ),
    );
  }
}
