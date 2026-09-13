import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/announcement.dart';
import '../theme/app_theme.dart';

class OpenAnnouncementsScreen extends StatefulWidget {
  final bool isVip;
  final VoidCallback onUpgrade;

  const OpenAnnouncementsScreen({
    Key? key,
    required this.isVip,
    required this.onUpgrade,
  }) : super(key: key);

  @override
  State<OpenAnnouncementsScreen> createState() => _OpenAnnouncementsScreenState();
}

class _OpenAnnouncementsScreenState extends State<OpenAnnouncementsScreen> {
  final List<Announcement> _vipAnnouncements = [
    Announcement(
      id: "jnd-01",
      title: "Jandarma 2.500 Uzman Erbaş Alımı",
      organization: "Jandarma Genel Komutanlığı",
      category: "Jandarma",
      summary: "Asayiş, komando ve sıhhiye branşlarında en az lise mezunu adaylar istihdam edilecektir.",
      requirements: ["En az lise mezunu olmak", "27 yaşını aşmamak"],
      applicationStart: "10.09.2026",
      applicationDeadline: "28.09.2026",
      officialUrl: "https://vatandas.jandarma.gov.tr/PTM/Giris",
      publishedAt: "2026-09-10",
      scannedAt12pm: "Bugün 12:00",
      isHot: true,
    ),
    Announcement(
      id: "msu-02",
      title: "MSÜ Harp Okulları ve Astsubay MYO Temini",
      organization: "Milli Savunma Bakanlığı (MSÜ)",
      category: "MSÜ",
      summary: "2026-MSÜ sınavı sonrası askeri öğrenci aday belirleme süreci ve fiziki yeterlilik parkuru.",
      requirements: ["En fazla 20 yaşında olmak", "MSÜ sınavına girmiş olmak"],
      applicationStart: "01.10.2026",
      applicationDeadline: "25.10.2026",
      officialUrl: "https://personeltemin.msb.gov.tr",
      publishedAt: "2026-09-12",
      scannedAt12pm: "Bugün 12:00",
      isHot: true,
    ),
    Announcement(
      id: "pomem-03",
      title: "32. Dönem POMEM 10.000 Polis Memuru Alımı",
      organization: "Polis Akademisi Başkanlığı",
      category: "POMEM",
      summary: "8.000 lisans, 2.000 önlisans mezunları arasından polis adayı alımı şartları.",
      requirements: ["KPSS P3 en az 60, P93 en az 65", "30 yaşından gün almamak"],
      applicationStart: "20.09.2026",
      applicationDeadline: "05.10.2026",
      officialUrl: "https://www.pa.edu.tr",
      publishedAt: "2026-09-08",
      scannedAt12pm: "Bugün 12:00",
      isHot: true,
    ),
    Announcement(
      id: "saglik-04",
      title: "Sağlık Bakanlığı 18.000 Sözleşmeli Personel & İşçi",
      organization: "Sağlık Bakanlığı",
      category: "Sağlık",
      summary: "Hemşire, ebe, sağlık teknikeri ve sürekli işçi kadro dağılımı yayımlandı.",
      requirements: ["İlgili sağlık mezuniyeti", "KPSS ilgili puan türü"],
      applicationStart: "22.09.2026",
      applicationDeadline: "08.10.2026",
      officialUrl: "https://yhgm.saglik.gov.tr",
      publishedAt: "2026-09-13",
      scannedAt12pm: "Bugün 12:00",
      isHot: true,
    ),
  ];

  Future<void> _launchUrl(String url) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSoft,
      appBar: AppBar(
        title: const Text("Açık İlanlar (VIP)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isVip ? Colors.amber.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.isVip ? "VIP Açık" : "Kilitli (Sadece VIP)",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: widget.isVip ? Colors.amber.shade900 : Colors.grey.shade700,
              ),
            ),
          )
        ],
      ),
      body: !widget.isVip ? _buildLockedScreen() : _buildUnlockedList(),
    );
  }

  // ÜCRETSİZ KULLANICI İÇİN KİLİTLİ EKRAN (SADECE VIP İÇİN!)
  Widget _buildLockedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.lock, size: 36, color: Colors.amber),
            ),
            const SizedBox(height: 16),
            const Text(
              "Açık İlanlar Havuzu Sadece VIP Üyelere Açıktır",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Türkiye genelindeki tüm aktif kamu alımları, sözleşmeli personel ilanları, kadro sayıları ve resmî başvuru kılavuzları bu ekranda toplanır. Sınırsız erişmek ve 3 arkadaşınızı eklemek için 39.99 ₺ Aile Paketi başlatın!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                icon: const Icon(Icons.workspace_premium, color: Colors.amber),
                label: const Text("39.99 ₺ ile Açık İlanları Aç (+3 Arkadaş)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: widget.onUpgrade,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // VIP ÜYE İÇİN TÜM AÇIK İLANLAR LİSTESİ
  Widget _buildUnlockedList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vipAnnouncements.length,
      itemBuilder: (context, index) {
        final a = _vipAnnouncements[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
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
                  Text(a.organization, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  if (a.isHot)
                    const Text("🔥 AÇIK BAŞVURU", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                ],
              ),
              const SizedBox(height: 4),
              Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(a.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text("Son: ${a.applicationDeadline}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    icon: const Icon(Icons.open_in_new, size: 12),
                    label: const Text("Resmî İlana Git & Başvur", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _launchUrl(a.officialUrl),
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }
}
