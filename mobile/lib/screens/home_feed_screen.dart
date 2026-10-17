import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../services/cache_service.dart';
import '../services/ad_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/notification_service.dart';
import 'profile_settings_screen.dart';
import 'family_subscription_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/in_app_purchase_service.dart';
import '../widgets/announcement_detail_sheet.dart';
import '../data/announcements_catalog.dart';

class ChannelAlarm {
  final String id;
  final String organization;
  final String title;
  final String position;
  final String city;
  final String date;
  final String quota;
  final String deadline;
  final String applicationPlace;
  final String employmentType;
  final String applicationType;
  final List<String> requirements;
  final String status;
  final String description;
  final String officialUrl;
  final IconData logoIcon;
  bool isAlarmActive;
  final String sectorType;      // 'KAMU', 'OZEL'
  final String contentType;     // 'ILAN', 'SINAV', 'MULAKAT', 'SONUC'
  final String category;        // Askeri & Emniyet, Bakanlıklar, Belediyeler & Mahalli İdareler, vb.
  final String educationLevel;  // Okuryazar, Lise, Ön Lisans, Lisans
  final String kpssStatus;      // KPSS'li, KPSS'siz, Muaf
  final String? examDate;

  Color get statusColor {
    switch (status) {
      case "Açık":
        return const Color(0xFF22C55E); // Yeşil
      case "Yakında":
        return const Color(0xFF3B82F6); // Mavi
      case "Sonuç":
        return const Color(0xFFEF4444); // Kırmızı
      case "Kapalı":
      default:
        return const Color(0xFF64748B); // Gri
    }
  }

  ChannelAlarm({
    required this.id,
    required this.organization,
    required this.title,
    String? position,
    this.city = "Ankara",
    this.date = "15.09.2025",
    this.quota = "250",
    this.deadline = "30.09.2025",
    this.applicationPlace = "ÖSYM",
    this.employmentType = "Sözleşmeli Personel",
    this.applicationType = "Online Başvuru",
    this.status = "Açık",
    this.requirements = const [
      "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini yapmasına engel bir durumu olmamak.",
      "KPSS'den ilgili puan türünden en az 70 puan almak.",
    ],
    required this.description,
    required this.officialUrl,
    this.logoIcon = Icons.local_hospital,
    this.isAlarmActive = false,
    this.sectorType = "KAMU",
    this.contentType = "ILAN",
    this.category = "Bakanlıklar",
    this.educationLevel = "Lisans",
    this.kpssStatus = "KPSS'li",
    this.examDate,
  }) : position = position ?? title;

  static DateTime? parseTurkishDate(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final clean = raw.trim();
      if (clean.contains('.')) {
        final parts = clean.split('.');
        if (parts.length == 3) {
          final day = int.parse(parts[0].trim());
          final month = int.parse(parts[1].trim());
          final year = int.parse(parts[2].trim());
          return DateTime(year, month, day);
        }
      } else if (clean.contains('/')) {
        final parts = clean.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0].trim());
          final month = int.parse(parts[1].trim());
          final year = int.parse(parts[2].trim());
          return DateTime(year, month, day);
        }
      } else if (clean.contains('-')) {
        final parts = clean.split('-');
        if (parts.length == 3) {
          final year = int.parse(parts[0].trim());
          final month = int.parse(parts[1].trim());
          final day = int.parse(parts[2].trim());
          return DateTime(year, month, day);
        }
      }
    } catch (_) {}
    return null;
  }

  static String calculateStatus({
    required String startDateStr,
    required String deadlineDateStr,
    DateTime? referenceDate,
    String defaultStatus = "Açık",
  }) {
    if (defaultStatus == "Sonuç") return "Sonuç";

    final ref = referenceDate ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);

    final DateTime? deadline = parseTurkishDate(deadlineDateStr);
    final DateTime? startDate = parseTurkishDate(startDateStr);

    // 1. Son başvuru tarihi referans gününden önceyse -> Bitti / Kapalı
    if (deadline != null && today.isAfter(deadline)) {
      return "Kapalı";
    }

    // 2. Başvuru başlangıç tarihi referans gününden sonraysa -> Henüz başlamadı / Yakında
    if (startDate != null && today.isBefore(startDate)) {
      return "Yakında";
    }

    // 3. Başlangıç ile bitiş arasındaysa veya aynı günse -> Açık
    return "Açık";
  }

  ChannelAlarm copyWith({
    String? id,
    String? organization,
    String? title,
    String? position,
    String? city,
    String? date,
    String? quota,
    String? deadline,
    String? applicationPlace,
    String? employmentType,
    String? applicationType,
    List<String>? requirements,
    String? status,
    String? description,
    String? officialUrl,
    IconData? logoIcon,
    bool? isAlarmActive,
    String? sectorType,
    String? contentType,
    String? category,
    String? educationLevel,
    String? kpssStatus,
    String? examDate,
  }) {
    return ChannelAlarm(
      id: id ?? this.id,
      organization: organization ?? this.organization,
      title: title ?? this.title,
      position: position ?? this.position,
      city: city ?? this.city,
      date: date ?? this.date,
      quota: quota ?? this.quota,
      deadline: deadline ?? this.deadline,
      applicationPlace: applicationPlace ?? this.applicationPlace,
      employmentType: employmentType ?? this.employmentType,
      applicationType: applicationType ?? this.applicationType,
      requirements: requirements ?? this.requirements,
      status: status ?? this.status,
      description: description ?? this.description,
      officialUrl: officialUrl ?? this.officialUrl,
      logoIcon: logoIcon ?? this.logoIcon,
      isAlarmActive: isAlarmActive ?? this.isAlarmActive,
      sectorType: sectorType ?? this.sectorType,
      contentType: contentType ?? this.contentType,
      category: category ?? this.category,
      educationLevel: educationLevel ?? this.educationLevel,
      kpssStatus: kpssStatus ?? this.kpssStatus,
      examDate: examDate ?? this.examDate,
    );
  }
}

class HomeFeedScreen extends StatefulWidget {
  final bool isVip;
  final VoidCallback? onUpgradeVip;

