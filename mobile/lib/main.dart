import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_feed_screen.dart';
import 'screens/custom_watcher_screen.dart';
import 'screens/family_subscription_screen.dart';
import 'screens/profile_settings_screen.dart';
import 'screens/login_screen.dart';
import 'services/in_app_purchase_service.dart';
import 'services/notification_service.dart';
import 'services/ad_service.dart';
import 'services/firebase_sync_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("Firebase başlatma notu: $e");
  }

  Future.microtask(() async {
    try {
      await InAppPurchaseService.instance.initialize();
    } catch (_) {}

    try {
      await FirebaseSyncService.restoreUserDataFromCloud();
    } catch (_) {}

    try {
      await AdService.instance.initialize(testMode: false);
    } catch (e) {
      debugPrint("Unity Ads başlatma notu: $e");
    }
  });

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
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _isAuthenticated;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final hasAuth = await FirebaseSyncService.hasCompletedAuth();
    if (mounted) {
      setState(() {
        _isAuthenticated = hasAuth;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF091122),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
      );
    }

    if (_isAuthenticated == false) {
      return LoginScreen(
        onLoginSuccess: () {
          setState(() {
            _isAuthenticated = true;
          });
        },
      );
    }

    return const MainNavigationScreen();
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

  @override
  void initState() {
    super.initState();
    _loadVipStatus();
  }

  Future<void> _loadVipStatus() async {
    final vip = await FirebaseSyncService.isVip();
    if (mounted) {
      setState(() {
        _isVip = vip;
      });
    }
  }

  void _upgradeToVip() {
    setState(() {
      _currentIndex = 2; // Aile Planı sekmesine yönlendir
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeFeedScreen(
        isVip: _isVip,
        onUpgradeVip: _upgradeToVip,
      ),
      CustomWatcherScreen(
        isVip: _isVip,
        onUpgradeVip: _upgradeToVip,
      ),
      FamilySubscriptionScreen(
        isVip: _isVip,
        onPlanPurchased: () async {
          await FirebaseSyncService.setVipStatus(true);
          setState(() => _isVip = true);
        },
      ),
      ProfileSettingsScreen(
        isVip: _isVip,
        onUpgradeVip: _upgradeToVip,
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1E2D4A), width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          indicatorColor: const Color(0xFF1E3A8A),
          backgroundColor: const Color(0xFF0F172A),
          elevation: 2,
          onDestinationSelected: (idx) {
            setState(() {
              _currentIndex = idx;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.radar_outlined, color: Color(0xFF94A3B8)),
              selectedIcon: Icon(Icons.radar, color: Color(0xFF38BDF8)),
              label: 'İlan Radarı',
            ),
            NavigationDestination(
              icon: Icon(Icons.language_outlined, color: Color(0xFF94A3B8)),
              selectedIcon: Icon(Icons.language, color: Color(0xFF38BDF8)),
              label: 'Özel Linkler',
            ),
            NavigationDestination(
              icon: Icon(Icons.workspace_premium_outlined, color: Color(0xFF94A3B8)),
              selectedIcon: Icon(Icons.workspace_premium, color: AppTheme.amberGold),
              label: 'Aile Planı',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined, color: Color(0xFF94A3B8)),
              selectedIcon: Icon(Icons.tune, color: Color(0xFF38BDF8)),
              label: 'Profil & Ayar',
            ),
          ],
        ),
      ),
    );
  }
}
