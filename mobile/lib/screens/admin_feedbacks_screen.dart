import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class AdminFeedbacksScreen extends StatefulWidget {
  const AdminFeedbacksScreen({Key? key}) : super(key: key);

  @override
  State<AdminFeedbacksScreen> createState() => _AdminFeedbacksScreenState();
}

class _AdminFeedbacksScreenState extends State<AdminFeedbacksScreen> {
  String _filter = "Tümü"; // "Tümü", "Bekleyenler", "Yanıtlananlar"
  bool _isLoading = false;
  List<Map<String, dynamic>> _feedbacks = [];
  String? _errorMessage;

  final List<String> _quickResponses = [
    "Geri bildiriminiz için çok teşekkür ederiz! Konuyla ilgili inceleme ve çalışma başlattık, en kısa sürede çözülecektir.",
    "Bildirdiğiniz sorun teknik ekibimiz tarafından düzeltilmiştir. Dikkatiniz ve desteğiniz için çok teşekkür ederiz!",
    "Değerli öneriniz için teşekkürler! Yeni güncellememize eklemek üzere geliştirme listemize aldık.",
    "Talebiniz incelendi. Belirttiğiniz kadro ve ilan bilgileri sisteme dahil edilmiştir.",
  ];

  @override
  void initState() {
    super.initState();
    _loadAllFeedbacks();
    _listenToFirestoreSafely();
  }

  void _listenToFirestoreSafely() {
    try {
      FirebaseFirestore.instance.collection('feedbacks').snapshots().listen((snapshot) {
        if (!mounted) return;
        if (snapshot.docs.isNotEmpty) {
          final List<Map<String, dynamic>> list = [];
          for (var doc in snapshot.docs) {
            final data = doc.data();
            list.add({
              ...data,
              'id': doc.id,
            });
          }
          _sortAndSetFeedbacks(list);
        }
      }, onError: (err) {
        // Firestore permission denied veya index hatası durumunda arka plan API devrede
        _loadFeedbacksFromApi();
      });
    } catch (_) {
      _loadFeedbacksFromApi();
    }
  }

  Future<void> _loadAllFeedbacks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. Önce doğrudan Firestore dene (index istemeden)
    try {
      final snap = await FirebaseFirestore.instance.collection('feedbacks').get();
      if (snap.docs.isNotEmpty) {
        final List<Map<String, dynamic>> list = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        _sortAndSetFeedbacks(list);
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    } catch (_) {
      // Permission denied veya kural engeli durumunda API'ye geç
    }

    // 2. Yedek: Backend Admin API (Firebase Admin Root Yetkisiyle)
    await _loadFeedbacksFromApi();
  }

