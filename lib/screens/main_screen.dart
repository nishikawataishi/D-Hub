import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/scout_screen.dart';
import '../screens/event_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import '../models/scout.dart';

/// メイン画面
/// 4つのタブ（ホーム、スカウト、イベント、マイページ）を管理するBottomNavigationBar
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final _firestoreService = FirestoreService();

  // ScoutScreenのStateにアクセスするためのキー
  final GlobalKey<ScoutScreenState> _scoutScreenKey =
      GlobalKey<ScoutScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      ScoutScreen(key: _scoutScreenKey),
      EventScreen(),
      const ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<Scout>>(
      stream: _firestoreService.getScoutsForUser(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Firestore Error (MainScreen): ${snapshot.error}');
          // エラー時も SizedBox.shrink() は返さず、UIはそのまま表示する（バッジは非表示扱い）
        }

        bool hasUnread = false;
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final scouts = snapshot.data!;
          hasUnread = scouts.any((scout) => scout.isRead == false);
        }

        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _screens[_currentIndex],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: _onItemTapped,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: AppTheme.primary,
                  unselectedItemColor: AppTheme.textSecondary,
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  selectedFontSize: 12,
                  unselectedFontSize: 12,
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.home_outlined),
                      activeIcon: Icon(Icons.home),
                      label: 'ホーム',
                    ),
                    BottomNavigationBarItem(
                      icon: Badge(
                        isLabelVisible: hasUnread,
                        backgroundColor: AppTheme.notification,
                        child: const Icon(Icons.mail_outline),
                      ),
                      activeIcon: Badge(
                        isLabelVisible: hasUnread,
                        backgroundColor: AppTheme.notification,
                        child: const Icon(Icons.mail),
                      ),
                      label: 'スカウト',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.event_note_outlined),
                      activeIcon: Icon(Icons.event_note),
                      label: 'イベント',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline),
                      activeIcon: Icon(Icons.person),
                      label: 'マイページ',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
