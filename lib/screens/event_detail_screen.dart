import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event.dart';
import '../models/event_application.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'group_detail_screen.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as add2cal;
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isApplying = false;
  bool _isCancelling = false;

  Future<void> _apply(String userId) async {
    setState(() => _isApplying = true);
    try {
      final profile = await FirestoreService().getUserProfile(userId);
      if (profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('プロフィールが見つかりません。先にプロフィールを設定してください。')),
          );
        }
        return;
      }
      await FirestoreService().applyToEvent(
        eventId: widget.event.id,
        student: profile,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('参加申し込みを送信しました！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('申し込みに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('申し込みをキャンセルしますか？'),
        content: const Text('このイベントへの参加申し込みを取り消します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('戻る'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('キャンセルする'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await FirestoreService().cancelApplication(widget.event.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('申し込みをキャンセルしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('キャンセルに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${widget.event.startAt.month}/${widget.event.startAt.day} ${widget.event.startAt.hour}:${widget.event.startAt.minute.toString().padLeft(2, '0')}';

    final userId = FirebaseAuth.instance.currentUser?.uid;

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
              widget.event.title,
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
                Text(widget.event.campus.label, style: const TextStyle(fontSize: 16)),
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
                        GroupDetailScreen(organization: widget.event.organization),
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
                      widget.event.organization.logoEmoji,
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
                            widget.event.organization.name,
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

            // 参加費・人数・場所
            if (widget.event.location != null ||
                widget.event.fee != null ||
                widget.event.capacity != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    if (widget.event.location != null)
                      _InfoRow(
                        icon: Icons.place_outlined,
                        label: '場所',
                        value: widget.event.location!,
                      ),
                    if (widget.event.location != null &&
                        (widget.event.fee != null ||
                            widget.event.capacity != null))
                      const Divider(height: 20),
                    if (widget.event.fee != null)
                      _InfoRow(
                        icon: Icons.payments_outlined,
                        label: '参加費',
                        value: widget.event.fee!,
                      ),
                    if (widget.event.fee != null && widget.event.capacity != null)
                      const Divider(height: 20),
                    if (widget.event.capacity != null)
                      _InfoRow(
                        icon: Icons.people_outline,
                        label: '人数',
                        value: widget.event.capacity!,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

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
                widget.event.description,
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
              // カレンダー追加ボタン
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (kIsWeb) {
                      final start = widget.event.startAt.toUtc();
                      final end = start.add(const Duration(hours: 2));
                      String fmt(DateTime d) =>
                          '${d.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
                      final url = Uri.parse(
                        'https://calendar.google.com/calendar/render'
                        '?action=TEMPLATE'
                        '&text=${Uri.encodeComponent(widget.event.title)}'
                        '&dates=${fmt(start)}/${fmt(end)}'
                        '&details=${Uri.encodeComponent(widget.event.description)}'
                        '&location=${Uri.encodeComponent(widget.event.campus.label)}',
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
                      final buildEvent = add2cal.Event(
                        title: widget.event.title,
                        description: widget.event.description,
                        location: widget.event.campus.label,
                        startDate: widget.event.startAt,
                        endDate: widget.event.startAt.add(const Duration(hours: 2)),
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

              // 申し込みボタン（申し込み状況に応じて変化）
              if (userId != null)
                StreamBuilder<EventApplication?>(
                  stream: FirestoreService().getMyApplication(widget.event.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final application = snapshot.data;

                    // 承認済みかつLINE URLがある場合はLINEボタンを先頭に表示
                    final lineButton = (application?.status ==
                                ApplicationStatus.accepted &&
                            widget.event.groupLineUrl != null &&
                            widget.event.groupLineUrl!.isNotEmpty)
                        ? Column(
                            children: [
                              _LineJoinButton(
                                url: widget.event.groupLineUrl!,
                              ),
                              const SizedBox(height: 12),
                            ],
                          )
                        : const SizedBox.shrink();

                    // 申し込みボタン or ステータス
                    final actionWidget = application == null
                        ? SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isApplying
                                  ? null
                                  : () => _apply(userId),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isApplying
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'このイベントに参加する',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          )
                        : Column(
                            children: [
                              _AppliedStatusCard(status: application.status),
                              if (application.status ==
                                  ApplicationStatus.applied) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    onPressed:
                                        _isCancelling ? null : _cancel,
                                    child: _isCancelling
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            '申し込みをキャンセルする',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          );

                    return Column(
                      children: [lineButton, actionWidget],
                    );
                  },
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ログインして参加申し込みする',
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

/// グループLINE参加ボタン
class _LineJoinButton extends StatelessWidget {
  final String url;
  const _LineJoinButton({required this.url});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('LINEを開けませんでした')),
              );
            }
          }
        },
        icon: const Icon(Icons.chat_bubble_outline, size: 20),
        label: const Text(
          'グループLINEに参加する',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF06C755), // LINE green
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// 申し込み済み時のステータス表示カード
class _AppliedStatusCard extends StatelessWidget {
  final ApplicationStatus status;

  const _AppliedStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String message;

    switch (status) {
      case ApplicationStatus.applied:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        message = '申し込み済み（団体の承認をお待ちください）';
      case ApplicationStatus.accepted:
        color = Colors.green;
        icon = Icons.check_circle_outline;
        message = '参加が承認されました！';
      case ApplicationStatus.rejected:
        color = AppTheme.error;
        icon = Icons.cancel_outlined;
        message = '今回は参加できませんでした';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 場所・参加費・人数の1行表示
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 10),
        Text(
          '$label：',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

