import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user_profile.dart';

/// 学生検索の各リストアイテムを表すカードWidget
class StudentCard extends StatelessWidget {
  final UserProfile student;
  final VoidCallback onTap;

  const StudentCard({super.key, required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ユーザーアイコン
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withAlpha(25),
                child: const Icon(Icons.person, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              // 学生情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${student.faculty} ${student.grade}回生 • ${student.mainCampus.name}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 興味タグ
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: student.interests.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
