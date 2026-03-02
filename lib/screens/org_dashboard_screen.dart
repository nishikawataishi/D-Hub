import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_notifier.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import '../models/event.dart';
import '../models/organization.dart';
import 'components/student_card.dart';
import 'components/org_profile_edit_tab.dart';
import 'org_create_screen.dart'; // 新規追加
import 'student_detail_screen.dart';
import 'event_edit_screen.dart';
// Added this import as it seems to be intended for event details
import 'components/verified_badge.dart'; // Added this import as it seems to be intended for verified badge

/// 団体用ダッシュボード画面
/// 学生検索・スカウト、団体プロフィール編集、イベント管理などを行う
class OrgDashboardScreen extends StatefulWidget {
  const OrgDashboardScreen({super.key});

  @override
  State<OrgDashboardScreen> createState() => _OrgDashboardScreenState();
}

class _OrgDashboardScreenState extends State<OrgDashboardScreen> {
  int _selectedIndex = 0;
  Organization? _currentOrg;
  bool _isOrgLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrgStatus();
  }

  Future<void> _loadOrgStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final org = await FirestoreService().getOrganization(user.uid);
      if (mounted) {
        setState(() {
          _currentOrg = org;
          _isOrgLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isOrgLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOrgLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 団体情報がない場合は作成画面へ誘導するか、未登録状態を表示
    if (_currentOrg == null) {
      return _buildNoOrgView();
    }

    final status = _currentOrg!.status;
    final isVerified = status == 'verified';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '団体ダッシュボード',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 8),
              const VerifiedBadge(size: 20),
            ],
          ],
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
      body: Column(
        children: [
          if (!isVerified) _buildStatusBanner(status),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _selectedIndex == 2 && isVerified
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
    if (_currentOrg?.status != 'verified') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '審査承認後に学生検索が利用可能になります',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

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

  /// 団体未登録時の表示
  Widget _buildNoOrgView() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('団体ダッシュボード'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
            icon: const Icon(Icons.logout, color: AppTheme.textSecondary),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.group_add_outlined,
                size: 80,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 24),
              const Text(
                '団体が登録されていません',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'スカウト送信やイベント掲載を始めるには、まず団体作成の申請を行ってください。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrgCreateScreen(),
                      ),
                    ).then((_) => _loadOrgStatus());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '団体作成を申請する',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ステータスバナー
  Widget _buildStatusBanner(String status) {
    final isPending = status == 'pending';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isPending ? Colors.amber.shade50 : Colors.red.shade50,
      child: Row(
        children: [
          Icon(
            isPending ? Icons.hourglass_empty : Icons.error_outline,
            color: isPending ? Colors.amber.shade800 : Colors.red.shade800,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPending ? '審査中：承認されるまで機能が制限されます。' : '申請却下：内容を確認し、再申請してください。',
              style: TextStyle(
                color: isPending ? Colors.amber.shade900 : Colors.red.shade900,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
