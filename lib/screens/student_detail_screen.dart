import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import 'components/photo_gallery.dart';
import 'components/scout_compose_dialog.dart';

/// 学生プロフィールの詳細閲覧とスカウト送信を行う画面
class StudentDetailScreen extends StatefulWidget {
  final UserProfile student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  Future<void> _showScoutDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 実際にログインしている団体の情報を取得
    final senderOrg = await FirestoreService().getOrganization(user.uid);
    if (senderOrg == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('団体情報の取得に失敗しました')));
      }
      return;
    }

    if (!mounted) return;

    // 本文は定型文に限定されるため、選択UIはダイアログ側が受け持つ
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => ScoutComposeDialog(
        student: widget.student,
        senderOrg: senderOrg,
      ),
    );

    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.student.name} さんにスカウトを送信しました！'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          '学生詳細',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 写真ギャラリー or アイコン
            if (widget.student.photoUrls.isNotEmpty) ...[
              PhotoGallery(photoUrls: widget.student.photoUrls),
              const SizedBox(height: 16),
            ] else ...[
              CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primary.withAlpha(25),
                backgroundImage: widget.student.iconUrl != null
                    ? NetworkImage(widget.student.iconUrl!)
                    : null,
                child: widget.student.iconUrl == null
                    ? const Icon(Icons.person, size: 50, color: AppTheme.primary)
                    : null,
              ),
              const SizedBox(height: 16),
            ],

            // 名前
            Text(
              widget.student.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // 学部・回生・キャンパス
            Text(
              '${widget.student.faculty} ${widget.student.grade}回生 • ${widget.student.mainCampus.label}',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // 興味タグセクション
            if (widget.student.interests.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '興味・関心',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.student.interests.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 48),
            ],

            // スカウト送信ボタン
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _showScoutDialog,
                icon: const Icon(Icons.send_rounded),
                label: const Text(
                  'この学生をスカウトする',
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
          ],
        ),
      ),
    );
  }
}
