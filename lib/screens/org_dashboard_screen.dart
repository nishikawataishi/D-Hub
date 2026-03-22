import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_notifier.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import '../models/event.dart';
import '../models/event_application.dart';
import '../models/organization.dart';
import '../models/scout.dart';
import 'components/student_card.dart';
import 'components/org_profile_edit_tab.dart';
import 'org_create_screen.dart';
import 'student_detail_screen.dart';
import 'event_edit_screen.dart';
import 'event_applications_screen.dart';
import 'components/verified_badge.dart';

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
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final org = await FirestoreService().getOrganization(user.uid);
        if (mounted) {
          setState(() {
            _currentOrg = org;
            _isOrgLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('OrgDashboardScreen._loadOrgStatus error: $e');
    }
    if (mounted) setState(() => _isOrgLoading = false);
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
              '審査承認後にスカウト管理が利用可能になります',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    final orgId = FirebaseAuth.instance.currentUser?.uid;
    if (orgId == null) return const SizedBox();

    return StreamBuilder<List<Scout>>(
      stream: FirestoreService().getScoutsByOrganization(orgId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'エラーが発生しました\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.error),
            ),
          );
        }

        final scouts = snapshot.data ?? [];
        final totalCount = scouts.length;
        final readCount = scouts.where((s) => s.isRead).length;
        final unreadCount = totalCount - readCount;

        if (scouts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.send_outlined,
                  size: 64,
                  color: AppTheme.textSecondary.withOpacity(0.4),
                ),
                const SizedBox(height: 16),
                const Text(
                  'まだスカウトを送っていません',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '学生検索タブから気になる学生にスカウトを送りましょう！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // サマリーバー
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.surface,
              child: Row(
                children: [
                  _ScoutStatChip(
                    label: '合計',
                    count: totalCount,
                    color: AppTheme.primary,
                    icon: Icons.send_rounded,
                  ),
                  const SizedBox(width: 8),
                  _ScoutStatChip(
                    label: '既読',
                    count: readCount,
                    color: Colors.green,
                    icon: Icons.done_all_rounded,
                  ),
                  const SizedBox(width: 8),
                  _ScoutStatChip(
                    label: '未読',
                    count: unreadCount,
                    color: Colors.orange,
                    icon: Icons.mark_email_unread_outlined,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),
            // スカウト履歴リスト
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: scouts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final scout = scouts[index];
                  return _ScoutHistoryCard(scout: scout);
                },
              ),
            ),
          ],
        );
      },
    );
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
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EventApplicationsScreen(event: event),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          // 編集ボタン
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EventEditScreen(event: event),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            tooltip: 'イベントを編集',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                          const SizedBox(width: 16),
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
                      const SizedBox(height: 10),
                      // 申し込み件数バッジ
                      StreamBuilder<List<EventApplication>>(
                        stream: FirestoreService()
                            .getApplicationsForEvent(event.id),
                        builder: (context, appSnapshot) {
                          final apps = appSnapshot.data ?? [];
                          final total = apps.length;
                          final accepted = apps
                              .where(
                                (a) =>
                                    a.status == ApplicationStatus.accepted,
                              )
                              .length;
                          final pending = apps
                              .where(
                                (a) => a.status == ApplicationStatus.applied,
                              )
                              .length;

                          return Row(
                            children: [
                              _AppCountChip(
                                icon: Icons.people_outline,
                                label: '申し込み $total 件',
                                color: AppTheme.primary,
                              ),
                              if (pending > 0) ...[
                                const SizedBox(width: 8),
                                _AppCountChip(
                                  icon: Icons.hourglass_empty,
                                  label: '審査中 $pending',
                                  color: Colors.orange,
                                ),
                              ],
                              if (accepted > 0) ...[
                                const SizedBox(width: 8),
                                _AppCountChip(
                                  icon: Icons.check_circle_outline,
                                  label: '承認 $accepted',
                                  color: Colors.green,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
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
              isPending
                  ? '審査中：承認されるまで機能が制限されます。審査が終わり次第（24H以内）自動で承認され、フルサービスがご利用頂けます。'
                  : '申請却下：以下を確認の上、プロフィールを修正して再申請してください。\n①団体名・説明が具体的に記載されているか\n②活動内容がわかる写真が設定されているか\n③Instagram URLなどの連絡先が設定されているか\nご不明な点はお問い合わせください。',
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

/// スカウト統計チップ
class _ScoutStatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _ScoutStatChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$label $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// スカウト履歴カード
class _ScoutHistoryCard extends StatelessWidget {
  final Scout scout;

  const _ScoutHistoryCard({required this.scout});

  @override
  Widget build(BuildContext context) {
    final sentDate = scout.sentAt;
    final dateLabel =
        '${sentDate.year}/${sentDate.month.toString().padLeft(2, '0')}/${sentDate.day.toString().padLeft(2, '0')}';

    // targetUserName が未保存の場合はFirestoreから取得
    final nameFuture = scout.targetUserName != null
        ? Future.value(scout.targetUserName!)
        : FirestoreService()
            .getUserProfile(scout.targetUserId)
            .then((p) => p?.name ?? '不明');

    return FutureBuilder<String>(
      future: nameFuture,
      builder: (context, nameSnap) {
        final displayName = nameSnap.data ?? '読み込み中…';

        return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // アイコン
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primary.withOpacity(0.1),
            backgroundImage: scout.targetUserIconUrl != null
                ? NetworkImage(scout.targetUserIconUrl!)
                : null,
            child: scout.targetUserIconUrl == null
                ? const Icon(Icons.person, color: AppTheme.primary, size: 24)
                : null,
          ),
          const SizedBox(width: 12),
          // 情報
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    // 既読/未読バッジ
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scout.isRead
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: scout.isRead
                              ? Colors.green.withOpacity(0.4)
                              : Colors.orange.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        scout.isRead ? '既読' : '未読',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scout.isRead ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  scout.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (scout.isRead && scout.readAt != null) ...[
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.done_all_rounded,
                        size: 12,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${scout.readAt!.month}/${scout.readAt!.day} 既読',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
        );
      },
    );
  }
}

/// 申し込み件数表示チップ
class _AppCountChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AppCountChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
