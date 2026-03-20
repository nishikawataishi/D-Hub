import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/organization.dart';
import '../models/event.dart';
import '../theme/app_theme.dart';
import '../screens/components/verified_badge.dart';
import 'components/photo_gallery.dart';
import '../services/firestore_service.dart';
import 'event_detail_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final Organization organization;

  const GroupDetailScreen({super.key, required this.organization});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _firestoreService = FirestoreService();
  bool _isScouted = false;

  @override
  void initState() {
    super.initState();
    _checkScoutStatus();
  }

  Future<void> _checkScoutStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final result = await _firestoreService.hasScouted(
      orgId: widget.organization.id,
      userId: userId,
    );
    if (mounted) setState(() => _isScouted = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.organization.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('シェア機能は準備中です')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー（ロゴ＆情報）
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  image: widget.organization.logoUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(
                            widget.organization.logoUrl!,
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: widget.organization.logoUrl == null
                    ? Center(
                        child: Text(
                          widget.organization.logoEmoji,
                          style: const TextStyle(fontSize: 50),
                        ),
                      )
                    : null,
              ),
            ),
            // 写真ギャラリー
            if (widget.organization.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              PhotoGallery(photoUrls: widget.organization.photoUrls),
            ],
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.organization.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.organization.status == 'verified') ...[
                    const SizedBox(width: 8),
                    const VerifiedBadge(size: 24),
                  ],
                ],
              ),
            ),
            Center(
              child: Text(
                widget.organization.categories.isNotEmpty
                    ? widget.organization.categories.first.label
                    : '',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChip(widget.organization.categories.first.label, Icons.category),
                const SizedBox(width: 8),
                _buildChip(widget.organization.campus.label, Icons.location_on),
              ],
            ),
            const SizedBox(height: 32),

            // 団体の紹介文
            const Text(
              '団体紹介',
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
                widget.organization.description,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ),

            // Instagram リンク
            if (widget.organization.instagramUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final url = _buildInstagramUrl(
                      widget.organization.instagramUrl.trim(),
                    );
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Instagramを見る'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],

            // グループLINE（スカウト済みの場合のみ表示）
            if (_isScouted &&
                widget.organization.groupLineUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(
                      widget.organization.groupLineUrl.trim(),
                    );
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('LINEを開けませんでした')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text(
                    'グループLINEに参加する',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06C755),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // イベント一覧
            const Text(
              '関連イベント',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Event>>(
              stream: _firestoreService.getEventsByOrganization(
                widget.organization.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final relatedEvents = snapshot.data ?? [];

                if (relatedEvents.isEmpty) {
                  return const Text('現在予定されているイベントはありません。');
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: relatedEvents.length,
                  itemBuilder: (context, index) {
                    final event = relatedEvents[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                      color: AppTheme.surface,
                      child: ListTile(
                        title: Text(
                          event.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${event.startAt.month}/${event.startAt.day} ${event.startAt.hour}:${event.startAt.minute.toString().padLeft(2, '0')} - ${event.campus.label}',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EventDetailScreen(event: event),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _buildInstagramUrl(String input) {
    if (input.startsWith('http://') || input.startsWith('https://')) {
      return input;
    }
    // @付きユーザー名 or ユーザー名のみ
    final username = input.startsWith('@') ? input.substring(1) : input;
    return 'https://www.instagram.com/$username';
  }

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
