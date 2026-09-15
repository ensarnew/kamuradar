import 'dart:ui';
import 'package:flutter/material.dart';
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
    this.contentType = "ILAN",
    this.category = "Bakanlıklar",
    this.educationLevel = "Lisans",
    this.kpssStatus = "KPSS'li",
    this.examDate,
  }) : position = position ?? title;
}

class HomeFeedScreen extends StatefulWidget {
  final bool isVip;
  final VoidCallback? onUpgradeVip;

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
  final int _baseNotificationLimit = 3;
  int _bonusNotifications = 0;
  int _usedNotifications = 1;
  bool _isLoadingLive = false;
  bool _isOfflineMode = false;

  int get _totalAllowedNotifications => _baseNotificationLimit + _bonusNotifications;
  int get _remainingNotifications => (_totalAllowedNotifications - _usedNotifications).clamp(0, _totalAllowedNotifications);

  @override
  void initState() {
    super.initState();
    _loadCachedAlarms();
    _syncWithLiveServer();

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

  Future<void> _loadCachedAlarms() async {
    try {
      final activeIds = await CacheService.getActiveAlarms();
      final bonus = await CacheService.getBonusNotifications();
      final used = await CacheService.getUsedNotifications();
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


    final List<ChannelAlarm> _channels = [
    ChannelAlarm(
      id: "saglik-01",
      organization: "Sağlık Bakanlığı",
      title: "36.000 Sözleşmeli Sağlık Personeli ve İşçi Alımı",
      position: "36.000 Sözleşmeli Sağlık Personeli",
      city: "Tüm Türkiye",
      date: "08.09.2026",
      quota: "36.000",
      deadline: "25.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["T.C. vatandaşı olmak", "KPSS ilgili puan türünden en az 65 almak", "Görevini yapmaya engel sağlık sorunu olmamak"],
      description: "Hemşire, ebe, sağlık teknikeri, büro personeli ve güvenlik alımları ÖSYM ve İŞKUR üzerinden alınıyor.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.local_hospital,
      isAlarmActive: true,
    ),
    ChannelAlarm(
      id: "polis-01",
      organization: "Polis Akademisi",
      title: "32. Dönem POMEM 10.000 Polis Memuru Alımı",
      position: "32. Dönem POMEM 10.000",
      city: "Tüm Türkiye",
      date: "05.09.2026",
      quota: "10.000",
      deadline: "22.09.2026",
      applicationPlace: "Polis Akademisi",
      employmentType: "Emniyet Hizmetleri",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "15.10.2026",
      requirements: const ["Lisans P3 en az 60, Önlisans P93 en az 65 puan", "30 yaşından gün almamış olmak", "Fiziki parkurda başarılı olmak"],
      description: "Lisans ve önlisans mezunu adaylar için 32. Dönem POMEM fiziki yeterlilik ve başvuru takvimi başladı.",
      officialUrl: "https://pa.edu.tr",
      logoIcon: Icons.local_police,
      isAlarmActive: true,
    ),
    ChannelAlarm(
      id: "adalet-01",
      organization: "Adalet Bakanlığı",
      title: "12.500 Zabıt Katibi, Mübaşir ve İnfaz Koruma Memuru (İKM)",
      position: "12.500 Zabıt Katibi & İKM",
      city: "Tüm Türkiye",
      date: "10.09.2026",
      quota: "12.500",
      deadline: "28.09.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Adalet Hizmetleri",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "MULAKAT",
      category: "Bakanlıklar",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      examDate: "20.10.2026",
      requirements: const ["KPSS 70 taban puan", "Zabıt katipliği için 3 dakikada 90 doğru kelime", "Güvenlik soruşturmasından geçmek"],
      description: "Adliyeler ve CTE cezaevleri için KPSS 70 taban puanla personel alım mülakat takvimi açıklandı.",
      officialUrl: "https://pgm.adalet.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: true,
    ),
    ChannelAlarm(
      id: "jandarma-01",
      organization: "Jandarma Genel Komutanlığı",
      title: "6.500 Sözleşmeli Uzman Erbaş ve Jandarma Asayiş Alımı",
      position: "6.500 Uzman Erbaş",
      city: "Tüm Türkiye",
      date: "07.09.2026",
      quota: "6.500",
      deadline: "24.09.2026",
      applicationPlace: "Jandarma PTS",
      employmentType: "Sözleşmeli Erbaş",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "Lise",
      kpssStatus: "KPSS'li",
      examDate: "12.11.2026",
      requirements: const ["En az lise mezunu olmak", "27 yaşını bitirmemiş olmak", "En az 167 cm boyunda olmak"],
      description: "Komando, asayiş ve lojistik branşlarında görev alacak sözleşmeli uzman erbaş temin süreci.",
      officialUrl: "https://vatandas.jandarma.gov.tr",
      logoIcon: Icons.security,
      isAlarmActive: true,
    ),
    ChannelAlarm(
      id: "egm-bekci",
      organization: "Emniyet Genel Müdürlüğü",
      title: "Çarşı ve Mahalle Bekçiliği 3.200 Kontenjan Başvurusu",
      position: "Çarşı ve Mahalle Bekçisi",
      city: "81 İl Geneli",
      date: "05.09.2026",
      quota: "3.200",
      deadline: "22.09.2026",
      applicationPlace: "Polis Akademisi",
      employmentType: "Emniyet Hizmetleri",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      examDate: "05.10.2026",
      requirements: const ["En az lise mezunu olmak", "Askerlik hizmetini tamamlamış olmak", "En az 167 cm boyunda olmak"],
      description: "81 il valiliği emrinde istihdam edilmek üzere lise mezunu bekçi alımı.",
      officialUrl: "https://pa.edu.tr",
      logoIcon: Icons.local_police,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "msb-subay",
      organization: "Milli Savunma Bakanlığı",
      title: "2026 Yılı Dış Kaynaktan Muvazzaf Subay Temini",
      position: "Muvazzaf Subay (Teğmen)",
      city: "Ankara / MSB",
      date: "02.09.2026",
      quota: "1.850",
      deadline: "20.09.2026",
      applicationPlace: "MSB Personel Temin",
      employmentType: "Subay Kadrosu",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "18.10.2026",
      requirements: const ["4 yıllık lisans mezunu olmak", "KPSS P3 en az 60 puan", "27 yaşını doldurmamış olmak"],
      description: "Kara, Deniz ve Hava Kuvvetleri Komutanlıklarına lisans mezunu subay alımı.",
      officialUrl: "https://personeltemin.msb.gov.tr",
      logoIcon: Icons.military_tech,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "msb-astsubay",
      organization: "Milli Savunma Bakanlığı",
      title: "2026 Yılı Dış Kaynaktan Muvazzaf Astsubay Temini",
      position: "Muvazzaf Astsubay (Astsb. Çvş.)",
      city: "Ankara / MSB",
      date: "03.09.2026",
      quota: "2.400",
      deadline: "21.09.2026",
      applicationPlace: "MSB Personel Temin",
      employmentType: "Astsubay Kadrosu",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      examDate: "25.10.2026",
      requirements: const ["Önlisans KPSS P93 en az 60 puan", "25 yaşını doldurmamış olmak", "Fiziki değerlendirmeden geçmek"],
      description: "Kuvvet komutanlıklarına önlisans ve lisans mezunları arasından astsubay alımı.",
      officialUrl: "https://personeltemin.msb.gov.tr",
      logoIcon: Icons.military_tech,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "sahil-guvenlik",
      organization: "Sahil Güvenlik Komutanlığı",
      title: "Sahil Güvenlik 600 Uzman Erbaş Alımı",
      position: "Uzman Erbaş (Muhafız/Serdümen)",
      city: "Kıyı İlleri",
      date: "01.09.2026",
      quota: "600",
      deadline: "18.09.2026",
      applicationPlace: "SGK Başvuru Portalı",
      employmentType: "Sözleşmeli Erbaş",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      examDate: "10.10.2026",
      requirements: const ["Askerliğini yapmış veya yapıyor olmak", "Yüzme bilmek", "27 yaşını bitirmemiş olmak"],
      description: "Marmara, Ege, Akdeniz ve Karadeniz bot komutanlıklarına erbaş alımı.",
      officialUrl: "https://sg.gov.tr",
      logoIcon: Icons.directions_boat,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "deniz-kuvvetleri",
      organization: "Deniz Kuvvetleri Komutanlığı",
      title: "Denizaltı ve Gemiadamı Sözleşmeli Er Alımı",
      position: "Sözleşmeli Er",
      city: "Gölcük / Aksaz / Foça",
      date: "04.09.2026",
      quota: "1.200",
      deadline: "30.09.2026",
      applicationPlace: "MSB Personel Temin",
      employmentType: "Sözleşmeli Er",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "İlköğretim",
      kpssStatus: "KPSS'siz",
      requirements: const ["En az ilköğretim mezunu", "20-25 yaş aralığında olmak", "Sağlık raporu almak"],
      description: "Deniz Kuvvetleri gemilerinde güverte, makine ve ikmal branşlarında er alımı.",
      officialUrl: "https://personeltemin.msb.gov.tr",
      logoIcon: Icons.anchor,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "hava-kuvvetleri",
      organization: "Hava Kuvvetleri Komutanlığı",
      title: "Hava Savunma ve Uçak Bakım Astsubay Alımı",
      position: "Hava Astsubay",
      city: "Eskişehir / İzmir",
      date: "06.09.2026",
      quota: "750",
      deadline: "24.09.2026",
      applicationPlace: "MSB Personel Temin",
      employmentType: "Astsubay",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      examDate: "08.11.2026",
      requirements: const ["İlgili MYO teknik bölümlerinden mezun", "KPSS P93 en az 65", "Renk körlüğü bulunmamak"],
      description: "Uçak gövde motor, aviyonik ve radar sistemleri bakım branşlarına alım.",
      officialUrl: "https://personeltemin.msb.gov.tr",
      logoIcon: Icons.airplanemode_active,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "kara-kuvvetleri-er",
      organization: "Kara Kuvvetleri Komutanlığı",
      title: "15.000 Sözleşmeli Erbaş ve Er Temini",
      position: "Sözleşmeli Er",
      city: "Tüm Birlikler",
      date: "11.09.2026",
      quota: "15.000",
      deadline: "10.10.2026",
      applicationPlace: "MSB Personel Temin",
      employmentType: "Sözleşmeli Er",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "İlköğretim",
      kpssStatus: "KPSS'siz",
      requirements: const ["En az ilköğretim mezunu", "20 yaşından gün almış olmak", "Adli sicil kaydı temiz olmak"],
      description: "Hudut, komando ve piyade birlikleri için 15 bin sözleşmeli er alımı.",
      officialUrl: "https://personeltemin.msb.gov.tr",
      logoIcon: Icons.security,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "paem-komiser",
      organization: "Polis Akademisi (PAEM)",
      title: "8. Dönem PAEM 1.000 İlk Derece Amirlik (Komiser Yrd.) Sınavı",
      position: "Komiser Yardımcısı Adayı",
      city: "Ankara",
      date: "12.09.2026",
      quota: "1.000",
      deadline: "01.10.2026",
      applicationPlace: "Polis Akademisi",
      employmentType: "Emniyet Amiri Kadrosu",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "Askeri & Emniyet",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "22.11.2026",
      requirements: const ["KPSS P3 en az 75 puan", "28 yaşını tamamlamamış olmak", "Silah taşımaya engel hali olmamak"],
      description: "Lisans mezunları arasından emniyet teşkilatına komiser yardımcısı yetiştirme sınavı.",
      officialUrl: "https://pa.edu.tr",
      logoIcon: Icons.local_police,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "pmyo-polis-okulu",
      organization: "Polis Akademisi (PMYO)",
      title: "2026 PMYO 2.500 Polis Memuru Alımı (YKS Puanı ile)",
      position: "Polis Meslek Yüksekokulu Öğrencisi",
      city: "Tüm Türkiye",
      date: "14.09.2026",
      quota: "2.500",
      deadline: "05.10.2026",
      applicationPlace: "Polis Akademisi",
      employmentType: "Öğrenci / Memur Adayı",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "Askeri & Emniyet",
      educationLevel: "Lise",
      kpssStatus: "Muaf",
      examDate: "15.11.2026",
      requirements: const ["Lise veya dengi okul mezunu", "TYT ham puan en az 250", "18-26 yaş aralığında olmak"],
      description: "YKS TYT ham puan türünden en az 250 puan alan lise mezunu adaylar için alım.",
      officialUrl: "https://pa.edu.tr",
      logoIcon: Icons.school,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "jandarma-astsubay-jamyo",
      organization: "Jandarma ve Sahil Güvenlik Akademisi",
      title: "2026 JSGA Muvazzaf Astsubay ve Subay Alımı",
      position: "JSGA Astsubay / Subay",
      city: "Beytepe / Ankara",
      date: "09.09.2026",
      quota: "1.600",
      deadline: "29.09.2026",
      applicationPlace: "JSGA Portalı",
      employmentType: "Subay/Astsubay",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      examDate: "28.10.2026",
      requirements: const ["KPSS ilgili puan türünden en az 65", "Fiziki yeterlilik testi", "Mülakatta başarılı olmak"],
      description: "Jandarma ve Sahil Güvenlik bünyesinde görev alacak muvazzaf subay ve astsubay temini.",
      officialUrl: "https://jsga.edu.tr",
      logoIcon: Icons.shield,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "egm-kriminal",
      organization: "Emniyet Genel Müdürlüğü Kriminal Daire",
      title: "Kriminal Daire Başkanlığı 150 Uzman Kimyager ve Biyolog Alımı",
      position: "Kriminal Uzmanı",
      city: "Ankara / İstanbul / İzmir",
      date: "13.09.2026",
      quota: "150",
      deadline: "02.10.2026",
      applicationPlace: "e-Devlet",
      employmentType: "Teknik Hizmetler",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Kimya, Biyoloji, Adli Bilişim mezunu", "KPSS P3 en az 70", "Laboratuvar yetkinliği"],
      description: "Adli bilişim, kimyasal ve balistik inceleme laboratuvarlarına lisans mezunu uzman temini.",
      officialUrl: "https://egm.gov.tr",
      logoIcon: Icons.biotech,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "mulakat-pomem-31",
      organization: "Polis Akademisi",
      title: "31. Dönem POMEM Fiziki Parkur ve Sözlü Mülakat Tarihleri",
      position: "Mülakat Çağrısı",
      city: "Bölge Merkezleri",
      date: "15.09.2026",
      quota: "7.500",
      deadline: "30.09.2026",
      applicationPlace: "Polis Akademisi",
      employmentType: "Mülakat Duyurusu",
      applicationType: "Online Sorgulama",
      status: "Açık",
      contentType: "MULAKAT",
      category: "Askeri & Emniyet",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "10.10.2026",
      requirements: const ["Sınav giriş belgesi", "Sağlık bilgi formu", "Kimlik belgesi"],
      description: "Adayların sınav giriş belgeleri ve parkur salon randevuları ilan edilmiştir.",
      officialUrl: "https://pa.edu.tr",
      logoIcon: Icons.sports_soccer,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "sonuc-jandarma-uzman",
      organization: "Jandarma Genel Komutanlığı",
      title: "2026-1 Sözleşmeli Uzman Erbaş Yerleştirme Sonuçları",
      position: "Sonuç Açıklaması",
      city: "Tüm Türkiye",
      date: "14.09.2026",
      quota: "4.000",
      deadline: "14.09.2026",
      applicationPlace: "Jandarma PTS",
      employmentType: "Sonuç Duyurusu",
      applicationType: "Sonuç Ekranı",
      status: "Sonuç",
      contentType: "SONUC",
      category: "Askeri & Emniyet",
      educationLevel: "Lise",
      kpssStatus: "KPSS'li",
      requirements: const ["T.C. kimlik numarası ile e-Devlet girişi"],
      description: "Sözlü mülakat ve fiziki parkur sonrası asil ve yedek liste e-Devlet kapısında açıklandı.",
      officialUrl: "https://vatandas.jandarma.gov.tr",
      logoIcon: Icons.verified,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "msb-iscialimi",
      organization: "Milli Savunma Bakanlığı",
      title: "Askeri Tersane ve Fabrikalara 2.800 Sürekli İşçi Alımı",
      position: "Tersane İşçisi (Kaynakçı, Torna, Elektrik)",
      city: "İstanbul / Kocaeli / İzmir",
      date: "10.09.2026",
      quota: "2.800",
      deadline: "28.09.2026",
      applicationPlace: "İŞKUR",
      employmentType: "Sürekli İşçi",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["Meslek lisesi veya MEB ustalık belgesi", "18-35 yaş aralığında olmak"],
      description: "Askeri fabrikalar genel müdürlüğü bünyesine İŞKUR kura yöntemiyle işçi alımı.",
      officialUrl: "https://iskur.gov.tr",
      logoIcon: Icons.precision_manufacturing,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "meb-ogretmen-20k",
      organization: "Milli Eğitim Bakanlığı",
      title: "20.000 Sözleşmeli Öğretmen Atama Takvimi ve Kontenjanları",
      position: "Sözleşmeli Öğretmen (Tüm Branşlar)",
      city: "81 İl Geneli",
      date: "09.09.2026",
      quota: "20.000",
      deadline: "27.09.2026",
      applicationPlace: "MEBBİS / e-Devlet",
      employmentType: "Sözleşmeli Öğretmen",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "20.10.2026",
      requirements: const ["Eğitim Fakültesi mezunu veya formasyon", "KPSS ÖABT puan türünden en az 50 puan", "Sağlık raporu"],
      description: "Sınıf öğretmenliği, özel eğitim, İngilizce, din kültürü ve okul öncesi başta olmak üzere atama.",
      officialUrl: "https://meb.gov.tr",
      logoIcon: Icons.school,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "adalet-cte-ikm",
      organization: "Adalet Bakanlığı (CTE)",
      title: "Ceza ve Tevkifevleri 5.000 İnfaz ve Koruma Memuru (İKM)",
      position: "İnfaz ve Koruma Memuru (Gardiyan)",
      city: "Ceza İnfaz Kurumları",
      date: "08.09.2026",
      quota: "5.000",
      deadline: "25.09.2026",
      applicationPlace: "e-Devlet / Adalet",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Lise",
      kpssStatus: "KPSS'li",
      examDate: "15.10.2026",
      requirements: const ["KPSS en az 70 puan", "Erkeklerde en az 170 cm, kadınlarda 160 cm boy", "30 yaşını bitirmemiş olmak"],
      description: "Ceza infaz kurumlarına en az lise mezunu kadın ve erkek İKM alımı yapılacak.",
      officialUrl: "https://cte.adalet.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "icisleri-nufus",
      organization: "İçişleri Bakanlığı",
      title: "1.200 İl/İlçe Nüfus Müdürlüğü Büro Personeli Alımı",
      position: "Büro Personeli (Nüfus)",
      city: "81 İl Nüfus Müdürlükleri",
      date: "11.09.2026",
      quota: "1.200",
      deadline: "29.09.2026",
      applicationPlace: "e-Devlet Kariyer Kapısı",
      employmentType: "Sözleşmeli Personel (4/B)",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Önlisans KPSS P93 en az 65 puan", "Büro yönetimi veya adalet bölümleri öncelikli", "Arşiv araştırması olumlu olmak"],
      description: "Nüfus ve Vatandaşlık İşleri Genel Müdürlüğü bünyesinde kimlik/pasaport işlemleri için istihdam.",
      officialUrl: "https://icisleri.gov.tr",
      logoIcon: Icons.badge,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "icisleri-112-cagri",
      organization: "İçişleri Bakanlığı",
      title: "112 Acil Çağrı Merkezleri 850 Çağrı Karşılama Personeli",
      position: "112 Çağrı Yönlendirici",
      city: "Bölge Çağrı Merkezleri",
      date: "07.09.2026",
      quota: "850",
      deadline: "23.09.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["KPSS P93 en az 60 puan", "Çağrı Hizmetleri MYO mezunu olmak avantajlı", "Vardiyalı çalışabilmek"],
      description: "Acil çağrı hatlarını karşılamak üzere diksiyonu düzgün vardiyalı çalışacak personel alımı.",
      officialUrl: "https://icisleri.gov.tr",
      logoIcon: Icons.emergency,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "aile-bakanligi-asdep",
      organization: "Aile ve Sosyal Hizmetler Bakanlığı",
      title: "2.500 ASDEP Görevlisi ve Sosyal Hizmet Uzmanı Alımı",
      position: "ASDEP Personeli / Psikolog / Sosyolog",
      city: "Tüm İller",
      date: "12.09.2026",
      quota: "2.500",
      deadline: "30.09.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["İlgili lisans bölümlerinden mezun olmak", "KPSS P3 en az 70 puan", "Saha çalışmasına engel hali olmamak"],
      description: "Sosyal Hizmet, Psikoloji, Sosyoloji ve Rehberlik mezunları için saha destek personeli alımı.",
      officialUrl: "https://aile.gov.tr",
      logoIcon: Icons.family_restroom,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "genclik-spor-yurt",
      organization: "Gençlik ve Spor Bakanlığı (GSB)",
      title: "3.200 Yurt Yönetim Personeli ve Antrenör Alımı",
      position: "Yurt Personeli & Antrenör",
      city: "KYK Yurtları",
      date: "06.09.2026",
      quota: "3.200",
      deadline: "24.09.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Lisans mezunu olmak", "KPSS P3 en az 60 puan", "30 yaşını doldurmamış olmak"],
      description: "Üniversite KYK yurtlarında idari personel ve spor tesislerinde antrenör istihdamı.",
      officialUrl: "https://gsb.gov.tr",
      logoIcon: Icons.sports_soccer,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "tarim-orman-muhendis",
      organization: "Tarım ve Orman Bakanlığı",
      title: "1.500 Ziraat, Veteriner ve Gıda Mühendisi Alımı",
      position: "Mühendis / Veteriner Hekim",
      city: "İl ve İlçe Müdürlükleri",
      date: "10.09.2026",
      quota: "1.500",
      deadline: "28.09.2026",
      applicationPlace: "ÖSYM Tercih",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Tercih",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Ziraat, Veteriner, Gıda Mühendisliği mezuniyeti", "KPSS P3 en az 70 puan", "Seyahate engel hali olmamak"],
      description: "Tarım il müdürlükleri, gıda denetim birimleri ve hayvancılık şubelerine personel takviyesi.",
      officialUrl: "https://tarimorman.gov.tr",
      logoIcon: Icons.forest,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "hazine-maliye-guy",
      organization: "Gelir İdaresi Başkanlığı (GİB)",
      title: "2.000 Gelir Uzman Yardımcısı (GUY) Giriş Sınavı",
      position: "Gelir Uzman Yardımcısı",
      city: "Tüm Vergi Daireleri",
      date: "05.09.2026",
      quota: "2.000",
      deadline: "22.09.2026",
      applicationPlace: "GİB Sınav Portalı",
      employmentType: "Kariyer Meslek (Memur)",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "14.11.2026",
      requirements: const ["İİBF/Hukuk mezunu olmak", "KPSS A Grubu P48 en az 70 puan", "35 yaşını doldurmamış olmak"],
      description: "İİBF, SBF ve Hukuk fakültesi mezunları için vergi uzman yardımcılığı yazılı sınavı.",
      officialUrl: "https://gib.gov.tr",
      logoIcon: Icons.account_balance,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ticaret-gumruk-muhafaza",
      organization: "Ticaret Bakanlığı",
      title: "1.000 Gümrük Muhafaza Memuru ve Muayene Memuru Alımı",
      position: "Gümrük Muhafaza Memuru",
      city: "Gümrük Kapıları ve Limanlar",
      date: "04.09.2026",
      quota: "1.000",
      deadline: "21.09.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "05.11.2026",
      requirements: const ["KPSS P3 en az 70 puan", "Erkeklerde en az 172 cm, kadınlarda 165 cm boy", "Fiziki yeterlilikte başarılı olmak"],
      description: "Sınır kapıları, havalimanları ve limanlarda kaçakçılıkla mücadele için muhafaza personeli.",
      officialUrl: "https://ticaret.gov.tr",
      logoIcon: Icons.shield,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "cevre-sehircilik-mimar",
      organization: "Çevre, Şehircilik ve İklim Değişikliği Bakanlığı",
      title: "800 Mimar, İnşaat ve Harita Mühendisi Alımı",
      position: "Mühendis / Mimar",
      city: "Deprem Bölgesi ve İller",
      date: "08.09.2026",
      quota: "800",
      deadline: "26.09.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["İnşaat, Mimar, Harita mezunu", "KPSS P3 en az 75 puan", "Şantiye deneyimi tercih sebebi"],
      description: "Kentsel dönüşüm ve afet bölgesi konut projelerinde görev yapacak teknik uzman alımı.",
      officialUrl: "https://csb.gov.tr",
      logoIcon: Icons.apartment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "kultur-turizm-arkeolog",
      organization: "Kültür ve Turizm Bakanlığı",
      title: "450 Müze Araştırmacısı, Arkeolog ve Restoratör Alımı",
      position: "Arkeolog / Sanat Tarihçisi",
      city: "Müzeler ve Örenyerleri",
      date: "02.09.2026",
      quota: "450",
      deadline: "20.09.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Arkeoloji veya Sanat Tarihi lisans diploması", "KPSS P3 en az 70 puan", "Arazi çalışmasına yatkın olmak"],
      description: "Türkiye genelindeki milli müzeler ve kazı alanlarında görevlendirilmek üzere uzman alımı.",
      officialUrl: "https://ktb.gov.tr",
      logoIcon: Icons.museum,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ulastirma-denetim",
      organization: "Ulaştırma ve Altyapı Bakanlığı",
      title: "300 Denizcilik ve Havacılık Uzman Yardımcısı Alımı",
      position: "Ulaştırma Uzman Yardımcısı",
      city: "Ankara / İstanbul",
      date: "11.09.2026",
      quota: "300",
      deadline: "30.09.2026",
      applicationPlace: "e-Devlet Kariyer Kapısı",
      employmentType: "Kariyer Meslek",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "28.11.2026",
      requirements: const ["Mühendislik veya Hukuk mezuniyeti", "KPSS ilgili puan türünden en az 75", "YDS en az 70 (C)"],
      description: "Tersaneler, demiryolları ve sivil havacılık regülasyon birimlerine uzman yardımcısı alımı.",
      officialUrl: "https://uab.gov.tr",
      logoIcon: Icons.traffic,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "enerji-tabii-kaynaklar",
      organization: "Enerji ve Tabii Kaynaklar Bakanlığı",
      title: "200 Maden ve Enerji Uzman Yardımcısı Giriş Sınavı",
      position: "Enerji Uzman Yardımcısı",
      city: "Ankara",
      date: "07.09.2026",
      quota: "200",
      deadline: "25.09.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Memur Kadrosu",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "12.12.2026",
      requirements: const ["Maden, Elektrik, Enerji Mühendisliği", "KPSS P1/P2 en az 75 puan", "35 yaş altı olmak"],
      description: "Yenilenebilir enerji, nükleer santral denetimi ve madencilik strateji dairelerine alım.",
      officialUrl: "https://enerji.gov.tr",
      logoIcon: Icons.electric_bolt,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "sanayi-teknoloji-uzman",
      organization: "Sanayi ve Teknoloji Bakanlığı",
      title: "150 Sanayi ve Teknoloji Uzman Yardımcısı Alımı",
      position: "Sanayi Uzman Yardımcısı",
      city: "Ankara",
      date: "09.09.2026",
      quota: "150",
      deadline: "27.09.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Kariyer Meslek",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Bilgisayar, Endüstri, Makine veya Yazılım Mühendisliği", "KPSS P1/P3 en az 75", "İleri düzey İngilizce"],
      description: "Milli Teknoloji Hamlesi, Ar-Ge teşvikleri ve OSB denetimleri için mühendis/uzman alımı.",
      officialUrl: "https://sanayi.gov.tr",
      logoIcon: Icons.precision_manufacturing,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "adalet-mulakat-katip",
      organization: "Adalet Bakanlığı",
      title: "Zabıt Katipliği 3 Dakikada 90 Kelime Klavye Uygulama Takvimi",
      position: "Uygulama Sınavı",
      city: "Adliyeler",
      date: "14.09.2026",
      quota: "6.000",
      deadline: "25.09.2026",
      applicationPlace: "Adalet Komisyonları",
      employmentType: "Mülakat Duyurusu",
      applicationType: "Adliye Girişi",
      status: "Açık",
      contentType: "MULAKAT",
      category: "Bakanlıklar",
      educationLevel: "Lise",
      kpssStatus: "KPSS'li",
      examDate: "05.10.2026",
      requirements: const ["KPSS 70 ve üzeri adaylar", "3 dakikada yanlışsız en az 90 kelime yazabilmek"],
      description: "F ve Q klavye sınav saatleri adliye adalet komisyonları resmi web sayfalarında ilan edildi.",
      officialUrl: "https://pgm.adalet.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "saglik-sonuc-atama",
      organization: "Sağlık Bakanlığı • Sonuç",
      title: "2026/1 Sağlık Bakanlığı Sözleşmeli Pozisyonlara Yerleştirme Sonuçları",
      position: "KPSS Yerleştirme Sonucu",
      city: "Tüm Türkiye",
      date: "13.09.2026",
      quota: "27.000",
      deadline: "13.09.2026",
      applicationPlace: "ÖSYM Sonuç",
      employmentType: "Sonuç Duyurusu",
      applicationType: "Sonuç Ekranı",
      status: "Sonuç",
      contentType: "SONUC",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["ÖSYM AIS sonuç sorgulama"],
      description: "ÖSYM 2026/1 Sağlık Bakanlığı KPSS taban puanları ve atama sonuçları erişime açıldı.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.local_hospital,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ibb-itfaiye-zabita",
      organization: "İstanbul Büyükşehir Belediyesi (İBB)",
      title: "500 İtfaiye Eri ve 250 Zabıta Memuru Alımı",
      position: "İtfaiye Eri / Zabıta Memuru",
      city: "İstanbul",
      date: "08.09.2026",
      quota: "750",
      deadline: "26.09.2026",
      applicationPlace: "İBB Kariyer Portalı",
      employmentType: "Belediye Memuru (657)",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      examDate: "15.10.2026",
      requirements: const ["İlgili önlisans bölümlerinden mezun olmak", "KPSS P93 en az 60 puan", "C sınıfı sürücü belgesi"],
      description: "İBB bünyesinde istihdam edilmek üzere KPSS 60 taban puanla fiziki parkur sınavlı memur alımı.",
      officialUrl: "https://kariyer.ibb.istanbul",
      logoIcon: Icons.local_fire_department,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "abb-ego-sofor",
      organization: "Ankara Büyükşehir Belediyesi (ABB)",
      title: "400 EGO Otobüs Şoförü ve Raylı Sistem Teknisyeni",
      position: "Otobüs Şoförü / Raylı Sistem Teknisyeni",
      city: "Ankara",
      date: "06.09.2026",
      quota: "400",
      deadline: "24.09.2026",
      applicationPlace: "ABB Kariyer Merkezi",
      employmentType: "Belediye Şirket İşçisi",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["Eski E veya yeni D sınıfı ehliyet", "SRC 2 ve Psikoteknik belgesi", "En az 2 yıl şoförlük deneyimi"],
      description: "Ankara genelinde EGO Genel Müdürlüğü filosu için D sınıfı ehliyetli şoför alımı.",
      officialUrl: "https://ankara.bel.tr",
      logoIcon: Icons.directions_bus,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "izmir-izsu-teknik",
      organization: "İzmir Büyükşehir Belediyesi (İZSU)",
      title: "200 Su ve Kanalizasyon Şebeke Teknisyeni Alımı",
      position: "Su Tesisat / Boru Hatları Ustası",
      city: "İzmir",
      date: "04.09.2026",
      quota: "200",
      deadline: "22.09.2026",
      applicationPlace: "İZSU İnsan Kaynakları",
      employmentType: "Sürekli İşçi",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["Meslek lisesi tesisat, makine veya inşaat", "Vardiyalı çalışabilmek", "35 yaşından gün almamış olmak"],
      description: "İZSU Genel Müdürlüğü su arıtma tesisleri ve kanal bakım şantiyelerine personel alımı.",
      officialUrl: "https://izsu.gov.tr",
      logoIcon: Icons.water_drop,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "bursa-belediyesi-zabita",
      organization: "Bursa Büyükşehir Belediyesi",
      title: "100 Zabıta Memuru Alımı (Kadın/Erkek)",
      position: "Zabıta Memuru",
      city: "Bursa",
      date: "07.09.2026",
      quota: "100",
      deadline: "25.09.2026",
      applicationPlace: "Bursa BB Portalı",
      employmentType: "Memur Kadrosu",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "20.10.2026",
      requirements: const ["KPSS P3 en az 65 puan", "Erkeklerde en az 167, kadınlarda 160 cm boy", "30 yaşını doldurmamış olmak"],
      description: "Pazar yerleri, çevre ve halk sağlığı denetimi için lisans mezunu zabıta kadrosu.",
      officialUrl: "https://bursa.bel.tr",
      logoIcon: Icons.local_police,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "antalya-belediyesi-cankurtaran",
      organization: "Antalya Büyükşehir Belediyesi",
      title: "150 Cankurtaran, Peyzaj ve Park Bahçe Görevlisi",
      position: "Cankurtaran / Park Bahçe İşçisi",
      city: "Antalya",
      date: "05.09.2026",
      quota: "150",
      deadline: "23.09.2026",
      applicationPlace: "Antalya BB Kariyer",
      employmentType: "Mevsimlik/Geçici İşçi",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["Gümüş veya bronz cankurtaran brövesi", "Fiziki dayanıklılık", "Adli sicil kaydı"],
      description: "Konyaaltı ve Lara halk plajları ile kentsel yeşil alan bakım birimlerine personel.",
      officialUrl: "https://antalya.bel.tr",
      logoIcon: Icons.park,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "gaziantep-belediyesi-itfaiye",
      organization: "Gaziantep Büyükşehir Belediyesi",
      title: "80 İtfaiye Eri Sınav Duyurusu",
      position: "İtfaiye Eri",
      city: "Gaziantep",
      date: "09.09.2026",
      quota: "80",
      deadline: "27.09.2026",
      applicationPlace: "Gaziantep BB",
      employmentType: "Memur",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      examDate: "12.11.2026",
      requirements: const ["İtfaiyecilik MYO mezuniyeti", "KPSS P93 en az 60", "Kapalı alan fobisi bulunmamak"],
      description: "Sivil Savunma ve İtfaiyecilik önlisans mezunları arasından yazılı ve uygulamalı sınavla alım.",
      officialUrl: "https://gaziantep.bel.tr",
      logoIcon: Icons.local_fire_department,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "konya-belediyesi-sofor",
      organization: "Konya Büyükşehir Belediyesi",
      title: "120 Tramvay Sürücüsü (Vatman) ve Otobüs Şoförü",
      position: "Vatman / Şoför",
      city: "Konya",
      date: "11.09.2026",
      quota: "120",
      deadline: "30.09.2026",
      applicationPlace: "Konya Kariyer",
      employmentType: "Belediye İşçisi",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'siz",
      requirements: const ["Raylı Sistemler veya Otomotiv MYO mezunu", "Psikoteknik onay raporu", "Vardiyaya uygun olmak"],
      description: "Konya raylı sistem ağı ve toplu taşıma araçları için vatman ve otobüs kaptanı alımı.",
      officialUrl: "https://konya.bel.tr",
      logoIcon: Icons.train,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "kocaeli-belediyesi-muhendis",
      organization: "Kocaeli Büyükşehir Belediyesi",
      title: "60 Çevre ve İnşaat Mühendisi Alımı",
      position: "Mühendis Kadrosu",
      city: "Kocaeli",
      date: "03.09.2026",
      quota: "60",
      deadline: "21.09.2026",
      applicationPlace: "Kocaeli BB Portalı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["İlgili mühendislik fakültesi mezunu", "KPSS P3 en az 70 puan", "B sınıfı sürücü belgesi"],
      description: "Körfez çevre koruma projeleri ve altyapı güçlendirme projelerinde çalışacak mühendisler.",
      officialUrl: "https://kocaeli.bel.tr",
      logoIcon: Icons.engineering,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "diyarbakir-belediyesi-zabita",
      organization: "Diyarbakır Büyükşehir Belediyesi",
      title: "75 Zabıta Memuru Alımı Giriş Sınavı",
      position: "Zabıta Memuru",
      city: "Diyarbakır",
      date: "12.09.2026",
      quota: "75",
      deadline: "01.10.2026",
      applicationPlace: "Diyarbakır BB",
      employmentType: "Memur",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      examDate: "25.10.2026",
      requirements: const ["Önlisans KPSS en az 60 puan", "Boy-kilo şartlarına uymak", "30 yaş altı olmak"],
      description: "Belediye zabıta yönetmeliği hükümlerine göre KPSS puan sıralamasıyla sözlü ve fiziki sınav.",
      officialUrl: "https://diyarbakir.bel.tr",
      logoIcon: Icons.local_police,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "trabzon-belediyesi-park",
      organization: "Trabzon Büyükşehir Belediyesi",
      title: "90 Bahçıvan ve Ağaç Budama İşçisi Alımı",
      position: "Park ve Bahçeler İşçisi",
      city: "Trabzon",
      date: "06.09.2026",
      quota: "90",
      deadline: "24.09.2026",
      applicationPlace: "İŞKUR",
      employmentType: "Sürekli İşçi",
      applicationType: "Kura Çekimi",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "İlköğretim",
      kpssStatus: "KPSS'siz",
      requirements: const ["En az ilkokul mezuniyeti", "Ağır bedensel işe engeli olmamak", "Trabzon'da ikamet etmek"],
      description: "Şehir parkları, refüjler ve sahil bantlarında bakım yapacak saha işçisi temini.",
      officialUrl: "https://trabzon.bel.tr",
      logoIcon: Icons.forest,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "sanliurfa-su-ariza",
      organization: "Şanlıurfa Büyükşehir Belediyesi (ŞUSKİ)",
      title: "110 Su Tesisatçısı ve Kepçe Operatörü Alımı",
      position: "Operatör / Usta",
      city: "Şanlıurfa",
      date: "08.09.2026",
      quota: "110",
      deadline: "26.09.2026",
      applicationPlace: "ŞUSKİ İnsan Kaynakları",
      employmentType: "Sürekli İşçi",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["G sınıfı iş makinesi ehliyeti (operatörler için)", "Askerlik yapmış olmak"],
      description: "İçme suyu şebeke arıza onarım ve kanalizasyon altyapı yenileme ekipleri için personel.",
      officialUrl: "https://suski.gov.tr",
      logoIcon: Icons.plumbing,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ibb-zabita-parkur-mulakat",
      organization: "İstanbul Büyükşehir Belediyesi",
      title: "İBB Zabıta Memuru Fiziki Yeterlilik ve Boy-Kilo Ölçüm Takvimi",
      position: "Fiziki Parkur Mülakatı",
      city: "Yenikapı / İstanbul",
      date: "14.09.2026",
      quota: "250",
      deadline: "28.09.2026",
      applicationPlace: "İBB İnsan Kaynakları",
      employmentType: "Mülakat Duyurusu",
      applicationType: "Parkur Çağrısı",
      status: "Açık",
      contentType: "MULAKAT",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      examDate: "08.10.2026",
      requirements: const ["Kimlik kartı", "Spor kıyafeti", "Sağlık beyan dilekçesi"],
      description: "Adayların spor salonu randevu saatleri ve sınav yönergeleri ilan edilmiştir.",
      officialUrl: "https://kariyer.ibb.istanbul",
      logoIcon: Icons.sports_soccer,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "bogazici-akademik",
      organization: "Boğaziçi Üniversitesi",
      title: "45 Araştırma Görevlisi ve Öğretim Görevlisi Alımı",
      position: "Araştırma Görevlisi / Öğretim Görevlisi",
      city: "İstanbul",
      date: "09.09.2026",
      quota: "45",
      deadline: "27.09.2026",
      applicationPlace: "Boğaziçi Rektörlüğü",
      employmentType: "Akademik Personel",
      applicationType: "Şahsen / Posta",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Yüksek Lisans",
      kpssStatus: "Muaf",
      examDate: "18.10.2026",
      requirements: const ["ALES sayısal/eşit ağırlık en az 80", "YÖKDİL/YDS en az 85 puan", "Tezli yüksek lisans yapıyor olmak"],
      description: "Mühendislik, İktisadi ve İdari Bilimler ve Fen-Edebiyat fakültelerine genç araştırmacılar.",
      officialUrl: "https://boun.edu.tr",
      logoIcon: Icons.school,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "odtu-muhendislik-arastirma",
      organization: "Orta Doğu Teknik Üniversitesi (ODTÜ)",
      title: "30 Araştırma Görevlisi Alımı (Bilgisayar & Elektrik)",
      position: "Araştırma Görevlisi",
      city: "Ankara",
      date: "07.09.2026",
      quota: "30",
      deadline: "25.09.2026",
      applicationPlace: "ODTÜ Personel Daire",
      employmentType: "Akademik Kadro",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Yüksek Lisans",
      kpssStatus: "Muaf",
      examDate: "15.10.2026",
      requirements: const ["ALES Sayısal en az 85", "İleri düzey İngilizce (YDS 85+ / TOEFL 95+)", "İlgili alanda tez konusu"],
      description: "Yapay zeka, siber güvenlik, mikroelektronik ve robotik alanlarında doktora/yüksek lisans kadrosu.",
      officialUrl: "https://metu.edu.tr",
      logoIcon: Icons.science,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "itu-ogretim-uyesi",
      organization: "İstanbul Teknik Üniversitesi (İTÜ)",
      title: "50 Doktor Öğretim Üyesi ve Doçent Alımı",
      position: "Doktor Öğretim Üyesi / Doçent",
      city: "İstanbul",
      date: "05.09.2026",
      quota: "50",
      deadline: "23.09.2026",
      applicationPlace: "İTÜ Rektörlük",
      employmentType: "Öğretim Üyesi",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Doktora",
      kpssStatus: "Muaf",
      requirements: const ["Doktora unvanına sahip olmak", "Uluslararası SCI/SSCI yayın şartlarını karşılamak"],
      description: "Gemi inşaatı, havacılık, maden ve inşaat mühendisliği bölümlerine öğretim üyesi alımı.",
      officialUrl: "https://itu.edu.tr",
      logoIcon: Icons.school,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "hacettepe-hemsire-saglik",
      organization: "Hacettepe Üniversitesi Hastaneleri",
      title: "180 Sözleşmeli Hemşire, Röntgen Teknikeri ve Biyolog",
      position: "Hemşire / Röntgen Teknikeri",
      city: "Ankara",
      date: "11.09.2026",
      quota: "180",
      deadline: "29.09.2026",
      applicationPlace: "Hacettepe Başvuru Portalı",
      employmentType: "Sözleşmeli Sağlık Personeli (4/B)",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Hemşirelik lisans mezuniyeti", "KPSS P3 en az 65 puan", "Vardiyalı çalışmaya engel hali olmamak"],
      description: "Hacettepe Tıp Fakültesi Erişkin ve Onkoloji Hastaneleri yoğun bakım ve ameliyathanelerine personel.",
      officialUrl: "https://hacettepe.edu.tr",
      logoIcon: Icons.local_hospital,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "istanbul-uni-idari",
      organization: "İstanbul Üniversitesi",
      title: "120 Büro Personeli, Koruma ve Destek Personeli Alımı",
      position: "Büro Personeli / Güvenlik",
      city: "İstanbul (Beyazıt / Avcılar)",
      date: "08.09.2026",
      quota: "120",
      deadline: "26.09.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Sözleşmeli Personel (4/B)",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Önlisans KPSS en az 65 puan", "Özel güvenlik kimlik kartı (güvenlik için)", "35 yaş altı olmak"],
      description: "Öğrenci işleri, kütüphaneler ve kampüs güvenlik birimlerinde istihdam edilmek üzere personel alımı.",
      officialUrl: "https://istanbul.edu.tr",
      logoIcon: Icons.apartment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ankara-uni-arastirma",
      organization: "Ankara Üniversitesi",
      title: "35 Araştırma Görevlisi Alımı (Hukuk & Siyasal)",
      position: "Araştırma Görevlisi",
      city: "Ankara",
      date: "10.09.2026",
      quota: "35",
      deadline: "28.09.2026",
      applicationPlace: "Ankara Üni Personel",
      employmentType: "Akademik Personel",
      applicationType: "Şahsen / Online",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Yüksek Lisans",
      kpssStatus: "Muaf",
      examDate: "22.10.2026",
      requirements: const ["Hukuk veya İİBF lisans mezuniyeti", "ALES en az 75 puan", "YDS en az 70 puan"],
      description: "Hukuk Fakültesi ve Mülkiye bölümlerine 50/d kadrosunda araştırma görevlisi alınacaktır.",
      officialUrl: "https://ankara.edu.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ege-uni-laborant",
      organization: "Ege Üniversitesi Tıp Fakültesi",
      title: "75 Tıbbi Laboratuvar ve Anestezi Teknikeri Alımı",
      position: "Laborant / Anestezi Teknikeri",
      city: "İzmir (Bornova)",
      date: "06.09.2026",
      quota: "75",
      deadline: "24.09.2026",
      applicationPlace: "Ege Üni İK",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Tıbbi Laboratuvar Teknikleri MYO mezuniyeti", "KPSS P93 en az 70 puan"],
      description: "Üniversite hastanesi merkez biyokimya ve mikrobiyoloji laboratuvarlarına önlisans mezunu teknik kadro.",
      officialUrl: "https://ege.edu.tr",
      logoIcon: Icons.biotech,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "gazi-uni-muhendis-memur",
      organization: "Gazi Üniversitesi",
      title: "50 Mühendis, Kütüphaneci ve Programcı Alımı",
      position: "Mühendis / Yazılımcı / Kütüphaneci",
      city: "Ankara",
      date: "12.09.2026",
      quota: "50",
      deadline: "02.10.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Sözleşmeli Personel (4/B)",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Bilgisayar/Yazılım Mühendisliği veya BBY mezuniyeti", "KPSS P3 en az 70 puan"],
      description: "Bilgi İşlem Daire Başkanlığı ve Merkez Kütüphane kadrolarına teknik personel istihdamı.",
      officialUrl: "https://gazi.edu.tr",
      logoIcon: Icons.engineering,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "marmara-uni-saglik-idari",
      organization: "Marmara Üniversitesi",
      title: "90 Sağlık Teknikeri ve Güvenlik Görevlisi Alımı",
      position: "Sağlık Teknikeri / Güvenlik Görevlisi",
      city: "İstanbul (Maltepe / Başıbüyük)",
      date: "04.09.2026",
      quota: "90",
      deadline: "22.09.2026",
      applicationPlace: "Marmara Üni Personel",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["İlgili önlisans mezuniyeti", "KPSS P93 en az 65 puan"],
      description: "Başıbüyük Sağlık Kampüsü hastanesine tekniker ve yerleşke koruma personeli alımı.",
      officialUrl: "https://marmara.edu.tr",
      logoIcon: Icons.local_hospital,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "anadolu-uni-ogretim-gorevlisi",
      organization: "Anadolu Üniversitesi",
      title: "25 Açıköğretim ve Uzaktan Eğitim Öğretim Görevlisi Alımı",
      position: "Öğretim Görevlisi",
      city: "Eskişehir",
      date: "07.09.2026",
      quota: "25",
      deadline: "25.09.2026",
      applicationPlace: "Anadolu Üni Portalı",
      employmentType: "Öğretim Görevlisi",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Yüksek Lisans",
      kpssStatus: "Muaf",
      examDate: "15.10.2026",
      requirements: const ["ALES en az 70 puan", "YDS en az 60 puan", "Tezli yüksek lisans tamamlamış olmak"],
      description: "Açıköğretim Fakültesi ders materyali ve e-öğrenme içerik geliştirme birimlerine akademisyen.",
      officialUrl: "https://anadolu.edu.tr",
      logoIcon: Icons.auto_stories,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "akademik-mulakat-hacettepe",
      organization: "Hacettepe Üniversitesi",
      title: "Tıp ve Sağlık Bilimleri Öğretim Üyeliği Sözlü Mülakat Takvimi",
      position: "Sözlü Mülakat",
      city: "Sıhhiye / Ankara",
      date: "14.09.2026",
      quota: "40",
      deadline: "26.09.2026",
      applicationPlace: "Fakülte Dekanlıkları",
      employmentType: "Mülakat Duyurusu",
      applicationType: "Şahsen Mülakat",
      status: "Açık",
      contentType: "MULAKAT",
      category: "Üniversiteler & Akademik",
      educationLevel: "Doktora",
      kpssStatus: "Muaf",
      examDate: "05.10.2026",
      requirements: const ["Jüri dosyası teslim makbuzu", "Yayın listesi", "Doçentlik/Doktora belgesi"],
      description: "Akademik jüri önünde deneme dersi ve sözlü sınav değerlendirme programı ilan edildi.",
      officialUrl: "https://hacettepe.edu.tr",
      logoIcon: Icons.checklist,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "meb-typ-temizlik",
      organization: "İŞKUR & MEB",
      title: "60.000 Okul Temizlik ve Güvenlik TYP Personeli Alımı",
      position: "TYP Temizlik ve Güvenlik Görevlisi",
      city: "81 İl İlçe MEM'ler",
      date: "10.09.2026",
      quota: "60.000",
      deadline: "28.09.2026",
      applicationPlace: "esube.iskur.gov.tr",
      employmentType: "Toplum Yararına Program (TYP)",
      applicationType: "Online / e-Devlet",
      status: "Açık",
      contentType: "ILAN",
      category: "İŞKUR & Kamu İşçi",
      educationLevel: "İlköğretim",
      kpssStatus: "KPSS'siz",
      requirements: const ["İŞKUR'a kayıtlı işsiz olmak", "Aynı adreste oturanların toplam geliri net asgari ücretin 1.5 katını aşmamak", "18 yaşını doldurmuş olmak"],
      description: "Devlet okullarında 9 ay süreli asgari ücretli temizlik, hijyen ve çevre düzenleme istihdamı.",
      officialUrl: "https://esube.iskur.gov.tr",
      logoIcon: Icons.cleaning_services,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "saglik-bakanligi-isci",
      organization: "Sağlık Bakanlığı & İŞKUR",
      title: "10.000 Sürekli İşçi Alımı (Temizlik, Güvenlik, Bakım Onarım)",
      position: "Temizlik, Güvenlik, Klinik Destek",
      city: "Şehir Hastaneleri ve Devlet Hastaneleri",
      date: "08.09.2026",
      quota: "10.000",
      deadline: "24.09.2026",
      applicationPlace: "İŞKUR Portalı",
      employmentType: "Sürekli İşçi (4857)",
      applicationType: "Noter Kurası",
      status: "Açık",
      contentType: "ILAN",
      category: "İŞKUR & Kamu İşçi",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      examDate: "15.10.2026",
      requirements: const ["En az lise mezuniyeti", "Özel güvenlik kimlik kartı (güvenlik için)", "18-40 yaş aralığında olmak"],
      description: "Türkiye genelinde şehir hastanelerine noter huzurunda kura çekimiyle kadrolu sürekli işçi alımı.",
      officialUrl: "https://iskur.gov.tr",
      logoIcon: Icons.local_hospital,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "dsi-isci-alimi",
      organization: "Devlet Su İşleri (DSİ)",
      title: "1.250 Dozer Operatörü, Sondör ve Bakım Ustası Alımı",
      position: "Ağır Vasıta Operatörü / Bakım Ustası",
      city: "DSİ Bölge Müdürlükleri",
      date: "05.09.2026",
      quota: "1.250",
      deadline: "23.09.2026",
      applicationPlace: "İŞKUR",
      employmentType: "Sürekli İşçi (Kadrolu)",
      applicationType: "Noter Kurası / Uygulama",
      status: "Açık",
      contentType: "ILAN",
      category: "İŞKUR & Kamu İşçi",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["G sınıfı ehliyet ve operatörlük belgesi", "En az 2 yıl arazi deneyimi", "Sağlık heyet raporu"],
      description: "Baraj, gölet ve taşkın koruma projelerinde istihdam edilmek üzere iş makinesi operatörü temini.",
      officialUrl: "https://dsi.gov.tr",
      logoIcon: Icons.water,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ogm-yangin-iscisi",
      organization: "Orman Genel Müdürlüğü (OGM)",
      title: "2.500 Orman Yangınıyla Mücadele İşçisi Alımı",
      position: "Yangın Söndürme İşçisi",
      city: "Ege, Akdeniz ve Marmara İşletmeleri",
      date: "07.09.2026",
      quota: "2.500",
      deadline: "25.09.2026",
      applicationPlace: "İŞKUR",
      employmentType: "Geçici / Mevsimlik İşçi",
      applicationType: "Fiziki Dayanıklılık Testi",
      status: "Açık",
      contentType: "ILAN",
      category: "İŞKUR & Kamu İşçi",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      examDate: "10.10.2026",
      requirements: const ["En az lise mezuniyeti", "Fiziki güç parkurunda başarılı olmak", "30 yaşını aşmamış olmak"],
      description: "Orman yangınlarına müdahale ekipleri için arazide koşu, tırmanma ve güç testine dayalı alım.",
      officialUrl: "https://ogm.gov.tr",
      logoIcon: Icons.local_fire_department,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "kgm-karayollari-isci",
      organization: "Karayolları Genel Müdürlüğü (KGM)",
      title: "850 Yol Bakım ve Kar Mücadele İşçisi Alımı",
      position: "Asfalt Ustası / Kar Bıçağı Operatörü",
      city: "KGM Şube Şeflikleri",
      date: "11.09.2026",
      quota: "850",
      deadline: "29.09.2026",
      applicationPlace: "İŞKUR",
      employmentType: "Sürekli İşçi",
      applicationType: "Kura + Mülakat",
      status: "Açık",
      contentType: "ILAN",
      category: "İŞKUR & Kamu İşçi",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["C veya CE sınıfı ehliyet", "Ağır iş yapabilir raporu", "Vardiyalı çalışabilmek"],
      description: "Kış mevsimi kar püskürtme, yol açma ve asfalt yama ekipleri için kadrolu eleman alımı.",
      officialUrl: "https://kgm.gov.tr",
      logoIcon: Icons.traffic,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "caykur-mevsimlik-isci",
      organization: "ÇAYKUR",
      title: "1.000 Çay Eksperi ve Fabrika İşçisi Alımı",
      position: "Mevsimlik Fabrika İşçisi",
      city: "Rize, Trabzon, Artvin, Giresun",
      date: "03.09.2026",
      quota: "1.000",
      deadline: "21.09.2026",
      applicationPlace: "İŞKUR Rize İl Müdürlüğü",
      employmentType: "Mevsimlik İşçi",
      applicationType: "Noter Kurası",
      status: "Açık",
      contentType: "ILAN",
      category: "İŞKUR & Kamu İşçi",
      educationLevel: "İlköğretim",
      kpssStatus: "KPSS'siz",
      requirements: const ["İlgili illerde ikamet etmek", "18-45 yaş aralığında olmak"],
      description: "Çay işleme fabrikalarında üretim sezonunda görev alacak imalat ve paketleme personeli.",
      officialUrl: "https://caykur.gov.tr",
      logoIcon: Icons.coffee,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "eti-maden-kamu-isci",
      organization: "Eti Maden İşletmeleri",
      title: "350 Yeraltı ve Yerüstü Maden İşçisi Alımı",
      position: "Maden İşçisi / Mekanikçi",
      city: "Balıkesir / Kütahya / Eskişehir",
      date: "09.09.2026",
      quota: "350",
      deadline: "27.09.2026",
      applicationPlace: "İŞKUR",
      employmentType: "Sürekli İşçi (Kadrolu)",
      applicationType: "Kura + Sağlık Heyeti",
      status: "Açık",
      contentType: "ILAN",
      category: "İŞKUR & Kamu İşçi",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["Meslek lisesi maden, makine, elektrik", "Yeraltı çalışma koşullarına engel sağlık sorunu olmamak"],
      description: "Bor tesisleri ve maden ocaklarında çalıştırılmak üzere sürekli işçi temini.",
      officialUrl: "https://etimaden.gov.tr",
      logoIcon: Icons.engineering,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "sonuc-saglik-isci-kura",
      organization: "Sağlık Bakanlığı & İŞKUR",
      title: "Sağlık Bakanlığı 10.000 Sürekli İşçi Alımı Noter Kura Sonuçları",
      position: "Kura Sonucu",
      city: "Tüm Türkiye",
      date: "14.09.2026",
      quota: "10.000",
      deadline: "14.09.2026",
      applicationPlace: "Yönetim Hizmetleri GM",
      employmentType: "Sonuç Duyurusu",
      applicationType: "Online Kura Ekranı",
      status: "Sonuç",
      contentType: "SONUC",
      category: "İŞKUR & Kamu İşçi",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["T.C. Kimlik No ile sorgulama"],
      description: "Canlı yayında noter huzurunda çekilen asil ve yedek kura listeleri sisteme yüklenmiştir.",
      officialUrl: "https://yhgm.saglik.gov.tr",
      logoIcon: Icons.fact_check,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "dhmi-atco-arff",
      organization: "Devlet Hava Meydanları İşletmesi (DHMİ)",
      title: "120 Hava Trafik Kontrolörü (ATCO) ve 200 ARFF Memuru Alımı",
      position: "Hava Trafik Kontrolörü / ARFF İtfaiye",
      city: "Tüm Havalimanları",
      date: "11.09.2026",
      quota: "320",
      deadline: "29.09.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "KİT Sözleşmeli (399)",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "KİT & Bankalar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "20.10.2026",
      requirements: const ["Lisans KPSS P3 en az 75 puan", "FEAST veya ICAO İngilizce seviye 4 yeterliliği", "Uçuş tabipliği heyet raporu"],
      description: "Hava sahası kontrol kuleleri ve acil durum kurtarma birimlerine yüksek maaşlı personel.",
      officialUrl: "https://dhmi.gov.tr",
      logoIcon: Icons.airplanemode_active,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "tcdd-makinist-tren",
      organization: "TCDD Taşımacılık A.Ş.",
      title: "250 Makinist ve Tren Teşkil Görevlisi Alımı",
      position: "Makinist / Tren Teşkil İşçisi",
      city: "Ankara, Eskişehir, Sivas, İzmir",
      date: "09.09.2026",
      quota: "250",
      deadline: "27.09.2026",
      applicationPlace: "İŞKUR & TCDD",
      employmentType: "KİT İşçisi / Personeli",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "KİT & Bankalar",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Raylı Sistemler Makinistlik MYO mezuniyeti", "KPSS P93 en az 65 puan", "Psikoteknik test onayı"],
      description: "Yüksek Hızlı Tren (YHT) ve konvansiyonel tren hatlarında makinist eğitimi verilecek personel alımı.",
      officialUrl: "https://tcddtasimacilik.gov.tr",
      logoIcon: Icons.train,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "botas-muhendis-uzman",
      organization: "Boru Hatları ile Petrol Taşıma A.Ş. (BOTAŞ)",
      title: "180 Doğalgaz Boru Hattı Mühendisi ve Teknisyeni Alımı",
      position: "Petrol/Gaz Mühendisi / SCADA Teknisyeni",
      city: "Ankara / Ceyhan / Dörtyol",
      date: "07.09.2026",
      quota: "180",
      deadline: "25.09.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "KİT Personeli",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "KİT & Bankalar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Petrol, Makine veya Elektrik Mühendisliği", "KPSS P1/P3 en az 75 puan", "YDS en az 70 puan"],
      description: "Mavi Akım, TANAP ve LNG depolama tesislerinde görev yapacak yüksek nitelikli teknik kadro.",
      officialUrl: "https://botas.gov.tr",
      logoIcon: Icons.local_gas_station,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "tpao-saha-muhendisi",
      organization: "Türkiye Petrolleri Anonim Ortaklığı (TPAO)",
      title: "300 Sondaj Mühendisi ve Jeofizik Uzmanı Alımı",
      position: "Sondaj Mühendisi / Jeolog",
      city: "Filyos / Sakarya Gaz Sahası / Şırnak",
      date: "05.09.2026",
      quota: "300",
      deadline: "23.09.2026",
      applicationPlace: "TPAO Kariyer",
      employmentType: "KİT Sözleşmeli",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "KİT & Bankalar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'siz",
      requirements: const ["Petrol ve Doğalgaz, Jeoloji veya Maden Mühendisliği", "İyi seviyede İngilizce", "Saha ve vardiya uyumu"],
      description: "Karadeniz gazı ve Gabar petrol sahası arama/üretim operasyonlarında görev alacak mühendisler.",
      officialUrl: "https://tpao.gov.tr",
      logoIcon: Icons.oil_barrel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "teias-trafo-teknisyen",
      organization: "Türkiye Elektrik İletim A.Ş. (TEİAŞ)",
      title: "220 Yüksek Gerilim Trafo Teknisyeni Alımı",
      position: "Yüksek Gerilim Teknisyeni",
      city: "Bölge İletim Müdürlükleri",
      date: "08.09.2026",
      quota: "220",
      deadline: "26.09.2026",
      applicationPlace: "İŞKUR",
      employmentType: "KİT Daimi İşçisi",
      applicationType: "Kura + Mülakat",
      status: "Açık",
      contentType: "ILAN",
      category: "KİT & Bankalar",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["Meslek lisesi Elektrik bölümü mezunu", "EKAT belgesi sahibi olmak tercih sebebi", "Yüksekte çalışabilmek"],
      description: "380 kV ve 154 kV şalt sahaları ve enerji nakil hatları periyodik bakım onarım ekiplerine alım.",
      officialUrl: "https://teias.gov.tr",
      logoIcon: Icons.bolt,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ziraat-mufettis-uzman",
      organization: "T.C. Ziraat Bankası A.Ş.",
      title: "450 Müfettiş Yardımcısı ve Uzman Yardımcısı Giriş Sınavı",
      position: "Müfettiş Yrd. / Uzman Yrd.",
      city: "Genel Müdürlük (İstanbul / Ankara)",
      date: "12.09.2026",
      quota: "450",
      deadline: "01.10.2026",
      applicationPlace: "Anadolu Üniversitesi Sınav Portalı",
      employmentType: "Banka Personeli",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "KİT & Bankalar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      examDate: "15.11.2026",
      requirements: const ["İİBF, SBF, Hukuk veya Mühendislik lisans mezuniyeti", "30 yaşından gün almamış olmak", "Adli sicil kaydı"],
      description: "Ziraat Finans Grubu teftiş kurulu ve uzmanlık kadroları için yazılı giriş sınavı açılmıştır.",
      officialUrl: "https://ziraatbank.com.tr",
      logoIcon: Icons.account_balance,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "halkbank-servis-gorevlisi",
      organization: "Türkiye Halk Bankası A.Ş.",
      title: "600 Servis Görevlisi (Gişe & Müşteri Temsilcisi) Alımı",
      position: "Servis Görevlisi",
      city: "81 İl Şubeleri",
      date: "10.09.2026",
      quota: "600",
      deadline: "28.09.2026",
      applicationPlace: "İstanbul Üniversitesi Sınav Portalı",
      employmentType: "Banka Personeli",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "KİT & Bankalar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      examDate: "08.11.2026",
      requirements: const ["4 yıllık üniversite mezuniyeti", "30 yaşını doldurmamış olmak", "İletişim ve ikna kabiliyeti"],
      description: "Halkbank şube ağında gişe operasyonları ve KOBİ müşteri ilişkileri için sınav duyurusu.",
      officialUrl: "https://halkbank.com.tr",
      logoIcon: Icons.account_balance,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "vakifbank-mufettis",
      organization: "Türkiye Vakıflar Bankası T.A.O.",
      title: "200 Stajyer Müfettiş ve BT Müfettiş Yardımcısı Alımı",
      position: "Müfettiş Yardımcısı",
      city: "İstanbul Genel Müdürlük",
      date: "06.09.2026",
      quota: "200",
      deadline: "24.09.2026",
      applicationPlace: "VakıfBank Kariyer",
      employmentType: "Banka Personeli",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "KİT & Bankalar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      examDate: "21.11.2026",
      requirements: const ["İktisat, İşletme, Hukuk, Endüstri veya Bilgisayar Müh.", "28 yaşını aşmamış olmak", "İyi derecede İngilizce"],
      description: "Finansal süreçler ve bilgi teknolojileri sistem denetimi yapacak geleceğin yöneticileri.",
      officialUrl: "https://vakifbank.com.tr",
      logoIcon: Icons.account_balance,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ptt-posta-dagitici",
      organization: "PTT A.Ş.",
      title: "1.500 Posta Dağıtıcısı ve Gişe Görevlisi Alımı",
      position: "Posta Dağıtıcı / Gişe Personeli",
      city: "Tüm Türkiye Şubeleri",
      date: "04.09.2026",
      quota: "1.500",
      deadline: "22.09.2026",
      applicationPlace: "PTT Kariyer Portalı",
      employmentType: "İdari Hizmet Sözleşmeli (İHS)",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "KİT & Bankalar",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Önlisans veya Lisans KPSS en az 65 puan", "A2 ve B sınıfı ehliyet (dağıtıcılar için)", "35 yaş altı olmak"],
      description: "PTT kargo dağıtım ağı ve merkez gişelerinde görev yapacak personel istihdamı.",
      officialUrl: "https://ptt.gov.tr",
      logoIcon: Icons.local_shipping,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "aselsan-roket-savunma",
      organization: "ASELSAN & ROKETSAN",
      title: "400 Savunma Sanayii Donanım ve Yazılım Mühendisi Alımı",
      position: "Gömülü Yazılım / RF Donanım Mühendisi",
      city: "Ankara (Macunköy & Akyurt)",
      date: "13.09.2026",
      quota: "400",
      deadline: "05.10.2026",
      applicationPlace: "Savunma Sanayii Kariyer",
      employmentType: "Tam Zamanlı Mühendis",
      applicationType: "Online Portföy",
      status: "Açık",
      contentType: "ILAN",
      category: "KİT & Bankalar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      requirements: const ["Elektrik-Elektronik, Bilgisayar, Makine Müh.", "GPA en az 3.00/4.00", "Güvenlik soruşturması (Milli Gizli)"],
      description: "Milli hava savunma sistemleri, radar ve elektro-optik projelerine deneyimli ve yeni mezun mühendis.",
      officialUrl: "https://aselsan.com",
      logoIcon: Icons.precision_manufacturing,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "kpss-lisans-sinavi",
      organization: "Ölçme, Seçme ve Yerleştirme Merkezi (ÖSYM)",
      title: "2026-KPSS Lisans (Genel Yetenek - Genel Kültür & Eğitim Bilimleri)",
      position: "2026 KPSS Lisans Oturumları",
      city: "81 İl Merkezi",
      date: "01.09.2026",
      quota: "1.200.000 Aday",
      deadline: "15.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Merkezi Kamu Sınavı",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "18.10.2026",
      requirements: const ["Lisans mezunu olmak veya lisans son sınıfta okumak", "Sınav kılavuzundaki başvuru ücretini yatırmak"],
      description: "B Grubu memurluk ve A Grubu kariyer kadroları için merkezi değerlendirme sınavı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.edit_calendar,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "kpss-onlisans-sinavi",
      organization: "ÖSYM",
      title: "2026-KPSS Önlisans Sınav Başvuruları ve Kılavuzu",
      position: "KPSS Önlisans Sınavı",
      city: "81 İl Merkezi",
      date: "03.09.2026",
      quota: "850.000 Aday",
      deadline: "20.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Merkezi Sınav",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      examDate: "01.11.2026",
      requirements: const ["Önlisans mezunu veya son sınıfta olmak", "Fotoğraflı T.C. kimlik kartı"],
      description: "İki yıllık meslek yüksekokulu mezunları için iki yılda bir düzenlenen genel memurluk sınavı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.event_note,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "kpss-ortaogretim-lise",
      organization: "ÖSYM",
      title: "2026-KPSS Ortaöğretim (Lise Düzeyi) Başvuru Takvimi",
      position: "KPSS Ortaöğretim",
      city: "Tüm Sınav Merkezleri",
      date: "05.09.2026",
      quota: "1.500.000 Aday",
      deadline: "25.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Merkezi Sınav",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lise",
      kpssStatus: "KPSS'li",
      examDate: "22.11.2026",
      requirements: const ["Lise mezunu veya lisede öğrenci olmak", "ÖSYM başvuru merkezinden kayıt"],
      description: "Lise ve dengi okul mezunları için zabıt katibi, infaz koruma ve teknisyenlik atamalarında kullanılan sınav.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.edit_calendar,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ekpss-engelli-kamu",
      organization: "ÖSYM & Aile Bakanlığı",
      title: "2026-EKPSS Engelli Kamu Personeli Seçme Sınavı",
      position: "EKPSS Sınavı ve Kura Kayıtları",
      city: "81 İl",
      date: "02.09.2026",
      quota: "120.000 Aday",
      deadline: "19.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Merkezi Engelli Sınavı",
      applicationType: "Online / Sosyal Hizmetler",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lise",
      kpssStatus: "Muaf",
      examDate: "29.11.2026",
      requirements: const ["Engelli Sağlık Kurulu Raporu (%40 ve üzeri)", "ÖSYM engelli salonu talep dilekçesi"],
      description: "En az %40 engelli sağlık kurulu raporuna sahip adayların kamu memurluklarına atanma sınavı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.accessible,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "dgs-dikey-gecis",
      organization: "ÖSYM",
      title: "2026-DGS Dikey Geçiş Sınavı Başvuru Kılavuzu",
      position: "DGS Sınavı",
      city: "Tüm İller",
      date: "04.09.2026",
      quota: "350.000 Aday",
      deadline: "22.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Akademik Geçiş Sınavı",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Ön Lisans",
      kpssStatus: "Muaf",
      examDate: "11.10.2026",
      requirements: const ["Önlisans mezunu olmak veya mezun aşamasında olmak"],
      description: "Önlisans mezunlarının lisans programlarına geçişini sağlayan sayısal ve sözel yetenek sınavı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.school,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ales-sonbahar",
      organization: "ÖSYM",
      title: "2026-ALES/2 Akademik Personel ve Lisansüstü Eğitimi Giriş Sınavı",
      position: "ALES/2 Sınavı",
      city: "81 İl",
      date: "06.09.2026",
      quota: "250.000 Aday",
      deadline: "24.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Akademik Sınav",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      examDate: "15.11.2026",
      requirements: const ["Lisans mezunu veya son sınıf öğrencisi olmak", "5 yıl geçerlilik süresi"],
      description: "Yüksek lisans, doktora başvuruları ve öğretim elemanı kadrolarına atanma için zorunlu sınav.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.menu_book,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "yds-yabanci-dil",
      organization: "ÖSYM",
      title: "2026-YDS/2 Yabancı Dil Bilgisi Seviye Tespit Sınavı",
      position: "YDS/2 İngilizce / Almanca / Fransızca",
      city: "Bölge Merkezleri",
      date: "08.09.2026",
      quota: "150.000 Aday",
      deadline: "26.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Dil Seviye Sınavı",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      examDate: "01.11.2026",
      requirements: const ["80 çoktan seçmeli soru", "180 dakika sınav süresi"],
      description: "Kamuda dil tazminatı, kariyer uzmanlıkları ve doçentlik başvuruları için yabancı dil sınavı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.language,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "hakimlik-sinavi",
      organization: "ÖSYM & Adalet Bakanlığı",
      title: "2026 Adli Yargı Hâkim ve Savcı Yardımcılığı Giriş Sınavı",
      position: "Hâkim / Savcı Yardımcısı Adaylığı",
      city: "Ankara / İstanbul / İzmir",
      date: "10.09.2026",
      quota: "1.500",
      deadline: "30.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Yargı Meslek Sınavı",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      examDate: "26.12.2026",
      requirements: const ["Hukuk Fakültesi mezunu olmak", "35 yaşını doldurmamış olmak", "Kamu haklarından yasaklı olmamak"],
      description: "Hukuk fakültesi mezunları için adli, idari ve avukatlık mesleğinden geçiş hâkim yardımcılığı sınavı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "sayistay-denetci-sinavi",
      organization: "Sayıştay Başkanlığı & ÖSYM",
      title: "2026 Sayıştay Denetçi Yardımcısı Adaylığı Eleme Sınavı",
      position: "Sayıştay Denetçi Yardımcısı",
      city: "Ankara",
      date: "12.09.2026",
      quota: "45",
      deadline: "02.10.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Üst Düzey Denetim Kadrosu",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      examDate: "19.12.2026",
      requirements: const ["Hukuk, SBF, İİBF mezuniyeti", "35 yaşını bitirmemiş olmak", "Eleme ve yazılı sınavı başarmak"],
      description: "Türkiye Büyük Millet Meclisi adına kamu harcamalarını denetleyen Sayıştay denetçi yardımcılığı sınavı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.account_balance,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "kaymakamlik-sinavi",
      organization: "İçişleri Bakanlığı & ÖSYM",
      title: "2026 İçişleri Bakanlığı Kaymakam Adaylığı Giriş Sınavı",
      position: "Kaymakam Adayı",
      city: "Ankara",
      date: "14.09.2026",
      quota: "100",
      deadline: "05.10.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Mülki İdare Amirliği",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      examDate: "05.12.2026",
      requirements: const ["Hukuk, SBF, İİBF veya Kamu Yönetimi mezuniyeti", "35 yaşını doldurmamış olmak", "Askerlikle ilişiği olmamak"],
      description: "İlçelerde cumhurbaşkanlığı adına mülki idareyi yönetmek üzere kaymakam adayı yazılı sınavı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.apartment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-kpss-lisans-res",
      organization: "ÖSYM • Sonuç",
      title: "2026-KPSS Lisans Alan Bilgisi ve ÖABT Sonuçları Açıklandı",
      position: "KPSS Lisans Sonuç Belgesi",
      city: "Tüm Türkiye",
      date: "15.09.2026",
      quota: "Tüm Adaylar",
      deadline: "15.09.2026",
      applicationPlace: "ÖSYM Sonuç Portalı",
      employmentType: "Sonuç Duyurusu",
      applicationType: "Sonuç Ekranı",
      status: "Sonuç",
      contentType: "SONUC",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["T.C. Kimlik No ve ÖSYM şifresi ile giriş"],
      description: "KPSS Genel Yetenek, Genel Kültür, Eğitim Bilimleri ve ÖABT puanları sorgulamaya açılmıştır.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.fact_check,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-dgs-res",
      organization: "ÖSYM • Sonuç",
      title: "2026-DGS Dikey Geçiş Sınavı Merkezi Yerleştirme Sonuçları",
      position: "DGS Yerleştirme Sonuçları",
      city: "Tüm Türkiye",
      date: "14.09.2026",
      quota: "55.000",
      deadline: "14.09.2026",
      applicationPlace: "ÖSYM Sonuç",
      employmentType: "Sonuç Duyurusu",
      applicationType: "Sonuç Ekranı",
      status: "Sonuç",
      contentType: "SONUC",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Ön Lisans",
      kpssStatus: "Muaf",
      requirements: const ["Yerleştirme belgesi çıktısı ile üniversite kaydı"],
      description: "Önlisans programlarından 4 yıllık lisans programlarına geçiş yerleştirme sonuçları açıklandı.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.assignment_turned_in,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-tus-res",
      organization: "ÖSYM • Sonuç",
      title: "2026-TUS Tıpta Uzmanlık Eğitimi Giriş Sınavı 2. Dönem Sonuçları",
      position: "TUS 2. Dönem Sonuçları",
      city: "Tüm Türkiye",
      date: "13.09.2026",
      quota: "Tıp Doktorları",
      deadline: "13.09.2026",
      applicationPlace: "ÖSYM Sonuç",
      employmentType: "Sonuç Duyurusu",
      applicationType: "Sonuç Ekranı",
      status: "Sonuç",
      contentType: "SONUC",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      requirements: const ["Tıp Fakültesi mezunu tıp doktorları"],
      description: "Temel Tıp ve Klinik Tıp branş sıralamaları ve uzmanlık kontenjanları sorgulama ekranı.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.medical_services,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-dus-res",
      organization: "ÖSYM • Sonuç",
      title: "2026-DUS Diş Hekimliğinde Uzmanlık Eğitimi Sınavı Sonuçları",
      position: "DUS Sonuç Açıklaması",
      city: "Tüm Türkiye",
      date: "10.09.2026",
      quota: "Diş Hekimleri",
      deadline: "10.09.2026",
      applicationPlace: "ÖSYM Sonuç",
      employmentType: "Sonuç Duyurusu",
      applicationType: "Sonuç Ekranı",
      status: "Sonuç",
      contentType: "SONUC",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      requirements: const ["Diş Hekimliği Fakültesi mezuniyeti"],
      description: "DUS 1. dönem uzmanlık eğitimi yerleştirme sonuçları erişime açıldı.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.medical_services,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "meb-ekys-res",
      organization: "ÖSYM • Sonuç",
      title: "2026-MEB-EKYS Eğitim Kurumlarına Yönetici Seçme Sonuçları",
      position: "EKYS Müdürlük Sonuçları",
      city: "Tüm Türkiye",
      date: "12.09.2026",
      quota: "12.000",
      deadline: "12.09.2026",
      applicationPlace: "ÖSYM Sonuç",
      employmentType: "Sonuç Duyurusu",
      applicationType: "Sonuç Ekranı",
      status: "Sonuç",
      contentType: "SONUC",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      requirements: const ["MEB kadrolu öğretmeni olmak"],
      description: "Okul müdürü ve müdür yardımcılığı yazılı sınavı kesin değerlendirme sonuçları.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.manage_accounts,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "disisleri-meslek-memuru",
      organization: "Dışişleri Bakanlığı",
      title: "110 Aday Meslek Memuru (Diplomat) Giriş Sınavı",
      position: "Aday Meslek Memuru (Diplomat)",
      city: "Ankara / Dış Temsilcilikler",
      date: "14.09.2026",
      quota: "110",
      deadline: "05.10.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Kariyer Meslek (Diplomat)",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      examDate: "20.12.2026",
      requirements: const ["Uluslararası İlişkiler, Siyaset Bilimi, Hukuk veya İktisat", "YDS en az 85 puan (İngilizce/Fransızca/Almanca)", "35 yaşını doldurmamış olmak"],
      description: "Büyükelçilikler ve başkonsolosluklarda diplomatik temsil görevi yapacak meslek memuru alımı.",
      officialUrl: "https://mfa.gov.tr",
      logoIcon: Icons.public,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "hazine-vergi-mufettis",
      organization: "Hazine ve Maliye Bakanlığı",
      title: "350 Vergi Müfettiş Yardımcısı Giriş Sınavı",
      position: "Vergi Müfettiş Yardımcısı",
      city: "Ankara / İstanbul / İzmir",
      date: "13.09.2026",
      quota: "350",
      deadline: "04.10.2026",
      applicationPlace: "VDK Sınav Portalı",
      employmentType: "Müfettiş Kadrosu",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "12.12.2026",
      requirements: const ["İİBF veya Hukuk fakültesi mezunu olmak", "KPSS A Grubu ilgili puan türünden en az 80", "Yazılı ve sözlü sınavda başarılı olmak"],
      description: "Vergi Denetim Kurulu (VDK) bünyesinde vergi incelemesi ve denetimi yapacak müfettişler.",
      officialUrl: "https://hmb.gov.tr",
      logoIcon: Icons.account_balance,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "adalet-icra-mudur",
      organization: "Adalet Bakanlığı",
      title: "700 İcra Müdür ve İcra Müdür Yardımcısı Seçme Sınavı",
      position: "İcra Müdürü / Müdür Yardımcısı",
      city: "Tüm İcra Daireleri",
      date: "11.09.2026",
      quota: "700",
      deadline: "01.10.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Adalet Memuru",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      examDate: "06.12.2026",
      requirements: const ["Hukuk veya Adalet Meslek Yüksekokulu mezuniyeti", "35 yaşını bitirmemiş olmak", "ÖSYM yazılı sınavında barajı aşmak"],
      description: "İcra ve İflas dairelerinde haciz, satış ve takip işlemlerini yürütecek müdürlük sınavı.",
      officialUrl: "https://pgm.adalet.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "cevre-iklim-uzman",
      organization: "Çevre ve Şehircilik Bakanlığı",
      title: "80 İklim Değişikliği Uzman Yardımcısı Alımı",
      position: "İklim Uzman Yardımcısı",
      city: "Ankara",
      date: "12.09.2026",
      quota: "80",
      deadline: "02.10.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Kariyer Meslek",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Çevre Mühendisliği veya Kimya lisans mezuniyeti", "KPSS P1/P3 en az 75", "YDS en az 70 puan"],
      description: "Karbon emisyon ticareti, yeşil dönüşüm ve çevre mevzuatı hazırlığı için teknik uzman alımı.",
      officialUrl: "https://iklim.gov.tr",
      logoIcon: Icons.forest,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "tarim-su-urunleri",
      organization: "Tarım ve Orman Bakanlığı",
      title: "120 Su Ürünleri ve Balıkçılık Mühendisi Alımı",
      position: "Su Ürünleri Mühendisi",
      city: "Kıyı ve İç Su Şube Müdürlükleri",
      date: "09.09.2026",
      quota: "120",
      deadline: "28.09.2026",
      applicationPlace: "ÖSYM Tercih",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Tercih",
      status: "Açık",
      contentType: "ILAN",
      category: "Bakanlıklar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Su Ürünleri Mühendisliği mezuniyeti", "KPSS P3 en az 68 puan", "Arazi şartlarına uyum"],
      description: "Deniz ve göllerde kaçak avcılık denetimi ve balık çiftliği ruhsatlandırma birimlerine istihdam.",
      officialUrl: "https://tarimorman.gov.tr",
      logoIcon: Icons.directions_boat,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "egm-poh-ozel-harekat",
      organization: "Polis Akademisi & EGM",
      title: "Polis Özel Harekat (PÖH) Branş Seçme ve Fiziki Parkur Takvimi",
      position: "Özel Harekat Polisi (PÖH)",
      city: "Gölbaşı / Ankara",
      date: "14.09.2026",
      quota: "1.500",
      deadline: "30.09.2026",
      applicationPlace: "Polis Akademisi",
      employmentType: "Emniyet Hizmetleri",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "MULAKAT",
      category: "Askeri & Emniyet",
      educationLevel: "Lise",
      kpssStatus: "KPSS'li",
      examDate: "18.10.2026",
      requirements: const ["Emniyet teşkilatı mensubu olmak veya POMEM/PMYO mezuniyeti", "Ağır fiziki dayanıklılık parkurunu geçmek", "Atış yeterliliği"],
      description: "Terörle mücadele ve operasyonel görevlerde yer alacak fiziki dayanıklılığı yüksek özel harekat personeli.",
      officialUrl: "https://pa.edu.tr",
      logoIcon: Icons.security,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "jandarma-lojistik-astsubay",
      organization: "Jandarma Genel Komutanlığı",
      title: "400 Lojistik ve İkmal Branşlı Sözleşmeli Astsubay Alımı",
      position: "Lojistik Astsubay",
      city: "Bölge Komutanlıkları",
      date: "10.09.2026",
      quota: "400",
      deadline: "29.09.2026",
      applicationPlace: "Jandarma PTS",
      employmentType: "Sözleşmeli Astsubay",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      examDate: "15.11.2026",
      requirements: const ["İlgili önlisans bölümlerinden mezun olmak", "KPSS P93 en az 65 puan", "27 yaşını aşmamış olmak"],
      description: "Muhasebe, ikmal, ulaştırma ve bakım onarım kadrolarında astsubay rütbesiyle görev alımı.",
      officialUrl: "https://vatandas.jandarma.gov.tr",
      logoIcon: Icons.military_tech,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "msb-harita-muhendis",
      organization: "Milli Savunma Bakanlığı (HGM)",
      title: "Harita Genel Müdürlüğü 60 Jeodezi ve Fotogrametri Mühendisi",
      position: "Harita Mühendisi",
      city: "Cebeci / Ankara",
      date: "08.09.2026",
      quota: "60",
      deadline: "27.09.2026",
      applicationPlace: "MSB Personel Temin",
      employmentType: "Sözleşmeli Mühendis",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Askeri & Emniyet",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Harita/Geomatik Mühendisliği mezuniyeti", "KPSS P3 en az 75 puan", "Güvenlik soruşturması (Gizli derece)"],
      description: "Uydu görüntüleme, coğrafi bilgi sistemleri ve askeri harita üretimi için mühendis istihdamı.",
      officialUrl: "https://personeltemin.msb.gov.tr",
      logoIcon: Icons.public,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "adana-itfaiye-eri",
      organization: "Adana Büyükşehir Belediyesi",
      title: "110 İtfaiye Eri ve Arama Kurtarma Teknisyeni Alımı",
      position: "İtfaiye Eri",
      city: "Adana",
      date: "07.09.2026",
      quota: "110",
      deadline: "25.09.2026",
      applicationPlace: "Adana BB",
      employmentType: "Memur Kadrosu",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      examDate: "16.10.2026",
      requirements: const ["İtfaiyecilik önlisans mezuniyeti", "KPSS P93 en az 60", "En az C sınıfı sürücü belgesi"],
      description: "Adana kent merkezi ve ilçelerinde yangın ve doğal afet müdahale istasyonlarına memur alımı.",
      officialUrl: "https://adana.bel.tr",
      logoIcon: Icons.local_fire_department,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "eskisehir-sehir-tiyatrolari",
      organization: "Eskişehir Büyükşehir Belediyesi",
      title: "45 Sahne Sanatları, Ses Işık Teknisyeni ve Sahne Amiri",
      position: "Sahne Amiri / Işık Teknisyeni",
      city: "Eskişehir",
      date: "05.09.2026",
      quota: "45",
      deadline: "24.09.2026",
      applicationPlace: "Eskişehir BB İK",
      employmentType: "Sözleşmeli Sanat Personeli",
      applicationType: "Uygulama Sınavı",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'siz",
      requirements: const ["Konservatuvar veya ilgili teknik MYO mezuniyeti", "Sahne deneyimi"],
      description: "Şehir Tiyatroları ve Senfoni Orkestrası sahnelerinde görev alacak teknik sanat kadrosu.",
      officialUrl: "https://eskisehir.bel.tr",
      logoIcon: Icons.music_note,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "mersin-imar-sehir-plancisi",
      organization: "Mersin Büyükşehir Belediyesi",
      title: "40 Şehir Plancısı ve CBS Uzmanı Alımı",
      position: "Şehir Plancısı / CBS Uzmanı",
      city: "Mersin",
      date: "09.09.2026",
      quota: "40",
      deadline: "28.09.2026",
      applicationPlace: "Mersin Kariyer",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["Şehir ve Bölge Planlama lisans mezuniyeti", "KPSS P3 en az 70 puan", "GIS yazılımlarına hakim olmak"],
      description: "Kıyı master planı ve kentsel dönüşüm alanları nazım imar planı çalışmalarında istihdam.",
      officialUrl: "https://mersin.bel.tr",
      logoIcon: Icons.location_city,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "samsun-fen-isleri-usta",
      organization: "Samsun Büyükşehir Belediyesi",
      title: "85 Asfalt Silindir Operatörü ve Duvar Ustası",
      position: "İş Makinesi Operatörü / Usta",
      city: "Samsun",
      date: "06.09.2026",
      quota: "85",
      deadline: "25.09.2026",
      applicationPlace: "İŞKUR Samsun",
      employmentType: "Sürekli İşçi",
      applicationType: "Kura + Uygulama",
      status: "Açık",
      contentType: "ILAN",
      category: "Belediyeler & Mahalli İdareler",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["G sınıfı operatörlük belgesi veya MEB ustalık belgesi", "Samsun il sınırlarında ikamet"],
      description: "Fen İşleri Daire Başkanlığı yol yapım şantiyelerinde istihdam edilecek daimi işçi.",
      officialUrl: "https://samsun.bel.tr",
      logoIcon: Icons.engineering,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "marmara-hukuk-akademik",
      organization: "Marmara Üniversitesi Hukuk Fakültesi",
      title: "20 Araştırma Görevlisi Alımı (Medeni Hukuk & Ceza Hukuku)",
      position: "Araştırma Görevlisi",
      city: "İstanbul (Göztepe)",
      date: "11.09.2026",
      quota: "20",
      deadline: "29.09.2026",
      applicationPlace: "Marmara Üni Personel",
      employmentType: "Akademik Personel (50/d)",
      applicationType: "Şahsen Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Yüksek Lisans",
      kpssStatus: "Muaf",
      examDate: "18.10.2026",
      requirements: const ["Hukuk lisans mezunu olmak", "ALES Eşit Ağırlık en az 80", "Yabancı dil (YDS) en az 75"],
      description: "Hukuk Fakültesi anabilim dallarında lisansüstü eğitim gören araştırmacılar için kadro ilanı.",
      officialUrl: "https://marmara.edu.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ytu-biyomuhendislik-arastirma",
      organization: "Yıldız Teknik Üniversitesi (YTÜ)",
      title: "25 Biyomühendislik ve Nanoteknoloji Araştırmacısı",
      position: "Araştırma Görevlisi",
      city: "İstanbul (Davutpaşa)",
      date: "13.09.2026",
      quota: "25",
      deadline: "02.10.2026",
      applicationPlace: "YTÜ Personel",
      employmentType: "Akademik Kadro",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Yüksek Lisans",
      kpssStatus: "Muaf",
      examDate: "22.10.2026",
      requirements: const ["Biyomühendislik veya Kimya Mühendisliği mezuniyeti", "ALES Sayısal en az 82", "İleri İngilizce"],
      description: "Teknopark bünyesindeki biyoteknoloji laboratuvarlarında çalışacak araştırmacılar.",
      officialUrl: "https://yildiz.edu.tr",
      logoIcon: Icons.science,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "cukurova-ziraat-akademik",
      organization: "Çukurova Üniversitesi Ziraat Fakültesi",
      title: "15 Öğretim Görevlisi ve Uzman Alımı",
      position: "Öğretim Görevlisi",
      city: "Adana (Balcalı)",
      date: "08.09.2026",
      quota: "15",
      deadline: "26.09.2026",
      applicationPlace: "Çukurova Rektörlük",
      employmentType: "Akademik Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "Üniversiteler & Akademik",
      educationLevel: "Yüksek Lisans",
      kpssStatus: "Muaf",
      examDate: "14.10.2026",
      requirements: const ["Ziraat Mühendisliği tezli yüksek lisans mezunu", "ALES en az 70 puan"],
      description: "Tarımsal sulama, bitki koruma ve biyoteknoloji araştırma uygulama merkezine personel.",
      officialUrl: "https://cu.edu.tr",
      logoIcon: Icons.forest,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "tcdd-ray-bakim-isci",
      organization: "TCDD Genel Müdürlüğü & İŞKUR",
      title: "450 Demiryolu Hattı Bakım ve Onarım İşçisi Alımı",
      position: "Yol Bakım Onarım İşçisi",
      city: "TCDD Bölge Müdürlükleri",
      date: "10.09.2026",
      quota: "450",
      deadline: "29.09.2026",
      applicationPlace: "İŞKUR",
      employmentType: "Daimi İşçi (Kadrolu)",
      applicationType: "Noter Kurası + Sağlık",
      status: "Açık",
      contentType: "ILAN",
      category: "İŞKUR & Kamu İşçi",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["Meslek lisesi raylı sistemler, inşaat veya makine", "Demiryolu sağlık kurul raporu", "Askerlik yapmış olmak"],
      description: "Ray değiştirme, travers montajı ve hat geometrisi kontrol ekiplerine ağır işçi alımı.",
      officialUrl: "https://tcdd.gov.tr",
      logoIcon: Icons.train,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ogm-fidanlik-isci",
      organization: "Orman Genel Müdürlüğü (OGM)",
      title: "600 Orman Fidanlığı Üretim ve Bakım İşçisi Alımı",
      position: "Fidan Yetiştirme İşçisi",
      city: "Bölge Fidanlık Müdürlükleri",
      date: "07.09.2026",
      quota: "600",
      deadline: "26.09.2026",
      applicationPlace: "İŞKUR",
      employmentType: "Geçici / Mevsimlik İşçi",
      applicationType: "Kura Usulü",
      status: "Açık",
      contentType: "ILAN",
      category: "İŞKUR & Kamu İşçi",
      educationLevel: "İlköğretim",
      kpssStatus: "KPSS'siz",
      requirements: const ["En az ilkokul mezuniyeti", "18-40 yaş aralığında olmak", "Fiziki çalışmaya engeli bulunmamak"],
      description: "Milli ağaçlandırma seferberliği kapsamında fidan üretimi, tüpleme ve sulama işleri.",
      officialUrl: "https://ogm.gov.tr",
      logoIcon: Icons.forest,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ilbank-muhendis-sehir-planci",
      organization: "İller Bankası A.Ş. (İLBANK)",
      title: "130 İnşaat, Harita ve Çevre Mühendisi Giriş Sınavı",
      position: "Teknik Uzman Yardımcısı",
      city: "Ankara / İstanbul / İzmir",
      date: "12.09.2026",
      quota: "130",
      deadline: "03.10.2026",
      applicationPlace: "İLBANK İnsan Kaynakları",
      employmentType: "Özel Hukuk Hükümlerine Tabi Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "KİT & Bankalar",
      educationLevel: "Lisans",
      kpssStatus: "KPSS'li",
      examDate: "28.11.2026",
      requirements: const ["İlgili mühendislik lisans mezuniyeti", "KPSS P1 en az 75 puan", "35 yaşını doldurmamış olmak"],
      description: "Belediyelerin içme suyu, arıtma ve kentsel altyapı projelerini finanse eden ve denetleyen uzman kadro.",
      officialUrl: "https://ilbank.gov.tr",
      logoIcon: Icons.account_balance,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "tubitak-savunma-arastirmaci",
      organization: "TÜBİTAK SAGE & BİLGEM",
      title: "180 Proje Teknisyeni ve Ar-Ge Araştırmacısı Alımı",
      position: "Savunma Ar-Ge Araştırmacısı",
      city: "Ankara / Gebze",
      date: "14.09.2026",
      quota: "180",
      deadline: "05.10.2026",
      applicationPlace: "TÜBİTAK Kariyer",
      employmentType: "Tam Zamanlı Proje Personeli",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "ILAN",
      category: "KİT & Bankalar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      requirements: const ["Elektrik-Elektronik, Havacılık, Yazılım Müh.", "En az 3.00 diploma notu", "Güvenlik incelemesinden geçmek"],
      description: "Güdümlü mühimmat, kriptoloji ve siber harp projelerinde görevlendirilecek uzman mühendisler.",
      officialUrl: "https://tubitak.gov.tr",
      logoIcon: Icons.science,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "turasas-vagon-imalat",
      organization: "TÜRASAŞ Türkiye Raylı Sistem Araçları A.Ş.",
      title: "200 Vagon İmalat Ustası ve CNC Freze Operatörü",
      position: "CNC Operatörü / Kaynak Ustası",
      city: "Sakarya / Eskişehir / Sivas",
      date: "09.09.2026",
      quota: "200",
      deadline: "28.09.2026",
      applicationPlace: "İŞKUR",
      employmentType: "KİT Kadrolu İşçisi",
      applicationType: "Kura + Uygulama Sınavı",
      status: "Açık",
      contentType: "ILAN",
      category: "KİT & Bankalar",
      educationLevel: "Lise",
      kpssStatus: "KPSS'siz",
      requirements: const ["Meslek lisesi talaşlı imalat veya kaynakçılık", "TÜRKAK akredite kaynakçı sertifikası"],
      description: "Milli elektrikli tren seti ve metro vagonlarının gövde montaj hatlarına işçi temini.",
      officialUrl: "https://turasas.gov.tr",
      logoIcon: Icons.precision_manufacturing,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "yokdil-sonbahar",
      organization: "ÖSYM",
      title: "2026-YÖKDİL/2 Yükseköğretim Kurumları Yabancı Dil Sınavı",
      position: "YÖKDİL/2 (Fen, Sağlık, Sosyal)",
      city: "Tüm İller",
      date: "07.09.2026",
      quota: "180.000 Aday",
      deadline: "24.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Akademik Dil Sınavı",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      examDate: "25.10.2026",
      requirements: const ["Lisans mezunu veya lisans öğrencisi olmak", "80 soru, 180 dakika"],
      description: "Lisansüstü tez, doçentlik ve TUS/DUS başvurularında kullanılan alan bazlı dil yeterlilik sınavı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.language,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "msu-askeri-ogrenci",
      organization: "ÖSYM & Milli Savunma Bakanlığı",
      title: "2026-MSÜ Milli Savunma Üniversitesi Askeri Öğrenci Sınavı",
      position: "Harp Okulları ve Astsubay MYO Sınavı",
      city: "81 İl",
      date: "10.09.2026",
      quota: "450.000 Aday",
      deadline: "01.10.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Askeri Seçme Sınavı",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lise",
      kpssStatus: "Muaf",
      examDate: "20.12.2026",
      requirements: const ["Lise son sınıf öğrencisi veya mezun olmak", "En fazla 20 yaşında olmak", "Askeri öğrenci kriterlerini taşımak"],
      description: "Kara, Deniz, Hava Harp Okulları ile Bando ve Kuvvet Astsubay MYO aday belirleme sınavı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.military_tech,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "kpss-dhbt-sinavi",
      organization: "ÖSYM & Diyanet İşleri Başkanlığı",
      title: "2026-KPSS Din Hizmetleri Alan Bilgisi Testi (DHBT)",
      position: "DHBT Sınavı (İmam-Hatip / Kur'an Kursu)",
      city: "İl Merkezleri",
      date: "12.09.2026",
      quota: "300.000 Aday",
      deadline: "02.10.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Mesleki Alan Sınavı",
      applicationType: "Online Başvuru",
      status: "Açık",
      contentType: "SINAV",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lise",
      kpssStatus: "KPSS'li",
      examDate: "13.12.2026",
      requirements: const ["İmam Hatip Lisesi veya İlahiyat Fakültesi mezuniyeti", "KPSS genel yetenek genel kültür oturumuna girmiş olmak"],
      description: "Diyanet teşkilatına imam-hatip, müezzin-kayyım ve Kur'an kursu öğreticisi alım sınavı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.auto_stories,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "sonuc-sayistay-yazili",
      organization: "Sayıştay Başkanlığı • Sonuç",
      title: "2026 Sayıştay Denetçi Yardımcılığı Yazılı Sınav Sonuçları",
      position: "Mülakata Kalanlar Listesi",
      city: "Ankara",
      date: "14.09.2026",
      quota: "135 Mülakat Çağrısı",
      deadline: "14.09.2026",
      applicationPlace: "Sayıştay Duyurular",
      employmentType: "Sonuç Duyurusu",
      applicationType: "Sonuç Listesi",
      status: "Sonuç",
      contentType: "SONUC",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Lisans",
      kpssStatus: "Muaf",
      requirements: const ["Sözlü sınav giriş belgesi ve mülakat formunun teslimi"],
      description: "Yazılı sınavda başarılı olup sözlü mülakata katılmaya hak kazanan adayların listesi ve taban puanlar.",
      officialUrl: "https://sayistay.gov.tr",
      logoIcon: Icons.assignment_turned_in,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "sonuc-kpss-onlisans-yerlestirme",
      organization: "ÖSYM • Sonuç",
      title: "2026/2 Bazı Kamu Kurum ve Kuruluşlarına Merkezi Yerleştirme Sonuçları",
      position: "KPSS Tercih Sonuçları",
      city: "Tüm Türkiye",
      date: "15.09.2026",
      quota: "4.500",
      deadline: "15.09.2026",
      applicationPlace: "ÖSYM Sonuç",
      employmentType: "Sonuç Duyurusu",
      applicationType: "Sonuç Ekranı",
      status: "Sonuç",
      contentType: "SONUC",
      category: "ÖSYM & Sınavlar",
      educationLevel: "Ön Lisans",
      kpssStatus: "KPSS'li",
      requirements: const ["ÖSYM AIS sonuç sorgulama"],
      description: "Önlisans ve ortaöğretim mezunları için merkezi B grubu kadro yerleştirme sonuçları yayınlanmıştır.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.checklist,
      isAlarmActive: false,
    ),
  ];


  int get _activeCount => _channels.where((c) => c.isAlarmActive).length;

  // 🔒 Sistemde VIP olmayan kullanıcı için açık olan YALNIZCA 4 sabit ilan (Filtrelese bile sadece bunlar açık)
  static const Set<String> _freeAnnouncementIds = {
    "saglik-01",
    "polis-01",
    "adalet-01",
    "jandarma-01",
  };

  bool _isChannelLocked(ChannelAlarm ch) {
    if (_effectiveVip) return false;
    return !_freeAnnouncementIds.contains(ch.id);
  }

  int _selectedTabIndex = 0; // 0: İlanlar, 1: Sınav Takvimi, 2: Sonuç & Mülakat
  String _selectedCategory = "Tümü";
  String _selectedKpss = "Tümü";
  String _selectedEducation = "Tümü";

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

  List<ChannelAlarm> get _filteredChannels {
    return _channels.where((c) {
      if (_selectedTabIndex == 0 && c.contentType != "ILAN") return false;
      if (_selectedTabIndex == 1 && c.contentType != "SINAV") return false;
      if (_selectedTabIndex == 2 && c.contentType != "MULAKAT" && c.contentType != "SONUC") return false;
      if (_selectedCategory != "Tümü" && c.category != _selectedCategory) return false;
      if (_selectedKpss != "Tümü" && c.kpssStatus != _selectedKpss) return false;
      if (_selectedEducation != "Tümü" && c.educationLevel != _selectedEducation) return false;
      return true;
    }).toList();
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
                          _selectedCategory = "Tümü";
                          _selectedKpss = "Tümü";
                          _selectedEducation = "Tümü";
                        });
                        setModalState(() {});
                      },
                      child: const Text("Sıfırla", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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

  // 👑 VIP & PREMIUM İLAN KİLİDİ POP-UP'I (3 PAKETLİ)
  void _showPremiumUpgradePopUp() {
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
            const Text(
              "Tüm İlanların Kilidini Açın",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              "İlk 4 ilan ücretsizdir. Bu ilan ve diğer 50 güncel kamu alımını görmek, anlık alarmlar ve özel web sitesi nöbetçisi için paket seçin.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 18),

            // 1. Paket: Yıllık VIP (En Popüler)
            InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Google Play Store güvenli satın alma penceresi açılıyor...")),
                );
                final success = await InAppPurchaseService.instance.buyProduct(InAppPurchaseService.yearlyVipId);
                if (!success) {
                  // Fallback: Aile Planı Ekranına yönlendir
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
                    const Text("Yıllık VIP (4 Kişilik Aile Planı)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    const Text("1 Yıl boyunca tüm ilanlar açık, özel web sitesi nöbetçisi ve 3 arkadaş slotu.", style: TextStyle(color: Colors.white70, fontSize: 10)),
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
                  // Fallback: Aile Planı Ekranına yönlendir
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
                        Text("Aylık VIP Aile Paketi (4 Kişi)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text("Tüm kilitler açık, özel web nöbetçisi, 3 arkadaş dahil.", style: TextStyle(fontSize: 10, color: Colors.black54)),
                      ],
                    ),
                    Text("39.99 ₺ / ay", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF0F172A))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Şimdilik Ücretsiz İlk 4 İlanla Devam Et", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
                  : "Ücretsiz hesaplarda ayda 3 adet anlık bildirim alma hakkınız vardır. Reklam izleyerek anında +2 ek bildirim hakkı kazanabilirsiniz!",
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
                  Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.green), SizedBox(width: 8), Text("1 Öde, 4 Kişi Kullan (3 Arkadaşını Ücretsiz Ekle)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))]),
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
                  setState(() => _isUserVip = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("👑 VIP Aktif! Sınırsız bildirim alımı açıldı.")),
                  );
                },
                child: const Text("39.99 ₺ ile Sınırsız VIP Yap (+3 Arkadaş)", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
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
                                _showPremiumUpgradePopUp();
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
