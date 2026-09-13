import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/custom_link.dart';
import '../theme/app_theme.dart';
import '../widgets/radar_ai_sheet.dart';


class CustomWatcherScreen extends StatefulWidget {
  const CustomWatcherScreen({Key? key}) : super(key: key);

  @override
  State<CustomWatcherScreen> createState() => _CustomWatcherScreenState();
}

class _CustomWatcherScreenState extends State<CustomWatcherScreen> {
  bool _isUserVip = false;
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  final List<CustomLinkWatcher> _watchers = [
    CustomLinkWatcher(
      id: "watch-01",
      url: "https://vatandas.jandarma.gov.tr/PTM/Giris",
      label: "Jandarma Personel Temin Sayfası",
      lastChecked12pm: "Bugün 12:00",
      hasUpdate: false,
    ),
    CustomLinkWatcher(
      id: "watch-02",
      url: "https://personeltemin.msb.gov.tr/duyurular",
      label: "MSB Personel Temin Duyurular",
      lastChecked12pm: "Bugün 12:00",
      hasUpdate: true,
    ),
  ];

  void _addWatcher(String label, String url) {
    if (label.isEmpty || url.isEmpty) return;
    setState(() {
      _watchers.insert(
        0,
        CustomLinkWatcher(
          id: "watch-${_watchers.length + 1}",
          label: label,
          url: url,
          lastChecked12pm: "İlk kontrol: Yarın 12:00",
          hasUpdate: false,
        ),
      );
      _labelController.clear();
      _urlController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("'$label' takibe alındı! Saat 12:00'de taranacak.")),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Açılıyor: $url")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSoft,
      appBar: AppBar(
        title: const Text("Özel Link Takibi (URL Watcher)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => setState(() => _isUserVip = !_isUserVip),
            child: Text(_isUserVip ? "VIP Açık" : "Kilitli (Ücretsiz)", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
              width: 70,
              height: 70,
              decoration: BoxDecoration(color: Colors.amber.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.lock, size: 36, color: Colors.amber),
            ),
            const SizedBox(height: 16),
            const Text(
              "Özel Web Sitesi Takibi VIP Özelliktir",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "İstediğiniz kamu veya üniversite duyuru sayfasının linkini ekleyin. Sistemimiz bu linki her gün saat 12:00'de otomatik tarar ve yeni bir duyuru algılandığında anında bildirim gönderir.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
              onPressed: () => setState(() => _isUserVip = true),
              child: const Text("39.99 ₺ ile Premium Başlat (+3 Arkadaş)", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
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
          // RadarAI Rehberlik Kartı
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF1E293B)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Neyi takip etmek istiyorsun?",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Resmi duyuru linkini bilmiyorsan RadarAI'ya sor, senin için bulup buraya kopyalasın!",
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    RadarAISheet.show(
                      context,
                      isVip: _isUserVip,
                      initialPrompt: "Bana Polis Akademisi duyuru sayfası resmi linkini verir misin?",
                    );
                  },
                  child: const Text("RadarAI'ya Sor", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Ekleme Kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Yeni Web Sayfası Takibi Ekle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                const Text("Her gün saat 12:00'de tek seferde taranır.", style: TextStyle(color: Colors.white60, fontSize: 11)),
                const SizedBox(height: 12),
                TextField(
                  controller: _labelController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Sayfa Başlığı (Örn: X Üniversitesi İlanları)",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                    filled: true,
                    fillColor: Colors.white12,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "https://...",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                    filled: true,
                    fillColor: Colors.white12,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => _addWatcher(_labelController.text, _urlController.text),
                    child: const Text("Takibe Al (Saat 12:00 Kontrolü)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Hızlı Butonlar
          const Text("Hızlı Ekle (Popüler Resmî Portallar):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _addWatcher("Jandarma Personel Temin", "https://vatandas.jandarma.gov.tr/PTM/Giris"),
                  child: const Text("+ Jandarma PTM", style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _addWatcher("MSB Personel Temin", "https://personeltemin.msb.gov.tr"),
                  child: const Text("+ MSB Temin", style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Liste
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Takip Ettiğiniz Sayfalar", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text("${_watchers.length} Sayfa", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),

          ..._watchers.map((w) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(w.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              subtitle: InkWell(
                onTap: () => _openLink(w.url),
                child: Text(w.url, style: const TextStyle(fontSize: 10, color: Colors.blue, decoration: TextDecoration.underline)),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (w.hasUpdate)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                      child: const Text("YENİ DUYURU!", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
                    )
                  else
                    const Text("Değişiklik Yok", style: TextStyle(fontSize: 9, color: Colors.grey)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                    onPressed: () {
                      setState(() => _watchers.removeWhere((item) => item.id == w.id));
                    },
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}
