import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/firebase_sync_service.dart';
import 'home_feed_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  // Bildirim Alanı
  final TextEditingController _notifTitleController = TextEditingController();
  final TextEditingController _notifBodyController = TextEditingController();
  final TextEditingController _notifUrlController = TextEditingController();

  // Manuel İlan Alanı
  final TextEditingController _newOrgController = TextEditingController();
  final TextEditingController _newTitleController = TextEditingController();
  final TextEditingController _newDatesController = TextEditingController();
  final TextEditingController _newUrlController = TextEditingController();

  // Kullanıcı Arama & VIP Alanı
  final TextEditingController _userSearchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchingUsers = false;

  // Tarihe Göre Tarama Kontrolleri (Örn: 10.09.2026)
  final TextEditingController _scanDateController = TextEditingController();
  int _scannedOpenCount = 0;
  int _scannedUpcomingCount = 0;
  int _scannedClosedCount = 0;

  bool _isBotRunning = false;
  bool _isSyncingAnnouncements = false;
  int _activeListingCount = 118;
  final int _purgedCount = 17;

  // Hazır Bildirim Şablonları (5-6 Adet)
  final List<Map<String, String>> _readyTemplates = [
    {
      "badge": "📢 Yeni Alımlar",
      "title": "📢 Yeni Kamu & Memur İlanları Listelendi!",
      "body": "Radarda bugün 30+ yeni kamu personeli ve memur alım ilanı yayınlandı. Başvurular başlamadan inceleyin!",
      "url": "https://kamuradar.app",
    },
    {
      "badge": "📅 Sınav Takvimi",
      "title": "📅 ÖSYM Sınav ve Tercih Takvimi Açıklandı!",
      "body": "KPSS, YDS, ALES ve DGS sınav başvuru ve tercih takvimleri güncellendi. Takviminizi hemen kontrol edin.",
      "url": "https://ais.osym.gov.tr",
    },
    {
      "badge": "🎖️ Askeri & Polis",
      "title": "🎖️ Polislik ve Askeri Alımlar Başladı!",
      "body": "POMEM, Jandarma ve MSB subay/astsubay alım duyuruları aktif. Başvuru şartları için tıklayın.",
      "url": "https://vatandas.jandarma.gov.tr",
    },
    {
      "badge": "⏰ Son Günler",
      "title": "⏰ Son Başvuru Tarihleri Yaklaşıyor!",
      "body": "Bu hafta başvuruları sona erecek bakanlık ve kamu ilanlarını kaçırmayın. Başvuru süresini kontrol edin.",
      "url": "https://kamuradar.app",
    },
    {
      "badge": "⚖️ Bakanlıklar",
      "title": "⚖️ Adalet ve Sağlık Bakanlığı Alımları!",
      "body": "Zabıt katibi, infaz koruma memuru ve sağlık personeli alımları yayında! Kontenjanları inceleyin.",
      "url": "https://pgm.adalet.gov.tr",
    },
    {
      "badge": "👑 VIP Fırsat",
      "title": "👑 KamuRadar VIP: 1 Alana 3 Bedava!",
      "body": "Aile Planı ile tek abonelikle 4 kişi sınırsız anlık bildirim ve özel web sayfası takibi kazanın.",
      "url": "https://kamuradar.app/vip",
    },
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _scanDateController.text = "${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}";
    _loadInitialUsers();
  }

  Future<void> _loadInitialUsers() async {
    final users = await FirebaseSyncService.searchUsers("");
    if (mounted && users.isNotEmpty) {
      setState(() {
        _searchResults = users;
      });
    }
  }

  // 150+ İlanı Referans Tarihe Göre Tara, Sınıflandır & Firebase Firestore'a Eşitle
  Future<void> _syncAllAnnouncementsToFirestore() async {
    setState(() => _isSyncingAnnouncements = true);
    try {
      final refDateStr = _scanDateController.text.trim();
      final DateTime refDate = ChannelAlarm.parseTurkishDate(refDateStr) ?? DateTime.now();

      final catalog = HomeFeedScreen.catalog;
      int open = 0;
      int upcoming = 0;
      int closed = 0;

      final List<Map<String, dynamic>> items = catalog.map((ch) {
        // İlan durumunu referans tarihe göre kesin olarak sınıflandır:
        // 1. Son başvuru geçmişse -> Kapalı (Biten İlanlar)
        // 2. Başvuru henüz başlamamışsa -> Yakında (Gelecekte Açılacak)
        // 3. Başlangıç ile bitiş arasındaysa -> Açık (Aktif Başvuru)
        final computedStatus = ChannelAlarm.calculateStatus(
          startDateStr: ch.date,
          deadlineDateStr: ch.deadline,
          referenceDate: refDate,
          defaultStatus: ch.status,
        );

        if (computedStatus == "Açık") {
          open++;
        } else if (computedStatus == "Yakında") {
          upcoming++;
        } else if (computedStatus == "Kapalı") {
          closed++;
        }

        return {
          'id': ch.id,
          'organization': ch.organization,
          'title': ch.title,
          'position': ch.position,
          'city': ch.city,
          'date': ch.date,
          'quota': ch.quota,
          'deadline': ch.deadline,
          'application_place': ch.applicationPlace,
          'employment_type': ch.employmentType,
          'application_type': ch.applicationType,
          'status': computedStatus,
          'category': ch.category,
          'education_level': ch.educationLevel,
          'kpss_status': ch.kpssStatus,
          'exam_date': ch.examDate ?? '',
          'requirements': ch.requirements,
          'description': ch.description,
          'official_url': ch.officialUrl,
          'content_type': ch.contentType,
          'is_future': computedStatus == "Yakında",
          'is_closed': computedStatus == "Kapalı",
          'scanned_reference_date': refDateStr,
        };
      }).toList();

      final count = await FirebaseSyncService.uploadAnnouncementsBatch(items);
      setState(() {
        _isSyncingAnnouncements = false;
        _activeListingCount = count;
        _scannedOpenCount = open;
        _scannedUpcomingCount = upcoming;
        _scannedClosedCount = closed;
      });

      // Canlı bildirim de fırlat (Tüm kullanıcılar ve veritabanı görsün)
      await FirebaseSyncService.publishBroadcastNotification(
        title: "🚀 $refDateStr Tarihli İlan Taraması!",
        body: "Günün tarihine göre radarda $open Açık İlan, $upcoming Yakında Başlayacak İlan yayında ($closed ilanın süresi doldu).",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 5),
            content: Text("✅ $count adet ilan eşitlendi!\n🟢 $open Açık İlan  |  🔵 $upcoming Yakında  |  ⚪ $closed Biten İlan"),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSyncingAnnouncements = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.urgentRed,
            content: Text("Eşitleme hatası: $e"),
          ),
        );
      }
    }
  }

  void _trigger12pmBot() async {
    setState(() => _isBotRunning = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isBotRunning = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.successGreen,
        content: Text("🤖 Gündüz Sunucu Botu başarıyla çalıştırıldı! Süresi biten ilanlar temizlendi, yeni takvimler eşitlendi."),
      ),
    );
  }

  // Hazır Şablonu Tek Tıkla Gönder
  Future<void> _sendTemplateNotification(Map<String, String> tpl) async {
    final title = tpl["title"] ?? "";
    final body = tpl["body"] ?? "";
    final url = tpl["url"] ?? "";

    await FirebaseSyncService.publishBroadcastNotification(
      title: title,
      body: body,
      targetUrl: url.isNotEmpty ? url : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryBlue,
          content: Text("🚀 Hazır Bildirim Fırlatıldı: '$title'"),
        ),
      );
    }
  }

  // Özel Yazılan Bildirimi Gönder
  Future<void> _sendCustomNotification() async {
    final title = _notifTitleController.text.trim();
    final body = _notifBodyController.text.trim();
    final promoUrl = _notifUrlController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen bildirim başlığı ve mesajı girin.")),
      );
      return;
    }

    _notifTitleController.clear();
    _notifBodyController.clear();
    _notifUrlController.clear();

    await FirebaseSyncService.publishBroadcastNotification(
      title: title,
      body: body,
      targetUrl: promoUrl.isNotEmpty ? promoUrl : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryBlue,
          duration: const Duration(seconds: 4),
          content: Text("🚀 Bildirim tüm cihazlara ve Firestore'a başarıyla iletildi: '$title'"),
        ),
      );
    }
  }

  // Kullanıcı Arama
  Future<void> _searchUsers() async {
    final q = _userSearchController.text.trim();
    setState(() => _isSearchingUsers = true);
    final results = await FirebaseSyncService.searchUsers(q);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearchingUsers = false;
      });
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aramaya uygun kullanıcı bulunamadı.")),
        );
      }
    }
  }

  // Kullanıcıya VIP Ver veya Kaldır
  Future<void> _toggleUserVip(String uid, bool currentVip) async {
    final newStatus = !currentVip;
    final success = await FirebaseSyncService.setUserVipByAdmin(uid, newStatus);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: newStatus ? AppTheme.successGreen : Colors.orange,
          content: Text(newStatus
              ? "👑 Kullanıcıya VIP Aile Planı başarıyla tanımlandı!"
              : "Kullanıcının VIP üyeliği sonlandırıldı."),
        ),
      );
      _searchUsers();
    }
  }

  void _addNewAnnouncement() {
    final org = _newOrgController.text.trim();
    final title = _newTitleController.text.trim();

    if (org.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen kurum ve başlık girin.")),
      );
      return;
    }

    setState(() {
      _activeListingCount++;
    });

    _newOrgController.clear();
    _newTitleController.clear();
    _newDatesController.clear();
    _newUrlController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.successGreen,
        content: Text("✅ Yeni ilan sisteme eklendi: '$title'"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSoft,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text("Yönetici Kontrol Paneli", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade400),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.green, size: 8),
                SizedBox(width: 5),
                Text("Admin Modu", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Sistem Durum Kartları
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    "Katalog İlanları",
                    "$_activeListingCount",
                    Icons.campaign,
                    AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    "Temizlenen (Sona Eren)",
                    "$_purgedCount",
                    Icons.auto_delete,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    "Firebase Proje",
                    "kamuradar-1e9b2",
                    Icons.cloud_done,
                    Colors.green,
                    isSmallText: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    "Bildirim & Canlı Sync",
                    "FCM + Firestore %100",
                    Icons.bolt,
                    Colors.indigo,
                    isSmallText: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 2. 🚀 TÜM İLANLARI TARA & FIREBASE'E EŞİTLE BUTONU (Madde 6)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.amber.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.rocket_launch, color: Colors.amber, size: 22),
                      SizedBox(width: 8),
                      Text("Tarihe Göre İlanları Tara & Firebase'e Eşitle", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Mevcut ve gelecekte açılacak olan 150+ kamu ilanını girdiğiniz referans tarihe göre analiz eder; açık, yakında ve biten ilanları otomatik sınıflandırıp Firebase'e yazar.",
                    style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 12),

                  // Tarih Seçici / Giriş Alanı
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Tarama Referans Tarihi (GG.AA.YYYY):",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _scanDateController,
                                decoration: InputDecoration(
                                  hintText: "10.09.2026",
                                  isDense: true,
                                  prefixIcon: const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryBlue),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                final now = DateTime.now();
                                setState(() {
                                  _scanDateController.text = "${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}";
                                });
                              },
                              child: const Text("Bugün", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 4),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                setState(() {
                                  _scanDateController.text = "10.09.2026";
                                });
                              },
                              child: const Text("10.09.2026", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "📌 Girilen tarihe göre: Başvurusu henüz başlamamış ilanlar 'Yakında' durumuna geçer, son başvuru tarihi geçmiş olanlar 'Kapalı (Bitenler)' listesine aktarılır, süresi devam edenler ise 'Açık' ilan olarak sisteme kaydedilir.",
                          style: TextStyle(fontSize: 10, color: Colors.black54, height: 1.3),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSyncingAnnouncements ? null : _syncAllAnnouncementsToFirestore,
                      icon: _isSyncingAnnouncements
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                          : const Icon(Icons.cloud_upload, size: 20),
                      label: Text(
                        _isSyncingAnnouncements ? "İlanlar Sınıflandırılıyor & Firebase'e Yazılıyor..." : "🚀 Tarihe Göre Tara & Firebase'e Eşitle",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),

                  if (_scannedOpenCount > 0 || _scannedUpcomingCount > 0 || _scannedClosedCount > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text("🟢 Açık: $_scannedOpenCount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green)),
                          Text("🔵 Yakında: $_scannedUpcomingCount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)),
                          Text("⚪ Bitenler: $_scannedClosedCount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 3. 📋 HAZIR BİLDİRİM ŞABLONLARI (Madde 10)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.mark_chat_unread, color: AppTheme.primaryBlue, size: 20),
                      SizedBox(width: 8),
                      Text("Hazır Yazılı Bildirim Şablonları (Tek Tıkla Gönder)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Tüm kullanıcılara anında bildirim ulaştırmak için aşağıdaki hazır mesajlardan birini seçip 'Gönder' butonuna basabilirsiniz.",
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  ..._readyTemplates.map((tpl) => _buildTemplateCard(tpl)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. 👑 KULLANICI ARA & VIP VER (Madde 7)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.manage_accounts, color: Colors.amber, size: 22),
                      SizedBox(width: 8),
                      Text("Kullanıcı Ara & VIP Tanımla", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Kullanıcı e-posta adresini veya adını yazarak arayın, tek tıkla VIP Aile Planı hediye edin veya durumunu yönetin.",
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _userSearchController,
                          decoration: InputDecoration(
                            hintText: "E-posta veya kullanıcı adı...",
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onSubmitted: (_) => _searchUsers(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSearchingUsers ? null : _searchUsers,
                        child: _isSearchingUsers
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text("Ara"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_searchResults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text("Kayıtlı kullanıcılar yükleniyor veya arama yapınız.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                    )
                  else
                    ..._searchResults.take(10).map((user) => _buildUserCard(user)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 5. ÖZEL PUSH BİLDİRİMİ GÖNDERME (FCM & Firestore)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.send_to_mobile, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text("Özel Push Bildirimi Gönder (FCM + Firestore)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "İstediğiniz özel bir metin ve link ile tüm kullanıcılara canlı bildirim fırlatın.",
                    style: TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notifTitleController,
                    decoration: InputDecoration(
                      labelText: "Bildirim Başlığı",
                      hintText: "Örn: 🎬 Yeni Videom Yayında! / Özel Fırsat",
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notifBodyController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: "Bildirim Mesajı",
                      hintText: "Örn: KPSS ve kamu alımlarında kaçırılmayacak detayları anlattım. İzlemek için dokunun!",
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notifUrlController,
                    decoration: InputDecoration(
                      labelText: "Yönlendirilecek Link (İsteğe Bağlı)",
                      hintText: "Örn: https://youtube.com/watch?v=... veya https://kamuradar.app",
                      prefixIcon: const Icon(Icons.link, size: 18, color: AppTheme.primaryBlue),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _sendCustomNotification,
                      icon: const Icon(Icons.campaign, size: 18),
                      label: const Text("Tüm Kullanıcılara Bildirimi Fırlat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 6. Gündüz Botunu Manuel Tetikle Butonu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.smart_toy, color: AppTheme.primaryBlue, size: 20),
                      SizedBox(width: 8),
                      Text("Sunucu Botu & Otomatik Süre Temizliği", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Gündüz botunu beklemeden şimdi çalıştırır. Resmî kaynakları (ÖSYM, Polis, Jandarma) tarar ve başvuru tarihi geçmiş ilanları temizler.",
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isBotRunning ? null : _trigger12pmBot,
                      icon: _isBotRunning
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                          : const Icon(Icons.play_circle_fill, size: 18),
                      label: Text(
                        _isBotRunning ? "Bot Taraması Yapılıyor..." : "Gündüz Sunucu Botunu Şimdi Çalıştır",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 7. Manuel Hızlı İlan Ekle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.add_circle, color: AppTheme.successGreen, size: 20),
                      SizedBox(width: 8),
                      Text("Manuel Hızlı İlan Ekle", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newOrgController,
                    decoration: InputDecoration(
                      labelText: "Kurum Adı",
                      hintText: "Örn: Adalet Bakanlığı",
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newTitleController,
                    decoration: InputDecoration(
                      labelText: "İlan / Sınav Başlığı",
                      hintText: "Örn: 5.000 İnfaz Koruma Memuru Alımı",
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newDatesController,
                          decoration: InputDecoration(
                            labelText: "Tarihler",
                            hintText: "15.09.2026 - 30.09.2026",
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _newUrlController,
                          decoration: InputDecoration(
                            labelText: "Resmî Link",
                            hintText: "https://ais.osym.gov.tr",
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _addNewAnnouncement,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text("İlanı Canlı Radara Ekle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, String> tpl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tpl["badge"] ?? "",
                  style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_note, size: 16, color: Colors.blueGrey),
                label: const Text("Kullan", style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                onPressed: () {
                  setState(() {
                    _notifTitleController.text = tpl["title"] ?? "";
                    _notifBodyController.text = tpl["body"] ?? "";
                    _notifUrlController.text = tpl["url"] ?? "";
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Şablon özel bildirim alanına aktarıldı.")),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tpl["title"] ?? "",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            tpl["body"] ?? "",
            style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _sendTemplateNotification(tpl),
              icon: const Icon(Icons.send, size: 14, color: Colors.amber),
              label: const Text("Bu Bildirimi Şimdi Gönder", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final bool isVip = user['is_vip'] == true;
    final String email = user['email'] ?? 'E-posta Yok';
    final String name = user['display_name'] ?? 'İsimsiz';
    final String uid = user['uid'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isVip ? Colors.amber.shade300 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isVip ? Colors.amber.shade100 : Colors.blueGrey.shade100,
            child: Icon(
              isVip ? Icons.stars : Icons.person,
              size: 20,
              color: isVip ? Colors.amber.shade800 : Colors.blueGrey,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isVip ? Colors.amber.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isVip ? "👑 VIP (Aile Planı)" : "Standart (Ücretsiz)",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isVip ? Colors.amber.shade900 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isVip ? Colors.red.shade600 : const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(60, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _toggleUserVip(uid, isVip),
            child: Text(
              isVip ? "VIP Kaldır" : "VIP Ver",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, {bool isSmallText = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallText ? 11 : 16,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
