import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../services/cache_service.dart';
import '../services/ad_service.dart';
import 'profile_settings_screen.dart';
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
  final String description;
  final String officialUrl;
  final IconData logoIcon;
  bool isAlarmActive;

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
      id: "ann-01",
      organization: "Sağlık Bakanlığı",
      title: "Sağlık Bakanlığı Hemşire Alımı",
      position: "Hemşire Alımı",
      city: "Ankara",
      date: "15.09.2025",
      quota: "250",
      deadline: "30.09.2025",
      applicationPlace: "ÖSYM",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
        "Kamu haklarından mahrum bulunmamak.",
        "Sağlık açısından görevini yapmasına engel bir durumu olmamak.",
        "KPSS'den ilgili puan türünden en az 70 puan almak.",
        "Hemşirelik lisans veya önlisans programından mezun olmak.",
      ],
      description: "Sağlık Bakanlığı taşra ve merkez teşkilatı için 250 hemşire alımı ÖSYM KPSS-2025/5 tercih kılavuzuyla başladı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.local_hospital,
      isAlarmActive: true,
    ),
    ChannelAlarm(
      id: "ann-02",
      organization: "Milli Eğitim Bakanlığı",
      title: "MEB 20.000 Sözleşmeli Öğretmen Alımı",
      position: "Sözleşmeli Öğretmen Alımı",
      city: "Tüm Türkiye",
      date: "14.09.2025",
      quota: "20.000",
      deadline: "28.09.2025",
      applicationPlace: "MEB İlkatama",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
        "Kamu haklarından mahrum bulunmamak.",
        "KPSS ilgili ÖABT alan puanından taban puanı geçmiş olmak.",
        "Pedagojik formasyon ve ilgili öğretmenlik lisans diplomasına sahip olmak.",
      ],
      description: "Sınıf öğretmenliği, özel eğitim, İngilizce ve din kültürü başta olmak üzere 20.000 sözleşmeli öğretmen alım süreci.",
      officialUrl: "https://ilkatama.meb.gov.tr",
      logoIcon: Icons.school,
      isAlarmActive: true,
    ),
    ChannelAlarm(
      id: "ann-03",
      organization: "Emniyet Genel Müdürlüğü",
      title: "32. Dönem POMEM 10.000 Polis Memuru Alımı",
      position: "Polis Memuru Alımı",
      city: "Ankara",
      date: "13.09.2025",
      quota: "10.000",
      deadline: "26.09.2025",
      applicationPlace: "Polis Akademisi",
      employmentType: "Emniyet Hizmetleri",
      applicationType: "Online Başvuru",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
        "30 yaşından gün almamış olmak.",
        "Lisans için KPSS P3 en az 60, önlisans için KPSS P93 en az 65 almak.",
        "Emniyet Teşkilatı Sağlık Şartları Yönetmeliğinde belirtilen fiziki koşulları taşımak.",
      ],
      description: "8.000 lisans ve 2.000 önlisans mezunu adaylar arasından POMEM polis memuru alımı fiziki yeterlilik parkuru ve başvuru süreci.",
      officialUrl: "https://www.pa.edu.tr",
      logoIcon: Icons.shield,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ann-04",
      organization: "Tarım ve Orman Bakanlığı",
      title: "Tarım ve Orman Bakanlığı 1.500 Büro Personeli Alımı",
      position: "Büro Personeli Alımı",
      city: "Tüm Türkiye",
      date: "12.09.2025",
      quota: "1.500",
      deadline: "26.09.2025",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "e-Devlet Üzerinden",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
        "Kamu haklarından mahrum bulunmamak.",
        "İktisat, işletme veya büro yönetimi lisans/önlisans mezunu olmak.",
        "KPSS P3 veya P93 puan türünden en az 70 puan almış olmak.",
      ],
      description: "Tarım ve Orman Bakanlığı ile OGM bünyesinde istihdam edilmek üzere 1.500 büro personeli alımı.",
      officialUrl: "https://www.tarimorman.gov.tr",
      logoIcon: Icons.park,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ann-05",
      organization: "Adalet Bakanlığı",
      title: "Adalet Bakanlığı 12.500 Zabıt Katibi & İKM Alımı",
      position: "Zabıt Katibi Alımı",
      city: "Ankara",
      date: "11.09.2025",
      quota: "12.500",
      deadline: "28.09.2025",
      applicationPlace: "Adalet Bakanlığı (PGM)",
      employmentType: "Sözleşmeli Personel",
      applicationType: "e-Devlet Üzerinden",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
        "35 yaşını bitirmemiş olmak.",
        "Uygulamalı klavye sınavında 3 dakikada en az 90 doğru kelime yazmak.",
        "KPSS en az 70 taban puan almış olmak.",
      ],
      description: "Adliyeler ve Ceza İnfaz Kurumları için KPSS 70 taban puanla zabıt katibi, mübaşir ve infaz koruma memuru alımı.",
      officialUrl: "https://pgm.adalet.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ann-06",
      organization: "Belediye",
      title: "İstanbul ve Ankara Belediyeleri Temizlik İşçisi Alımı",
      position: "İşçi Alımı (Temizlik Görevlisi)",
      city: "İstanbul",
      date: "10.09.2025",
      quota: "500",
      deadline: "22.09.2025",
      applicationPlace: "İŞKUR / Belediye",
      employmentType: "Sürekli İşçi",
      applicationType: "Online Başvuru",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
        "En az ilkokul mezunu olmak.",
        "Vardiyalı ve açık alanda çalışmaya engel sağlık sorunu bulunmamak.",
        "İlgili il sınırları içinde ikamet ediyor olmak.",
      ],
      description: "Büyükşehir belediyeleri ve bağlı iştirakler bünyesinde görevlendirilmek üzere 500 temizlik personeli sürekli işçi alımı.",
      officialUrl: "https://www.turkiye.gov.tr",
      logoIcon: Icons.location_city,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ann-07",
      organization: "Jandarma Genel K.",
      title: "Jandarma 2.500 Uzman Erbaş Alımı",
      position: "Uzman Erbaş Alımı",
      city: "Tüm Türkiye",
      date: "09.09.2025",
      quota: "2.500",
      deadline: "28.09.2025",
      applicationPlace: "Jandarma PTM",
      employmentType: "Uzman Erbaş",
      applicationType: "Online Başvuru",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı ve erkek olmak.",
        "27 yaşını bitirmemiş olmak.",
        "En az lise ve dengi okul mezunu olmak.",
        "Askerlik ve sağlık şartlarını eksiksiz taşımak.",
      ],
      description: "Asayiş, komando ve sıhhiye branşlarında en az lise mezunu uzman erbaş temin süreci.",
      officialUrl: "https://vatandas.jandarma.gov.tr/PTM/Giris",
      logoIcon: Icons.military_tech,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ann-08",
      organization: "Milli Savunma Bakanlığı",
      title: "MSÜ Askeri Öğrenci & Subay Alımı",
      position: "Subay / Astsubay Alımı",
      city: "Ankara",
      date: "08.09.2025",
      quota: "3.200",
      deadline: "05.10.2025",
      applicationPlace: "MSB Personel Temin",
      employmentType: "Muvazzaf Askeri Personel",
      applicationType: "Online Başvuru",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
        "Harp Okulları için 20, Astsubay MYO için 21 yaşından büyük olmamak.",
        "MSÜ ve YKS baraj puanını sağlamış olmak.",
        "Fiziki yeterlilik parkuru ve mülakat aşamalarını geçmek.",
      ],
      description: "Kara, Deniz, Hava Harp Okulları ile Astsubay Meslek Yüksekokulları askeri öğrenci ve subay aday belirleme süreci.",
      officialUrl: "https://personeltemin.msb.gov.tr",
      logoIcon: Icons.military_tech,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ann-09",
      organization: "Gelir İdaresi Başkanlığı",
      title: "1.271 Gelir Uzman Yardımcısı (GUY) Alımı",
      position: "Gelir Uzman Yardımcısı (GUY)",
      city: "Ankara",
      date: "07.09.2025",
      quota: "1.271",
      deadline: "30.09.2025",
      applicationPlace: "GİB Sınav Portalı",
      employmentType: "Kariyer Meslek Memuru",
      applicationType: "Online Başvuru",
      requirements: const [
        "İİBF, SBF veya Hukuk fakültesi mezunu olmak.",
        "35 yaşını doldurmamış olmak.",
        "KPSS A Grubu ilgili puan türlerinden en az 70 almak.",
        "Yazılı ve sözlü sınavda başarılı olmak.",
      ],
      description: "Hazine ve Maliye Bakanlığı Gelir İdaresi Başkanlığı bünyesinde 1.271 Gelir Uzman Yardımcısı istihdam edilecektir.",
      officialUrl: "https://www.gib.gov.tr",
      logoIcon: Icons.trending_up,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ann-10",
      organization: "İŞKUR",
      title: "MEB 40.000 Okul Güvenlik & Temizlik (TYP)",
      position: "TYP Güvenlik & Temizlik",
      city: "Tüm Türkiye",
      date: "06.09.2025",
      quota: "40.000",
      deadline: "24.09.2025",
      applicationPlace: "İŞKUR e-Şube",
      employmentType: "Toplum Yararına Program",
      applicationType: "Online Başvuru",
      requirements: const [
        "İŞKUR'a kayıtlı işsiz olmak.",
        "18 yaşını tamamlamış olmak.",
        "Emekli ve malul aylığı almamak.",
        "Hane geliri asgari ücretin 1.5 katını aşmamak.",
      ],
      description: "81 il milli eğitim müdürlüklerine bağlı okullarda görev yapacak 40.000 temizlik ve güvenlik görevlisi alımı.",
      officialUrl: "https://esube.iskur.gov.tr",
      logoIcon: Icons.work,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ann-11",
      organization: "ÖSYM",
      title: "2026-KPSS Lisans & Önlisans Takvimi",
      position: "2026-KPSS Başvuru Takvimi",
      city: "Tüm Türkiye",
      date: "05.09.2025",
      quota: "Genel Sınav",
      deadline: "02.10.2025",
      applicationPlace: "ÖSYM AİS",
      employmentType: "Kamu Personel Sınavı",
      applicationType: "AİS Online Başvuru",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı veya mavi kart sahibi olmak.",
        "Lisans veya önlisans programından mezun veya mezun olabilir durumda olmak.",
        "ÖSYM AİS şifresine veya e-Devlet girişine sahip olmak.",
      ],
      description: "KPSS Lisans ve Önlisans sınav başvuru ve sonuç takibi.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
  ];


  int get _activeCount => _channels.where((c) => c.isAlarmActive).length;

  Future<void> _launchUrl(String url) async {
    if (_effectiveVip) {
      _directLaunchUrl(url);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Resmî sayfaya yönlendiriliyorsunuz..."),
        duration: Duration(seconds: 1),
      ),
    );

    AdService.instance.showInterstitialAd(
      onComplete: () {
        _directLaunchUrl(url);
      },
    );
  }

  Future<void> _directLaunchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Yönlendiriliyor: $url")),
        );
      }
    }
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
              "İlk 4 ilan ücretsizdir. Bu ilan ve diğer 16 kamu alımını görmek, alarmlarını açmak ve sıfır reklam deneyimi için paket seçin.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 18),

            // 1. Paket: Yıllık VIP (En Popüler)
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _isUserVip = true);
                widget.onUpgradeVip?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("👑 Yıllık VIP Aile Planı Aktif! Tüm 20 ilanın kilidi açıldı ve reklamlar kaldırıldı.")),
                );
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
                    const Text("1 Yıl boyunca tüm ilanlar açık, sıfır reklam, 3 arkadaş slotu ve sınırsız alarmlar.", style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 2. Paket: Aylık VIP
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _isUserVip = true);
                widget.onUpgradeVip?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("👑 Aylık VIP Aile Planı Aktif! Tüm 20 ilanın kilidi açıldı.")),
                );
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
                        Text("Tüm kilitler açık, sıfır reklam, 3 arkadaş dahil.", style: TextStyle(fontSize: 10, color: Colors.black54)),
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
    CacheService.saveActiveAlarms(
      _channels.where((c) => c.isAlarmActive).map((c) => c.id).toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(channel.isAlarmActive
            ? "🔔 ${channel.title} radara eklendi! İlan çıktığında bildirim kotanızdan iletilecektir."
            : "${channel.title} takibi kapatıldı."),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSoft,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.radar, color: AppTheme.primaryBlue, size: 22),
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
                  const Text("Günde 1 Kez Toplu Tarama:", style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(
                    _isUserVip ? "VIP Sınırsız Bildirim (12:00)" : "Kalan Bildirim: $_remainingNotifications / $_totalAllowedNotifications Hak",
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.notifications_active, color: AppTheme.primaryBlue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "İlan okumakla vakit kaybetmeyin. İlgilendiğiniz alımların zilini açık bırakın; yeni ilan açıldığında her gün saat 12:00'de telefonunuza bildirim gelsin!",
                        style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Takip Kanalları
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Takip & Alarm Kanalları", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(
                    "$_activeCount Takvim Radarda Açık",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _channels.length,
              itemBuilder: (context, index) {
                final ch = _channels[index];
                final isLocked = index >= 4 && !_effectiveVip;

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
                        status: "Açık",
                        logoIcon: ch.logoIcon,
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
                            color: const Color(0xFFDC2626), // Kırmızı amblem tonu
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Kurum, Pozisyon ve Lokasyon/Tarih Bilgisi
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ch.organization,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ch.position,
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
                                  const SizedBox(width: 10),
                                  const Icon(Icons.access_time, size: 11, color: Colors.white54),
                                  const SizedBox(width: 2),
                                  Text(
                                    ch.date,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Zil butonu
                        InkWell(
                          onTap: isLocked ? null : () => _toggleChannelAlarm(ch),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Icon(
                              ch.isAlarmActive ? Icons.notifications_active : Icons.notifications_none,
                              color: ch.isAlarmActive ? const Color(0xFF22C55E) : Colors.white38,
                              size: 19,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // "Açık" yeşil hap rozet
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Açık",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                );

                if (!isLocked) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: cardBody,
                  );
                }

                // 5. İlandan İtibaren Buzlu (Blur) & Kilitli Kart
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                          child: cardBody,
                        ),
                        Positioned.fill(
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.65),
                            child: InkWell(
                              onTap: () {
                                _showPremiumUpgradePopUp();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.lock, color: Colors.amber, size: 20),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      "👑 Bu İlan VIP Üyelere Özeldir",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      "İlk 4 ilan ücretsizdir. Kalan 16 ilanın kilidini açmak için VIP'e geçin.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 10, color: Colors.black54),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        "Kilidi Aç (VIP)",
                                        style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10),
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
