import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _isGroupOwner = false;
  String? _joinedViaCode;
  String? _groupOwnerName;
  StreamSubscription<DocumentSnapshot>? _familyCodeSub;

  @override
  void initState() {
    super.initState();
    _isPlanPurchased = widget.isVip;
    _checkPlanRole();
  }

  @override
  void dispose() {
    _familyCodeSub?.cancel();
    _friendCodeController.dispose();
    super.dispose();
  }

  Future<void> _checkPlanRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isVip = prefs.getBool("cache_is_vip") ?? widget.isVip;
      final isOwner = prefs.getBool("is_family_group_owner") ?? false;
      final joinedCode = prefs.getString("joined_family_code");

      if (isVip && !isOwner) {
        // Davetli VIP üye: Asla yönetici kodu üretmez, sadece arkadaşının koduyla VIP'dir
        if (mounted) {
          setState(() {
            _isGroupOwner = false;
            _isPlanPurchased = true;
            _joinedViaCode = joinedCode;
          });
        }
        if (joinedCode != null && joinedCode.isNotEmpty) {
          _listenToFamilyCode(joinedCode);
        }
      } else if (isVip && isOwner) {
        // Satın alan grup yöneticisi
        if (mounted) {
          setState(() {
            _isGroupOwner = true;
            _isPlanPurchased = true;
          });
        }
        await _loadOrGenerateInviteCode();
      } else {
        if (mounted) {
          setState(() {
            _isGroupOwner = false;
            _isPlanPurchased = false;
          });
        }
      }
    } catch (_) {}
  }

  String _generateUniqueCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    final rand = Random();
    final suffix = List.generate(4, (index) => chars[rand.nextInt(chars.length)]).join();
    return "KR-$suffix";
  }

  // 1. KOD ASLA DEĞİŞMEZ: Önce Firestore'a bakar, varsa kesinlikle onu korur
  Future<void> _loadOrGenerateInviteCode() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      String? code;

      // Adım A: Firestore users dokümanında kayıtlı sabit invite_code var mı?
      if (user != null) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (userDoc.exists && userDoc.data()?['invite_code'] != null) {
            final savedCode = userDoc.data()!['invite_code'].toString();
            if (savedCode.isNotEmpty && savedCode != "KAMU77") {
              code = savedCode;
            }
          }

          // Adım B: users altında yoksa family_codes koleksiyonunda bu owner_uid ile oluşturulmuş kod var mı?
          if (code == null || code.isEmpty) {
            final querySnap = await FirebaseFirestore.instance
                .collection('family_codes')
                .where('owner_uid', isEqualTo: user.uid)
                .limit(1)
                .get();
            if (querySnap.docs.isNotEmpty) {
              code = querySnap.docs.first.id;
            }
          }
        } catch (_) {}
      }

      // Adım C: Yerel hafızaya bak
      if (code == null || code.isEmpty) {
        final localCode = prefs.getString("user_family_invite_code");
        if (localCode != null && localCode.isNotEmpty && localCode != "KAMU77") {
          code = localCode;
        }
      }

      // Adım D: Hiçbir yerde kod yoksa İLK VE TEK SEFERLİK benzersiz kod üret
      if (code == null || code.isEmpty) {
        code = _generateUniqueCode();
      }

      // Hem yerel hafızaya hem Firebase users dokümanına KALICI olarak sabitle
      await prefs.setString("user_family_invite_code", code);
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'invite_code': code,
            'is_vip': true,
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _generatedInviteCode = code;
        });
      }

      // Firebase'deki o kod dokümanını canlı dinle
      _listenToFamilyCode(code);
    } catch (_) {}
  }

  // Canlı Firestore Dinleyicisi: Biri girdiğinde ekranda anında 2, 3 veya 4. sıraya düşer!
  void _listenToFamilyCode(String code) {
    _familyCodeSub?.cancel();
    final docRef = FirebaseFirestore.instance.collection('family_codes').doc(code);
    final user = FirebaseAuth.instance.currentUser;

    if (_isGroupOwner) {
      docRef.set({
        'code': code,
        'owner_uid': user?.uid ?? 'anonymous',
        'owner_email': user?.email ?? '',
        'owner_name': (user?.displayName != null && user!.displayName!.isNotEmpty)
            ? user.displayName!
            : (user?.email != null && user!.email!.isNotEmpty)
                ? user.email!.split('@')[0]
                : 'Yönetici',
        'is_active': true,
        'max_members': _maxExtraMembers,
      }, SetOptions(merge: true));
    }

    _familyCodeSub = docRef.snapshots().listen((snap) {
      if (!mounted || !snap.exists) return;
      final data = snap.data();
      if (data == null) return;

      final ownerName = (data['owner_name'] ?? data['owner_email'] ?? 'Grup Yöneticisi').toString();
      final cloudMembersRaw = data['members'] as List<dynamic>? ?? [];
      final List<String> parsedMembers = [];
      for (var item in cloudMembersRaw) {
        if (item is Map) {
          parsedMembers.add((item['name'] ?? item['email'] ?? 'Aile Üyesi').toString());
        } else if (item is String) {
          parsedMembers.add(item);
        }
      }

      setState(() {
        _groupOwnerName = ownerName;
        _members = parsedMembers;
      });
      SharedPreferences.getInstance().then((p) => p.setStringList("family_members_list", parsedMembers));
    });
  }

  // 1. Aboneliği Satın Al (Aylık veya Yıllık)
  Future<void> _buySubscription() async {
    final planNames = [
      "Aylık VIP (39.99 ₺)",
      "Yıllık Avantajlı VIP (299.99 ₺)",
    ];
    final planKey = _selectedPlanIndex == 1 ? "yearly_vip" : "monthly_vip";

    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    // KOD ASLA DEĞİŞMEZ: Önce mevcut kodu Firestore'dan veya yerelden al
    String? code;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data()?['invite_code'] != null) {
          code = userDoc.data()!['invite_code'].toString();
        }
      } catch (_) {}
    }
    code ??= prefs.getString("user_family_invite_code");

    if (code == null || code.isEmpty || code == "KAMU77") {
      code = _generateUniqueCode();
    }

    await prefs.setString("user_family_invite_code", code);
    await prefs.setBool("is_family_group_owner", true);
    await prefs.remove("joined_family_code");

    setState(() {
      _isPlanPurchased = true;
      _isGroupOwner = true;
      _generatedInviteCode = code;
    });

    try {
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'invite_code': code,
          'is_vip': true,
          'vip_plan': planKey,
        }, SetOptions(merge: true));
      }

      await FirebaseFirestore.instance.collection('family_codes').doc(code).set({
        'code': code,
        'owner_uid': user?.uid ?? 'anonymous',
        'owner_email': user?.email ?? '',
        'owner_name': (user?.displayName != null && user!.displayName!.isNotEmpty)
            ? user.displayName!
            : (user?.email != null && user!.email!.isNotEmpty)
                ? user.email!.split('@')[0]
                : 'Yönetici',
        'plan': planKey,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'max_members': _maxExtraMembers,
      }, SetOptions(merge: true));
    } catch (_) {}

    _listenToFamilyCode(code);

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
              _familyCodeSub?.cancel();

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool("is_family_group_owner", false);
              await prefs.remove("joined_family_code");
              await prefs.remove("user_family_invite_code");
              await prefs.remove("family_members_list");

              setState(() {
                _isPlanPurchased = false;
                _isGroupOwner = false;
                _generatedInviteCode = null;
                _members.clear();
              });

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

  // 3. Karşı Tarafın Kod Girme Alanı (FİREBASE KONTROLÜ - DOLU İSE DOLU UYARISI VERİR)
  Future<void> _submitFriendInviteCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    bool isValid = false;
    String? errorMessage;
    String? targetOwnerName;

    try {
      final doc = await FirebaseFirestore.instance.collection('family_codes').doc(cleanCode).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final bool isActive = data['is_active'] == true;
        final String ownerUid = (data['owner_uid'] ?? '').toString();
        final String ownerName = (data['owner_name'] ?? data['owner_email'] ?? 'Grup Yöneticisi').toString();
        targetOwnerName = ownerName;

        if (!isActive) {
          errorMessage = "Bu davet koduna ait aile aboneliği artık aktif değil!";
        } else if (user != null && ownerUid == user.uid) {
          errorMessage = "Kendi davet kodunuzu giremezsiniz! Siz zaten bu grubun yöneticisisiniz.";
        } else {
          final List currentMembersRaw = List.from(data['members'] ?? []);
          final String myUid = user?.uid ?? '';
          final String myIdentifier = (user?.displayName != null && user!.displayName!.isNotEmpty)
              ? user.displayName!
              : (user?.email != null && user!.email!.isNotEmpty)
                  ? user.email!
                  : "Arkadaş #${currentMembersRaw.length + 1}";

          bool alreadyIn = false;
          for (var m in currentMembersRaw) {
            if (m is Map && (m['uid'] == myUid || m['name'] == myIdentifier || m['email'] == user?.email)) {
              alreadyIn = true;
              break;
            } else if (m is String && m == myIdentifier) {
              alreadyIn = true;
              break;
            }
          }

          if (alreadyIn) {
            isValid = true;
          } else if (currentMembersRaw.length >= _maxExtraMembers) {
            // KULLANICININ İSTEDİĞİ DOLU UYARISI:
            errorMessage = "Kod sahibinin ($ownerName) aile planı dolu! (3/3 kişi katılmış).";
          } else {
            // Kod sahibinin sırasına yeni üyeyi ekle
            final newMemberMap = {
              'uid': myUid,
              'email': user?.email ?? '',
              'name': myIdentifier,
              'joined_at': DateTime.now().toIso8601String(),
            };
            currentMembersRaw.add(newMemberMap);

            await FirebaseFirestore.instance.collection('family_codes').doc(cleanCode).update({
              'members': currentMembersRaw,
            });

            if (user != null) {
              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                'is_vip': true,
                'vip_plan': 'family_invited_vip',
                'joined_family_code': cleanCode,
                'family_owner_uid': ownerUid,
              }, SetOptions(merge: true));
            }
            isValid = true;
          }
        }
      } else {
        errorMessage = "Geçersiz davet kodu! Bu kod sistemde kayıtlı değildir.";
      }
    } catch (e) {
      errorMessage = "Bağlantı hatası: Davet kodu doğrulanamadı. Lütfen internet bağlantınızı kontrol edin.";
    }

    if (isValid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("joined_family_code", cleanCode);
      await prefs.setBool("is_family_group_owner", false);
      await prefs.remove("user_family_invite_code");

      setState(() {
        _isPlanPurchased = true;
        _isGroupOwner = false;
        _joinedViaCode = cleanCode;
      });

      _listenToFamilyCode(cleanCode);

      await FirebaseSyncService.setVipStatus(true, plan: "family_invited_vip");
      widget.onPlanPurchased?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text("🎉 Tebrikler! Kod sahibinin ($targetOwnerName) aile planına başarıyla katıldınız. Tüm VIP avantajlarınız sınırsız aktif!"),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
            content: Text(errorMessage ?? "Geçersiz davet kodu! Lütfen kodu kontrol edin."),
          ),
        );
      }
    }
  }

  void _shareOnWhatsApp() async {
    if (_generatedInviteCode == null) return;
    final message = "KamuRadar Aile VIP Davet Kodum: $_generatedInviteCode\n\nKamuRadar uygulamasını indir, Aile Planı ekranında bu davet kodunu girerek 54 ilana ve canlı nöbetçiye ücretsiz eriş!\nİndir: https://kamuradar.onrender.com";
    final url = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(message)}");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        final webUrl = Uri.parse("https://api.whatsapp.com/send?text=${Uri.encodeComponent(message)}");
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("WhatsApp başlatılamadı: $e")),
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
              icon: Icons.language,
              iconColor: const Color(0xFF38BDF8),
              title: "Özel Web Sitesi Nöbetçisi",
              description: "Kendi dilediğiniz resmî kamu veya sınav sayfalarını ekleyin; sistem belirlediğiniz kelimelerle sayfayı takip etsin.",
            ),
            const SizedBox(height: 8),

            _buildFeatureCard(
              icon: Icons.schedule,
              iconColor: AppTheme.amberGold,
              title: "Gündüz 2 Saatte Bir Canlı Denetim",
              description: "Gündüz 10:00 - 22:00 arasında otomatik denetim yapılır; yeni ilan tespit edildiğinde anında bildirim gönderilir.",
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
                              "Tüm yıl boyunca 54 ilanın tamamı açık, 4 kişilik aile planı ve özel web sitesi takibi.",
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
                              "Aylık yenilenir. 54 ilanın tamamı açık, sınırsız bildirim, 4 kişilik aile planı ve özel site takibi.",
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
                        ? "299.99 ₺ ile Yıllık VIP Başlat"
                        : "39.99 ₺ ile Aylık VIP Başlat",
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  onPressed: _buySubscription,
                ),
              ),
            ] else ...[
              if (_isGroupOwner) ...[
                // 1. Yönetici Kartı: Sadece satın alan kişi kod dağıtabilir ve slotları yönetir
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
                              Text("Aboneliğiniz Aktif (Grup Yöneticisi)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          TextButton(
                            onPressed: _cancelSubscription,
                            child: const Text("İptal Et", style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text("3 Arkadaşınızla Paylaşacağınız Özel Davet Kodu:", style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E2D4A))),
                            child: Text(
                              _generatedInviteCode ?? "KR-YENİ",
                              style: const TextStyle(color: AppTheme.amberGold, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            icon: const Icon(Icons.copy, size: 14, color: Colors.white),
                            label: const Text("Kopyala", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              if (_generatedInviteCode != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Davet kodunuz kopyalandı: $_generatedInviteCode")),
                                );
                              }
                            },
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            icon: const Icon(Icons.share, size: 14, color: Colors.white),
                            label: const Text("WhatsApp'ta Paylaş", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: _shareOnWhatsApp,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text("Grup Kontenjanı (Siz + 3 Kişi)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                _buildSlot(
                  "1. ${(FirebaseAuth.instance.currentUser?.displayName != null && FirebaseAuth.instance.currentUser!.displayName!.isNotEmpty) ? FirebaseAuth.instance.currentUser!.displayName! : (FirebaseAuth.instance.currentUser?.email != null ? FirebaseAuth.instance.currentUser!.email!.split('@')[0] : 'Yönetici')} (Siz - Yönetici)",
                  "Aktif",
                  const Color(0xFF38BDF8),
                  true,
                ),
                for (int i = 0; i < _maxExtraMembers; i++)
                  if (i < _members.length)
                    _buildSlot("${i + 2}. ${_members[i]}", "Aile Üyesi • Aktif", const Color(0xFF10B981), true)
                  else
                    _buildSlot("${i + 2}. Boş Davet Yuvası", "Arkadaşınızı davet edin", const Color(0xFF64748B), false),
              ] else ...[
                // 2. Davetli Üye Kartı: Kod DAĞITAMAZ, sadece VIP haklarından faydalanır
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131E33),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user, color: Color(0xFF10B981), size: 22),
                          SizedBox(width: 8),
                          Text("Aile Planı Üyeliği Aktif (Davetli Üye)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _joinedViaCode != null
                            ? "Arkadaşınızın '$_joinedViaCode' davet koduyla Premium aile grubuna katıldınız. 54 İlanın tamamı ve özel web sitesi nöbetçisi sınırsız kullanımınızdadır."
                            : "Premium Aile Planı üyesi olarak tüm VIP avantajlarından (54 İlan Açık, Özel Nöbetçi) sınırsız yararlanıyorsunuz.",
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E2D4A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline, color: Color(0xFF38BDF8), size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Güvenlik & Lisans Kuralı: Yalnızca satın alan grup yöneticisi yeni üye davet edebilir. Üyeliğiniz yönetici aboneliği devam ettiği sürece aktiftir.",
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Grup Kontenjanı (Yönetici + 3 Kişi)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                _buildSlot(
                  "1. ${_groupOwnerName ?? 'Grup Yöneticisi'} (Yönetici)",
                  "Aktif",
                  const Color(0xFF38BDF8),
                  true,
                ),
                for (int i = 0; i < _maxExtraMembers; i++)
                  if (i < _members.length)
                    _buildSlot("${i + 2}. ${_members[i]}", "Aile Üyesi • Aktif", const Color(0xFF10B981), true)
                  else
                    _buildSlot("${i + 2}. Boş Davet Yuvası", "Bekleniyor", const Color(0xFF64748B), false),
              ],
            ],

            // 2. KISIM: KARŞI TARAF İÇİN KOD GİRME ALANI (SADECE VIP OLMAYANLAR İÇİN GÖRÜNÜR)
            if (!_isPlanPurchased) ...[
              const SizedBox(height: 24),
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
                              hintText: "Davet Kodunu Girin (Örn: KR-XXXX)",
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
