import 'package:flutter/material.dart';
import 'screens/home_feed_screen.dart';
import 'screens/open_announcements_screen.dart';
import 'screens/custom_watcher_screen.dart';
import 'screens/family_subscription_screen.dart';
import 'widgets/radar_ai_sheet.dart';
import 'theme/app_theme.dart';


void main() {
  runApp(const KamuRadarApp());
}

class KamuRadarApp extends StatelessWidget {
  const KamuRadarApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KamuRadar PRO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isVip = false;

  void _upgradeToVip() {
    setState(() {
      _currentIndex = 3; // Aile Planı sekmesine yönlendir
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const HomeFeedScreen(),
      OpenAnnouncementsScreen(
        isVip: _isVip,
        onUpgrade: _upgradeToVip,
      ),
      const CustomWatcherScreen(),
      const FamilySubscriptionScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      floatingActionButton: RadarAIFloatingButton(
        isVip: _isVip,
        onUpgradeRequested: _upgradeToVip,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        indicatorColor: AppTheme.primaryBlue.withOpacity(0.12),
        backgroundColor: Colors.white,
        elevation: 1,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.notifications_active_outlined),
            selectedIcon: Icon(Icons.notifications_active, color: AppTheme.primaryBlue),
            label: 'Alarm Radarı',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text("VIP", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
              backgroundColor: AppTheme.amberGold,
              child: Icon(Icons.campaign_outlined),
            ),
            selectedIcon: Badge(
              label: Text("VIP", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
              backgroundColor: AppTheme.amberGold,
              child: Icon(Icons.campaign, color: AppTheme.primaryBlue),
            ),
            label: 'Açık İlanlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.language_outlined),
            selectedIcon: Icon(Icons.language, color: AppTheme.primaryBlue),
            label: 'Özel Linkler',
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium, color: AppTheme.amberGold),
            label: 'Aile Planı',
          ),
        ],
      ),
    );
  }
}
