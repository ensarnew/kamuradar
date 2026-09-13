import 'package:flutter/material.dart';

class FamilySubscriptionScreen extends StatefulWidget {
  const FamilySubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<FamilySubscriptionScreen> createState() => _FamilySubscriptionScreenState();
}

class _FamilySubscriptionScreenState extends State<FamilySubscriptionScreen> {
  bool _isPlanPurchased = false; // Kural: Önce 39.99 ₺ ödeyecek, sonra kod üretilecek
  String? _generatedInviteCode;
  List<String> _members = [];
  final int _maxExtraMembers = 3;

  // 1. Aboneliği Satın Al (39.99 ₺)
  void _buySubscription() {
    setState(() {
      _isPlanPurchased = true;
      _generatedInviteCode = "KAMU77"; // 6 haneli üretilen kod
      _members = [
        "Ahmet Yılmaz (11.09.2026 katıldı)",
        "Mustafa Kaya (12.09.2026 katıldı)",
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Aylık 39.99 ₺ ödeme onaylandı! Davet kodunuz üretildi: KAMU77")),
    );
  }

  // 2. Ana Kişinin Aboneliği İptal Etmesi (Cascade Cancellation)
  void _cancelSubscription() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Aboneliği İptal Et?"),
        content: const Text(
          "Aboneliği iptal ederseniz hem sizin hem de davet ettiğiniz 3 arkadaşınızın Premium hakları (özel link takibi ve açık ilan erişimi) anında sonlanacaktır. Emin misiniz?",
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Vazgeç")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isPlanPurchased = false;
                _generatedInviteCode = null;
                _members.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Abonelik iptal edildi. Sizin ve davet ettiğiniz tüm üyelerin Premium hakları sonlandırıldı.")),
              );
            },
            child: const Text("Evet, İptal Et", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // 3. Karşı Tarafın Kod Girme Alanı
  void _submitFriendInviteCode(String code) {
    if (code.trim().toUpperCase() == "KAMU77") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tebrikler! Davet kodu doğrulandı. Siz de anında Premium üye oldunuz!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Geçersiz davet kodu! Lütfen arkadaşınızdan 6 haneli kodu teyit edin.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Premium & Aile Paketi", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. KISIM: PREMİUM SATIN ALMA VEYA YÖNETİM
            if (!_isPlanPurchased) ...[
              // Henüz Satın Alınmadı: Doğrudan Kod Verilmez!
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
                          child: const Text("1 ÖDE + 3 KİŞİ EKLE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black)),
                        ),
                        const Text("Aylık 39.99 ₺", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text("KamuRadar Aile & Ekip Paketi", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text(
                      "Tek bir üyelikle siz ve 3 arkadaşınız (toplam 4 kişi) tüm açık kamu ilanlarını sınırsız görür ve özel web sitesi linki ekleyerek her gün saat 12:00'de anlık bildirim alır.",
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.credit_card, color: Colors.white),
                        label: const Text("Aylık 39.99 ₺ ile Premium Başlat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: _buySubscription,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Satın Alındı: Kod Üretildi ve Slotlar Açıldı
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
                            SizedBox(width: 6),
                            Text("Aboneliğiniz Aktif (Yönetici)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        TextButton(
                          onPressed: _cancelSubscription,
                          child: const Text("İptal Et", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text("Arkadaşlarınızla Paylaşacağınız Davet Kodu:", style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            _generatedInviteCode ?? "",
                            style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                          icon: const Icon(Icons.copy, size: 14, color: Colors.white),
                          label: const Text("Kopyala", style: TextStyle(color: Colors.white, fontSize: 11)),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Davet kodu kopyalandı!")));
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text("Grup Kontenjanı (Siz + 3 Kişi)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildSlot("1. Ensar (Siz - Yönetici)", "Aktif", Colors.blueAccent, true),
              ..._members.map((m) => _buildSlot(m, "Aktif", Colors.green, true)),
              if (_members.length < _maxExtraMembers)
                _buildSlot("Boş Davet Yuvası (${_maxExtraMembers - _members.length} Kişilik Yer Var)", "Arkadaşınızı davet edin", Colors.grey, false),
            ],

            const SizedBox(height: 24),

            // 2. KISIM: AYRI ALAN - KARŞI TARAF İÇİN KOD GİRME ALANI
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.slate.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.key, color: Colors.indigo, size: 18),
                      SizedBox(width: 6),
                      Text("Arkadaşının Davet Kodu mu Var?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Size verilen 6 haneli aile davet kodunu girerek ücret ödemeden anında Premium'a geçebilirsiniz.",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: "Örn: KAMU77",
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onSubmitted: _submitFriendInviteCode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                        onPressed: () => _submitFriendInviteCode("KAMU77"),
                        child: const Text("Katıl & Premium Ol", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(String title, String status, Color color, bool isOccupied) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(isOccupied ? Icons.person : Icons.person_add, color: color, size: 14),
        ),
        title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        trailing: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}
