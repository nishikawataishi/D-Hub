import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
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
    String inputUrl = widget.scout.organizationInstagramUrl?.trim() ?? '';

    // 何も入力されていない場合は、デフォルトでInstagramのトップ（または団体名で検索など）を表示
    if (inputUrl.isEmpty) {
      inputUrl = 'https://www.instagram.com/';
    }

    // @で始まる場合はユーザー名として扱う（例: @username -> username）
    if (inputUrl.startsWith('@')) {
      inputUrl = inputUrl.substring(1);
    }

    String finalUrlString;
    if (inputUrl.startsWith('http://') || inputUrl.startsWith('https://')) {
      // 既にフルURLの場合はそのまま使用
      finalUrlString = inputUrl;
    } else if (inputUrl.contains('instagram.com')) {
      // ドメインが含まれているがスキームがない場合（例: instagram.com/xxx）
      finalUrlString = 'https://$inputUrl';
    } else {
      // ユーザー名のみと推測される場合
      // 斜線などの不要な文字をトリミング
      final cleanPath = inputUrl.endsWith('/')
          ? inputUrl.substring(0, inputUrl.length - 1)
          : inputUrl;
      finalUrlString = 'https://www.instagram.com/$cleanPath/';
    }

    final Uri url = Uri.parse(finalUrlString);

    try {
      // Web環境とモバイル環境で使い分ける
      final LaunchMode mode = kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication;

      bool launched = false;
      if (await canLaunchUrl(url)) {
        launched = await launchUrl(url, mode: mode);
      }

      if (!launched) {
        // canLaunchUrlの結果に関わらず直接試行（フォールバック）
        launched = await launchUrl(url, mode: mode);
      }

      if (!launched && mounted) {
        throw Exception('Could not launch');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Instagramを開けませんでした。URLを確認してください: $finalUrlString'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 5),
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
                    image: widget.scout.organizationLogoUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(
                              widget.scout.organizationLogoUrl!,
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: widget.scout.organizationLogoUrl == null
                      ? Center(
                          child: Text(
                            orgEmoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        )
                      : null,
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

            // スカウト対応の説明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '興味があればInstagramまたはグループLINEから団体に連絡してください。\n興味がない場合は何もしなくて構いません（断りの返信は不要です）。',
                      style: TextStyle(fontSize: 12, color: AppTheme.primary, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
            // グループLINEボタン（URLが設定されている場合のみ表示）
            if ((widget.scout.organizationGroupLineUrl ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final uri = Uri.parse(
                      widget.scout.organizationGroupLineUrl!.trim(),
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('LINEを開けませんでした')),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: const Text(
                    'グループLINEに参加する',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06C755),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
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
