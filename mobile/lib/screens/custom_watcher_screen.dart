import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/custom_link.dart';
import '../services/firebase_sync_service.dart';
import '../services/notification_service.dart';


class CustomWatcherScreen extends StatefulWidget {
  final bool isVip;
  final VoidCallback? onUpgradeVip;

  const CustomWatcherScreen({
    Key? key,
    this.isVip = false,
    this.onUpgradeVip,
  }) : super(key: key);

  @override
  State<CustomWatcherScreen> createState() => _CustomWatcherScreenState();
}

class _CustomWatcherScreenState extends State<CustomWatcherScreen> {
  late bool _isUserVip;
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _keywordsController = TextEditingController();

  static const Set<String> _ignoredGenericTerms = {
    "alım", "alımı", "alimlari", "alımları",
    "duyuru", "duyurular", "duyuruları", "duyurusu",
    "ilan", "ilanlar", "ilanları", "ilanı",
    "haber", "haberler", "haberleri",
    "sayfa", "sayfası", "genel", "tarih", "tarihi",
    "sözleşme", "sözleşmesi", "şartlar", "şartları",
    "detay", "detaylar", "detayları", "bilgi", "bilgileri",
    "kur", "tara", "bana", "olan", "için", "veya", "ile",
    "hakkında", "iletişim", "anasayfa", "giriş", "çıkış", "menu", "ara",
    "kılavuz", "kilavuz", "başvuru", "basvuru", "sonuç", "sonuçlar"
  };

  static String _extractVisibleText(String html) {
    String clean = html.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<head[^>]*>[\s\S]*?</head>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<noscript[^>]*>[\s\S]*?</noscript>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<iframe[^>]*>[\s\S]*?</iframe>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<[^>]+>'), ' ');
    clean = clean.replaceAll('&nbsp;', ' ')
                 .replaceAll('&amp;', '&')
                 .replaceAll('&quot;', '"')
                 .replaceAll('&#39;', "'")
                 .replaceAll('&lt;', '<')
                 .replaceAll('&gt;', '>');
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.toLowerCase();
  }

  final List<CustomLinkWatcher> _watchers = [
    CustomLinkWatcher(
      id: "watch-01",
      url: "https://vatandas.jandarma.gov.tr/PTM/Giris",
      label: "Jandarma Uzman Erbaş Alımı Nöbetçisi",
      lastChecked12pm: "Gündüz Taraması (10:00 - 22:00)",
      hasUpdate: false,
      aiCriteria: "Uzman Erbaş",
      targetKeywords: ["Uzman Erbaş"],
      isNotificationActive: true,
      lastScannedResult: "Gündüz periyodu (10:00 - 22:00) nöbette",
    ),
    CustomLinkWatcher(
      id: "watch-02",
      url: "https://personeltemin.msb.gov.tr/duyurular",
      label: "MSB Personel Temin Duyurular",
      lastChecked12pm: "Gündüz Taraması (10:00 - 22:00)",
      hasUpdate: false,
      aiCriteria: "Subay, Astsubay, MSÜ",
      targetKeywords: ["Subay", "Astsubay", "MSÜ"],
      isNotificationActive: true,
      lastScannedResult: "Gündüz periyodu (10:00 - 22:00) nöbette",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _isUserVip = widget.isVip;
    _checkVip();
    _loadWatchers();
  }

  Future<void> _checkVip() async {
    final vip = await FirebaseSyncService.isVip();
    if (mounted && (vip != _isUserVip)) {
      setState(() {
        _isUserVip = vip;
      });
    }
  }

  @override
  void didUpdateWidget(CustomWatcherScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVip != _isUserVip) {
      setState(() {
        _isUserVip = widget.isVip;
      });
    }
  }

