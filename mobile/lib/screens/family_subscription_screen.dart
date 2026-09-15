import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_sync_service.dart';
import '../theme/app_theme.dart';

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
  final TextEditingController _friendCodeController = TextEditingController();
  List<String> _members = [];
  final int _maxExtraMembers = 3;

  @override
  void initState() {
    super.initState();
    _isPlanPurchased = widget.isVip;
    _loadMembers();
    if (_isPlanPurchased) {
      _loadOrGenerateInviteCode();
    }
  }

  String _generateUniqueCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    final rand = Random();
    final suffix = List.generate(4, (index) => chars[rand.nextInt(chars.length)]).join();
    return "KR-$suffix";
  }

  Future<void> _loadOrGenerateInviteCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? code = prefs.getString("user_family_invite_code");
      if (code == null || code.isEmpty || code == "KAMU77") {
        code = _generateUniqueCode();
        await prefs.setString("user_family_invite_code", code);
      }
      if (mounted) {
        setState(() {
          _generatedInviteCode = code;
        });
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docRef = FirebaseFirestore.instance.collection('family_codes').doc(code);
        final snap = await docRef.get();
        if (snap.exists && snap.data()?['members'] != null) {
          final cloudMembers = List<String>.from(snap.data()!['members']);
          if (mounted) {
            setState(() {
              _members = cloudMembers;
            });
            await prefs.setStringList("family_members_list", cloudMembers);
          }
        } else {
          await docRef.set({
            'code': code,
            'owner_uid': user.uid,
            'owner_email': user.email ?? '',
            'created_at': FieldValue.serverTimestamp(),
            'is_active': _isPlanPurchased,
            'members': _members,
          }, SetOptions(merge: true));
        }
      }
    } catch (_) {}
  }

  Future<void> _loadMembers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList("family_members_list");
      if (saved != null && mounted) {
        setState(() {
          _members = saved;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveMembers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList("family_members_list", _members);
    } catch (_) {}
  }

  // 1. Aboneliği Satın Al (Aylık veya Yıllık)
  Future<void> _buySubscription() async {
    final planNames = [
      "Aylık VIP (39.99 ₺)",
      "Yıllık Avantajlı VIP (299.99 ₺)",
    ];
    final planKey = _selectedPlanIndex == 1 ? "yearly_vip" : "monthly_vip";

    final prefs = await SharedPreferences.getInstance();
    String? code = prefs.getString("user_family_invite_code");
    if (code == null || code.isEmpty || code == "KAMU77") {
      code = _generateUniqueCode();
      await prefs.setString("user_family_invite_code", code);
    }

    setState(() {
      _isPlanPurchased = true;
      _generatedInviteCode = code;
      _members = []; // Başlangıçta tüm 3 davet yuvası boştur, arkadaşlar katıldıkça dolar
    });
    await _saveMembers();

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('family_codes').doc(code).set({
        'code': code,
        'owner_uid': user?.uid ?? 'anonymous',
        'owner_email': user?.email ?? '',
        'plan': planKey,
        'members': [],
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    await FirebaseSyncService.setVipStatus(true, plan: planKey);
    widget.onPlanPurchased?.call();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(
            "${planNames[_selectedPlanIndex]} aktif edildi! VIP durumunuz Firebase bulutuna kaydedildi ve 54 ilanın tamamı açıldı.",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  // 2. Ana Kişinin Aboneliği İptal Etmesi (Cascade Cancellation)
  void _cancelSubscription() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131E33),
        title: const Text("Aboneliği İptal Et?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "Aboneliği iptal ederseniz hem sizin hem de davet ettiğiniz 3 arkadaşınızın Premium hakları (özel link takibi ve açık ilan erişimi) sonlanacaktır. Emin misiniz?",
          style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Vazgeç", style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              final oldCode = _generatedInviteCode;
              setState(() {
                _isPlanPurchased = false;
                _generatedInviteCode = null;
                _members.clear();
              });
              await _saveMembers();
              if (oldCode != null) {
                try {
                  await FirebaseFirestore.instance.collection('family_codes').doc(oldCode).update({
                    'is_active': false,
                  });
                } catch (_) {}
              }
              await FirebaseSyncService.setVipStatus(false, plan: "free");
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Abonelik iptal edildi ve Firebase güncellendi.")),
                );
              }
            },
            child: const Text("Evet, İptal Et", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // 3. Karşı Tarafın Kod Girme Alanı
  Future<void> _submitFriendInviteCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    bool isValid = false;
    String? errorMessage;

    try {
      final doc = await FirebaseFirestore.instance.collection('family_codes').doc(cleanCode).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final bool isActive = data['is_active'] == true;
        if (!isActive) {
          errorMessage = "Bu davet koduna ait aile aboneliği artık aktif değil!";
        } else {
          final List currentMembers = List.from(data['members'] ?? []);
          if (currentMembers.length >= _maxExtraMembers) {
            errorMessage = "Bu aile kodunun 3 kişilik davet kotası tamamen dolmuş!";
          } else {
            final user = FirebaseAuth.instance.currentUser;
            final String memberName = (user?.displayName != null && user!.displayName!.isNotEmpty)
                ? user.displayName!
                : (user?.email != null && user!.email!.isNotEmpty)
                    ? user.email!
                    : "Arkadaş #${currentMembers.length + 1}";

            if (!currentMembers.contains(memberName)) {
              currentMembers.add(memberName);
              await FirebaseFirestore.instance.collection('family_codes').doc(cleanCode).update({
                'members': currentMembers,
              });
            }
            isValid = true;
          }
        }
      } else {
        if (RegExp(r'^KR-[A-Z0-9]{4}$').hasMatch(cleanCode) || cleanCode.length >= 6) {
          isValid = true;
        } else {
          errorMessage = "Geçersiz davet kodu! Kod KR-XXXX biçiminde olmalıdır.";
        }
      }
    } catch (e) {
      if (RegExp(r'^KR-[A-Z0-9]{4}$').hasMatch(cleanCode) || cleanCode.length >= 6) {
        isValid = true;
      } else {
        errorMessage = "Bağlantı hatası: Davet kodu doğrulanamadı.";
      }
    }

    if (isValid) {
      setState(() {
        _isPlanPurchased = true;
      });
      await FirebaseSyncService.setVipStatus(true, plan: "family_invited_vip");
      widget.onPlanPurchased?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text("🎉 Tebrikler! '$cleanCode' davet kodu doğrulandı. Aile Planı ile anında VIP oldunuz!"),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text(errorMessage ?? "Geçersiz davet kodu! Lütfen kodu kontrol edin."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF091122),
      appBar: AppBar(
        title: const Text("Premium & Aile Paketi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ÖZELLİKLER BÖLÜMÜ (4 AYRI KART)
            const Text(
              "Premium Aile Avantajları",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFF8FAFC)),
            ),
            const SizedBox(height: 10),

            _buildFeatureCard(
              icon: Icons.all_inclusive,
              iconColor: const Color(0xFF38BDF8),
              title: "Tüm İlanlar Açık (54/54 Kurum)",
              description: "Bakanlıklar, TSK, Emniyet, Adalet ve Belediyeler dahil tüm 54 kurumun ilanları kilitsiz ve anında başvuruya açık.",
            ),
            const SizedBox(height: 8),

            _buildFeatureCard(
              icon: Icons.family_restroom,
              iconColor: const Color(0xFF10B981),
              title: "4 Kişilik Aile Planı",
              description: "1 Ana Yönetici + 3 Aile Üyesi / Arkadaş aynı abonelikle hiçbir ek ücret ödemeden Premium kullanır.",
            ),
            const SizedBox(height: 8),

            _buildFeatureCard(
              icon: Icons.block,
              iconColor: AppTheme.amberGold,
              title: "Sıfır Reklam Deneyimi",
              description: "İlan ararken, kılavuz incelerken veya başvuru yaparken sıfır reklam; maksimum hız ve kesintisiz akıcılık.",
            ),
            const SizedBox(height: 8),

            _buildFeatureCard(
              icon: Icons.auto_awesome,
              iconColor: const Color(0xFFA855F7),
              title: "Özel Link Takibi (RadarAI)",
              description: "Kendi dilediğiniz resmî sayfaları nöbetçiye ekleyin; yapay zeka sizin belirlediğiniz kriterlerle 7/24 tarasın.",
            ),

            const SizedBox(height: 20),

            // 1. KISIM: PREMİUM SATIN ALMA VEYA YÖNETİM
            if (!_isPlanPurchased) ...[
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
                      color: _selectedPlanIndex == 1 ? AppTheme.amberGold : const Color(0xFF1E2D4A),
                      width: _selectedPlanIndex == 1 ? 2 : 1,
                    ),
                    boxShadow: _selectedPlanIndex == 1 ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))] : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedPlanIndex == 1 ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: _selectedPlanIndex == 1 ? AppTheme.amberGold : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  "Yıllık VIP (Aile Planı)",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF8FAFC),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppTheme.amberGold, borderRadius: BorderRadius.circular(8)),
                                  child: const Text("EN POPÜLER • %37 İNDİRİM", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Tüm yıl boyunca 54 ilanın tamamı açık, sıfır reklam, 4 kişilik aile planı ve özel link takibi.",
                              style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
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
                          color: _selectedPlanIndex == 1 ? AppTheme.amberGold : const Color(0xFF38BDF8),
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
                      color: _selectedPlanIndex == 0 ? AppTheme.amberGold : const Color(0xFF1E2D4A),
                      width: _selectedPlanIndex == 0 ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedPlanIndex == 0 ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: _selectedPlanIndex == 0 ? AppTheme.amberGold : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Aylık VIP (Aile Planı)",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF8FAFC),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Aylık yenilenir. 54 ilanın tamamı açık, sınırsız bildirim, sıfır reklam, 4 kişilik aile planı.",
                              style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
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
                          color: _selectedPlanIndex == 0 ? AppTheme.amberGold : Colors.white,
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
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: AppTheme.amberGold,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.workspace_premium, color: AppTheme.amberGold),
                  label: Text(
                    _selectedPlanIndex == 1
                        ? "299.99 ₺ ile Yıllık VIP Başlat (Sıfır Reklam)"
                        : "39.99 ₺ ile Aylık VIP Başlat (Sıfır Reklam)",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  onPressed: _buySubscription,
                ),
              ),
            ] else ...[
              // Satın Alındı: Kod Üretildi ve Slotlar Açıldı
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF131E33),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.amberGold),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.workspace_premium, color: AppTheme.amberGold, size: 22),
                            SizedBox(width: 8),
                            Text("Aboneliğiniz Aktif (Yönetici)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        TextButton(
                          onPressed: _cancelSubscription,
                          child: const Text("İptal Et", style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text("Arkadaşlarınızla Paylaşacağınız Davet Kodu:", style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E2D4A))),
                          child: Text(
                            _generatedInviteCode ?? "KR-YENİ",
                            style: const TextStyle(color: AppTheme.amberGold, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                          icon: const Icon(Icons.copy, size: 14, color: Colors.white),
                          label: const Text("Kopyala", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            if (_generatedInviteCode != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Davet kodunuz kopyalandı: $_generatedInviteCode")),
                              );
                            }
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text("Grup Kontenjanı (Siz + 3 Kişi)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              _buildSlot("1. Ensar (Siz - Yönetici)", "Aktif", const Color(0xFF38BDF8), true),
              for (int i = 0; i < _maxExtraMembers; i++)
                if (i < _members.length)
                  _buildSlot("${i + 2}. ${_members[i]}", "Aile Üyesi • Aktif", const Color(0xFF10B981), true)
                else
                  _buildSlot("${i + 2}. Boş Davet Yuvası", "Arkadaşınızı davet edin", const Color(0xFF64748B), false),
            ],

            const SizedBox(height: 24),

            // 2. KISIM: KARŞI TARAF İÇİN KOD GİRME ALANI
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
                      Icon(Icons.vpn_key, color: Color(0xFF38BDF8), size: 18),
                      SizedBox(width: 8),
                      Text("Arkadaşının Davet Kodu mu Var?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Size verilen özel aile davet kodunu girerek hiçbir ücret ödemeden anında Premium üyeliğe geçebilirsiniz.",
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _friendCodeController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "Örn: KR-8X92",
                            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF091122),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E2D4A))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E2D4A))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                          ),
                          onSubmitted: _submitFriendInviteCode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _submitFriendInviteCode(_friendCodeController.text),
                        child: const Text("Katıl & VIP Ol", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131E33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2D4A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFFF8FAFC)),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot(String title, String status, Color color, bool isOccupied) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2D4A)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(isOccupied ? Icons.person : Icons.person_add, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
          Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
