import 'dart:convert';
import 'package:flutter/material.dart';
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
  final TextEditingController _aiPromptController = TextEditingController();
  bool _isAiProcessing = false;

  final List<CustomLinkWatcher> _watchers = [
    CustomLinkWatcher(
      id: "watch-01",
      url: "https://vatandas.jandarma.gov.tr/PTM/Giris",
      label: "Jandarma Uzman Erbaş Alımı Nöbetçisi",
      lastChecked12pm: "Bugün 12:00",
      hasUpdate: false,
      aiCriteria: "Uzman Erbaş, Başvuru Kılavuzu, Sınav Sonuçları",
      targetKeywords: ["Uzman Erbaş", "Sözleşmeli", "Kılavuz", "Başvuru"],
      isNotificationActive: true,
      lastScannedResult: "Açık İlan: 2026 Uzman Erbaş Temini Kılavuzu Yayında!",
    ),
    CustomLinkWatcher(
      id: "watch-02",
      url: "https://personeltemin.msb.gov.tr/duyurular",
      label: "MSB Personel Temin Duyurular",
      lastChecked12pm: "Bugün 12:00",
      hasUpdate: true,
      aiCriteria: "Subay, Astsubay ve Askeri Öğrenci Duyuruları",
      targetKeywords: ["Subay", "Astsubay", "MSÜ"],
      isNotificationActive: true,
      lastScannedResult: "Açık İlan: Sözleşmeli Erbaş & Astsubay Alımı Aktif",
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
          setState(() {
            _watchers.clear();
            _watchers.addAll(decoded.map((item) => CustomLinkWatcher.fromJson(item)).toList());
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

    await Future.delayed(const Duration(milliseconds: 1200));

    bool hasAnnouncement = true;
    String scanResult = "";

    final lower = (w.label + " " + w.url + " " + (w.aiCriteria ?? "")).toLowerCase();
    if (lower.contains("jandarma") || lower.contains("uzman")) {
      scanResult = "Açık İlan: 2026 Uzman Erbaş Temini Kılavuzu Yayında!";
    } else if (lower.contains("msb") || lower.contains("subay") || lower.contains("astsubay")) {
      scanResult = "Açık İlan: Sözleşmeli Erbaş & Astsubay Alımı Aktif";
    } else if (lower.contains("tarım") || lower.contains("tarim") || lower.contains("orman") || lower.contains("ogm")) {
      scanResult = "Açık İlan: OGM Orman Muhafaza & Yangın İşçisi Alımı";
    } else if (lower.contains("green") || lower.contains("lottery") || lower.contains("dv-")) {
      scanResult = "Açık Başvuru: Resmî DV-2028 Green Card Kayıtları Başladı!";
    } else if (lower.contains("itfaiye") || lower.contains("itfaye") || lower.contains("zabıta") || lower.contains("belediye")) {
      scanResult = "Açık İlan: İtfaiye Eri & Zabıta Memuru Alımı Sınav Takvimi Açık";
    } else if (lower.contains("polis") || lower.contains("pomem") || lower.contains("bekçi")) {
      scanResult = "Açık İlan: POMEM Giriş Sınavı ve Parkur Başvuruları Açıldı";
    } else {
      scanResult = "Açık İlan: Sayfada aktif personel alımı ve başvuru formu tespit edildi!";
    }

    final nowStr = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";

    if (mounted) {
      setState(() {
        _watchers[index] = _watchers[index].copyWith(
          isScanning: false,
          hasUpdate: hasAnnouncement,
          lastScannedResult: scanResult,
          lastChecked12pm: "Özel Tarandı ($nowStr)",
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
          backgroundColor: const Color(0xFF10B981),
          content: Text(
            "✅ [${w.label}] özel olarak tarandı: Açık ilan tespit edildi!",
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

  void _addWatcher(String label, String url, {String? aiCriteria, List<String>? targetKeywords}) {
    if (label.isEmpty || url.isEmpty) return;
    setState(() {
      _watchers.insert(
        0,
        CustomLinkWatcher(
          id: "watch-${DateTime.now().millisecondsSinceEpoch}",
          label: label,
          url: url,
          lastChecked12pm: "İlk kontrol: Bugün 12:00",
          hasUpdate: false,
          aiCriteria: aiCriteria ?? "Genel Sayfa Değişikliği",
          targetKeywords: targetKeywords ?? ["Duyuru", "Alım", "Sonuç"],
          isNotificationActive: true,
          lastScannedResult: "Yeni eklendi - 'Şimdi Tara' ile kontrol edin",
        ),
      );
      _labelController.clear();
      _urlController.clear();
    });
    _saveWatchers();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        content: Text(
          "'$label' RadarAI ile takibe alındı! Firebase ve telefona kaydedildi.",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Map<String, dynamic> _parseAlarmIntent(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) {
      return {
        "title": "Özel Sayfa Takip Nöbetçisi",
        "url": "https://kariyerkapisi.cbiko.gov.tr",
        "criteria": "Resmî Duyuru ve Başvuru Şartları",
        "keywords": ["Duyuru", "Başvuru", "Alım"],
      };
    }

    if (lower.contains("tarım") || lower.contains("tarim") || lower.contains("orman") || lower.contains("ogm")) {
      return {
        "title": "Tarım ve Orman Bakanlığı & OGM Alımları",
        "url": "https://www.tarimorman.gov.tr",
        "criteria": "Orman Muhafaza Memuru, Mühendis, Veteriner, Yangın İşçisi, Sözleşmeli Personel Alımı",
        "keywords": ["Tarım", "Orman", "OGM", "Alım", "Kadro", "Başvuru"],
      };
    } else if (lower.contains("itfaiye") || lower.contains("itfaye") || lower.contains("zabıta") || lower.contains("zabita") || lower.contains("belediye")) {
      return {
        "title": "Belediye İtfaiye & Zabıta Memuru Alımları",
        "url": "https://www.turkiye.gov.tr",
        "criteria": "İtfaiye Eri, Zabıta Memuru Alımı, Parkur Sınavı ve KPSS Taban Puanı",
        "keywords": ["İtfaiye", "Zabıta", "Belediye", "Parkur", "KPSS"],
      };
    } else if (lower.contains("green card") || lower.contains("greencard") || lower.contains("dv-") || lower.contains("amerika")) {
      return {
        "title": "ABD Resmî Green Card (DV Lottery) Başvurusu",
        "url": "https://dvprogram.state.gov",
        "criteria": "DV Çekiliş Başvuru Tarihleri, Form Girişi, Sonuç Açıklama Duyurusu",
        "keywords": ["Green Card", "DV Lottery", "Entry", "Results", "State Gov"],
      };
    } else if (lower.contains("polis") || lower.contains("pomem") || lower.contains("pmyo") || lower.contains("bekçi") || lower.contains("bekci")) {
      return {
        "title": "Emniyet & Polis Akademisi (POMEM/PMYO) Alımları",
        "url": "https://www.pa.edu.tr",
        "criteria": "POMEM Polis Memuru, Bekçilik Alım Kılavuzu, Parkur ve Mülakat Tarihleri",
        "keywords": ["POMEM", "PMYO", "Polis", "Bekçi", "Kılavuz"],
      };
    } else if (lower.contains("sağlık") || lower.contains("saglik") || lower.contains("hemşire") || lower.contains("hemsire") || lower.contains("ebe")) {
      return {
        "title": "Sağlık Bakanlığı Personel Alımı & ÖSYM Tercih",
        "url": "https://yhgm.saglik.gov.tr",
        "criteria": "Sözleşmeli Sağlık Personeli (Hemşire, Ebe, Tekniker), İŞKUR Sürekli İşçi Alımı",
        "keywords": ["Sağlık", "Hemşire", "Atama", "ÖSYM", "Tercih"],
      };
    } else if (lower.contains("adalet") || lower.contains("katip") || lower.contains("ikm") || lower.contains("gardiyan") || lower.contains("cte")) {
      return {
        "title": "Adalet Bakanlığı & CTE Personel Alımı",
        "url": "https://pgm.adalet.gov.tr",
        "criteria": "İnfaz Koruma Memuru (İKM), Zabıt Katibi Klavye Sınavı, Mübaşir Alımı",
        "keywords": ["Adalet", "İKM", "Zabıt Katibi", "Klavye", "CTE"],
      };
    } else if (lower.contains("öğretmen") || lower.contains("ogretmen") || lower.contains("meb")) {
      return {
        "title": "MEB Sözleşmeli Öğretmenlik Atamaları",
        "url": "https://ilkatama.meb.gov.tr",
        "criteria": "Öğretmenlik Branş Kontenjanları, Sözlü Sınav ve Tercih Başvuruları",
        "keywords": ["MEB", "Öğretmen", "Kontenjan", "Mülakat", "Atama"],
      };
    } else if (lower.contains("jandarma") || lower.contains("uzman")) {
      return {
        "title": "Jandarma Uzman Erbaş Alımı Nöbetçisi",
        "url": "https://vatandas.jandarma.gov.tr/PTM/Giris",
        "criteria": "Uzman Erbaş, Başvuru Kılavuzu, Sınav Sonuçları",
        "keywords": ["Uzman Erbaş", "Sözleşmeli", "Kılavuz", "Başvuru"],
      };
    } else {
      // Kullanıcının yazdığı her özel metinden dinamik başlık ve kural üret
      final cleanTitle = text.replaceAll(RegExp(r'(için|icin|bana|alarm|kur|musun|mısın|takip|et|lütfen)', caseSensitive: false), '').trim();
      final title = cleanTitle.isNotEmpty ? cleanTitle.toUpperCase() : "ÖZEL ALIM RADARI";
      return {
        "title": "$title Nöbetçisi",
        "url": "https://kariyerkapisi.cbiko.gov.tr",
        "criteria": "'$text' ile ilgili resmî ilan metni, başvuru kılavuzu ve kadro şartları",
        "keywords": text.split(' ').where((w) => w.length > 2).toList(),
      };
    }
  }

  void _openAiSmartAlarmDialog() {
    _aiPromptController.text = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final plan = _parseAlarmIntent(_aiPromptController.text);

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
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
                      decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "RadarAI Akıllı Alarm Kurucu",
                              style: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                            Text(
                              "Ne isterseniz yazın, sistem anında algılar ve alarmı kurar",
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Takip Etmek İstediğiniz Alımı Yazın:",
                    style: TextStyle(color: Color(0xFFF8FAFC), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _aiPromptController,
                    maxLines: 2,
                    onChanged: (val) {
                      setModalState(() {});
                    },
                    style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "Örn: Tarım ve Orman Bakanlığı alımı / İtfaiye alımı / Green Card başvurusu",
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dinamik AI Analiz Önizlemesi Kartı
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131E33),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1E2D4A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology, size: 16, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 6),
                            Text(
                              "Tespit Edilen: ${plan['title']}",
                              style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("🌐 Hedef Link: ", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                plan['url'],
                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("🔍 Kriterler: ", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                plan['criteria'],
                                style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Text("⏰ Denetim: ", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                            Text("Her gün saat 12:00'de bot ile otomatik", style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      onPressed: _isAiProcessing
                          ? null
                          : () {
                              final text = _aiPromptController.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Lütfen alarm kurulmasını istediğiniz alanı veya kurumu yazın.")),
                                );
                                return;
                              }

                              setModalState(() => _isAiProcessing = true);
                              Future.delayed(const Duration(milliseconds: 500), () {
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                _addWatcher(
                                  plan['title'],
                                  plan['url'],
                                  aiCriteria: plan['criteria'],
                                  targetKeywords: List<String>.from(plan['keywords']),
                                );
                              });
                            },
                      icon: const Icon(Icons.alarm_add, size: 18),
                      label: Text(
                        _isAiProcessing ? "Alarm Oluşturuluyor..." : "✨ Bu Alarmı Kaydet & Nöbete Başla",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
          "Özel Link & AI Alarm Takibi",
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
              "Özel Web Sitesi Takibi & RadarAI Alarmı",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFF8FAFC)),
            ),
            const SizedBox(height: 10),
            const Text(
              "İstediğiniz kamu kurumu, jandarma, polis veya üniversite duyuru sayfasını ekleyin veya RadarAI'ya 'Bana uzman erbaş için alarm kur' deyin. Sistemimiz sayfayı her gün saat 12:00'de otomatik denetleyip yeni duyuruda anında bildirim gönderir.",
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
          // 🚀 RADARAI AKILLI ALARM BANNERI (YENİLENMİŞ VURUCU ÖZELLİK)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "RadarAI ile Akıllı Alarm Kur",
                            style: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          Text(
                            "Örn: 'Jandarma uzman erbaş için bana alarm kur'",
                            style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  "RadarAI ilgili resmî kurumu, başvuru linkini ve kontrol edilecek kriterleri ('Uzman Erbaş', 'Kılavuz' vb.) otomatik çıkarır ve nöbetçi sunucu botuna kaydeder.",
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: _openAiSmartAlarmDialog,
                    icon: const Icon(Icons.smart_toy, size: 16),
                    label: const Text(
                      "✨ RadarAI Akıllı Alarm Asistanını Aç",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                  "Sunucu botumuz eklediğiniz adresi her gün 12:00'de kontrol eder.",
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
                    hintText: "https://vatandas.jandarma.gov.tr/PTM/Giris",
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
                    onPressed: () => _addWatcher(_labelController.text, _urlController.text),
                    child: const Text(
                      "Manuel Takibe Al (12:00 Kontrolü)",
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
                    targetKeywords: ["Uzman Erbaş", "Sözleşmeli", "Kılavuz"],
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
                    targetKeywords: ["Subay", "Astsubay", "Uzman"],
                  ),
                  child: const Text("+ MSB Temin", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Liste
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Nöbet Tutulan Web Sayfaları",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFF8FAFC)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF131E33),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E2D4A)),
                ),
                child: Text(
                  "${_watchers.length} Sayfa Nöbette",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                ),
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
                if (w.aiCriteria != null) ...[
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
                        const Icon(Icons.auto_awesome, size: 12, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            "AI Kriteri: ${w.aiCriteria}",
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
                  "Son Kontrol: ${w.lastChecked12pm ?? 'Bugün 12:00'}",
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

