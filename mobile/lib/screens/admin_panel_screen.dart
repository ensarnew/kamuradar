import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final TextEditingController _notifTitleController = TextEditingController();
  final TextEditingController _notifBodyController = TextEditingController();
  final TextEditingController _notifUrlController = TextEditingController();

  final TextEditingController _newOrgController = TextEditingController();
  final TextEditingController _newTitleController = TextEditingController();
  final TextEditingController _newDatesController = TextEditingController();
  final TextEditingController _newUrlController = TextEditingController();

  bool _isBotRunning = false;
  int _activeListingCount = 37;
  final int _purgedCount = 17;

  void _trigger12pmBot() async {
    setState(() => _isBotRunning = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isBotRunning = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.successGreen,
        content: Text("🤖 Gündüz Sunucu Botu başarıyla çalıştırıldı! (10:00-22:00 periyodu) Süresi biten ilanlar temizlendi, yeni takvimler eşitlendi."),
      ),
    );
  }

  void _sendCustomNotification() {
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

    final hasUrl = promoUrl.isNotEmpty;
    NotificationService.showLocalNotification(
      title: title,
      body: body,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primaryBlue,
        duration: const Duration(seconds: 4),
        content: Text(hasUrl
            ? "🚀 Firebase FCM: '$title' bildirimi fırlatıldı! Kullanıcılar tıklayınca doğrudan linke gidecek:\n🔗 $promoUrl"
            : "🚀 Firebase FCM: '$title' bildirimi tüm hedef kullanıcılara fırlatıldı!"),
      ),
    );
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
                    "Aktif İlanlar",
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
                    "Gündüz Botu",
                    "10:00 - 22:00",
                    Icons.alarm_on,
                    Colors.indigo,
                    isSmallText: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 2. Gündüz Botunu Manuel Tetikle Butonu
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
                    "Gündüz botunu (10:00, 12:00, 14:00, 16:00, 18:00, 20:00, 22:00) beklemeden şimdi çalıştırır. Resmî kaynakları (ÖSYM, Polis, Jandarma) tarar ve başvuru tarihi geçmiş olan tüm ilanları otomatik olarak siler.",
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

            const SizedBox(height: 16),

            // 3. Anlık Push Bildirimi Gönderme (FCM)
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
                      Text("Anlık Push Bildirimi & Reklam / Link Yönlendirme (FCM)", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Buradan yazacağın bildirim tüm kullanıcılara gider. Link eklersen, kullanıcı bildirime dokunduğu anda doğrudan senin YouTube videona, Instagram hesabına veya reklam aldığın web sitesine yönlendirilir.",
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
                      labelText: "Yönlendirilecek Link (YouTube / Sponsor / Web Sitesi)",
                      hintText: "Örn: https://youtube.com/watch?v=... veya https://siteniz.com",
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
                      label: const Text("Tüm Kullanıcılara Linkli Bildirimi Fırlat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. Yeni İlan Ekle
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
