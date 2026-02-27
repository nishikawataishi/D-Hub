import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/scout_screen.dart';
import '../screens/event_screen.dart';
import '../screens/profile_screen.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';

/// メイン画面
/// 4つのタブ（ホーム、スカウト、イベント、マイページ）を管理するBottomNavigationBar
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    // 未読スカウト数
    final unreadCount = mockScouts.where((s) => !s.isRead).length;

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
              onTap: (index) {
                setState(() => _currentIndex = index);
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'ホーム',
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(
                      '$unreadCount',
                      style: const TextStyle(fontSize: 10),
                    ),
                    child: const Icon(Icons.mail_outline),
                  ),
                  activeIcon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(
                      '$unreadCount',
                      style: const TextStyle(fontSize: 10),
                    ),
                    child: const Icon(Icons.mail),
                  ),
                  label: 'スカウト',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.event_outlined),
                  activeIcon: Icon(Icons.event),
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
  }
}
