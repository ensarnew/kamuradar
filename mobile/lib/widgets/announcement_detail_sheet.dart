import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../services/ad_service.dart';

class AnnouncementDetailData {
  final String id;
  final String organization;
  final String title;
  final String position;
  final String city;
  final String date;
  final String quota;
  final String employmentType;
  final String applicationPlace;
  final String applicationType;
  final List<String> requirements;
  final String officialUrl;
  final String status;
  final Color logoBgColor;
  final IconData logoIcon;

  const AnnouncementDetailData({
    required this.id,
    required this.organization,
    required this.title,
    required this.position,
    this.city = "Tüm Türkiye",
    this.date = "28.09.2026",
    this.quota = "Belirtilmemiş",
    this.employmentType = "Sözleşmeli Personel",
    this.applicationPlace = "Resmî Portal",
    this.applicationType = "Online Başvuru",
    this.requirements = const [
      "Türkiye Cumhuriyeti vatandaşı olmak.",
      "Kamu haklarından mahrum bulunmamak.",
      "Sağlık açısından görevini yapmasına engel bir durumu olmamak.",
      "KPSS'den ilgili puan türünden taban puanı almış olmak.",
    ],
    required this.officialUrl,
    this.status = "Açık",
    this.logoBgColor = Colors.white,
    this.logoIcon = Icons.account_balance,
  });
}

class AnnouncementDetailSheet extends StatefulWidget {
  final AnnouncementDetailData item;
  final bool isVip;

  const AnnouncementDetailSheet({
    Key? key,
    required this.item,
    this.isVip = false,
  }) : super(key: key);

  static void show(BuildContext context, AnnouncementDetailData item, {bool isVip = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AnnouncementDetailSheet(item: item, isVip: isVip),
    );
  }

  @override
  State<AnnouncementDetailSheet> createState() => _AnnouncementDetailSheetState();
}

class _AnnouncementDetailSheetState extends State<AnnouncementDetailSheet> {
  bool _isFavorite = false;

  Future<void> _handleApply() async {
    void openUrl() async {
      final uri = Uri.parse(widget.item.officialUrl);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Yönlendiriliyor: ${widget.item.officialUrl}")),
          );
        }
      }
    }

    // Ücretsiz kullanıcıya geçiş reklamı gösterip resmî linke yönlendir
    if (!widget.isVip) {
      AdService.instance.showInterstitialAd(
        onComplete: openUrl,
      );
    } else {
      openUrl();
    }
  }

  Color get _statusColor {
    switch (widget.item.status) {
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

  Future<void> _shareOnWhatsApp() async {
    final item = widget.item;
    final shareText = "📢 ${item.organization} - ${item.position}!\n\n"
        "👥 Kadro Sayısı: ${item.quota}\n"
        "📅 Son Başvuru: ${item.date}\n"
        "🏛️ Başvuru Yeri: ${item.applicationPlace}\n\n"
        "🔗 Resmî Başvuru Adresi:\n${item.officialUrl}\n\n"
        "🔔 Tüm kamu alımlarını ve KPSS takvimini anında takip etmek için KamuRadar'ı indir:\n"
        "https://play.google.com/store/apps/details?id=com.kamuradar.app";

    final whatsappUrl = "whatsapp://send?text=${Uri.encodeComponent(shareText)}";
    final uri = Uri.parse(whatsappUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(shareText, subject: item.position);
      }
    } catch (_) {
      await Share.share(shareText, subject: item.position);
    }
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorite
            ? "🔖 ${widget.item.position} favorilere eklendi!"
            : "Favorilerden çıkarıldı."),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF091122), // Koyu modern arka plan
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Tutamaç çizgisi
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Kapat butonu ve üst bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "İlan Detayı",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                        color: _isFavorite ? const Color(0xFF38BDF8) : Colors.white70,
                      ),
                      onPressed: _toggleFavorite,
                    ),
                  ],
                ),
              ),

              // Kaydırılabilir İçerik
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    // 1. Üst Başlık & Logo Kartı
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131E33),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF1F2E4D)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Beyaz dairesel logo kapsülü
                          Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              item.logoIcon,
                              color: const Color(0xFFDC2626), // Kırmızı resmî amblem tonu
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.organization,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.position,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Durum rozeti (Açık, Yakında, Sonuç, Kapalı)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2. 3'lü İstatistik Şeridi (Kadro Sayısı | Son Başvuru | Başvuru Yeri)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131E33),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF1F2E4D)),
                      ),
                      child: Row(
                        children: [
                          // Kadro Sayısı
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.people_outline, color: Color(0xFF60A5FA), size: 20),
                                const SizedBox(height: 4),
                                const Text(
                                  "Kadro Sayısı",
                                  style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.quota,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 36, color: const Color(0xFF1F2E4D)),
                          // Son Başvuru
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.calendar_month_outlined, color: Color(0xFF60A5FA), size: 20),
                                const SizedBox(height: 4),
                                const Text(
                                  "Son Başvuru",
                                  style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.date,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 36, color: const Color(0xFF1F2E4D)),
                          // Başvuru Yeri
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.language, color: Color(0xFF60A5FA), size: 20),
                                const SizedBox(height: 4),
                                const Text(
                                  "Başvuru Yeri",
                                  style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.applicationPlace,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 3. Kurum Bilgileri Kartı
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131E33),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF1F2E4D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Kurum Bilgileri",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow("Kurum Adı", item.organization),
                          _buildInfoRow("İlan Türü", item.employmentType),
                          _buildInfoRow("Pozisyon", item.position),
                          _buildInfoRow("Şehir", item.city),
                          _buildInfoRow("Başvuru Şekli", item.applicationType),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 4. Genel Şartlar Kartı
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131E33),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF1F2E4D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Genel Şartlar",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          ...item.requirements.map(
                            (req) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("• ", style: TextStyle(color: Color(0xFF60A5FA), fontSize: 14, fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      req,
                                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 5. Eylem Butonları
                    // 🔵 [✉️ Başvuru Yap]
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5), // Canlı mavi
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 3,
                        ),
                        onPressed: _handleApply,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mail_outline, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Başvuru Yap",
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 🟢 [💬 WhatsApp'ta Paylaş] (Doğrudan WhatsApp Kişi Seçimini Açar)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), // WhatsApp yeşili
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: _shareOnWhatsApp,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "WhatsApp'ta Paylaş",
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 🔖 [Favorilere Ekle]
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C172E),
                          side: const BorderSide(color: Color(0xFF1F2E4D), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _toggleFavorite,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                              color: const Color(0xFF38BDF8),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isFavorite ? "Favorilerden Kaldır" : "Favorilere Ekle",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const Text(": ", style: TextStyle(color: Colors.white60, fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
