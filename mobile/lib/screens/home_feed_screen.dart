import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class ChannelAlarm {
  final String id;
  final String organization;
  final String title;
  final String description;
  final String officialUrl;
  bool isAlarmActive;

  ChannelAlarm({
    required this.id,
    required this.organization,
    required this.title,
    required this.description,
    required this.officialUrl,
    this.isAlarmActive = false,
  });
}

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  bool _isUserVip = false;
  final int _freeAlarmLimit = 3;

  final List<ChannelAlarm> _channels = [
    ChannelAlarm(
      id: "ch-01",
      organization: "ÖSYM",
      title: "2026-KPSS Lisans Başvuruları & Geç Başvuru",
      description: "Genel Yetenek - Genel Kültür ve Eğitim Bilimleri sınav başvuru dönemi takibi.",
      officialUrl: "https://ais.osym.gov.tr",
      isAlarmActive: true, // 1. Alarm
    ),
    ChannelAlarm(
      id: "ch-02",
      organization: "ÖSYM",
      title: "2026-KPSS Lisans Sınav Sonuçları",
      description: "Lisans ve Alan Bilgisi puanları ÖSYM Sonuç sisteminde açıklandığı an haber verir.",
      officialUrl: "https://sonuc.osym.gov.tr",
      isAlarmActive: true, // 2. Alarm
    ),
    ChannelAlarm(
      id: "ch-03",
      organization: "ÖSYM",
      title: "2026-KPSS Önlisans Başvuru Takvimi",
      description: "2 yıllık üniversite mezunları için başvuru kılavuzu ve banka ödeme tarihleri.",
      officialUrl: "https://ais.osym.gov.tr",
      isAlarmActive: false, // 3. Seçilebilir (Kota dolar)
    ),
    ChannelAlarm(
      id: "ch-04",
      organization: "ÖSYM",
      title: "2026-KPSS Önlisans Sınav Sonuçları Açıklanması",
      description: "KPSS Önlisans puanları ve branş sıralamaları açıklandığında anında bildirim.",
      officialUrl: "https://sonuc.osym.gov.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-05",
      organization: "ÖSYM",
      title: "2026-KPSS Ortaöğretim (Lise Düzeyi) Başvuruları",
      description: "Lise mezunları için 2 yılda bir yapılan genel KPSS başvuru dönemi takibi.",
      officialUrl: "https://ais.osym.gov.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-06",
      organization: "ÖSYM",
      title: "2026-KPSS Ortaöğretim Sınav Sonuçları",
      description: "Lise KPSS sınav sonuçları ve puan kartı sorgulama ekranı alarmları.",
      officialUrl: "https://sonuc.osym.gov.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-07",
      organization: "ÖSYM & MSB",
      title: "2026-MSÜ Askeri Öğrenci Sınav Başvuruları",
      description: "Harp Okulları ve Astsubay MYO askeri öğrenci belirleme sınav takvimi.",
      officialUrl: "https://personeltemin.msb.gov.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-08",
      organization: "Milli Savunma Bakanlığı",
      title: "MSÜ Mülakat, Fiziki Parkur & Nihai Sonuçlar",
      description: "2. seçim aşamaları çağrı listesi ve asil/yedek sonuç duyuruları.",
      officialUrl: "https://personeltemin.msb.gov.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-09",
      organization: "Polis Akademisi",
      title: "32. Dönem POMEM Polis Memuru Alımı Başvuruları",
      description: "10.000 polis alımı (lisans/önlisans) e-Devlet başvuru süreci alarmları.",
      officialUrl: "https://www.pa.edu.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-10",
      organization: "Polis Akademisi",
      title: "POMEM Fiziki Parkur & Mülakat Sonuçları",
      description: "Polislik fiziki parkur dereceleri ve mülakat sonuçları açıklandığı an haber verir.",
      officialUrl: "https://www.pa.edu.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-11",
      organization: "Polis Akademisi",
      title: "PMYO Polis Meslek Yüksekokulu Başvuruları",
      description: "Lise mezunları için üniversite düzeyinde yatılı polislik sınavı ve TYT taban puanı.",
      officialUrl: "https://www.pa.edu.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-12",
      organization: "Jandarma Genel K.",
      title: "JSGA Subay ve Astsubay Temini Başvuruları",
      description: "Jandarma ve Sahil Güvenlik Akademisi muvazzaf/sözleşmeli subay alımı.",
      officialUrl: "https://vatandas.jandarma.gov.tr/PTM/Giris",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-13",
      organization: "Jandarma Genel K.",
      title: "Jandarma 2.500 Uzman Erbaş Alımı & Parkur",
      description: "Komando, asayiş ve sıhhiye uzman erbaş alımı başvuru ve sonuç takibi.",
      officialUrl: "https://vatandas.jandarma.gov.tr/PTM/Giris",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-14",
      organization: "EGM / Polis Akademisi",
      title: "Çarşı ve Mahalle Bekçiliği Alımları",
      description: "İl bazlı bekçi alım kontenjanları, yazılı sınav ve mülakat duyuruları.",
      officialUrl: "https://www.pa.edu.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-15",
      organization: "Adalet Bakanlığı (PGM)",
      title: "5.400 İKM, Zabıt Katibi & Mübaşir Alımı",
      description: "Cezaevi infaz koruma, katiplik klavye uygulama sınavı ve mülakat listeleri.",
      officialUrl: "https://pgm.adalet.gov.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-16",
      organization: "Sağlık Bakanlığı (YHGM)",
      title: "18.000 Sözleşmeli Sağlık Personeli & İşçi Alımı",
      description: "Hemşire, tekniker ve sürekli işçi branş dağılımları ve tercih takvimi.",
      officialUrl: "https://yhgm.saglik.gov.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-17",
      organization: "Milli Eğitim Bakanlığı",
      title: "20.000 Sözleşmeli Öğretmen Ataması & Tercihleri",
      description: "Branş bazında kontenjanlar, mülakat takvimi ve sözleşmeli atama sonuçları.",
      officialUrl: "https://personel.meb.gov.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-18",
      organization: "ÖSYM",
      title: "2026-DGS Dikey Geçiş Başvuru & Tercih Sonuçları",
      description: "Önlisanstan lisansa geçiş sınavı başvuru, taban puan ve yerleştirme takvimi.",
      officialUrl: "https://ais.osym.gov.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-19",
      organization: "ÖSYM",
      title: "2026-ALES / 1 ve ALES / 2 Akademik Sınav Takvimi",
      description: "Yüksek lisans ve akademik kadro başvuruları için ALES sınav & sonuç takvimi.",
      officialUrl: "https://ais.osym.gov.tr",
      isAlarmActive: false,
    ),
    ChannelAlarm(
      id: "ch-20",
      organization: "Gençlik ve Spor Bakanlığı",
      title: "GSB Yurt Yönetim Personeli & Gençlik Lideri",
      description: "GSB taşra teşkilatı büro personeli ve yurt yönetim memuru alım duyuruları.",
      officialUrl: "https://pgm.gsb.gov.tr",
      isAlarmActive: false,
    ),
  ];


  int get _activeCount => _channels.where((c) => c.isAlarmActive).length;

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

  // 4 ALARM DOLUNCA AÇILAN VIP POP-UP
  void _showVipPopUp() {
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
              child: const Icon(Icons.crown, color: Colors.amber, size: 30),
            ),
            const SizedBox(height: 12),
            const Text(
              "Ücretsiz Alarm Limiti Doldu (3 / 3)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              "Ücretsiz planda aynı anda en fazla 3 alım için alarm kurabilirsiniz. 4. alımı ve 20 sınav/alım takviminin tümünü kaçırmadan takip etmek için Aile Planını başlatın!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.slate.shade50, borderRadius: BorderRadius.circular(16)),
              child: const Column(
                children: [
                  Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.green), SizedBox(width: 8), Text("Sınırsız alım için alarm kurma", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))]),
                  SizedBox(height: 6),
                  Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.green), SizedBox(width: 8), Text("Özel web sayfası izleme (URL Watcher)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))]),
                  SizedBox(height: 6),
                  Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.green), SizedBox(width: 8), Text("1 Öde, 4 Kişi Kullan (3 Arkadaşını Ücretsiz Ekle)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _isUserVip = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("VIP Aktif! 4 alarm sınırı kalktı, sınırsız takip açıldı.")),
                  );
                },
                child: const Text("39.99 ₺ ile Sınırsız VIP Yap (+3 Arkadaş)", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleChannelAlarm(ChannelAlarm channel) {
    if (channel.isAlarmActive) {
      setState(() {
        channel.isAlarmActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${channel.title} alarmı kapatıldı.")),
      );
    } else {
      if (!_isUserVip && _activeCount >= _freeAlarmLimit) {
        // 5. Alarm denemesi: POP-UP AÇILIR!
        _showVipPopUp();
        return;
      }
      setState(() {
        channel.isAlarmActive = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🔔 ${channel.title} alarmı kuruldu! Saat 12:00'de kontrol edilecek.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSoft,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.radar, color: AppTheme.primaryBlue, size: 22),
            SizedBox(width: 8),
            Text("KamuRadar", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ActionChip(
              label: Text(
                _isUserVip ? "VIP Sınırsız" : "$_activeCount/$_freeAlarmLimit Alarm",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isUserVip ? Colors.amber.shade900 : Colors.grey.shade800),
              ),
              backgroundColor: _isUserVip ? Colors.amber.shade100 : Colors.grey.shade200,
              onPressed: () => setState(() => _isUserVip = !_isUserVip),
            ),
          )
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
                    _isUserVip ? "VIP Sınırsız Mod (Saat 12:00)" : "Kota: $_activeCount / $_freeAlarmLimit Açık",
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
                    _isUserVip ? "Sınırsız Takip (VIP)" : "$_activeCount / $_freeAlarmLimit Alarm Açık",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isUserVip ? Colors.green : Colors.amber.shade900),
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
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ch.isAlarmActive ? Colors.emerald.shade300 : AppTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(ch.organization, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                          // Zil Aç/Kapat Butonu
                          ActionChip(
                            avatar: Icon(
                              ch.isAlarmActive ? Icons.notifications_active : Icons.notifications_off_outlined,
                              size: 14,
                              color: ch.isAlarmActive ? Colors.emerald.shade800 : Colors.grey,
                            ),
                            label: Text(
                              ch.isAlarmActive ? "Alarm Açık" : "Kapalı",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: ch.isAlarmActive ? Colors.emerald.shade900 : Colors.grey.shade700,
                              ),
                            ),
                            backgroundColor: ch.isAlarmActive ? Colors.emerald.shade50 : Colors.grey.shade100,
                            onPressed: () => _toggleChannelAlarm(ch),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(ch.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(ch.description, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text("Her gün 12:00 taranır", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 12),
                            label: const Text("Resmî Sayfaya Git", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () => _launchUrl(ch.officialUrl),
                          ),
                        ],
                      )
                    ],
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
