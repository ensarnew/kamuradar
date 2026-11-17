import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/announcement.dart';
import '../theme/app_theme.dart';
import '../data/announcements_catalog.dart';

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
  List<Announcement> get _vipAnnouncements {
    final openChannels = AnnouncementsCatalog.staticCatalog
        .where((c) => c.status == "Açık")
        .toList();

    return openChannels.map((c) {
      return Announcement(
        id: c.id,
        title: c.title,
        organization: c.organization,
        category: c.category,
        summary: c.description.isNotEmpty ? c.description : "${c.position} - Kontenjan: ${c.quota}",
        requirements: c.requirements.isNotEmpty ? c.requirements : ["Başvuru şartları için resmi kılavuza bakınız."],
        applicationStart: c.date,
        applicationDeadline: c.deadline,
        officialUrl: c.officialUrl,
        publishedAt: c.date,
        scannedAt12pm: "Bugün 12:00",
        isHot: true,
      );
    }).toList();
  }

  Future<void> _launchUrl(String url) async {
    String target = url;
    if (target.contains("vatandas.jandarma.gov.tr")) {
      target = "https://personeltemin.jandarma.gov.tr";
    }
    if (target.contains("personeltemin.msb.gov.tr/duyurular")) {
      target = "https://personeltemin.msb.gov.tr";
    }
    final uri = Uri.parse(target);
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
              "Türkiye genelindeki tüm aktif kamu alımları, sözleşmeli personel ilanları, kadro sayıları ve resmî başvuru kılavuzları bu ekranda toplanır. Sınırsız erişmek ve 1 arkadaşınızı eklemek için 39.99 ₺ Aile Paketi başlatın!",
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
                label: const Text("39.99 ₺ ile Açık İlanları Aç (+1 Arkadaş)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
