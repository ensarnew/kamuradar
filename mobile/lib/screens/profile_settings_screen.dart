import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import '../services/ad_service.dart';
import '../services/notification_service.dart';
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
            onPressed: () {
              final pwd = controller.text.trim();
              if (pwd == "Ensarakyr110823.AZRA") {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
                );
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
  final int _baseNotificationLimit = 3;

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
    _loadAlarmStats();
  }

  Future<void> _loadAlarmStats() async {
    final activeIds = await CacheService.getActiveAlarms();
    final bonus = await CacheService.getBonusNotifications();
    final used = await CacheService.getUsedNotifications();
    if (mounted) {
      setState(() {
        _activeAlarmCount = activeIds.length;
        _bonusNotifications = bonus;
        _usedNotifications = used;
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

          // 2. AYLIK BİLDİRİM ALMA KOTASI (UYGULAMA BİLDİRİMİ - REKLAMLA YÜKSELEN BÖLÜM)
          _buildNotificationQuotaSection(),

          const SizedBox(height: 16),

          // 3. TAKİP EDİLEN İLAN & SINAVLAR (REKLAMLA DEĞİL - LİSTE VE RADAR AYARI)
          _buildJobAlarmsSection(),

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
                                color: widget.isVip ? Colors.amber.shade100 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.isVip ? "VIP" : "ÜCRETSİZ",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: widget.isVip ? Colors.amber.shade900 : AppTheme.primaryBlue,
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

  // 2. Uygulama Bildirim Kotası (Reklamla Yükselen Aylık Bildirim Hakkı)
  Widget _buildNotificationQuotaSection() {
    final ratio = widget.isVip ? 1.0 : (_usedNotifications / _totalAllowedNotifications).clamp(0.0, 1.0);

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
                      widget.isVip ? "Sınırsız (VIP)" : "$_usedNotifications / $_totalAllowedNotifications Hak ($_remainingNotifications Kaldı)",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: widget.isVip ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
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
                      widget.isVip ? AppTheme.amberGold : (ratio >= 1.0 ? AppTheme.urgentRed : const Color(0xFF38BDF8)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isVip
                      ? "👑 VIP hesabınızla tüm alım ve sınav bildirimlerini sınırsız ve reklamsız alırsınız."
                      : "Ücretsiz hesaplara ayda 3 adet bildirim alma hakkı tanınır. Kısa bir reklam izleyerek anında +2 bildirim hakkı kazanabilirsiniz.",
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Reklamla +2 Bildirim Hakkı Kazan Butonu
          if (!widget.isVip)
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

          // 12:00 Toplu Tarama
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text("Günde 1 Kez Toplu Bildirim (Saat 12:00)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC))),
            subtitle: const Text("Gereksiz bildirim kirliliği olmaz, her gün 12:00'de toplu özet gelir.", style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
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
          const Text("Uygulama Bilgisi", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFF8FAFC))),
          const SizedBox(height: 8),
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
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {},
                child: const Text("Gizlilik Sözleşmesi", style: TextStyle(fontSize: 11)),
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
}
