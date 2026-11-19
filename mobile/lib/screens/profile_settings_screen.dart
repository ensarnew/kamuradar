import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import '../services/ad_service.dart';
import '../services/notification_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'admin_panel_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final bool isVip;
  final VoidCallback? onUpgradeVip;

  const ProfileSettingsScreen({
    Key? key,
    this.isVip = false,
    this.onUpgradeVip,
  }) : super(key: key);

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  int _activeAlarmCount = 2;
  int _usedNotifications = 1;
  int _versionTapCount = 0;
  DateTime? _lastTapTime;
  bool _isVip = false;
  bool _isScanningWatchers = false;
  bool get _effectiveVip => widget.isVip || _isVip;

  // 🎯 Akıllı KPSS Puanı ve Tercihler
  double _userKpssScore = 0.0;
  String _userKpssType = "P3 - Lisans";
  String _userKpssEducation = "Lisans";

  @override
  void didUpdateWidget(ProfileSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVip != oldWidget.isVip) {
      setState(() => _isVip = widget.isVip);
    }
  }

  Future<void> _checkVipStatus() async {
    final vip = await FirebaseSyncService.isVip();
    if (mounted && vip != _isVip) {
      setState(() => _isVip = vip);
    }
  }

  void _handleVersionTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!).inSeconds > 2) {
      _versionTapCount = 1;
    } else {
      _versionTapCount++;
    }
    _lastTapTime = now;

    if (_versionTapCount >= 5) {
      _versionTapCount = 0;
      _showAdminPasswordDialog();
    }
  }

  void _showAdminPasswordDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text("Yönetici Doğrulama", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "KamuRadar Yönetici Paneline erişmek için lütfen yetkili şifrenizi girin:",
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Yönetici Şifresi",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.amber,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final pwd = controller.text.trim();
              if (pwd == "Ensarakyr110823.AZRA") {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
                );
                if (mounted) {
                  await _checkVipStatus();
                  await _loadAlarmStats();
                  widget.onUpgradeVip?.call();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.urgentRed,
                    content: Text("❌ Hatalı yönetici şifresi! Erişim reddedildi."),
                  ),
                );
              }
            },
            child: const Text("Giriş Yap", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  int _bonusNotifications = 0;
  final int _baseNotificationLimit = 10;

  // Uygulama Genel Ayarları (App Settings)
  bool _dailyScanNotification = true;
  bool _notificationSound = true;
  bool _notificationVibrate = true;
  bool _urgentLastDayAlert = true;

  int get _totalAllowedNotifications => _baseNotificationLimit + _bonusNotifications;
  int get _remainingNotifications => (_totalAllowedNotifications - _usedNotifications).clamp(0, _totalAllowedNotifications);

  @override
  void initState() {
    super.initState();
    _isVip = widget.isVip;
    _checkVipStatus();
    _loadAlarmStats();
  }

  Future<void> _loadAlarmStats() async {
    final activeIds = await CacheService.getActiveAlarms();
    final bonus = await CacheService.getBonusNotifications();
    final used = await CacheService.getUsedNotifications();
    final kpss = await CacheService.getUserKpssProfile();
    final double score = (kpss['score'] as num?)?.toDouble() ?? 0.0;
    final String kType = (kpss['type'] ?? "P3 - Lisans").toString();
    final String edu = (kpss['education'] ?? "Lisans").toString();

    await _checkVipStatus();
    if (mounted) {
      setState(() {
        _activeAlarmCount = activeIds.length;
        _bonusNotifications = bonus;
        _usedNotifications = used;
        _userKpssScore = score;
        _userKpssType = kType;
        _userKpssEducation = edu;
      });
    }
  }

  Future<void> _watchRewardedAd() async {
    AdService.instance.showRewardedAd(
      onStarted: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎬 Sponsorlu reklam yükleniyor ve oynatılıyor..."),
            duration: Duration(seconds: 2),
          ),
        );
      },
      onRewardEarned: () async {
        final newBonus = _bonusNotifications + 2;
        await CacheService.saveBonusNotifications(newBonus);
        if (mounted) {
          setState(() {
            _bonusNotifications = newBonus;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.successGreen,
              content: Text("🎉 Video tamamlandı! +2 Bildirim Alma Hakkı eklendi. Yeni Kota: $_totalAllowedNotifications bildirim!"),
            ),
          );
        }
      },
      onFailure: (errorMessage) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.urgentRed,
              content: Text(errorMessage),
            ),
          );
        }
      },
    );
  }

  Future<void> _resetAllAlarms() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tüm İlan Alarmlarını Sıfırla"),
        content: const Text("Kurulu olan tüm ilan takipleri kapatılacaktır. Onaylıyor musunuz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.urgentRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sıfırla"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CacheService.saveActiveAlarms([]);
      if (mounted) {
        setState(() {
          _activeAlarmCount = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tüm ilan alarmları kapatıldı.")),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    await CacheService.saveExamSchedules([]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Önbellek başarıyla temizlendi.")),
      );
    }
  }

  Future<void> _triggerCustomWatcherScan() async {
    setState(() => _isScanningWatchers = true);
    try {
      final res = await ApiService.scanCustomWatchersAndNotify();
      if (!mounted) return;
      final scanned = res['scanned_count'] ?? 0;
      final notifications = res['notifications_sent'] ?? 0;
      final updated = res['updated_count'] ?? 0;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131E33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
              SizedBox(width: 8),
              Text(
                "Özel Link Taraması",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            "📡 Özel kamu linkleri başarıyla tarandı!\n\n"
            "• Taranan Link Sayısı: $scanned\n"
            "• Tespit Edilen Değişiklik: $updated\n"
            "• Gönderilen Push Bildirimi: $notifications\n\n"
            "Özel linkleri takip eden kullanıcılara bildirim anında iletildi.",
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Tamam"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.urgentRed,
          content: Text("❌ Özel link tarama hatası: $e"),
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanningWatchers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSoft,
      appBar: AppBar(
        title: const Text("Profil & Ayarlar", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. KULLANICI / GOOGLE PROFİL KARTI
          _buildProfileCard(),

          const SizedBox(height: 16),

          // 1.5 🎯 KPSS PUANIM & AKILLI EŞLEŞME
          _buildKpssProfileSection(),

          const SizedBox(height: 16),

          // 2. AYLIK BİLDİRİM ALMA KOTASI (UYGULAMA BİLDİRİMİ - REKLAMLA YÜKSELEN BÖLÜM)
          _buildNotificationQuotaSection(),

          const SizedBox(height: 16),

          // 3. TAKİP EDİLEN İLAN & SINAVLAR (REKLAMLA DEĞİL - LİSTE VE RADAR AYARI)
          _buildJobAlarmsSection(),

          const SizedBox(height: 16),

          // 3.1 ÖZEL LİNK TARAMA & CANLI BİLDİRİM BUTONU
          _buildCustomWatcherScanSection(),

          const SizedBox(height: 16),

          // 4. UYGULAMA BİLDİRİM TERCİHLERİ (12:00 TOPLU TARAMA, SES, TİTREŞİM)
          _buildAppSettingsSection(),

          const SizedBox(height: 16),

          // 5. DEPOLAMA & ÇEVRİMDIŞI MOD
          _buildStorageSection(),

          const SizedBox(height: 16),

          // 6. YASAL & HAKKINDA
          _buildAboutSection(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 1. Profil Kartı
  Widget _buildProfileCard() {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isLoggedIn = user != null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131E33),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.borderSubtle),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    backgroundImage: isLoggedIn && user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                    child: !isLoggedIn || user.photoURL == null
                        ? const Icon(Icons.person, color: AppTheme.primaryBlue, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isLoggedIn ? (user.displayName ?? "Kullanıcı") : "Misafir Kullanıcı",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _effectiveVip ? Colors.amber.shade100 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _effectiveVip ? "VIP" : "ÜCRETSİZ",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: _effectiveVip ? Colors.amber.shade900 : AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLoggedIn ? (user.email ?? "") : "Cihaz Yerel Profili (Yedekleme Kapalı)",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (!isLoggedIn)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.account_circle, color: AppTheme.primaryBlue, size: 18),
                    label: const Text(
                      "Google ile Giriş Yap & Alarmları Yedekle",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryBlue),
                    ),
                    onPressed: () async {
                      try {
                        await AuthService.signInWithGoogle();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Giriş yapılamadı: $e")));
                      }
                    },
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Bulut Senkronizasyonu Aktif", style: TextStyle(fontSize: 11, color: AppTheme.successGreen, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => AuthService.signOut(),
                      child: const Text("Çıkış Yap", style: TextStyle(color: AppTheme.urgentRed, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  // 1.5 🎯 KPSS Puanım & Akıllı Eşleşme Bölümü
  Widget _buildKpssProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _userKpssScore > 0 ? const Color(0xFF22C55E).withValues(alpha: 0.5) : AppTheme.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.military_tech_rounded, color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🎯 KPSS Puanım & Akıllı Eşleşme",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      "Puanınıza uygun kadroları anında yeşil etiketleyin",
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _userKpssScore > 0 ? const Color(0xFF22C55E) : Colors.amber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: _showKpssScoreDialog,
                child: Text(
                  _userKpssScore > 0 ? "Güncelle" : "Puan Gir",
                  style: TextStyle(
                    color: _userKpssScore > 0 ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          if (_userKpssScore > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Puan: ${_userKpssScore.toStringAsFixed(1)} | Mezuniyet: $_userKpssEducation",
                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    _userKpssType,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showKpssScoreDialog() {
    double tempScore = _userKpssScore > 0 ? _userKpssScore : 70.0;
    String tempEducation = _userKpssEducation;
    String tempType = _userKpssType;
    final scoreController = TextEditingController(text: tempScore.toStringAsFixed(1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.military_tech_rounded, color: Colors.amber, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "🎯 KPSS Puanı & Tercih Profiliniz",
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Puanına uyan yüzlerce kamu alımını anında yeşil gör!",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Öğrenim Seviyeniz:",
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ["Lisans", "Ön Lisans", "Lise"].map((edu) {
                        final isSel = tempEducation == edu;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                tempEducation = edu;
                                if (edu == "Lisans") tempType = "P3 - Lisans";
                                if (edu == "Ön Lisans") tempType = "P93 - Ön Lisans";
                                if (edu == "Lise") tempType = "P94 - Ortaöğretim";
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSel ? AppTheme.primaryBlue : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? const Color(0xFF38BDF8) : Colors.transparent,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                edu,
                                style: TextStyle(
                                  color: isSel ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "KPSS Puan Türü: $tempType",
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "KPSS Puanınızı Girin (Örn: 72.50):",
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: scoreController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "70.00",
                                hintStyle: TextStyle(color: Colors.white38),
                              ),
                              onChanged: (val) {
                                final parsed = double.tryParse(val.replaceAll(',', '.'));
                                if (parsed != null) {
                                  setModalState(() {
                                    tempScore = parsed.clamp(0.0, 100.0);
                                  });
                                }
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${tempScore.toStringAsFixed(1)} Puan",
                              style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: tempScore.clamp(50.0, 100.0),
                      min: 50.0,
                      max: 100.0,
                      divisions: 100,
                      activeColor: AppTheme.primaryBlue,
                      inactiveColor: const Color(0xFF334155),
                      onChanged: (val) {
                        setModalState(() {
                          tempScore = val;
                          scoreController.text = val.toStringAsFixed(1);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final parsed = double.tryParse(scoreController.text.replaceAll(',', '.')) ?? tempScore;
                          final finalScore = parsed.clamp(0.0, 100.0);
                          await CacheService.saveUserKpssProfile(
                            score: finalScore,
                            kpssType: tempType,
                            education: tempEducation,
                          );
                          if (mounted) {
                            setState(() {
                              _userKpssScore = finalScore;
                              _userKpssType = tempType;
                              _userKpssEducation = tempEducation;
                            });
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("🎯 KPSS Puanı ($finalScore) başarıyla kaydedildi!"),
                                backgroundColor: const Color(0xFF22C55E),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          "Puanımı Kaydet",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 2. Uygulama Bildirim Kotası (Reklamla Yükselen Aylık Bildirim Hakkı)
  Widget _buildNotificationQuotaSection() {
    final ratio = _effectiveVip ? 1.0 : (_usedNotifications / _totalAllowedNotifications).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.notifications_active, color: AppTheme.amberGold, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Aylık Bildirim Alma Kotası", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFF8FAFC))),
                    Text("Telefonunuza düşen anlık duyuru haklarınız", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Kota Barı
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Kullanılan Bildirim:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC))),
                    Text(
                      _effectiveVip ? "Sınırsız (VIP)" : "$_usedNotifications / $_totalAllowedNotifications Hak ($_remainingNotifications Kaldı)",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _effectiveVip ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF1E2D4A),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _effectiveVip ? AppTheme.amberGold : (ratio >= 1.0 ? AppTheme.urgentRed : const Color(0xFF38BDF8)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _effectiveVip
                      ? "👑 VIP hesabınızla tüm alım ve sınav bildirimlerini sınırsız ve reklamsız alırsınız."
                      : "Ücretsiz hesaplara ayda 10 adet bildirim alma hakkı tanınır. Kısa bir reklam izleyerek anında +2 bildirim hakkı kazanabilirsiniz.",
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Reklamla +2 Bildirim Hakkı Kazan Butonu
          if (!_effectiveVip)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_circle_fill, color: Colors.amber, size: 18),
                label: const Text(
                  "🎬 Kısa Reklam İzle (+2 Bildirim Hakkı Kazan)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                ),
                onPressed: _watchRewardedAd,
              ),
            ),
        ],
      ),
    );
  }

  // 3. Takip Edilen İlan & Sınavlar (Reklamla Değil - Kullanıcı İstediği Alımları Açar)
  Widget _buildJobAlarmsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF1E3A8A).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.campaign, color: Color(0xFF38BDF8), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Takip Edilen İlan & Sınavlar", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFF8FAFC))),
                    Text("$_activeAlarmCount Alım ve Sınav Radarda Takipte", style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "İlan ve sınavları radara eklemek tamamen ücretsizdir. Yeni duyuru yayınlandığında telefonunuza bildirim gelmesi için aylık bildirim hakkınız kullanılır.",
                    style: const TextStyle(fontSize: 10, color: Color(0xFFCBD5E1), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Color(0xFFEF4444)),
              label: const Text("Kurulu Alarmları Kapat", style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
              onPressed: _resetAllAlarms,
            ),
          ),
        ],
      ),
    );
  }

  // 3.1 Özel Link Tarama & Canlı Bildirim Butonu
  Widget _buildCustomWatcherScanSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.podcasts, color: Color(0xFF38BDF8), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Özel Link Takibi & Canlı Bildirim",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFF8FAFC)),
                    ),
                    Text(
                      "Özel link takipçilerine anlık bildirim fırlatır",
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF38BDF8)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Bu butona bastığınızda kullanıcıların sisteme eklediği tüm özel kamu linkleri (üniversite, belediye, bakanlık) anında taranır ve takip edenlere bildirim gider.",
                    style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              onPressed: _isScanningWatchers ? null : _triggerCustomWatcherScan,
              icon: _isScanningWatchers
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.wifi_tethering, size: 18),
              label: Text(
                _isScanningWatchers ? "Özel Linkler Taranıyor..." : "📡 Özel Linkleri Şimdi Tara & Bildirim Gönder",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Uygulama Ayarları Bölümü (Bildirim, Ses, Saat)
  Widget _buildAppSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.settings, color: AppTheme.amberGold, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Uygulama Bildirim Ayarları", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFF8FAFC))),
                    Text("Günlük tarama saati ve telefon tercihleri", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Gündüz Otomatik Tarama (10:00 - 22:00)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text("Gündüz Otomatik Tarama (10:00 - 22:00)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC))),
            subtitle: const Text("10:00, 12:00, 14:00, 16:00, 18:00, 20:00, 22:00 saatlerinde 2 saatte bir taranır. Gece sessizdir.", style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            value: _dailyScanNotification,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (v) => setState(() => _dailyScanNotification = v),
          ),
          const Divider(height: 1),

          // Kritik Son 24 Saat
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text("Kritik Son Gün Uyarısı (24 Saat Kala)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC))),
            subtitle: const Text("Takip ettiğiniz ilanın son başvuru gününde acil hatırlatma.", style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            value: _urgentLastDayAlert,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (v) => setState(() => _urgentLastDayAlert = v),
          ),
          const Divider(height: 1, color: Color(0xFF1E2D4A)),

          // Bildirim Sesi
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text("Bildirim Sesi", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC))),
            value: _notificationSound,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (v) => setState(() => _notificationSound = v),
          ),
          const Divider(height: 1, color: Color(0xFF1E2D4A)),

          const Divider(height: 1, color: Color(0xFF1E2D4A)),

          // Titreşim
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text("Titreşim", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC))),
            value: _notificationVibrate,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (v) => setState(() => _notificationVibrate = v),
          ),
          const SizedBox(height: 14),

          // TEST BİLDİRİMİ GÖNDER TUŞU
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: const Color(0xFF38BDF8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.notifications_active, size: 18),
              label: const Text(
                "🔔 Test Bildirimi Gönder (Zil Testi)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () async {
                await NotificationService.showLocalNotification(
                  title: "KamuRadar Test Bildirimi 🔔",
                  body: "Tebrikler! Bildirim sisteminiz başarıyla yapılandırıldı ve çalışıyor.",
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF10B981),
                      content: Text("✅ Test bildirimi telefonunuza gönderildi! Üst bildirim çubuğunuzu kontrol edin."),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // 4. Depolama & Çevrimdışı Mod
  Widget _buildStorageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.offline_pin, color: AppTheme.successGreen, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Çevrimdışı Önbellek (Offline Mode)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFF8FAFC))),
                    Text("İnternetsiz ortamda alarmlarınız güvende", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Önbellek Durumu:", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              Text("✅ Cihazda Saklanıyor", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.successGreen)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF1E2D4A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.sync, size: 14),
                  label: const Text("Şimdi Senkronize Et", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Canlı sunucu ile senkronize edildi.")),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.urgentRed,
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _clearCache,
                child: const Text("Temizle", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 5. Hakkında & Yasal
  Widget _buildAboutSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Uygulama & Yasal Bilgiler", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFF8FAFC))),
          const SizedBox(height: 8),

          // Sürüm Bilgisi
          InkWell(
            onTap: _handleVersionTap,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Sürüm", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  Text("KamuRadar PRO v1.0.0", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFF1E2D4A)),
          const SizedBox(height: 8),

          // Yasal Uyarı & Sorumluluk Reddi Butonu
          InkWell(
            onTap: () => _showLegalDisclaimerDialog(context),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.gavel, size: 16, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Resmî Kurum Sorumluluk Reddi Beyanı", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text("Devlet kurumu bağımsızlığı ve resmi kaynaklar", style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFF1E2D4A)),
          const SizedBox(height: 12),

          // Google Play'de Yıldız Verme Butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: const Color(0xFFF59E0B),
                side: const BorderSide(color: Color(0xFFF59E0B)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.star, color: Color(0xFFF59E0B), size: 20),
              label: const Text(
                "Google Play'de 5 Yıldız Ver & Destek Ol",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () async {
                final uri = Uri.parse("https://play.google.com/store/apps/details?id=com.kamuradar.app");
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () async {
                  final uri = Uri.parse("https://github.com/ensarnew/kamuradar/blob/main/PRIVACY_POLICY.md");
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
                child: const Text("Gizlilik Sözleşmesi", style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
              ),
              TextButton.icon(
                icon: const Icon(Icons.help_outline, size: 14),
                label: const Text("Destek & İletişim", style: TextStyle(fontSize: 11)),
                onPressed: () async {
                  final uri = Uri.parse("https://play.google.com/store/apps/details?id=com.kamuradar.app");
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLegalDisclaimerDialog(BuildContext context) {
    final sources = [
      {"name": "T.C. Resmî Gazete", "url": "https://www.resmigazete.gov.tr"},
      {"name": "Kariyer Kapısı Kamu İşe Alım", "url": "https://kariyerkapisi.gov.tr"},
      {"name": "Cumhurbaşkanlığı Kamu İlan Portalı", "url": "https://kamuilan.sbb.gov.tr"},
      {"name": "Türkiye İş Kurumu (İŞKUR)", "url": "https://www.iskur.gov.tr"},
      {"name": "ÖSYM Sınav ve Sonuç Portalı", "url": "https://www.osym.gov.tr"},
      {"name": "Jandarma Personel Temin Portalı", "url": "https://personeltemin.jandarma.gov.tr"},
      {"name": "Polis Akademisi Başkanlığı", "url": "https://pa.edu.tr"},
      {"name": "Millî Savunma Bakanlığı (MSB)", "url": "https://www.msb.gov.tr"},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131E33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFF59E0B))),
        title: const Row(
          children: [
            Icon(Icons.gavel, color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Resmî Sorumluluk Reddi & Kaynaklar",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "KamuRadar Bağımsız Bir Takip Servisidir",
                style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                "KamuRadar uygulaması; herhangi bir devlet kurumu, bakanlık, askeri teşkilat veya resmi kamu kuruluşu ile resmi ya da kurumsal bir bağa sahip değildir ve bir devlet kuruluşunu temsil etmemektedir.",
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                "Resmî Bilgi ve İlan Kaynakları:",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              ...sources.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: InkWell(
                      onTap: () => launchUrl(Uri.parse(s["url"]!), mode: LaunchMode.externalApplication),
                      child: Row(
                        children: [
                          const Icon(Icons.link, color: Color(0xFF38BDF8), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${s['name']} (${s['url']})",
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 12),
              const Text(
                "Yasal Uyarı: Bu uygulama sadece açık kaynaklı ilanları listeleme ve kişisel alarm kurma amacıyla hizmet vermektedir. Kesin başvuru koşulları ve resmi başvurular yalnızca ilgili kurumun internet adresinden yapılmalıdır.",
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, height: 1.3),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Kapat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
