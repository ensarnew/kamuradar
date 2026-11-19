import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({Key? key}) : super(key: key);

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String _selectedCategory = "🐛 Hata / Sorun Bildir";
  bool _isSubmitting = false;

  final List<String> _categories = [
    "🐛 Hata / Sorun Bildir",
    "💡 Yeni Özellik / İlan İsteği",
    "⭐ Öneri & Görüş",
    "⚖️ Yanlış İlan Bilgisi",
    "❓ Genel Soru",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    final email = _emailController.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.urgentRed,
          content: Text("Lütfen konu başlığı ve mesajınızı yazın."),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
      final userName = user?.displayName ?? (email.isNotEmpty ? email.split('@')[0] : 'Misafir Kullanıcı');

      final docRef = await FirebaseFirestore.instance.collection('feedbacks').add({
        'user_id': userId,
        'user_name': userName,
        'email': email.isNotEmpty ? email : (user?.email ?? 'Belirtilmedi'),
        'category': _selectedCategory,
        'subject': subject,
        'message': message,
        'status': 'pending', // 'pending' | 'replied'
        'admin_reply': null,
        'created_at': FieldValue.serverTimestamp(),
        'replied_at': null,
        'app_version': '1.0.18',
      });

      // Misafir için de kendi gönderdiği feedback id'sini sakla
      final prefs = await SharedPreferences.getInstance();
      final myFeedbacks = prefs.getStringList("my_feedback_ids") ?? [];
      myFeedbacks.add(docRef.id);
      await prefs.setStringList("my_feedback_ids", myFeedbacks);

      if (!mounted) return;

      _subjectController.clear();
      _messageController.clear();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 26),
              SizedBox(width: 10),
              Text(
                "İletildi!",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: const Text(
            "Geri bildiriminiz yöneticimize ulaştı. İncelendiğinde bu ekrandan veya e-postanızdan size doğrudan teşekkür ve bilgilendirme yanıtı gönderilecektir.",
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _tabController.animateTo(1); // Yanıtlarım sekmesine geç
              },
              child: const Text("Taleplerimi Gör", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.urgentRed,
          content: Text("Gönderim hatası: $e"),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgSoft,
      appBar: AppBar(
        title: const Text("Geri Bildirim & Destek", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.edit_note), text: "Yeni Bildirim"),
            Tab(icon: Icon(Icons.forum_outlined), text: "Yanıtlanan Taleplerim"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewFeedbackTab(),
          _buildMyFeedbacksTab(),
        ],
      ),
    );
  }

  Widget _buildNewFeedbackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.support_agent, color: Color(0xFF38BDF8), size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Fikriniz Bizim İçin Değerli!",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Karşılaştığınız bir sorun, yeni özellik fikri veya eklenmesini istediğiniz ilanları yazın; ekibimiz doğrudan incelesin.",
                        style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            "Bildirim Türü:",
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final isSel = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: isSel,
                onSelected: (v) => setState(() => _selectedCategory = cat),
                selectedColor: AppTheme.primaryBlue,
                backgroundColor: const Color(0xFF131E33),
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          const Text(
            "Konu Başlığı:",
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF131E33),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2D4A)),
            ),
            child: TextField(
              controller: _subjectController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Örn: Zabıta alımı linki açılmıyor veya KPSS P94 filtresi",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            "Açıklama / Mesajınız:",
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF131E33),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2D4A)),
            ),
            child: TextField(
              controller: _messageController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Sorunu veya istediğiniz özelliği detaylıca açıklayın...",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            "İletişim E-Postanız (Yanıt İçin):",
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF131E33),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2D4A)),
            ),
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "ornek@gmail.com",
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              label: Text(
                _isSubmitting ? "Gönderiliyor..." : "Geri Bildirimi Gönder",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _isSubmitting ? null : _submitFeedback,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyFeedbacksTab() {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('feedbacks')
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];
        // Kullanıcının kendi dokümanlarını veya telefon hafızasındaki ID'leri filtrele
        final myDocs = allDocs.where((doc) {
          final data = doc.data();
          if (userId != null && data['user_id'] == userId) return true;
          if (user?.email != null && data['email'] == user!.email) return true;
          return false;
        }).toList();

        if (myDocs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131E33),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1E2D4A)),
                    ),
                    child: const Icon(Icons.inbox, size: 40, color: Colors.white38),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Henüz Bir Bildiriminiz Yok",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Gönderdiğiniz tüm istekler ve yöneticimizin size özel teşekkür yanıtları burada listelenecektir.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: myDocs.length,
          itemBuilder: (context, index) {
            final data = myDocs[index].data();
            final isReplied = data['status'] == 'replied' && data['admin_reply'] != null;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF131E33),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isReplied ? const Color(0xFF22C55E).withValues(alpha: 0.6) : const Color(0xFF1E2D4A),
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
                          data['category'] ?? 'Geri Bildirim',
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isReplied ? const Color(0xFF22C55E).withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isReplied ? "✅ Yanıtlandı" : "⏳ İnceleniyor",
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
                  Text(
                    data['subject'] ?? 'Konu Yok',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['message'] ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                  ),
                  if (isReplied) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified, color: Color(0xFF34D399), size: 16),
                              SizedBox(width: 6),
                              Text(
                                "👑 KamuRadar Yönetici Yanıtı:",
                                style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            data['admin_reply'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