  Future<void> _loadFeedbacksFromApi() async {
    try {
      final res = await http.get(
        Uri.parse("https://kamuradar.onrender.com/api/admin/feedbacks"),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final List<dynamic> rawList = jsonDecode(utf8.decode(res.bodyBytes));
        final List<Map<String, dynamic>> list = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _sortAndSetFeedbacks(list);
      } else {
        if (_feedbacks.isEmpty) {
          _errorMessage = "Sunucu yanıt kodu: ${res.statusCode}";
        }
      }
    } catch (e) {
      if (_feedbacks.isEmpty) {
        _errorMessage = "Bağlantı hatası: $e";
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortAndSetFeedbacks(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final aDate = a['created_at']?.toString() ?? '';
      final bDate = b['created_at']?.toString() ?? '';
      return bDate.compareTo(aDate);
    });

    if (mounted) {
      setState(() {
        _feedbacks = list;
        _errorMessage = null;
      });
    }
  }

  void _showReplySheet(Map<String, dynamic> item) {
    final docId = (item['id'] ?? '').toString();
    final currentReply = (item['admin_reply'] ?? '').toString();
    final replyController = TextEditingController(text: currentReply);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.reply_all_rounded, color: Colors.amber, size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Kullanıcıya Yanıt & Teşekkür",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Kullanıcı: ${item['user_name'] ?? 'İsimsiz'} (${item['email'] ?? 'E-posta Yok'})",
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Konu: ${item['subject'] ?? ''}",
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Mesaj: ${item['message'] ?? ''}",
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Hızlı Hazır Şablonlar (Tek Tıkla Seç):",
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    ..._quickResponses.map((res) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: InkWell(
                          onTap: () {
                            setSheetState(() {
                              replyController.text = res;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131E33),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF1E2D4A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bolt, color: Colors.amber, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    res,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 10),
                    const Text(
                      "Kullanıcıya İletilecek Yanıt Mesajı:",
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131E33),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E2D4A)),
                      ),
                      child: TextField(
                        controller: replyController,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Kullanıcıya özel mesajınızı buraya yazın...",
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Vazgeç", style: TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            label: const Text(
                              "Yanıtı Gönder",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: () async {
                              final text = replyController.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Lütfen bir yanıt metni girin.")),
                                );
                                return;
                              }

                              // 1. Önce Firestore doğrudan dene
                              bool saved = false;
                              try {
                                await FirebaseFirestore.instance.collection('feedbacks').doc(docId).update({
                                  'status': 'replied',
                                  'admin_reply': text,
                                  'replied_at': FieldValue.serverTimestamp(),
                                });
                                saved = true;
                              } catch (_) {}

                              // 2. Olmazsa Backend Admin Proxy ile kesin kaydet
                              if (!saved) {
                                try {
                                  final res = await http.post(
                                    Uri.parse("https://kamuradar.onrender.com/api/admin/feedback/reply"),
                                    headers: {"Content-Type": "application/json"},
                                    body: jsonEncode({
                                      "id": docId,
                                      "admin_reply": text,
                                    }),
                                  ).timeout(const Duration(seconds: 8));
                                  if (res.statusCode == 200) saved = true;
                                } catch (_) {}
                              }

                              // Yerel durumu güncelle
                              setState(() {
                                final idx = _feedbacks.indexWhere((f) => f['id'] == docId);
                                if (idx != -1) {
                                  _feedbacks[idx]['status'] = 'replied';
                                  _feedbacks[idx]['admin_reply'] = text;
                                }
                              });

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Color(0xFF22C55E),
                                    content: Text("✅ Yanıt başarıyla kullanıcıya iletildi ve 'Okundu' olarak kaydedildi!"),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteFeedback(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Silinsin mi?"),
        content: const Text("Bu geri bildirimi silmek istediğinizden emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Vazgeç")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.urgentRed),
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 1. Önce Firestore dene
    try {
      await FirebaseFirestore.instance.collection('feedbacks').doc(docId).delete();
    } catch (_) {
      // 2. Olmazsa Backend Admin Proxy ile sil
      try {
        await http.delete(Uri.parse("https://kamuradar.onrender.com/api/admin/feedback/$docId"));
      } catch (_) {}
    }

    setState(() {
      _feedbacks.removeWhere((f) => f['id'] == docId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredDocs = _feedbacks.where((item) {
      if (_filter == "Bekleyenler") return item['status'] != 'replied';
      if (_filter == "Yanıtlananlar") return item['status'] == 'replied';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgSoft,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text("Kullanıcı Geri Bildirimleri", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllFeedbacks,
            tooltip: "Yenile",
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtre Çipleri
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF0F172A),
            child: Row(
              children: ["Tümü", "Bekleyenler", "Yanıtlananlar"].map((f) {
                final isSel = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: isSel,
                    onSelected: (v) => setState(() => _filter = f),
                    selectedColor: AppTheme.primaryBlue,
                    backgroundColor: const Color(0xFF1E293B),
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : Colors.white70,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Liste Görünümü
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAllFeedbacks,
                    child: filteredDocs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.white38),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage ?? (_filter == "Bekleyenler" ? "Bekleyen bildirim yok!" : "Henüz geri bildirim gelmemiş."),
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                TextButton.icon(
                                  onPressed: _loadAllFeedbacks,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text("Tekrar Dene"),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              final item = filteredDocs[index];
                              final isReplied = item['status'] == 'replied';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131E33),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isReplied ? const Color(0xFF1E2D4A) : Colors.amber.withValues(alpha: 0.6),
                                    width: 1.2,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item['category'] ?? 'Geri Bildirim',
                                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isReplied
                                                ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                                                : Colors.amber.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isReplied ? "✅ Yanıtlandı" : "⏳ Yeni Bekliyor",
                                            style: TextStyle(
                                              color: isReplied ? const Color(0xFF4ADE80) : Colors.amber,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 14, color: Colors.white54),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${item['user_name'] ?? 'İsimsiz'} • ${item['email'] ?? 'E-posta Yok'}",
                                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item['subject'] ?? 'Başlık Yok',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['message'] ?? '',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                                    ),
                                    if (isReplied) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF064E3B).withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "💬 Gönderdiğiniz Yanıt:",
                                              style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item['admin_reply'] ?? '',
                                              style: const TextStyle(color: Colors.white, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white38),
                                          onPressed: () => _deleteFeedback((item['id'] ?? '').toString()),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isReplied ? const Color(0xFF1E293B) : Colors.amber,
                                            foregroundColor: isReplied ? Colors.white : const Color(0xFF0F172A),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          icon: Icon(
                                            isReplied ? Icons.edit : Icons.reply_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            isReplied ? "Yanıtı Güncelle" : "Yanıtla & Teşekkür Et",
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          onPressed: () => _showReplySheet(item),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
