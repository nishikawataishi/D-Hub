import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import 'components/photo_gallery.dart';

/// 学生プロフィールの詳細閲覧とスカウト送信を行う画面
class StudentDetailScreen extends StatefulWidget {
  final UserProfile student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  Future<void> _showScoutDialog() async {
    final messageController = TextEditingController();
    bool isSending = false;

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

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${widget.student.name} さんにスカウト送信'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'スカウトメッセージを入力してください。\n(送信済みのメッセージは学生の画面に表示されます)',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '例: あなたのプロフィールを見て興味を持ちました！ぜひ一度お話ししませんか？',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(context),
                  child: const Text(
                    'キャンセル',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (messageController.text.trim().isEmpty) return;

                          setDialogState(() {
                            isSending = true;
                          });

                          try {
                            await FirestoreService().sendScout(
                              targetUserId: widget.student.id,
                              senderOrg: senderOrg,
                              message: messageController.text.trim(),
                            );

                            if (context.mounted) {
                              Navigator.pop(context); // ダイアログを閉じる
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${widget.student.name} さんにスカウトを送信しました！',
                                  ),
                                  backgroundColor: AppTheme.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('送信に失敗しました: $e'),
                                  backgroundColor: AppTheme.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setDialogState(() {
                                isSending = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('送信する'),
                ),
              ],
            );
          },
        );
      },
    );
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
              '${widget.student.faculty} ${widget.student.grade}回生 • ${widget.student.mainCampus.name}',
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
