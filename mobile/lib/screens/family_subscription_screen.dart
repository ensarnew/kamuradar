import 'package:flutter/material.dart';

class FamilySubscriptionScreen extends StatefulWidget {
  final bool isVip;
  final VoidCallback? onPlanPurchased;

  const FamilySubscriptionScreen({
    Key? key,
    this.isVip = false,
    this.onPlanPurchased,
  }) : super(key: key);

  @override
  State<FamilySubscriptionScreen> createState() => _FamilySubscriptionScreenState();
}

class _FamilySubscriptionScreenState extends State<FamilySubscriptionScreen> {
  bool _isPlanPurchased = false;
  int _selectedPlanIndex = 1; // Varsayılan: Yıllık VIP (En Popüler)
  String? _generatedInviteCode;
  List<String> _members = [];
  final int _maxExtraMembers = 3;

  @override
  void initState() {
    super.initState();
    _isPlanPurchased = widget.isVip;
    if (_isPlanPurchased) {
      _generatedInviteCode = "KAMU77";
      _members = [
        "Ahmet Yılmaz (11.09.2026 katıldı)",
        "Mustafa Kaya (12.09.2026 katıldı)",
      ];
    }
  }

  // 1. Aboneliği Satın Al (Aylık veya Yıllık)
  void _buySubscription() {
    final planNames = [
      "Aylık VIP (39.99 ₺)",
      "Yıllık Avantajlı VIP (299.99 ₺)",
    ];
    setState(() {
      _isPlanPurchased = true;
      _generatedInviteCode = "KAMU77"; // 6 haneli üretilen kod
      _members = [
        "Ahmet Yılmaz (11.09.2026 katıldı)",
        "Mustafa Kaya (12.09.2026 katıldı)",
      ];
    });
    widget.onPlanPurchased?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${planNames[_selectedPlanIndex]} aktif edildi! Tüm reklamlar kaldırıldı ve 54 ilanın kilidi açıldı."),
      ),
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
      backgroundColor: const Color(0xFF091122),
      appBar: AppBar(
        title: const Text("Premium & Aile Paketi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. KISIM: PREMİUM SATIN ALMA VEYA YÖNETİM
            if (!_isPlanPurchased) ...[
              // Plan Seçim Kartları
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Avantajlı Paket Seçin", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 10),

                  // 1. Plan: Yıllık VIP (En Popüler)
                  InkWell(
                    onTap: () => setState(() => _selectedPlanIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedPlanIndex == 1 ? const Color(0xFF0F172A) : const Color(0xFF131E33),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedPlanIndex == 1 ? Colors.amber : const Color(0xFF1E2D4A),
                          width: _selectedPlanIndex == 1 ? 2 : 1,
                        ),
                        boxShadow: _selectedPlanIndex == 1 ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))] : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedPlanIndex == 1 ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: _selectedPlanIndex == 1 ? Colors.amber : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "Yıllık VIP (Aile Planı)",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedPlanIndex == 1 ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                                      child: const Text("EN POPÜLER • %37 İNDİRİM", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Tüm yıl boyunca 20 ilanın kilidi açık, sıfır reklam, 3 arkadaş ekleme hakkı.",
                                  style: TextStyle(fontSize: 10, color: _selectedPlanIndex == 1 ? Colors.white70 : Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "299.99 ₺\n/yıl",
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: _selectedPlanIndex == 1 ? Colors.amber : const Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Plan: Aylık VIP
                  InkWell(
                    onTap: () => setState(() => _selectedPlanIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedPlanIndex == 0 ? const Color(0xFF0F172A) : const Color(0xFF131E33),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedPlanIndex == 0 ? Colors.amber : const Color(0xFF1E2D4A),
                          width: _selectedPlanIndex == 0 ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedPlanIndex == 0 ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: _selectedPlanIndex == 0 ? Colors.amber : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Aylık VIP (Aile Planı)",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedPlanIndex == 0 ? Colors.white : Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Aylık yenilenir. 54 ilan açık, sınırsız bildirim, sıfır reklam, 3 arkadaş.",
                                  style: TextStyle(fontSize: 10, color: _selectedPlanIndex == 0 ? Colors.white70 : Colors.grey.shade400),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "39.99 ₺\n/ay",
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: _selectedPlanIndex == 0 ? Colors.amber : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Satın Al Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.workspace_premium, color: Colors.amber),
                      label: Text(
                        _selectedPlanIndex == 1
                            ? "299.99 ₺ ile Yıllık VIP Başlat (Sıfır Reklam)"
                            : "39.99 ₺ ile Aylık VIP Başlat (Sıfır Reklam)",
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      onPressed: _buySubscription,
                    ),
                  ),
                ],
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
                color: const Color(0xFF131E33),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2D4A)),
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
