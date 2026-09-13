import 'package:flutter/material.dart';
import '../models/announcement.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  final Announcement announcement;

  const AnnouncementDetailScreen({Key? key, required this.announcement}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("İlan Detayı", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                announcement.organization,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              announcement.title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, height: 1.3),
            ),
            const SizedBox(height: 16),

            // Tarih Kartı
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Başvuru Başlangıç", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 3),
                      Text(announcement.applicationStart ?? "-", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Son Başvuru", style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                      const SizedBox(height: 3),
                      Text(announcement.applicationDeadline ?? "-", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text("Özet & Açıklama", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              announcement.summary,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.5),
            ),
            const SizedBox(height: 20),

            const Text("Başvuru Şartları", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...announcement.requirements.map(
              (req) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(req, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 12:00 Tarama İmzası
            Center(
              child: Text(
                "Bu ilan ${announcement.scannedAt12pm} günlük 12:00 taramasında tespit edilmiştir.",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 30),

            // Resmî İlana Git Butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.open_in_new, color: Colors.white),
                label: const Text("Resmî Başvuru Ekranına Git", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Yönlendiriliyor: ${announcement.officialUrl}")),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
