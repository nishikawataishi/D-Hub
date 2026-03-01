import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../models/scout.dart';
import 'group_detail_screen.dart';

/// スカウト詳細画面
/// スカウト文章を全画面で閲覧し、団体詳細への遷移やInstagramでの連絡ができる
class ScoutDetailScreen extends StatefulWidget {
  final Scout scout;

  const ScoutDetailScreen({super.key, required this.scout});

  @override
  State<ScoutDetailScreen> createState() => _ScoutDetailScreenState();
}

class _ScoutDetailScreenState extends State<ScoutDetailScreen> {
  final _firestoreService = FirestoreService();
  bool _isLoadingOrg = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    if (!widget.scout.isRead && widget.scout.id.isNotEmpty) {
      await _firestoreService.markScoutAsRead(widget.scout.id);
    }
  }

  Future<void> _handleContact() async {
    final String urlString =
        widget.scout.organizationInstagramUrl ?? 'https://www.instagram.com/';
    final Uri url = Uri.parse(urlString);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('指定されたURLを開けませんでした'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _navigateToOrganization() async {
    setState(() {
      _isLoadingOrg = true;
    });

    try {
      final orgId = widget.scout.organizationId;
      final org = await _firestoreService.getOrganization(orgId);

      if (org != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupDetailScreen(organization: org),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('団体情報の取得に失敗しました'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOrg = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgName = widget.scout.organizationName;
    final orgEmoji = widget.scout.organizationEmoji;
    final message = widget.scout.message;
    final sentAt = widget.scout.sentAt;

    final timeString =
        '${sentAt.year}/${sentAt.month}/${sentAt.day} ${sentAt.hour}:${sentAt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('スカウト詳細'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 送信元情報
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(orgEmoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orgName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeString,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // メッセージ本文
            const Text(
              'メッセージ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // アクションボタン
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _handleContact,
                icon: const Icon(Icons.send_rounded),
                label: const Text(
                  'Instagramで連絡する',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _isLoadingOrg ? null : _navigateToOrganization,
                icon: _isLoadingOrg
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.business_rounded),
                label: Text(
                  _isLoadingOrg ? '読み込み中...' : '団体の詳細を見る',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
