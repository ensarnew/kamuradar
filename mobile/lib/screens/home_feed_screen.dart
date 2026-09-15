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
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Hemşire, ebe, sağlık teknikeri, büro personeli ve güvenlik alımları ÖSYM/İŞKUR üzerinden alınıyor.",
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
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Lisans ve önlisans mezunu adaylar için 32. Dönem POMEM fiziki yeterlilik ve başvuru takvimi başladı.",
      officialUrl: "https://pa.edu.tr",
      logoIcon: Icons.local_police,
      isAlarmActive: true,
    ),
    ChannelAlarm(
      id: "adalet-01",
      organization: "Adalet Bakanlığı",
      title: "12.500 Zabıt Katibi, Mübaşir ve İnfaz Koruma Memuru (İKM)",
      position: "12.500 Zabıt Katibi, Mübaşir",
      city: "Tüm Türkiye",
      date: "10.09.2026",
      quota: "12.500",
      deadline: "28.09.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Adliyeler ve CTE cezaevleri için KPSS 70 taban puanla personel alım başvuruları e-Devlet kapısında.",
      officialUrl: "https://pgm.adalet.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "jandarma-01",
      organization: "Jandarma Genel Komutanlığı",
      title: "6.500 Sözleşmeli Uzman Erbaş ve Jandarma Asayiş Alımı",
      position: "6.500 Sözleşmeli Uzman Erbaş",
      city: "Tüm Türkiye",
      date: "07.09.2026",
      quota: "6.500",
      deadline: "24.09.2026",
      applicationPlace: "Jandarma PTS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "En az lise mezunu 27 yaşını doldurmamış adaylar arasından komando ve asayiş uzman erbaş alımı.",
      officialUrl: "https://vatandas.jandarma.gov.tr",
      logoIcon: Icons.shield,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "polis-bekci",
      organization: "Emniyet Genel Müdürlüğü",
      title: "Çarşı ve Mahalle Bekçiliği 3.200 Kontenjan Başvurusu",
      position: "Çarşı ve Mahalle Bekçiliği",
      city: "Tüm Türkiye",
      date: "05.09.2026",
      quota: "3.200",
      deadline: "22.09.2026",
      applicationPlace: "Polis Akademisi",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "İl emniyet müdürlükleri bünyesinde istihdam edilmek üzere en az lise mezunu erkek bekçi alımı.",
      officialUrl: "https://pa.edu.tr",
      logoIcon: Icons.local_police,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "gib-guy",
      organization: "Gelir İdaresi Başkanlığı",
      title: "1.271 Gelir Uzman Yardımcısı (GUY) Giriş Sınavı",
      position: "1.271 Gelir Uzman Yardımcısı",
      city: "Ankara",
      date: "01.09.2026",
      quota: "1.271",
      deadline: "20.09.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "İİBF, SBF ve Hukuk fakültesi mezunları için 81 il taşra teşkilatına GUY alımı başvuruları açık.",
      officialUrl: "https://gib.gov.tr",
      logoIcon: Icons.account_balance,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "sayistay-01",
      organization: "ÖSYM • Sayıştay",
      title: "2026-Sayıştay Denetçi Yardımcılığı Eleme Sınavı",
      position: "2026-Sayıştay Denetçi Yardımcılığı Eleme",
      city: "Tüm Türkiye",
      date: "01.09.2026",
      quota: "2026",
      deadline: "18.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Sayıştay Başkanlığı denetçi yardımcısı adayı eleme sınavı başvuruları ÖSYM AIS üzerinden açık.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.account_balance,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "msb-er",
      organization: "Milli Savunma Bakanlığı",
      title: "Kara ve Hava Kuvvetleri 8.000 Sözleşmeli Er Temini",
      position: "Kara ve Hava Kuvvetleri",
      city: "Ankara",
      date: "01.09.2026",
      quota: "8.000",
      deadline: "25.09.2026",
      applicationPlace: "MSB Personel Temin",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "En az ilköğretim mezunu 25 yaşını bitirmemiş vatandaşlar için sözleşmeli erbaş/er temin başvurusu.",
      officialUrl: "https://personeltemin.msb.gov.tr",
      logoIcon: Icons.military_tech,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "meb-ogretmen",
      organization: "Milli Eğitim Bakanlığı",
      title: "20.000 Sözleşmeli Öğretmenlik Tercih ve Sözlü Sınavı",
      position: "20.000 Sözleşmeli Öğretmenlik Tercih",
      city: "Tüm Türkiye",
      date: "06.09.2026",
      quota: "20.000",
      deadline: "21.09.2026",
      applicationPlace: "MEB İlkatama",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Branş bazında kontenjan dağılımı yayımlandı; öğretmen adayları için tercih süreci e-Devlet üzerinden sürüyor.",
      officialUrl: "https://ilkatama.meb.gov.tr",
      logoIcon: Icons.school,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "iskur-typ-okul",
      organization: "İŞKUR • MEB",
      title: "Toplum Yararına Program (TYP) 40.000 Okul Güvenlik & Temizlik",
      position: "Toplum Yararına Program (TYP)",
      city: "Tüm Türkiye",
      date: "09.09.2026",
      quota: "40.000",
      deadline: "23.09.2026",
      applicationPlace: "İŞKUR e-Şube",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "2026-2027 Eğitim öğretim yılı için 81 il genelinde MEB bünyesinde TYP temizlik ve güvenlik alımı.",
      officialUrl: "https://esube.iskur.gov.tr",
      logoIcon: Icons.school,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "gsb-yurt",
      organization: "Gençlik ve Spor Bakanlığı",
      title: "1.500 Yurt Yönetim Personeli ve Destek Elemanı Alımı",
      position: "1.500 Yurt Yönetim Personeli",
      city: "Tüm Türkiye",
      date: "11.09.2026",
      quota: "1.500",
      deadline: "26.09.2026",
      applicationPlace: "Kariyer Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "KYK yurtlarında görevlendirilmek üzere lisans ve önlisans mezunları için sözleşmeli personel alımı.",
      officialUrl: "https://isealimkariyerkapisi.cbiko.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "belediye-zbt",
      organization: "Büyükşehir Belediyeleri",
      title: "İBB, ABB ve İZBB 1.800 Zabıta Memuru ve İtfaiye Eri Alımı",
      position: "İBB, ABB ve İZBB",
      city: "Tüm Türkiye",
      date: "08.09.2026",
      quota: "1.800",
      deadline: "22.09.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Kadın ve erkek adaylar için KPSS puanı ve boy-kilo şartıyla memur kadroları başvuruları başladı.",
      officialUrl: "https://turkiye.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-dhbt",
      organization: "ÖSYM",
      title: "2026-KPSS Din Hizmetleri Alan Bilgisi (DHBT) Başvuruları",
      position: "2026-KPSS Din Hizmetleri Alan",
      city: "Tüm Türkiye",
      date: "01.10.2026",
      quota: "2026",
      deadline: "15.10.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Diyanet İşleri Başkanlığı Kur'an kursu öğreticisi, imam-hatip ve müezzin-kayyım kadroları sınavı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "kaymakam-01",
      organization: "İçişleri Bakanlığı",
      title: "2026 Yılı 113. Dönem Kaymakam Adaylığı Giriş Sınavı",
      position: "2026 Yılı 113. Dönem",
      city: "Ankara",
      date: "08.10.2026",
      quota: "2026",
      deadline: "22.10.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Mülki İdare Amirliği Hizmetleri Sınıfı için 100 kaymakam adayı sınavı takvimi ve şartları.",
      officialUrl: "https://icisleri.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "hakim-savci-01",
      organization: "Adalet Bakanlığı • ÖSYM",
      title: "2026-Adli ve İdari Yargı Hakim & Savcı Yardımcılığı Sınavı",
      position: "2026-Adli ve İdari Yargı",
      city: "Tüm Türkiye",
      date: "15.10.2026",
      quota: "2026",
      deadline: "30.10.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "1.000 adli yargı, 100 avukatlık adli yargı ve 100 idari yargı hakim yardımcısı yazılı sınav başvurusu.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "msb-deniz-01",
      organization: "Milli Savunma Bakanlığı",
      title: "Deniz Kuvvetleri 2.500 Sözleşmeli Er ve Dalgıç Temini",
      position: "Deniz Kuvvetleri 2.500 Sözleşmeli",
      city: "Ankara",
      date: "05.10.2026",
      quota: "2.500",
      deadline: "25.10.2026",
      applicationPlace: "MSB Personel Temin",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Deniz Kuvvetleri Komutanlığı yüzer ve kıyı birlikleri için sözleşmeli personel alım dönemi.",
      officialUrl: "https://personeltemin.msb.gov.tr",
      logoIcon: Icons.military_tech,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "paem-01",
      organization: "Polis Akademisi",
      title: "PAEM 8. Dönem Emniyet Mensubu Olmayan Komiser Yardımcısı",
      position: "PAEM 8. Dönem Emniyet",
      city: "Tüm Türkiye",
      date: "12.10.2026",
      quota: "Genel Kontenjan",
      deadline: "28.10.2026",
      applicationPlace: "Polis Akademisi",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Lisans mezunları arasından ilk derece amir eğitimi için komiser yardımcısı adayı temini.",
      officialUrl: "https://pa.edu.tr",
      logoIcon: Icons.local_police,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "jandarma-subay-01",
      organization: "Jandarma ve Sahil Güvenlik",
      title: "2026 Yılı Muvazzaf/Sözleşmeli Subay ve Astsubay Alımı",
      position: "2026 Yılı Muvazzaf/Sözleşmeli Subay",
      city: "Tüm Türkiye",
      date: "16.10.2026",
      quota: "2026",
      deadline: "05.11.2026",
      applicationPlace: "Jandarma PTS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Yakında",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "JSGA bünyesinde istihdam edilmek üzere kadın ve erkek subay/astsubay alım takvimi.",
      officialUrl: "https://vatandas.jandarma.gov.tr",
      logoIcon: Icons.shield,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "dsi-muhendis-01",
      organization: "Devlet Su İşleri (DSİ)",
      title: "DSİ 1.253 Sözleşmeli Mühendis, Mimar ve Şehir Plancısı Alımı",
      position: "DSİ 1.253 Sözleşmeli Mühendis,",
      city: "Tüm Türkiye",
      date: "20.10.2026",
      quota: "1.253",
      deadline: "06.11.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Bölge müdürlüklerine inşaat, ziraat, makine ve harita mühendisliği kadroları için alım duyurusu.",
      officialUrl: "https://dsi.gov.tr",
      logoIcon: Icons.park,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "karayollari-01",
      organization: "Karayolları Genel Müdürlüğü (KGM)",
      title: "KGM 850 Düz İşçi, Asfalt ve Operatör Kadrosu Temini",
      position: "KGM 850 Düz İşçi,",
      city: "Tüm Türkiye",
      date: "24.10.2026",
      quota: "850",
      deadline: "10.11.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Kış bakım hazırlıkları kapsamında Türkiye geneli bölge şefliklerine sürekli işçi alımı.",
      officialUrl: "https://kgm.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "sgk-denetmen-01",
      organization: "Sosyal Güvenlik Kurumu (SGK)",
      title: "500 Sosyal Güvenlik Denetmen Yardımcısı Alımı",
      position: "500 Sosyal Güvenlik Denetmen",
      city: "Tüm Türkiye",
      date: "01.11.2026",
      quota: "500",
      deadline: "18.11.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "KPSS P23 ve P47 puan türlerinden mülakat usulüyle SGK denetmen yardımcısı alımı süreci.",
      officialUrl: "https://sgk.gov.tr",
      logoIcon: Icons.account_balance,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "gumruk-muhafaza-01",
      organization: "Ticaret Bakanlığı",
      title: "1.500 Gümrük Muhafaza Memuru ve Muayene Memuru Alımı",
      position: "1.500 Gümrük Muhafaza Memuru",
      city: "Ankara",
      date: "05.11.2026",
      quota: "1.500",
      deadline: "22.11.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Yakında",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Sınır kapıları ve havalimanı gümrük müdürlükleri için fiziki parkur ve mülakatlı alım ilanı.",
      officialUrl: "https://ticaret.gov.tr",
      logoIcon: Icons.account_balance,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "aile-bakanligi-01",
      organization: "Aile ve Sosyal Hizmetler Bakanlığı",
      title: "2.400 ASDEP ve Sosyal Hizmet Uzmanı Sözleşmeli Alımı",
      position: "2.400 ASDEP ve Sosyal",
      city: "Tüm Türkiye",
      date: "10.11.2026",
      quota: "2.400",
      deadline: "28.11.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Sosyal hizmet, psikoloji, sosyoloji ve çocuk gelişimi mezunları için ASDEP alımları.",
      officialUrl: "https://aile.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-yds-sonbahar",
      organization: "ÖSYM",
      title: "2026-YDS/2 Yabancı Dil Bilgisi Seviye Tespit Sınavı",
      position: "2026-YDS/2 Yabancı Dil Bilgisi",
      city: "Tüm Türkiye",
      date: "12.10.2026",
      quota: "2026",
      deadline: "24.10.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Sonbahar dönemi YDS başvuruları ÖSYM Aday İşlemleri Sistemi üzerinden alınacaktır.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-ales-sonbahar",
      organization: "ÖSYM",
      title: "2026-ALES/3 Akademik Personel ve Lisansüstü Eğitimi Sınavı",
      position: "2026-ALES/3 Akademik Personel ve",
      city: "Tüm Türkiye",
      date: "21.10.2026",
      quota: "2026",
      deadline: "04.11.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Yılın son ALES sınavı için başvuru takvimi ve sınav merkezi seçimi.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "tcdd-personel-01",
      organization: "TCDD Taşımacılık A.Ş.",
      title: "450 Tren Makinisti ve Demiryolu Hat Bakım Onarımcısı",
      position: "450 Tren Makinisti ve",
      city: "Tüm Türkiye",
      date: "02.11.2026",
      quota: "450",
      deadline: "16.11.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Yakında",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Meslek yüksekokulu ve meslek lisesi mezunları için İŞKUR üzerinden sürekli işçi alımı.",
      officialUrl: "https://tcddtasimacilik.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-kpss-l-res",
      organization: "ÖSYM • Sonuç",
      title: "2026-KPSS Lisans & Alan Bilgisi Nihai Sonuçları",
      position: "2026-KPSS Lisans & Alan",
      city: "Tüm Türkiye",
      date: "28.08.2026",
      quota: "2026",
      deadline: "28.08.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Sonuç",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "A grubu memurluk ve öğretmenlik kadroları için lisans sınav sonuçları ÖSYM sonuc sayfasında erişime açıldı.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-kpss-onlisans-res",
      organization: "ÖSYM • Sonuç",
      title: "2026-KPSS Önlisans Sınav Sonuç Takvimi",
      position: "2026-KPSS Önlisans Sınav Sonuç",
      city: "Tüm Türkiye",
      date: "20.09.2026",
      quota: "2026",
      deadline: "20.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Sonuç",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Eylül ayında tamamlanan önlisans memurluk sınavı sonuçları açıklanma aşamasında.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-yks-ek-res",
      organization: "ÖSYM • Sonuç",
      title: "2026-YKS Üniversite Ek Yerleştirme Sonuçları",
      position: "2026-YKS Üniversite Ek Yerleştirme",
      city: "Tüm Türkiye",
      date: "12.09.2026",
      quota: "2026",
      deadline: "12.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Sonuç",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Boş kalan üniversite kontenjanları için yapılan ek tercih yerleştirme sonuçları duyuruldu.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "polis-pmyo-res",
      organization: "Polis Akademisi • Sonuç",
      title: "2026 PMYO Polis Meslek Yüksekokulu Giriş Sınavı Sonuçları",
      position: "2026 PMYO Polis Meslek",
      city: "Tüm Türkiye",
      date: "04.09.2026",
      quota: "2026",
      deadline: "04.09.2026",
      applicationPlace: "Polis Akademisi",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Sonuç",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "YKS puanıyla alım yapılan 2026 PMYO mülakat ve fiziki yeterlilik asil/yedek sonuçları açıklandı.",
      officialUrl: "https://pa.edu.tr",
      logoIcon: Icons.local_police,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "msu-tercih-res",
      organization: "Milli Savunma Bakanlığı • Sonuç",
      title: "2026 MSÜ Harp Okulları & Astsubay MYO Ek Yerleştirme",
      position: "2026 MSÜ Harp Okulları",
      city: "Tüm Türkiye",
      date: "18.09.2026",
      quota: "2026",
      deadline: "18.09.2026",
      applicationPlace: "MSB Personel Temin",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Sonuç",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Milli Savunma Üniversitesi Kara, Hava, Deniz Harp Okulları boş kontenjan çağrı sonuçları.",
      officialUrl: "https://personeltemin.msb.gov.tr",
      logoIcon: Icons.military_tech,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "adli-tip-res",
      organization: "Adli Tıp Kurumu • Sonuç",
      title: "Adli Tıp Kurumu Merkez ve Taşra Personel Alımı Nihai Sonuçları",
      position: "Adli Tıp Kurumu Merkez",
      city: "Tüm Türkiye",
      date: "02.09.2026",
      quota: "Genel Kontenjan",
      deadline: "02.09.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Sonuç",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Kimyager, laborant, biyolog ve otopsi teknisyeni kadroları için asil/yedek liste yayımlandı.",
      officialUrl: "https://atk.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "meb-ekys-res",
      organization: "ÖSYM • Sonuç",
      title: "2026-MEB-EKYS Eğitim Kurumlarına Yönetici Seçme Sonuçları",
      position: "2026-MEB-EKYS Eğitim Kurumlarına Yönetici",
      city: "Tüm Türkiye",
      date: "15.08.2026",
      quota: "2026",
      deadline: "15.08.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Sonuç",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Müdür ve müdür yardımcılığı yazılı sınavı kesin değerlendirme sonuçları erişime açıldı.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.school,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-dus-res",
      organization: "ÖSYM • Sonuç",
      title: "2026-DUS Diş Hekimliğinde Uzmanlık Eğitimi Sınavı Sonuçları",
      position: "2026-DUS Diş Hekimliğinde Uzmanlık",
      city: "Tüm Türkiye",
      date: "10.08.2026",
      quota: "2026",
      deadline: "10.08.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Sonuç",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "DUS 1. dönem uzmanlık eğitimi yerleştirme sonuçları sorgulama ekranı.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-tus-res",
      organization: "ÖSYM • Sonuç",
      title: "2026-TUS Tıpta Uzmanlık Eğitimi Giriş Sınavı 2. Dönem Sonuçları",
      position: "2026-TUS Tıpta Uzmanlık Eğitimi",
      city: "Tüm Türkiye",
      date: "25.09.2026",
      quota: "2026",
      deadline: "25.09.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Sonuç",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Klinik ve temel tıp bilimleri branş sıralaması ve puan sorgulama ekranı.",
      officialUrl: "https://sonuc.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "cezaevi-ikm-boykilo-res",
      organization: "Adalet Bakanlığı • CTE",
      title: "İKM Boy-Kilo Ölçümü ve Mülakata Hak Kazananlar Listesi",
      position: "İKM Boy-Kilo Ölçümü ve",
      city: "Ankara",
      date: "07.09.2026",
      quota: "Genel Kontenjan",
      deadline: "07.09.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Sonuç",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Adalet komisyonları tarafından İnfaz Koruma Memurluğu fiziki ölçüm sonuç listeleri yayımlandı.",
      officialUrl: "https://cte.adalet.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "vakiflar-res",
      organization: "Vakıflar Genel Müdürlüğü",
      title: "VGM Sözleşmeli Koruma ve Güvenlik Görevlisi Alım Sonuçları",
      position: "VGM Sözleşmeli Koruma ve",
      city: "Tüm Türkiye",
      date: "01.09.2026",
      quota: "Genel Kontenjan",
      deadline: "01.09.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Sonuç",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Bölge müdürlükleri bazında KPSS puan sıralaması asil aday listeleri açıklandı.",
      officialUrl: "https://vgm.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "jandarma-uzm-yedek-res",
      organization: "Jandarma • Sonuç",
      title: "2026 Yılı Jandarma Uzman Erbaş 2. Yedek Çağrı Sonuçları",
      position: "2026 Yılı Jandarma Uzman",
      city: "Tüm Türkiye",
      date: "08.09.2026",
      quota: "2026",
      deadline: "08.09.2026",
      applicationPlace: "Jandarma PTS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Sonuç",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Eğitim birliklerine katılmayan adayların yerine 2. yedek planlaması tamamlandı.",
      officialUrl: "https://vatandas.jandarma.gov.tr",
      logoIcon: Icons.shield,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-kpss-lisans",
      organization: "ÖSYM",
      title: "2026-KPSS Lisans (GY-GK & Eğitim Bilimleri) Başvuruları",
      position: "2026-KPSS Lisans (GY-GK &",
      city: "Tüm Türkiye",
      date: "06.05.2026",
      quota: "2026",
      deadline: "20.05.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Kamu personeli seçme sınavı lisans başvuruları Mayıs 2026'da tamamlanmış ve sınav yapılmıştır.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-kpss-onlisans-b",
      organization: "ÖSYM",
      title: "2026-KPSS Önlisans Başvuru Takvimi",
      position: "2026-KPSS Önlisans Başvuru Takvimi",
      city: "Tüm Türkiye",
      date: "13.06.2026",
      quota: "2026",
      deadline: "02.07.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Önlisans mezunları için başvuru süreci Temmuz 2026'da tamamlanmıştır.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-kpss-ortaogretim-b",
      organization: "ÖSYM",
      title: "2026-KPSS Ortaöğretim (Lise Düzeyi) Başvuruları",
      position: "2026-KPSS Ortaöğretim (Lise Düzeyi)",
      city: "Tüm Türkiye",
      date: "18.07.2026",
      quota: "2026",
      deadline: "30.07.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Kapalı",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Lise mezunu adaylar için 2 yılda bir yapılan KPSS başvuruları Ağustos 2026'da sona erdi.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "osym-yks-2026",
      organization: "ÖSYM",
      title: "2026-YKS Yükseköğretim Kurumları Sınavı Başvuruları",
      position: "2026-YKS Yükseköğretim Kurumları Sınavı",
      city: "Tüm Türkiye",
      date: "01.02.2026",
      quota: "2026",
      deadline: "26.02.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Yakında",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "TYT, AYT ve YDT oturumları başvuruları Şubat 2026'da tamamlandı; yerleştirmeler yapıldı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.assignment,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "msu-2026-sinav",
      organization: "ÖSYM • MSÜ",
      title: "2026-MSÜ Askeri Öğrenci Belirleme Sınavı Başvuruları",
      position: "2026-MSÜ Askeri Öğrenci Belirleme",
      city: "Tüm Türkiye",
      date: "03.01.2026",
      quota: "2026",
      deadline: "30.01.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Harp Okulları ve Astsubay MYO yazılı sınavı başvuruları Ocak 2026'da tamamlandı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.military_tech,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "polis-pmyo-2026-b",
      organization: "Polis Akademisi",
      title: "2026 PMYO 2.500 Polis Öğrenci Alımı Başvuruları",
      position: "2026 PMYO 2.500 Polis",
      city: "Tüm Türkiye",
      date: "15.07.2026",
      quota: "2.500",
      deadline: "29.07.2026",
      applicationPlace: "Polis Akademisi",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "YKS TYT ham puanıyla yapılan PMYO başvuruları Temmuz 2026'da tamamlanmıştır.",
      officialUrl: "https://pa.edu.tr",
      logoIcon: Icons.local_police,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "saglik-2026-1",
      organization: "Sağlık Bakanlığı",
      title: "Sağlık Bakanlığı 2026/1 27.000 Personel Alımı",
      position: "Sağlık Bakanlığı 2026/1 27.000",
      city: "Tüm Türkiye",
      date: "21.02.2026",
      quota: "27.000",
      deadline: "28.02.2026",
      applicationPlace: "ÖSYM AIS",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Yılın ilk dönem merkezi sağlık personeli atamaları Mart 2026'da tamamlandı.",
      officialUrl: "https://ais.osym.gov.tr",
      logoIcon: Icons.local_hospital,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "danistay-zabita",
      organization: "Danıştay Başkanlığı",
      title: "Danıştay 50 Zabıt Katibi ve Şoför Alımı",
      position: "Danıştay 50 Zabıt Katibi",
      city: "Ankara",
      date: "05.06.2026",
      quota: "Genel Kontenjan",
      deadline: "15.06.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Yakında",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Danıştay merkez teşkilatı için sözleşmeli personel istihdam süreci tamamlandı.",
      officialUrl: "https://danistay.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "yargitay-memur",
      organization: "Yargıtay Başkanlığı",
      title: "Yargıtay 120 Sözleşmeli Zabıt Katibi ve Güvenlik Alımı",
      position: "Yargıtay 120 Sözleşmeli Zabıt",
      city: "Tüm Türkiye",
      date: "10.05.2026",
      quota: "120",
      deadline: "20.05.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Yargıtay hizmet binalarında istihdam edilecek personel başvuruları kapandı.",
      officialUrl: "https://yargitay.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "afad-arama-kurtarma",
      organization: "AFAD",
      title: "AFAD 1.101 Arama ve Kurtarma Teknisyeni Alımı",
      position: "AFAD 1.101 Arama ve",
      city: "Tüm Türkiye",
      date: "12.04.2026",
      quota: "1.101",
      deadline: "27.04.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "81 il AFAD müdürlükleri için fiziki parkur ve mülakatlı alım süreci tamamlandı.",
      officialUrl: "https://afad.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "diyanet-sozlesmeli-1",
      organization: "Diyanet İşleri Başkanlığı",
      title: "Diyanet 4.538 4/B Sözleşmeli Personel Alımı",
      position: "Diyanet 4.538 4/B Sözleşmeli",
      city: "Tüm Türkiye",
      date: "01.04.2026",
      quota: "4.538",
      deadline: "15.04.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "İmam-hatip, müezzin ve Kur'an kursu öğreticisi alım süreci Nisan 2026'da tamamlandı.",
      officialUrl: "https://diyanet.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "tarim-orman-1",
      organization: "Tarım ve Orman Bakanlığı",
      title: "OGM 3.000 Yangın İşçisi ve Orman Muhafaza Memuru Alımı",
      position: "OGM 3.000 Yangın İşçisi",
      city: "Ankara",
      date: "15.03.2026",
      quota: "3.000",
      deadline: "29.03.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Yakında",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Orman yangınlarıyla mücadele sezonu öncesi istihdam edilen geçici ve daimi işçi alımı.",
      officialUrl: "https://ogm.gov.tr",
      logoIcon: Icons.park,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "tubitak-arastirmaci",
      organization: "TÜBİTAK",
      title: "TÜBİTAK BİLGEM & MAM 450 Proje Personeli ve Araştırmacı Alımı",
      position: "TÜBİTAK BİLGEM & MAM",
      city: "Tüm Türkiye",
      date: "01.06.2026",
      quota: "450",
      deadline: "21.06.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Savunma sanayii ve yazılım projelerinde istihdam edilmek üzere personel alımı tamamlandı.",
      officialUrl: "https://kariyer.tubitak.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "cevre-sehircilik-1",
      organization: "Çevre, Şehircilik ve İklim Değişikliği Bakanlığı",
      title: "650 Kentsel Dönüşüm Uzman Yardımcısı ve Mühendis Alımı",
      position: "650 Kentsel Dönüşüm Uzman",
      city: "Ankara",
      date: "10.05.2026",
      quota: "650",
      deadline: "25.05.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Deprem bölgesi ve büyükşehirlerde kentsel dönüşüm faaliyetleri için memur alımı kapandı.",
      officialUrl: "https://csb.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "kyk-yurt-temizlik-1",
      organization: "GSB",
      title: "GSB 2026 Bahar Dönemi 2.000 Güvenlik ve Temizlik Görevlisi",
      position: "GSB 2026 Bahar Dönemi",
      city: "Tüm Türkiye",
      date: "10.02.2026",
      quota: "2026",
      deadline: "20.02.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Açık",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Üniversite kampüsleri ve yurtlar için İŞKUR kura çekimiyle yapılan işçi alımı.",
      officialUrl: "https://gsb.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "kultur-bakanligi-1",
      organization: "Kültür ve Turizm Bakanlığı",
      title: "Kültür Varlıkları ve Müzeler 350 Arkeolog & Restoratör Alımı",
      position: "Kültür Varlıkları ve Müzeler",
      city: "Ankara",
      date: "01.03.2026",
      quota: "350",
      deadline: "15.03.2026",
      applicationPlace: "e-Devlet Kapısı",
      employmentType: "Sözleşmeli Personel",
      applicationType: "Online Başvuru",
      status: "Yakında",
      requirements: const [
        "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini devamlı yapmasına engel bir durumu olmamak.",
      "İlgili KPSS puan türünden belirlenen taban puanı almış olmak.",
      "Belirtilen öğrenim ve mezuniyet şartlarını eksiksiz taşımak.",
      ],
      description: "Kazı başkanlıkları ve müzelerde istihdam edilmek üzere sözleşmeli personel atamaları kapandı.",
      officialUrl: "https://ktb.gov.tr",
      logoIcon: Icons.gavel,
      isAlarmActive: false,
    ),
  ];


  int get _activeCount => _channels.where((c) => c.isAlarmActive).length;

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
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _isUserVip = true);
                widget.onUpgradeVip?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("👑 Yıllık VIP Aile Planı Aktif! Tüm 54 ilanın kilidi açıldı.")),
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
                    const Text("1 Yıl boyunca tüm ilanlar açık, özel web sitesi nöbetçisi ve 3 arkadaş slotu.", style: TextStyle(color: Colors.white70, fontSize: 10)),
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
                  const SnackBar(content: Text("👑 Aylık VIP Aile Planı Aktif! Tüm 54 ilanın kilidi açıldı.")),
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
                        status: ch.status,
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
                        // Belirgin Bildirim Açma Butonu
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
                                  ch.isAlarmActive ? "Açık" : "Bildirim Aç",
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            color: const Color(0xFF091122).withValues(alpha: 0.82),
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
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.lock, color: Colors.amber, size: 20),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      "👑 Bu İlan VIP Üyelere Özeldir",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      "İlk 4 ilan ücretsizdir. 50+ güncel kamu alımının kilidini açmak için VIP'e geçin.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 10, color: Colors.white70),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        "Kilidi Aç (VIP)",
                                        style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 10),
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
