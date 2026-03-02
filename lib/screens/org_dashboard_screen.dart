import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_notifier.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import '../models/event.dart';
import 'components/student_card.dart';
import 'components/org_profile_edit_tab.dart';
import 'student_detail_screen.dart';
import 'event_edit_screen.dart';

/// 団体用ダッシュボード画面
/// 学生検索・スカウト、団体プロフィール編集、イベント管理などを行う
class OrgDashboardScreen extends StatefulWidget {
  const OrgDashboardScreen({super.key});

  @override
  State<OrgDashboardScreen> createState() => _OrgDashboardScreenState();
}

class _OrgDashboardScreenState extends State<OrgDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          '団体ダッシュボード',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              context.read<AuthNotifier>().signOut();
            },
            icon: const Icon(Icons.logout, color: AppTheme.textSecondary),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _selectedIndex == 2
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EventEditScreen(),
                  ),
                );
              },
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            label: '学生検索',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.send_rounded),
            label: 'スカウト',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_rounded),
            label: 'イベント管理',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            label: 'プロフィール',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildStudentSearchTab();
      case 1:
        return _buildScoutManagementTab();
      case 2:
        return _buildEventManagementTab();
      case 3:
        return _buildOrgProfileTab();
      default:
        return const Center(child: Text('Unknown Tab'));
    }
  }

  /// 学生検索タブ
  Widget _buildStudentSearchTab() {
    return StreamBuilder<List<UserProfile>>(
      stream: FirestoreService().getStudents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '学生データの取得に失敗しました\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.error),
            ),
          );
        }

        final students = snapshot.data ?? [];

        if (students.isEmpty) {
          return const Center(
            child: Text(
              'まだ登録されている学生がいません',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return StudentCard(
              student: student,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentDetailScreen(student: student),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// スカウト管理タブ
  Widget _buildScoutManagementTab() {
    return const Center(child: Text('スカウト送信・履歴管理 (実装予定)'));
  }

  /// イベント管理タブ
  // Implement event display logic
  Widget _buildEventManagementTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<List<Event>>(
      stream: FirestoreService().getEventsByOrganization(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return const Center(
            child: Text(
              'まだイベントがありません。\n右下の＋ボタンから作成してください。',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppTheme.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.border),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${event.startAt.year}/${event.startAt.month}/${event.startAt.day} ${event.startAt.hour}:${event.startAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.campus.label,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(
                  Icons.edit_outlined,
                  color: AppTheme.primary,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventEditScreen(event: event),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrgProfileTab() {
    return const OrgProfileEditTab();
  }
}
