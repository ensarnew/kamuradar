import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String? suggestedUrl;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.suggestedUrl,
  });
}

class RadarAISheet extends StatefulWidget {
  final bool isVip;
  final VoidCallback? onUpgradeRequested;
  final String? initialPrompt;

  const RadarAISheet({
    Key? key,
    required this.isVip,
    this.onUpgradeRequested,
    this.initialPrompt,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required bool isVip,
    VoidCallback? onUpgradeRequested,
    String? initialPrompt,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RadarAISheet(
        isVip: isVip,
        onUpgradeRequested: onUpgradeRequested,
        initialPrompt: initialPrompt,
      ),
    );
  }

  @override
  State<RadarAISheet> createState() => _RadarAISheetState();
}

class _RadarAISheetState extends State<RadarAISheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late int _maxQuota;
  int _usedCount = 0;
  bool _isExhausted = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Merhaba! Ben RadarAI. Kamu alımları (Jandarma, MSÜ, POMEM, KPSS vb.), başvuru şartları ve resmî duyuru linkleri konusunda size rehberlik edebilirim. Ne öğrenmek istersiniz?",
      isUser: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _maxQuota = widget.isVip ? 10 : 3;

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSendMessage(widget.initialPrompt!);
      });
    }
  }

  int get _remainingQuota => (_maxQuota - _usedCount).clamp(0, _maxQuota);

  void _handleSendMessage(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;

    if (_remainingQuota <= 0) {
      setState(() {
        _isExhausted = true;
        _messages.add(ChatMessage(
          text: "Sistem şu an aktif değil",
          isUser: false,
        ));
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: clean, isUser: true));
      _usedCount++;
      if (_remainingQuota <= 0) {
        _isExhausted = true;
      }
    });

    _textController.clear();
    _scrollToBottom();

    // AI Yanıtı Simülasyonu / Fallback
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final replyData = _generateAiReply(clean);
      setState(() {
        _messages.add(ChatMessage(
          text: replyData['reply']!,
          isUser: false,
          suggestedUrl: replyData['url'],
        ));
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Map<String, String?> _generateAiReply(String msg) {
    final lower = msg.toLowerCase();

    if (lower.contains("jandarma") || lower.contains("uzman")) {
      return {
        "reply": "🎯 Jandarma 2.500 Uzman Erbaş Alımı:\n• En az lise mezunu olmak\n• 27 yaşını bitirmemiş olmak (1999 ve sonrası)\n• Boy en az 167 cm (VKİ: 19-26)\n\nResmî Başvuru: https://vatandas.jandarma.gov.tr/PTM/Giris",
        "url": "https://vatandas.jandarma.gov.tr/PTM/Giris"
      };
    } else if (lower.contains("pomem") || lower.contains("polis")) {
      return {
        "reply": "👮 32. Dönem POMEM 10.000 Polis Memuru:\n• Lisans: KPSS P3 ≥ 60\n• Önlisans: KPSS P93 ≥ 65\n• Yaş: 30'dan gün almamış olmak\n• Erkek ≥ 167 cm, Kadın ≥ 162 cm\n\nResmî Portal: https://www.pa.edu.tr",
        "url": "https://www.pa.edu.tr"
      };
    } else if (lower.contains("kpss") || lower.contains("65") || lower.contains("70")) {
      return {
        "reply": "📊 KPSS 65 Puan Fırsatları:\n• Adalet Bakanlığı İKM (İnfaz Koruma)\n• Zabıt Katipliği ve Mübaşir\n• Belediye Zabıta & İtfaiye\n• POMEM Polislik Başvurusu\n\nResmî Takvim: https://ais.osym.gov.tr",
        "url": "https://ais.osym.gov.tr"
      };
    } else if (lower.contains("msü") || lower.contains("msu") || lower.contains("askeri")) {
      return {
        "reply": "🎖️ MSÜ Askeri Öğrenci Alımı:\n• Harp Okulları: En fazla 20 yaş\n• Astsubay MYO: En fazla 21 yaş\n• MSÜ yazılı sınavı + 2. Seçim Aşamaları (Fiziki/Mülakat)\n\nResmî Adres: https://personeltemin.msb.gov.tr",
        "url": "https://personeltemin.msb.gov.tr"
      };
    } else {
      return {
        "reply": "🤖 Sorunuz incelendi. Kamu personeli alımları Resmî Gazete ve kurumların personel temin ekranlarında yayımlanır. Takip etmek istediğiniz adresi KamuRadar 'Özel Linkler' sekmesine ekleyebilir, her gün 12:00'de otomatik taranmasını sağlayabilirsiniz.\n\nResmî Adres: https://kariyerkapisi.cbiko.gov.tr",
        "url": "https://kariyerkapisi.cbiko.gov.tr"
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Çekmece Tutacağı
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Başlık ve Kota Bilgisi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "RadarAI Asistanı",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.isVip ? AppTheme.amberGold : Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.isVip ? "VIP (10 Soru)" : "ÜCRETSİZ (3 Soru)",
                              style: TextStyle(
                                color: widget.isVip ? Colors.black : Colors.lightBlueAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _isExhausted
                            ? "Sistem şu an aktif değil (Kota doldu)"
                            : "Kalan Soru Hakkınız: $_remainingQuota / $_maxQuota",
                        style: TextStyle(
                          color: _isExhausted ? Colors.redAccent : Colors.white70,
                          fontSize: 12,
                          fontWeight: _isExhausted ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Hazır Öneri Butonları
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _buildPromptChip("Jandarma şartları neler?"),
                _buildPromptChip("32. Dönem POMEM boy-kilo?"),
                _buildPromptChip("KPSS 65 ile nereye girilir?"),
                _buildPromptChip("Özel linke ne yapıştırmalıyım?"),
              ],
            ),
          ),

          // Kota Bittiğinde Uyarı Kartı
          if (_isExhausted)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.isVip
                          ? "Sistem şu an aktif değil: Günlük 10 soru limitinize ulaştınız. Yarın saat 12:00'de kotanız yenilenir."
                          : "Sistem şu an aktif değil: 3 ücretsiz soru hakkınız doldu! VIP Aile Planı ile günde 10 soru hakkı kazanın.",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  if (!widget.isVip && widget.onUpgradeRequested != null)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onUpgradeRequested!();
                      },
                      child: const Text("Yükselt", style: TextStyle(color: AppTheme.amberGold, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),

          // Mesaj Geçmişi
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, index) {
                final m = _messages[index];
                return _buildMessageBubble(m);
              },
            ),
          ),

          // Mesaj Yazma Alanı
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: !_isExhausted,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _isExhausted
                          ? "Sistem şu an aktif değil..."
                          : "Bir kamu alımı sorusu yazın...",
                      hintStyle: TextStyle(
                        color: _isExhausted ? Colors.redAccent : Colors.white38,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (val) => _handleSendMessage(val),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded),
                  color: _isExhausted ? Colors.white24 : AppTheme.primaryBlue,
                  onPressed: _isExhausted ? null : () => _handleSendMessage(_textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        backgroundColor: const Color(0xFF1E293B),
        side: const BorderSide(color: Colors.white10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _isExhausted ? null : () => _handleSendMessage(text),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      );
    } else {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              ),
              if (msg.suggestedUrl != null) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text("Linki Kopyala & Özel Linkler'e Ekle", style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: AppTheme.amberGold,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: msg.suggestedUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Resmî link kopyalandı: ${msg.suggestedUrl}")),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }
  }
}

class RadarAIFloatingButton extends StatelessWidget {
  final bool isVip;
  final VoidCallback? onUpgradeRequested;

  const RadarAIFloatingButton({
    Key? key,
    required this.isVip,
    this.onUpgradeRequested,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'radar_ai_fab',
      onPressed: () {
        RadarAISheet.show(
          context,
          isVip: isVip,
          onUpgradeRequested: onUpgradeRequested,
        );
      },
      backgroundColor: Colors.transparent,
      elevation: 6,
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text(
              "RadarAI",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isVip ? AppTheme.amberGold : Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isVip ? "10 Soru" : "3 Soru",
                style: TextStyle(
                  color: isVip ? Colors.black : Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