  static List<ChannelAlarm> get catalog => _HomeFeedScreenState.staticChannelsCatalog;

  const HomeFeedScreen({
    Key? key,
    this.isVip = false,
    this.onUpgradeVip,
  }) : super(key: key);

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  bool _isUserVip = false;
  bool get _effectiveVip => widget.isVip || _isUserVip;
  final int _baseNotificationLimit = 10;
  int _bonusNotifications = 0;
  int _usedNotifications = 0;
  bool _isLoadingLive = false;
  bool _isOfflineMode = false;
  final Set<String> _unlockedWithAdsChannelIds = {};

  int get _totalAllowedNotifications => _baseNotificationLimit + _bonusNotifications;
  int get _remainingNotifications => (_totalAllowedNotifications - _usedNotifications).clamp(0, _totalAllowedNotifications);

  @override
  void didUpdateWidget(HomeFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVip != oldWidget.isVip) {
      setState(() {
        _isUserVip = widget.isVip;
      });
    }
  }

  Future<void> _checkVipStatus() async {
    final vip = await FirebaseSyncService.isVip();
    if (mounted && vip != _isUserVip) {
      setState(() {
        _isUserVip = vip;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _isUserVip = widget.isVip;
    _checkVipStatus();
    _loadCachedAlarms();
    _listenToFirestoreAnnouncements();
    _syncWithLiveServer();

    NotificationService.onLowQuotaWarning = () {
      if (mounted) {
        _loadCachedAlarms();
        _showLowQuotaAlert();
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunchPrompts();
    });
  }

  Future<void> _checkFirstLaunchPrompts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAcceptedDisclaimer = prefs.getBool("has_accepted_disclaimer") ?? false;
      if (!hasAcceptedDisclaimer && mounted) {
        await _showDisclaimerModal();
      }

      final hasShownRate = prefs.getBool("has_shown_rate_dialog") ?? false;
      if (!hasShownRate && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          await _showRateAppDialog();
        }
      }
    } catch (_) {}
  }

  Future<void> _showDisclaimerModal() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131E33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFF59E0B))),
        title: const Row(
          children: [
            Icon(Icons.gavel, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Yasal Uyarı & Sorumluluk Reddi",
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E2D4A)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "KamuRadar Bağımsız Bir Takip Servisidir",
                      style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "KamuRadar, herhangi bir devlet kurumu, bakanlık veya resmi kamu teşekkülü ile kurumsal/resmi bir bağı bulunmayan bağımsız bir kamu ilan ve sınav takip platformudur.",
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "• İlan Kaynakları: Uygulamada yer alan kamu alımları; Resmî Gazete, İŞKUR, Kamu İlan Portalı (kamuilan.sbb.gov.tr) ve ilgili kurumların halka açık resmi internet sitelerinden derlenmektedir.\n\n"
                "• Başvuru İşlemleri: KamuRadar üzerinden başvuru alınmaz. Başvurular yalnızca ilgili kurumun resmî web sayfası üzerinden gerçekleştirilir.\n\n"
                "• Kesin Bilgi: Nihai şartlar ve başvuru kılavuzları için kurumların resmi internet sayfaları esas alınmalıdır.",
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool("has_accepted_disclaimer", true);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("Okudum, Anladım ve Kabul Ediyorum", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _showRateAppDialog() async {
    int selectedStars = 5;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF131E33),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF38BDF8))),
          title: const Column(
            children: [
              Icon(Icons.stars, color: Color(0xFFF59E0B), size: 36),
              SizedBox(height: 8),
              Text(
                "KamuRadar'ı Değerlendirin",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Kamu ve KPSS ilanlarını kaçırmamanız için her gün güncellenen KamuRadar'ı beğendiniz mi? Deneyiminizi 5 yıldızla taçlandırarak bize destek olabilirsiniz!",
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      starIndex <= selectedStars ? Icons.star : Icons.star_border,
                      color: const Color(0xFFF59E0B),
                      size: 32,
                    ),
                    onPressed: () {
                      setModalState(() {
                        selectedStars = starIndex;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text(
                selectedStars == 5 ? "⭐⭐⭐⭐⭐ Harika!" : "$selectedStars Yıldız",
                style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool("has_shown_rate_dialog", true);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text("Daha Sonra", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool("has_shown_rate_dialog", true);
                      if (ctx.mounted) Navigator.pop(ctx);

                      final playStoreUri = Uri.parse("https://play.google.com/store/apps/details?id=com.kamuradar.app");
                      try {
                        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                    child: const Text("Puan Ver", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSubscription;

  void _listenToFirestoreAnnouncements() {
    try {
      _firestoreSubscription = FirebaseSyncService.getAnnouncementsStream().listen((snapshot) {
        if (!mounted) return;
        if (snapshot.docs.isNotEmpty) {
          final now = DateTime.now();
          final List<ChannelAlarm> remoteChannels = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final startDateStr = (data['date'] ?? data['application_start'] ?? '').toString();
            final deadlineStr = (data['deadline'] ?? data['application_deadline'] ?? '').toString();
            final defaultStatus = (data['status'] ?? 'Açık').toString();

            final evaluatedStatus = ChannelAlarm.calculateStatus(
              startDateStr: startDateStr,
              deadlineDateStr: deadlineStr,
              referenceDate: now,
              defaultStatus: defaultStatus,
            );

            final category = (data['category'] ?? 'Bakanlıklar').toString();

            remoteChannels.add(ChannelAlarm(
              id: doc.id,
              organization: (data['organization'] ?? 'Kamu Kurumu').toString(),
              title: (data['title'] ?? 'Kamu Alım İlanı').toString(),
              position: (data['position'] ?? data['title'] ?? 'Kamu Görevlisi').toString(),
              city: (data['city'] ?? 'Tüm Türkiye').toString(),
              date: startDateStr.isNotEmpty ? startDateStr : "${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}",
              quota: (data['quota'] ?? 'Belirtilmedi').toString(),
              deadline: deadlineStr.isNotEmpty ? deadlineStr : "${now.day.toString().padLeft(2, '0')}.${(now.month + 1).toString().padLeft(2, '0')}.${now.year}",
              applicationPlace: (data['applicationPlace'] ?? data['application_place'] ?? 'Resmî Başvuru Ekranı').toString(),
              employmentType: (data['employmentType'] ?? data['employment_type'] ?? 'Kamu Personeli').toString(),
              applicationType: (data['applicationType'] ?? data['application_type'] ?? 'Online Başvuru').toString(),
              status: evaluatedStatus,
              requirements: (data['requirements'] is List)
                  ? List<String>.from((data['requirements'] as List).map((e) => e.toString()))
                  : ["T.C. vatandaşı olmak", "Kamu haklarından mahrum bulunmamak", "Görevini yapmaya engel sağlık sorunu olmamak"],
              description: (data['description'] ?? data['summary'] ?? 'Detaylı başvuru kılavuzu ve şartları inceleyin.').toString(),
              officialUrl: (data['officialUrl'] ?? data['official_url'] ?? 'https://kamuradar.app').toString(),
              logoIcon: _getIconForCategory(category),
              sectorType: (data['sectorType'] ?? data['sector_type'] ?? 'KAMU').toString(),
              contentType: (data['contentType'] ?? data['content_type'] ?? 'ILAN').toString(),
              category: category,
              educationLevel: (data['educationLevel'] ?? data['education_level'] ?? 'Lisans').toString(),
              kpssStatus: (data['kpssStatus'] ?? data['kpss_status'] ?? 'KPSS\'li').toString(),
              examDate: data['examDate'] ?? data['exam_date'],
            ));
          }

          if (remoteChannels.isNotEmpty) {
            setState(() {
              _channels
                ..clear()
                ..addAll(remoteChannels);
            });
            _loadCachedAlarms();
            // 🔓 İlk Firebase yüklemesinde 4 ücretsiz ilan ID'sini belirle ve kaydet
            _initFreeAnnouncementIds(remoteChannels);
          }
        }
      }, onError: (err) {
        // Hata durumunda yerel zengin katalog kesintisiz devam eder
      });
    } catch (_) {}
  }

  IconData _getIconForCategory(String category) {
    final catLower = category.toLowerCase();
    if (catLower.contains("asker") || catLower.contains("jandarma") || catLower.contains("polis") || catLower.contains("emniyet")) {
      return Icons.shield;
    } else if (catLower.contains("sağlık") || catLower.contains("hastane")) {
      return Icons.local_hospital;
    } else if (catLower.contains("işkur") || catLower.contains("işçi") || catLower.contains("typ")) {
      return Icons.engineering;
    } else if (catLower.contains("belediye")) {
      return Icons.location_city;
    } else if (catLower.contains("üniversite") || catLower.contains("akademik")) {
      return Icons.school;
    } else if (catLower.contains("sınav") || catLower.contains("ösym") || catLower.contains("kpss")) {
      return Icons.fact_check;
    } else if (catLower.contains("kit") || catLower.contains("banka")) {
      return Icons.account_balance;
    }
    return Icons.business_center;
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedAlarms() async {
    try {
      final activeIds = await CacheService.getActiveAlarms();
      final bonus = await CacheService.getBonusNotifications();
      final used = await CacheService.getUsedNotifications();

      final prefs = await SharedPreferences.getInstance();
      final savedFreeIds = prefs.getStringList("free_preview_ids");
      if (savedFreeIds != null && savedFreeIds.isNotEmpty && !_freeIdsInitialized) {
        _freeAnnouncementIds = savedFreeIds.toSet();
        _freeIdsInitialized = true;
      }

      final adUnlocked = prefs.getStringList("unlocked_with_ads_ids");
      if (adUnlocked != null && adUnlocked.isNotEmpty) {
        _unlockedWithAdsChannelIds.addAll(adUnlocked);
      }

      // Tarihe göre ilan durumlarını sınıflandır:
      // Son başvuru tarihi geçmiş olanlar kesinlikle 'Kapalı', henüz başlamamışlar 'Yakında',
      // süresi devam edenler ise 'Açık' olarak değerlendirilir.
      final now = DateTime.now();
      for (int i = 0; i < _channels.length; i++) {
        final current = _channels[i];
        final evaluated = ChannelAlarm.calculateStatus(
          startDateStr: current.date,
          deadlineDateStr: current.deadline,
          referenceDate: now,
          defaultStatus: current.status,
        );
        
        _channels[i] = current.copyWith(
          status: evaluated,
        );
      }

      if (mounted) {
        setState(() {
          _bonusNotifications = bonus;
          _usedNotifications = used;
          if (activeIds.isNotEmpty) {
            for (var ch in _channels) {
              ch.isAlarmActive = activeIds.contains(ch.id);
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _syncWithLiveServer() async {
    try {
      setState(() => _isLoadingLive = true);
      final liveSchedules = await ApiService.getExamSchedules();
      if (liveSchedules.isNotEmpty && mounted) {
        setState(() {
          _isOfflineMode = false;
          _isLoadingLive = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOfflineMode = true;
          _isLoadingLive = false;
        });
      }
    }
  }

  void _shareOnWhatsApp(ChannelAlarm ch) {
    final shareText = "📢 ${ch.organization} Alımı / Takvimi: ${ch.title}!\n\n"
        "Detaylar ve başvuru adresi: ${ch.officialUrl}\n\n"
        "🔔 Hiçbir kamu ve KPSS sınavını kaçırmamak için KamuRadar uygulamasını Google Play'den indir:\n"
        "https://play.google.com/store/apps/details?id=com.kamuradar.app";
    Share.share(shareText, subject: ch.title);
  }



  Future<void> _loginWithGoogle() async {
    try {
      final user = await AuthService.signInWithGoogle();
      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hoş geldin, ${user.displayName}! 👋")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Giriş yapılamadı: $e")),
        );
      }
    }
  }

  void _showUserMenu(User user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child: user.photoURL == null ? const Icon(Icons.person, size: 30) : null,
            ),
            const SizedBox(height: 12),
            Text(user.displayName ?? "Kullanıcı", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(user.email ?? "", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.tune, color: AppTheme.primaryBlue),
              title: const Text("Profil & Bildirim Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("İlan alarm kotası ve uygulama tercihleri", style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSettingsScreen(
                      isVip: _isUserVip,
                      onUpgradeVip: () => setState(() => _isUserVip = true),
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Çıkış Yap", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(ctx);
                await AuthService.signOut();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Oturum kapatıldı.")),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }


  static List<ChannelAlarm> get staticChannelsCatalog => AnnouncementsCatalog.staticCatalog;
  late final List<ChannelAlarm> _channels = List.from(staticChannelsCatalog);


  int get _activeCount => _channels.where((c) => c.isAlarmActive).length;

  // 🔓 Ücretsiz kullanıcıya gösterilecek 4 sabit ilan ID'si
  // Firebase'den ilk yüklemede seçilir, SharedPreferences'a kaydedilir → sonraki açılışlarda değişmez
  Set<String> _freeAnnouncementIds = {
    "saglik-01",
    "polis-01",
    "adalet-01",
    "jandarma-01",
  }; // Fallback: statik catalog ID'leri

  bool _freeIdsInitialized = false;

  /// Firebase verisi yüklendikten sonra 4 ücretsiz ilan ID'sini belirler.
  /// Önce is_free_preview:true olanları arar, yoksa ilk 4 Açık ilanı seçer.
  /// Seçilen ID'ler SharedPreferences'a kaydedilir ve bir daha değişmez.
  Future<void> _initFreeAnnouncementIds(List<ChannelAlarm> channels) async {
    if (_freeIdsInitialized) return;
    final prefs = await SharedPreferences.getInstance();

    // 1. Daha önce kaydedilmiş ID'ler var mı?
    final savedIds = prefs.getStringList("free_preview_ids");
    if (savedIds != null && savedIds.isNotEmpty) {
      if (mounted) {
        setState(() {
          _freeAnnouncementIds = savedIds.toSet();
          _freeIdsInitialized = true;
        });
      }
      return;
    }

    // 2. Firebase/kanallardan 4 adet Açık KAMU ilanı seç
    // Önce Açık olan Kamu ilanlarına bak, yetmezse genel Açık ilanlara, yetmezse mevcut kanallara bak
    var candidates = channels
        .where((c) => c.status == "Açık" && c.sectorType == "KAMU")
        .toList();
    if (candidates.length < 4) {
      candidates = channels.where((c) => c.status == "Açık").toList();
    }
    if (candidates.isEmpty) {
      candidates = List.from(channels);
    }

    final selected = candidates.take(4).map((c) => c.id).toList();

    if (selected.isNotEmpty) {
      await prefs.setStringList("free_preview_ids", selected);
      if (mounted) {
        setState(() {
          _freeAnnouncementIds = selected.toSet();
          _freeIdsInitialized = true;
        });
      }
    }
  }

  bool _isChannelLocked(ChannelAlarm ch) {
    if (_effectiveVip) return false;
    if (_unlockedWithAdsChannelIds.contains(ch.id)) return false;
    return !_freeAnnouncementIds.contains(ch.id);
  }


  int _selectedTabIndex = 0; // 0: İlanlar, 1: Sınav Takvimi, 2: Sonuç & Mülakat
  String _selectedSector = "Tümü"; // "Tümü", "Kamu", "Normal"
  String _selectedCategory = "Tümü";
  String _selectedKpss = "Tümü";
  String _selectedEducation = "Tümü";
  String _selectedStatus = "Tümü"; // "Tümü", "Açık", "Yakında", "Kapalı"

  static const List<String> kAllSectors = [
    "Tümü",
    "Kamu",
    "Normal",
  ];

  static const List<String> kAllStatuses = [
    "Tümü",
    "Açık",
    "Yakında",
    "Kapalı",
  ];

  static const List<String> kAllCategories = [
    "Tümü",
    "Askeri & Emniyet",
    "Bakanlıklar",
    "Belediyeler & Mahalli İdareler",
    "Üniversiteler & Akademik",
    "İŞKUR & Kamu İşçi",
    "KİT & Bankalar",
    "ÖSYM & Sınavlar",
  ];

  static const List<String> kAllKpssStatuses = [
    "Tümü",
    "KPSS'li",
    "KPSS'siz",
    "Muaf",
  ];

  static const List<String> kAllEducationLevels = [
    "Tümü",
    "Okuryazar",
    "Lise",
    "Ön Lisans",
    "Lisans",
  ];

  int get _ilanCount => _channels.where((c) => c.contentType == "ILAN").length;
  int get _sinavCount => _channels.where((c) => c.contentType == "SINAV").length;
  int get _sonucMulakatCount => _channels.where((c) => c.contentType == "MULAKAT" || c.contentType == "SONUC").length;

  int get _kamuCount => _channels.where((c) => c.sectorType == "KAMU").length;
  int get _normalCount => _channels.where((c) => c.sectorType == "OZEL" || c.sectorType == "NORMAL").length;

  int get _openCount => _channels.where((c) => c.status == "Açık").length;
  int get _upcomingCount => _channels.where((c) => c.status == "Yakında").length;
  int get _closedCount => _channels.where((c) => c.status == "Kapalı").length;

  List<ChannelAlarm> get _filteredChannels {
    final list = _channels.where((c) {
      if (_selectedTabIndex == 0 && c.contentType != "ILAN") return false;
      if (_selectedTabIndex == 1 && c.contentType != "SINAV") return false;
      if (_selectedTabIndex == 2 && c.contentType != "MULAKAT" && c.contentType != "SONUC") return false;
      if (_selectedSector == "Kamu" && c.sectorType != "KAMU") return false;
      if (_selectedSector == "Normal" && c.sectorType != "OZEL" && c.sectorType != "NORMAL") return false;
      if (_selectedCategory != "Tümü" && c.category != _selectedCategory) return false;
      if (_selectedKpss != "Tümü" && c.kpssStatus != _selectedKpss) return false;
      if (_selectedEducation != "Tümü" && c.educationLevel != _selectedEducation) return false;
      if (_selectedStatus != "Tümü" && c.status != _selectedStatus) return false;
      return true;
    }).toList();

    // 🔓 Ücretsiz kullanıcılar için açık olan 4 sabit ilan en başta gösterilsin
    if (!_effectiveVip) {
      list.sort((a, b) {
        final aFree = _freeAnnouncementIds.contains(a.id);
        final bFree = _freeAnnouncementIds.contains(b.id);
        if (aFree && !bFree) return -1;
        if (!aFree && bFree) return 1;
        return 0;
      });
    }

    return list;
  }

  Widget _buildMainTab(int index, String label, IconData icon, int count) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 15, color: isSelected ? Colors.white : Colors.white60),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectorTab(String sectorKey, String label) {
    final isSelected = _selectedSector == sectorKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSector = sectorKey;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusQuickChip(String statusKey, String label, Color activeColor) {
    final isSel = _selectedStatus == statusKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = statusKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSel ? activeColor.withValues(alpha: 0.25) : const Color(0xFF131E33),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSel ? activeColor : const Color(0xFF1E2D4A),
            width: isSel ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            color: isSel ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Filtreleme & Arama", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedSector = "Tümü";
                          _selectedCategory = "Tümü";
                          _selectedKpss = "Tümü";
                          _selectedEducation = "Tümü";
                          _selectedStatus = "Tümü";
                        });
                        setModalState(() {});
                      },
                      child: const Text("Sıfırla", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text("Sektör / Kurum Türü", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kAllSectors.map((sec) {
                    final sel = _selectedSector == sec;
                    return ChoiceChip(
                      label: Text(sec == "Tümü" ? "🌐 Tümü" : (sec == "Kamu" ? "🏛️ Kamu İlanları" : "🏢 Normal (Özel Sektör)")),
                      selected: sel,
                      onSelected: (v) {
                        setState(() => _selectedSector = sec);
                        setModalState(() {});
                      },
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text("Kategori", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kAllCategories.map((cat) {
                    final sel = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: sel,
                      onSelected: (v) {
                        setState(() => _selectedCategory = cat);
                        setModalState(() {});
                      },
                      selectedColor: AppTheme.primaryBlue,
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text("KPSS Durumu", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kAllKpssStatuses.map((k) {
                    final sel = _selectedKpss == k;
                    return ChoiceChip(
                      label: Text(k),
                      selected: sel,
                      onSelected: (v) {
                        setState(() => _selectedKpss = k);
                        setModalState(() {});
                      },
                      selectedColor: const Color(0xFFF59E0B),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(color: sel ? const Color(0xFF0F172A) : Colors.white70, fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text("Öğrenim Seviyesi", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kAllEducationLevels.map((e) {
                    final sel = _selectedEducation == e;
                    return ChoiceChip(
                      label: Text(e),
                      selected: sel,
                      onSelected: (v) {
                        setState(() => _selectedEducation = e);
                        setModalState(() {});
                      },
                      selectedColor: const Color(0xFF10B981),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text("Başvuru Durumu (Tarihe Göre)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kAllStatuses.map((s) {
                    final sel = _selectedStatus == s;
                    Color chipColor = const Color(0xFF22C55E);
                    if (s == "Yakında") chipColor = const Color(0xFF3B82F6);
                    if (s == "Kapalı") chipColor = const Color(0xFF64748B);
                    if (s == "Tümü") chipColor = AppTheme.primaryBlue;

                    return ChoiceChip(
                      label: Text(s == "Kapalı" ? "Bitenler (Kapalı)" : (s == "Yakında" ? "Yakında Başlayacaklar" : (s == "Açık" ? "Açık İlanlar" : "Tümü"))),
                      selected: sel,
                      onSelected: (v) {
                        setState(() => _selectedStatus = s);
                        setModalState(() {});
                      },
                      selectedColor: chipColor,
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text("Filtreleri Uygula (${_filteredChannels.length} İlan)", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 👑 VIP & PREMIUM İLAN KİLİDİ POP-UP'I (3 PAKETLİ + 2 REKLAM İZLEYEREK AÇ SEÇENEĞİ)
  void _showPremiumUpgradePopUp({ChannelAlarm? targetChannel}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.workspace_premium, color: Color(0xFF0F172A), size: 32),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.shade300)),
              child: const Text("👑 VIP ÖZEL İLAN & SINAV KİLİDİ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF78350F))),
            ),
            const SizedBox(height: 8),
            Text(
              targetChannel != null ? "${targetChannel.organization} İlan Kilidini Açın" : "Tüm İlanların Kilidini Açın",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              targetChannel != null
                  ? "Bu ilanı 2 kısa reklam izleyerek hemen açabilir veya VIP Aile Planı ile sınırsız erişebilirsiniz."
                  : "İlk 4 ilan ücretsizdir. VIP Aile Planı ile tüm ilanlar, anlık alarmlar ve özel web sitesi nöbetçisine sınırsız erişin.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 18),

            // Seçenek A: 2 Reklam İzleyerek Bu İlanın Kilidini Aç (Ücretsiz alternatif)
            if (targetChannel != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                  label: const Text(
                    "🎬 2 Reklam İzle (Bu İlanı Aç)",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _unlockWithTwoAds(targetChannel);
                  },
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("VEYA SINIRSIZ VIP ALIN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // 1. Paket: Yıllık VIP (En Popüler)
            InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Google Play Store güvenli satın alma penceresi açılıyor...")),
                );
                final success = await InAppPurchaseService.instance.buyProduct(InAppPurchaseService.yearlyVipId);
                if (!success) {
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => FamilySubscriptionScreen(
                          isVip: _effectiveVip,
                          onPlanPurchased: () {
                            setState(() => _isUserVip = true);
                            widget.onUpgradeVip?.call();
                          },
                        ),
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber, width: 2),
                  boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
                          child: const Text("👑 EN POPÜLER • %37 TASARRUF", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        ),
                        const Text("299.99 ₺ / yıl", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text("Yıllık VIP (2 Kişilik Aile Planı)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    const Text("1 Yıl boyunca tüm ilanlar açık, özel web sitesi nöbetçisi ve 1 arkadaş slotu.", style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 2. Paket: Aylık VIP
            InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Google Play Store güvenli satın alma penceresi açılıyor...")),
                );
                final success = await InAppPurchaseService.instance.buyProduct(InAppPurchaseService.monthlyVipId);
                if (!success) {
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => FamilySubscriptionScreen(
                          isVip: _effectiveVip,
                          onPlanPurchased: () {
                            setState(() => _isUserVip = true);
                            widget.onUpgradeVip?.call();
                          },
                        ),
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Aylık VIP Aile Paketi (2 Kişi)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text("Tüm kilitler açık, özel web nöbetçisi, 1 arkadaş dahil.", style: TextStyle(fontSize: 10, color: Colors.black54)),
                      ],
                    ),
                    Text("39.99 ₺ / ay", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF0F172A))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            TextButton.icon(
              icon: const Icon(Icons.vpn_key, size: 14, color: Color(0xFF2563EB)),
              label: const Text("Promosyon / Aile Kodunuz mu Var? Kod Girin", style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => FamilySubscriptionScreen(
                      isVip: _effectiveVip,
                      onPlanPurchased: () {
                        setState(() => _isUserVip = true);
                        widget.onUpgradeVip?.call();
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),

            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Şimdilik Kapat", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎬 2 Reklam İzleyerek İlan Kilidini Açma Motoru
  void _unlockWithTwoAds(ChannelAlarm channel) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🎬 1. Reklam yükleniyor (1/2)... Lütfen sonuna kadar izleyin."),
        duration: Duration(seconds: 3),
      ),
    );

    AdService.instance.showRewardedAd(
      onRewardEarned: () {
        // 1. Reklam tamamlandı, kullanıcıya bilgi ver ve 2. reklamı aç
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: const Color(0xFF131E33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 24),
                SizedBox(width: 8),
                Text("1. Reklam Tamamlandı (1/2)", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              "İlanın kilidini açmak için lütfen 2. kısa reklamı da izleyin.",
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
            ),
            actions: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.play_circle_fill, size: 16),
                label: const Text("2. Reklamı İzle (Kilidi Aç)"),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  AdService.instance.showRewardedAd(
                    onRewardEarned: () async {
                      if (!mounted) return;
                      // Her 2 reklam da izlendi! İlanı yerel olarak aç
                      final prefs = await SharedPreferences.getInstance();
                      final currentList = prefs.getStringList("unlocked_with_ads_ids") ?? [];
                      if (!currentList.contains(channel.id)) {
                        currentList.add(channel.id);
                        await prefs.setStringList("unlocked_with_ads_ids", currentList);
                      }
                      setState(() {
                        _unlockedWithAdsChannelIds.add(channel.id);
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF22C55E),
                          content: Text("🎉 Tebrikler! '${channel.organization}' ilanı kilidi açıldı."),
                        ),
                      );

                      // Kilidi açılan ilanın detay sayfasını hemen aç
                      AnnouncementDetailSheet.show(
                        context,
                        AnnouncementDetailData(
                          id: channel.id,
                          organization: channel.organization,
                          title: channel.title,
                          position: channel.position,
                          city: channel.city,
                          date: channel.date,
                          quota: channel.quota,
                          applicationPlace: channel.applicationPlace,
                          employmentType: channel.employmentType,
                          applicationType: channel.applicationType,
                          requirements: channel.requirements,
                          officialUrl: channel.officialUrl,
                          status: channel.status,
                          logoIcon: channel.logoIcon,
                          category: channel.category,
                          contentType: channel.contentType,
                          educationLevel: channel.educationLevel,
                          kpssStatus: channel.kpssStatus,
                          examDate: channel.examDate,
                        ),
                        isVip: true, // Reklamla açıldığı için VIP gibi göster
                      );
                    },
                    onFailure: (err) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text(err)),
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
      onFailure: (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text(err)),
          );
        }
      },
    );
  }

  // KALAN 1 HAK POP-UP UYARISI
  void _showLowQuotaAlert() {
    if (_effectiveVip) return;
    if (_remainingNotifications != 1) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131E33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Son 1 Bildirim Hakkı!",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ücretsiz bildirim kotanızdan yalnızca 1 hakkınız kaldı. Yeni kamu ve KPSS ilanlarını anında yakalamak için:",
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              "• 🎬 Kısa bir reklam izleyerek anında +2 ek hak kazanabilirsiniz.\n• 👑 VIP Aile Planı'na geçerek 2 kişi sınırsız ve anlık bildirim alabilirsiniz.",
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Kapat", style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF38BDF8),
              side: const BorderSide(color: Color(0xFF38BDF8)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.play_circle_fill, size: 16),
            label: const Text("Reklam İzle (+2 Hak)"),
            onPressed: () {
              Navigator.pop(ctx);
              AdService.instance.showRewardedAd(
                onStarted: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("🎬 Sponsorlu reklam yükleniyor ve oynatılıyor...")),
                  );
                },
                onRewardEarned: () async {
                  if (mounted) {
                    final newBonus = _bonusNotifications + 2;
                    await CacheService.saveBonusNotifications(newBonus);
                    setState(() {
                      _bonusNotifications = newBonus;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green.shade700,
                        content: Text("🎉 Video tamamlandı! +2 Bildirim Alma Hakkı tanımlandı (Kalan: $_remainingNotifications)."),
                      ),
                    );
                  }
                },
                onFailure: (err) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppTheme.urgentRed, content: Text(err)),
                  );
                },
              );
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.stars, size: 16),
            label: const Text("VIP Yükselt", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FamilySubscriptionScreen(isVip: _effectiveVip),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // AYLIK BİLDİRİM KOTASI POP-UP'I (REKLAMLA YÜKSELEN BÖLÜM)
  void _showNotificationQuotaPopUp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active, color: Colors.amber, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              _isUserVip ? "Sınırsız Bildirim (VIP)" : "Aylık Bildirim Kotası (Kalan: $_remainingNotifications / $_totalAllowedNotifications)",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _isUserVip
                  ? "VIP üyeliğiniz sayesinde tüm kamu alımı ve sınav bildirimleri telefonunuza sınırsız olarak iletilir."
                  : "Ücretsiz hesaplarda ayda 10 adet anlık bildirim alma hakkınız vardır. Reklam izleyerek anında +2 ek bildirim hakkı kazanabilirsiniz!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
              child: const Column(
                children: [
                  Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.green), SizedBox(width: 8), Text("Sınırsız kamu ve KPSS duyuru bildirimi", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))]),
                  SizedBox(height: 6),
                  Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.green), SizedBox(width: 8), Text("Özel web sayfası izleme (URL Watcher)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))]),
                  SizedBox(height: 6),
                  Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.green), SizedBox(width: 8), Text("1 Öde, 2 Kişi Kullan (1 Arkadaşını Ücretsiz Ekle)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Seçenek 1: Sınırsız VIP Satın Al
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FamilySubscriptionScreen(isVip: _effectiveVip),
                    ),
                  );
                },
                child: const Text("39.99 ₺ ile Sınırsız VIP Yap (+1 Arkadaş)", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 8),
            // Seçenek 2: AdMob Ödüllü Reklam ile +2 Bildirim Hakkı Kazan
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A8A),
                  side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.play_circle_fill, color: Colors.blueAccent, size: 20),
                label: const Text(
                  "🎬 Kısa Reklam İzle (+2 Bildirim Hakkı Kazan)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
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
                      if (mounted) {
                        final newBonus = _bonusNotifications + 2;
                        await CacheService.saveBonusNotifications(newBonus);
                        setState(() {
                          _bonusNotifications = newBonus;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.green.shade700,
                            content: Text("🎉 Video tamamlandı! +2 Bildirim Alma Hakkı tanımlandı (Yeni Limit: $_totalAllowedNotifications bildirim)."),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleChannelAlarm(ChannelAlarm channel) {
    setState(() {
      channel.isAlarmActive = !channel.isAlarmActive;
    });

    final activeAlarms = _channels.where((c) => c.isAlarmActive).map((c) => c.id).toList();
    CacheService.saveActiveAlarms(activeAlarms);
    FirebaseSyncService.syncAlarms(activeAlarms);

    if (channel.isAlarmActive) {
      NotificationService.subscribeToChannel("topic_${channel.id}");
    } else {
      NotificationService.unsubscribeFromChannel("topic_${channel.id}");
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(channel.isAlarmActive
            ? "🔔 ${channel.title} radara eklendi! Firebase ve telefona kaydedildi."
            : "${channel.title} takibi kapatıldı."),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF091122),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.radar, color: AppTheme.primaryBlue, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            const Text("KamuRadar", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            if (_isOfflineMode)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.cloud_off, size: 15, color: Colors.amber),
              ),
            if (_isLoadingLive)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
        actions: [
          StreamBuilder<User?>(
            stream: AuthService.authStateChanges,
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user != null) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () => _showUserMenu(user),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                      child: user.photoURL == null
                          ? Text(user.displayName?.substring(0, 1).toUpperCase() ?? "U",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue))
                          : null,
                    ),
                  ),
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.account_circle_outlined, color: AppTheme.primaryBlue),
                  tooltip: "Google ile Giriş Yap",
                  onPressed: _loginWithGoogle,
                );
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ActionChip(
              avatar: Icon(Icons.notifications_active, size: 13, color: _isUserVip ? Colors.amber.shade900 : AppTheme.primaryBlue),
              label: Text(
                _isUserVip ? "VIP Sınırsız Bildirim" : "$_remainingNotifications Bildirim Hakkı",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isUserVip ? Colors.amber.shade900 : Colors.grey.shade800),
              ),
              backgroundColor: _isUserVip ? Colors.amber.shade100 : Colors.grey.shade200,
              onPressed: _showNotificationQuotaPopUp,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppTheme.primaryBlue, size: 20),
            tooltip: "Profil & Ayarlar",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileSettingsScreen(
                    isVip: _isUserVip,
                    onUpgradeVip: () => setState(() => _isUserVip = true),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],

      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Canlı Sayaç & Bilgi Şeridi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF0F172A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Gündüz Periyodik Tarama (10:00 - 22:00):", style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    _isUserVip ? "VIP Sınırsız Bildirim (2 Saatte Bir)" : "Kalan Bildirim: $_remainingNotifications / $_totalAllowedNotifications Hak",
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Bilgi Kutusu
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF131E33),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E2D4A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.notifications_active, color: AppTheme.primaryBlue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "İlan okumakla vakit kaybetmeyin. İlgilendiğiniz alımların zilini açık bırakın; yeni ilan açıldığında gündüz periyotlarında (10:00, 12:00, 14:00, 16:00, 18:00, 20:00, 22:00) telefonunuza anında bildirim gelsin!",
                        style: TextStyle(fontSize: 11, color: Color(0xFF93C5FD), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sektör Seçici: Kamu İlanları / Normal (Özel Sektör) / Tümü
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E2D4A)),
                ),
                child: Row(
                  children: [
                    _buildSectorTab("Tümü", "🌐 Tümü (${_channels.length})"),
                    _buildSectorTab("Kamu", "🏛️ Kamu ($_kamuCount)"),
                    _buildSectorTab("Normal", "🏢 Normal ($_normalCount)"),
                  ],
                ),
              ),
            ),

            // 3 Ana Sekme (İlanlar, Sınav Takvimi, Sonuç & Mülakat)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF131E33),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2D4A)),
                ),
                child: Row(
                  children: [
                    _buildMainTab(0, "İlanlar", Icons.campaign_rounded, _ilanCount),
                    _buildMainTab(1, "Sınav Takvimi", Icons.event_note_rounded, _sinavCount),
                    _buildMainTab(2, "Sonuç & Mülakat", Icons.fact_check_rounded, _sonucMulakatCount),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Kategori Çipleri (Yatay Kaydırılabilir) + Filtre Butonu
            SizedBox(
              height: 38,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: _showFilterModal,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (_selectedKpss != "Tümü" || _selectedEducation != "Tümü")
                            ? Colors.amber.withValues(alpha: 0.25)
                            : const Color(0xFF131E33),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (_selectedKpss != "Tümü" || _selectedEducation != "Tümü")
                              ? Colors.amber
                              : const Color(0xFF1E2D4A),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune,
                            size: 14,
                            color: (_selectedKpss != "Tümü" || _selectedEducation != "Tümü")
                                ? Colors.amber
                                : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Filtre",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: (_selectedKpss != "Tümü" || _selectedEducation != "Tümü")
                                  ? Colors.amber
                                  : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 16),
                      itemCount: kAllCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, idx) {
                        final cat = kAllCategories[idx];
                        final isSel = _selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSel,
                          onSelected: (val) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          },
                          selectedColor: AppTheme.primaryBlue,
                          backgroundColor: const Color(0xFF131E33),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : Colors.white70,
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSel ? AppTheme.primaryBlue : const Color(0xFF1E2D4A),
                            ),
                          ),
                          showCheckmark: false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Başvuru Durumuna Göre Hızlı Filtre Butonları (Açık, Yakında, Bitenler)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusQuickChip("Tümü", "Tümü (${_channels.length})", AppTheme.primaryBlue),
                    const SizedBox(width: 6),
                    _buildStatusQuickChip("Açık", "🟢 Açık ($_openCount)", const Color(0xFF22C55E)),
                    const SizedBox(width: 6),
                    _buildStatusQuickChip("Yakında", "🔵 Yakında ($_upcomingCount)", const Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    _buildStatusQuickChip("Kapalı", "⚪ Bitenler ($_closedCount)", const Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Liste Başlığı ve Sayaç
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedTabIndex == 0
                        ? "Aktif Alım İlanları (${_filteredChannels.length})"
                        : _selectedTabIndex == 1
                            ? "Sınav & Başvuru Takvimi (${_filteredChannels.length})"
                            : "Sonuçlar & Mülakatlar (${_filteredChannels.length})",
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    "$_activeCount Alarm Açık",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Paywall Hatırlatma Şeridi (İlk 4 ilan ücretsiz)
            if (!_effectiveVip && _filteredChannels.length > 4)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "👑 İlk 4 İlan Ücretsizdir",
                              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              "Kalan ${_filteredChannels.length - 4} ilanın detayları için VIP'e geçin.",
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: _showPremiumUpgradePopUp,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            "VIP'e Geç",
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // İlan Listesi (Filtrelenmiş & İlk 4 açık, 5+ kilitli)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredChannels.length,
              itemBuilder: (context, index) {
                final ch = _filteredChannels[index];
                final isLocked = _isChannelLocked(ch);

                final cardBody = InkWell(
                  onTap: () {
                    AnnouncementDetailSheet.show(
                      context,
                      AnnouncementDetailData(
                        id: ch.id,
                        organization: ch.organization,
                        title: ch.title,
                        position: ch.position,
                        city: ch.city,
                        date: ch.date,
                        quota: ch.quota,
                        applicationPlace: ch.applicationPlace,
                        employmentType: ch.employmentType,
                        applicationType: ch.applicationType,
                        requirements: ch.requirements,
                        officialUrl: ch.officialUrl,
                        status: ch.status,
                        logoIcon: ch.logoIcon,
                        category: ch.category,
                        contentType: ch.contentType,
                        educationLevel: ch.educationLevel,
                        kpssStatus: ch.kpssStatus,
                        examDate: ch.examDate,
                      ),
                      isVip: _effectiveVip,
                    );
                  },
                  onLongPress: isLocked ? null : () => _shareOnWhatsApp(ch),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131E33),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ch.isAlarmActive ? const Color(0xFF22C55E).withValues(alpha: 0.6) : const Color(0xFF1E2D4A),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Beyaz dairesel logo kapsülü
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            ch.logoIcon,
                            color: const Color(0xFFDC2626),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Kurum, Pozisyon ve Lokasyon/Tarih Bilgisi
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      ch.organization,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      ch.educationLevel,
                                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ch.position,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 11, color: Colors.white54),
                                  const SizedBox(width: 2),
                                  Text(
                                    ch.city,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.access_time, size: 11, color: Colors.white54),
                                  const SizedBox(width: 2),
                                  Text(
                                    ch.date,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    ch.kpssStatus,
                                    style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Bildirim Açma Butonu
                        InkWell(
                          onTap: isLocked ? null : () => _toggleChannelAlarm(ch),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: ch.isAlarmActive ? const Color(0xFF22C55E).withValues(alpha: 0.2) : const Color(0xFF1E2F4D),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: ch.isAlarmActive ? const Color(0xFF22C55E) : const Color(0xFFF59E0B).withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ch.isAlarmActive ? Icons.notifications_active : Icons.notifications_none,
                                  color: ch.isAlarmActive ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ch.isAlarmActive ? "Açık" : "Bildirim",
                                  style: TextStyle(
                                    color: ch.isAlarmActive ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Durum rozeti (Açık, Yakında, Sonuç, Kapalı)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: ch.statusColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ch.status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right, color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                );

                if (!isLocked) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: cardBody,
                  );
                }

                // 👑 VIP Kilitli Kart (Taşma yapmayan, şık ve kompakt yatay tasarım)
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // Buzlu arka plan
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                          child: cardBody,
                        ),
                        // Şık, taşmayan VIP Kilit Kaplaması
                        Positioned.fill(
                          child: Material(
                            color: const Color(0xFF091122).withValues(alpha: 0.85),
                            child: InkWell(
                              onTap: () {
                                _showPremiumUpgradePopUp(targetChannel: ch);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                      ),
                                      child: const Icon(Icons.lock_rounded, color: Colors.amber, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Text(
                                                "🔒 VIP Kilitli İlan",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              SizedBox(width: 5),
                                              Text("👑", style: TextStyle(fontSize: 11)),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${ch.organization} • ${ch.category}",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.amber,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Colors.amber, Colors.orangeAccent],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber.withValues(alpha: 0.35),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.workspace_premium, color: Color(0xFF0F172A), size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            "Kilidi Aç",
                                            style: TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}