  Future<void> _loadWatchers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString("custom_watchers_list");
      if (data != null && data.isNotEmpty) {
        final List decoded = json.decode(data);
        if (decoded.isNotEmpty && mounted) {
          final loaded = decoded.map((item) {
            final w = CustomLinkWatcher.fromJson(item);
            // Eski sürümlerden veya alakasız sitelerden kalan hatalı pozitif sonuçları temizle
            if (w.url.contains("3dtoptantr") || (w.hasUpdate && !w.url.contains("gov.tr") && !w.url.contains("edu.tr") && !w.url.contains("tsk.tr"))) {
              return w.copyWith(
                hasUpdate: false,
                lastScannedResult: "❌ İlan Bulunamadı: Aradığınız kriterler bu sayfada geçmiyor.",
              );
            }
            return w;
          }).toList();
          setState(() {
            _watchers.clear();
            _watchers.addAll(loaded);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveWatchers() async {
    try {
      final listJson = _watchers.map((w) => w.toJson()).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("custom_watchers_list", json.encode(listJson));
      await FirebaseSyncService.syncCustomWatchers(listJson);
    } catch (_) {}
  }

  Future<void> _scanWatcher(CustomLinkWatcher w) async {
    final index = _watchers.indexWhere((item) => item.id == w.id);
    if (index == -1) return;

    setState(() {
      _watchers[index] = _watchers[index].copyWith(isScanning: true);
    });

    bool hasAnnouncement = false;
    String scanResult = "";
    final nowStr = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    try {
      String rawUrl = w.url.trim();
      if (!rawUrl.startsWith("http://") && !rawUrl.startsWith("https://")) {
        rawUrl = "https://$rawUrl";
      }

      final uri = Uri.parse(rawUrl);
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ).timeout(const Duration(seconds: 9));

      if (response.statusCode >= 200 && response.statusCode < 400) {
        // Ham HTML yerine YALNIZCA ekranda görünen metni analiz et (script, css ve etiketler elenir)
        final visibleText = _extractVisibleText(response.body);

        // 1. Hedef arama terimlerini derle (YALNIZCA kullanıcının belirlediği spesifik terimler)
        final List<String> termsToSearch = [];
        for (var k in w.targetKeywords) {
          final clean = k.trim().toLowerCase();
          if (clean.length >= 2 && !_ignoredGenericTerms.contains(clean)) {
            termsToSearch.add(clean);
          }
        }

        // Eğer targetKeywords boşsa veya genel terimler elenince boş kaldıysa, başlıktan spesifik kelimeleri al
        if (termsToSearch.isEmpty) {
          final words = w.label.toLowerCase().split(RegExp(r'[\s,\-_/]+'))
              .map((w) => w.trim())
              .where((w) => w.length >= 3 && !_ignoredGenericTerms.contains(w))
              .toList();
          if (words.isNotEmpty) {
            termsToSearch.addAll(words);
          } else {
            termsToSearch.add(w.label.trim().toLowerCase());
          }
        }

        // 2. Sayfanın GÖRÜNÜR metninde YALNIZCA bu hedef terimleri ara
        final matchedTerms = <String>[];
        for (var term in termsToSearch) {
          if (visibleText.contains(term)) {
            matchedTerms.add(term);
          }
        }

        // KESİN KURAL: Sayfada aranan hedef terimler YOKSA asla ilan var demez!
        if (matchedTerms.isNotEmpty) {
          hasAnnouncement = true;
          scanResult = "🎯 Aradığınız '${matchedTerms.take(3).join(", ")}' duyurusu bu sayfada bulundu! (${response.statusCode} OK)";
        } else {
          hasAnnouncement = false;
          final wantedStr = termsToSearch.take(4).join(", ");
          scanResult = "❌ İlan Bulunamadı: Sayfa incelendi (${response.statusCode} OK). Aradığınız '$wantedStr' terimleri bu web sayfasında geçmiyor.";
        }
      } else {
        hasAnnouncement = false;
        scanResult = "Sunucu Hatası: Web sitesi HTTP ${response.statusCode} yanıtı verdi. Sayfa açılamadı.";
      }
    } catch (e) {
      hasAnnouncement = false;
      scanResult = "Bağlantı Kurulamadı: Web adresine erişilemedi veya adres geçersiz.";
    }

    if (mounted) {
      setState(() {
        _watchers[index] = _watchers[index].copyWith(
          isScanning: false,
          hasUpdate: hasAnnouncement,
          lastScannedResult: scanResult,
          lastChecked12pm: "Gündüz Taraması ($nowStr)",
        );
      });
    }

    await _saveWatchers();

    if (hasAnnouncement && _watchers[index].isNotificationActive) {
      await NotificationService.showLocalNotification(
        title: "🔍 Özel Tarama: ${w.label}",
        body: scanResult,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: hasAnnouncement ? const Color(0xFF10B981) : const Color(0xFF334155),
          content: Text(
            hasAnnouncement
                ? "✅ [${w.label}] tarandı: Açık duyuru tespit edildi!"
                : "ℹ️ [${w.label}] tarandı: Yeni duyuru bulunamadı (Sayfa stabil).",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  Future<void> _toggleWatcherNotification(CustomLinkWatcher w) async {
    final index = _watchers.indexWhere((item) => item.id == w.id);
    if (index == -1) return;

    final newState = !w.isNotificationActive;
    setState(() {
      _watchers[index] = _watchers[index].copyWith(isNotificationActive: newState);
    });

    await _saveWatchers();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: newState ? const Color(0xFF10B981) : const Color(0xFF475569),
          content: Text(
            newState
                ? "🔔 '${w.label}' için bildirimler AÇILDI."
                : "🔕 '${w.label}' için bildirimler KAPATILDI.",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  void _addWatcher(String label, String url, {String? aiCriteria, List<String>? targetKeywords, String? keywordsRaw}) {
    if (label.isEmpty || url.isEmpty) return;

    List<String> finalKeywords = [];
    if (targetKeywords != null && targetKeywords.isNotEmpty) {
      finalKeywords = targetKeywords;
    } else if (keywordsRaw != null && keywordsRaw.trim().isNotEmpty) {
      finalKeywords = keywordsRaw
          .split(RegExp(r'[,;\n]+'))
          .map((s) => s.trim())
          .where((s) => s.length >= 2)
          .toList();
    } else {
      final words = label.trim().split(RegExp(r'[\s,\-_/]+'))
          .map((w) => w.trim())
          .where((w) => w.length >= 3 && !_ignoredGenericTerms.contains(w.toLowerCase()))
          .toList();
      finalKeywords = words.isNotEmpty ? words : [label.trim()];
    }

    final newWatcher = CustomLinkWatcher(
      id: "watch-${DateTime.now().millisecondsSinceEpoch}",
      label: label.trim(),
      url: url.trim(),
      lastChecked12pm: "Gündüz Taraması (10:00 - 22:00)",
      hasUpdate: false,
      aiCriteria: aiCriteria ?? finalKeywords.join(", "),
      targetKeywords: finalKeywords,
      isNotificationActive: true,
      lastScannedResult: "Yeni eklendi - Şimdi taranıyor...",
    );

    setState(() {
      _watchers.insert(0, newWatcher);
      _labelController.clear();
      _urlController.clear();
      _keywordsController.clear();
    });
    _saveWatchers();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        content: Text(
          "'$label' takibe alındı! Sayfa canlı taranıyor...",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );

    _scanWatcher(newWatcher);
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E293B),
          content: Text("Açılıyor: $url", style: const TextStyle(color: Color(0xFFF8FAFC))),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF091122),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          "Özel Link Takibi (Web Nöbetçisi)",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFF8FAFC)),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: _isUserVip ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isUserVip ? const Color(0xFFF59E0B) : const Color(0xFF334155),
              ),
            ),
            child: TextButton.icon(
              onPressed: () => setState(() => _isUserVip = !_isUserVip),
              icon: Icon(
                _isUserVip ? Icons.workspace_premium : Icons.lock_outline,
                size: 14,
                color: _isUserVip ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
              ),
              label: Text(
                _isUserVip ? "VIP Aktif" : "VIP Kilitli",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: _isUserVip ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                ),
              ),
            ),
          )
        ],
      ),
      body: !_isUserVip ? _buildLockedView() : _buildActiveWatcherView(),
    );
  }

  Widget _buildLockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.satellite_alt, size: 38, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(height: 18),
            const Text(
              "Özel Web Sitesi Nöbetçisi",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFF8FAFC)),
            ),
            const SizedBox(height: 10),
            const Text(
              "İstediğiniz kamu kurumu, jandarma, polis veya üniversite duyuru sayfasını ekleyin ve aranacak terimleri belirleyin. Sistemimiz sayfayı gündüz saatlerinde (10:00, 12:00, 14:00, 16:00, 18:00, 20:00, 22:00) 2 saatte bir denetler, yeni ilan düştüğünde bildirim gönderir.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => setState(() => _isUserVip = true),
              icon: const Icon(Icons.workspace_premium, size: 16),
              label: const Text(
                "39.99 ₺ ile VIP Başlat (+3 Arkadaş)",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveWatcherView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Manuel Ekleme Kartı (Karanlık Lacivert & Açık Metin Kontrastı)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131E33),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF1E2D4A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Manuel Web Sayfası Takibi Ekle",
                  style: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w900, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Sunucu botumuz eklediğiniz adresi gündüz saatlerinde (10:00 - 22:00) 2 saatte bir kontrol eder.",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _labelController,
                  style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "Takip Başlığı (Örn: Jandarma Uzman Erbaş)",
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF091122),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1E2D4A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1E2D4A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "Web Adresi (Örn: https://vatandas.jandarma.gov.tr/...)",
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF091122),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1E2D4A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1E2D4A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _keywordsController,
                  style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "Aranacak Terimler (Örn: Jandarma, Uzman Erbaş, Başvuru)",
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF091122),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1E2D4A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1E2D4A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "ℹ️ Bot bu sayfayı tararken YALNIZCA girdiğiniz bu terimleri arar. Sayfada bu kelimeler yoksa asla ilan var demez.",
                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _addWatcher(
                      _labelController.text,
                      _urlController.text,
                      keywordsRaw: _keywordsController.text,
                    ),
                    child: const Text(
                      "Manuel Takibe Al & Şimdi Tara",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Hızlı Butonlar
          const Text(
            "Hızlı Ekle (Popüler Resmî Portallar):",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFF8FAFC)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF1E2D4A)),
                    backgroundColor: const Color(0xFF131E33),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _addWatcher(
                    "Jandarma Uzman Erbaş",
                    "https://vatandas.jandarma.gov.tr/PTM/Giris",
                    aiCriteria: "Uzman Erbaş Alımı",
                    targetKeywords: ["Uzman Erbaş", "Jandarma"],
                  ),
                  child: const Text("+ Jandarma PTM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF1E2D4A)),
                    backgroundColor: const Color(0xFF131E33),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _addWatcher(
                    "MSB Personel Temin",
                    "https://personeltemin.msb.gov.tr",
                    aiCriteria: "Askeri Personel Alımları",
                    targetKeywords: ["Subay", "Astsubay", "MSÜ"],
                  ),
                  child: const Text("+ MSB Temin", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Liste Başlığı ve Eylemler
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Nöbet Tutulan Web Sayfaları",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFF8FAFC)),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      for (var watcher in _watchers) {
                        _scanWatcher(watcher);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF2563EB),
                          content: Text("Tüm nöbetçi sayfalar canlı olarak taranıyor...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF38BDF8)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.refresh, size: 12, color: Color(0xFF38BDF8)),
                          SizedBox(width: 4),
                          Text(
                            "Tümünü Tara",
                            style: TextStyle(fontSize: 10, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131E33),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E2D4A)),
                    ),
                    child: Text(
                      "${_watchers.length} Sayfa",
                      style: const TextStyle(fontSize: 10, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          ..._watchers.map((w) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131E33),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: w.hasUpdate ? const Color(0xFF10B981) : const Color(0xFF1E2D4A),
                width: w.hasUpdate ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        w.label,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFFF8FAFC)),
                      ),
                    ),
                    if (w.hasUpdate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: const Text(
                          "YENİ DUYURU!",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "Değişiklik Yok",
                          style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _openLink(w.url),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 12, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          w.url,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF38BDF8),
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (w.targetKeywords.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF091122),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E2D4A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 12, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            "Aranan Terimler: ${w.targetKeywords.join(', ')}",
                            style: const TextStyle(fontSize: 10, color: Color(0xFFE2E8F0), fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (w.lastScannedResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: w.hasUpdate
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFF091122),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: w.hasUpdate ? const Color(0xFF10B981) : const Color(0xFF1E2D4A),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          w.hasUpdate ? Icons.check_circle : Icons.info_outline,
                          size: 16,
                          color: w.hasUpdate ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            w.lastScannedResult!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: w.hasUpdate ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    // 1. ÖZEL TARAMA TUŞU
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: const Color(0xFF38BDF8),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFF38BDF8), width: 0.8),
                          ),
                        ),
                        icon: w.isScanning
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                              )
                            : const Icon(Icons.travel_explore, size: 16),
                        label: Text(
                          w.isScanning ? "Taranıyor..." : "🔍 Şimdi Tara",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: w.isScanning ? null : () => _scanWatcher(w),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. BİLDİRİM AÇ / KAPA TUŞU
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: w.isNotificationActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        backgroundColor: w.isNotificationActive
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFF0F172A),
                        side: BorderSide(
                          color: w.isNotificationActive ? const Color(0xFF10B981) : const Color(0xFF334155),
                          width: 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(
                        w.isNotificationActive ? Icons.notifications_active : Icons.notifications_off,
                        size: 16,
                      ),
                      label: Text(
                        w.isNotificationActive ? "Bildirim Açık" : "Bildirim Kapalı",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _toggleWatcherNotification(w),
                    ),
                    const SizedBox(width: 6),

                    // 3. SİLME TUŞU
                    InkWell(
                      onTap: () {
                        setState(() => _watchers.removeWhere((item) => item.id == w.id));
                        _saveWatchers();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Son Kontrol: ${w.lastChecked12pm ?? 'Gündüz Taraması (10:00 - 22:00)'}",
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

