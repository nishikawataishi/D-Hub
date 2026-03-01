import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/event.dart';
import '../theme/app_theme.dart';
import 'group_detail_screen.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as add2cal;
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends StatelessWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${event.startAt.month}/${event.startAt.day} ${event.startAt.hour}:${event.startAt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('イベント詳細')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // イベントタイトル
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // 日時とキャンパス
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(dateStr, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 24),
                const Icon(
                  Icons.location_on,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(event.campus.label, style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 24),

            // 主催団体カード（タップで団体詳細へ遷移）
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        GroupDetailScreen(organization: event.organization),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Text(
                      event.organization.logoEmoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '主催',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            event.organization.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // イベント詳細文
            const Text(
              'イベント内容',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                event.description,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (kIsWeb) {
                      // Web環境: Google Calendar URLを開く
                      final start = event.startAt.toUtc();
                      final end = start.add(const Duration(hours: 2));
                      String fmt(DateTime d) =>
                          '${d.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
                      final url = Uri.parse(
                        'https://calendar.google.com/calendar/render'
                        '?action=TEMPLATE'
                        '&text=${Uri.encodeComponent(event.title)}'
                        '&dates=${fmt(start)}/${fmt(end)}'
                        '&details=${Uri.encodeComponent(event.description)}'
                        '&location=${Uri.encodeComponent(event.campus.label)}',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Googleカレンダーを開きました')),
                      );
                    } else {
                      // ネイティブ環境: add_2_calendar で端末カレンダーを起動
                      final buildEvent = add2cal.Event(
                        title: event.title,
                        description: event.description,
                        location: event.campus.label,
                        startDate: event.startAt,
                        endDate: event.startAt.add(const Duration(hours: 2)),
                      );
                      final success = await add2cal.Add2Calendar.addEvent2Cal(
                        buildEvent,
                      );
                      if (!context.mounted) return;
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('カレンダーに追加しました')),
                        );
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.calendar_month,
                    color: AppTheme.primary,
                  ),
                  label: const Text(
                    'カレンダーに追加',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('参加申し込みを送信しました！')),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'このイベントに参加する',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
