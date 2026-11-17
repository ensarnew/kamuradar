import 'package:flutter_test/flutter_test.dart';
import 'package:kamuradar/data/announcements_catalog.dart';
import 'package:kamuradar/screens/home_feed_screen.dart';

void main() {
  test('AnnouncementsCatalog dynamic dates test', () {
    final catalog = AnnouncementsCatalog.staticCatalog;
    expect(catalog.isNotEmpty, true);
    print('Total catalog items: ${catalog.length}');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int openCount = 0;
    int upcomingCount = 0;
    int resultCount = 0;

    for (final ch in catalog) {
      final startDate = ChannelAlarm.parseTurkishDate(ch.date);
      final deadlineDate = ChannelAlarm.parseTurkishDate(ch.deadline);

      expect(startDate != null, true, reason: 'Start date null for ${ch.id}: ${ch.date}');
      expect(deadlineDate != null, true, reason: 'Deadline null for ${ch.id}: ${ch.deadline}');

      if (ch.status == "Açık") {
        openCount++;
        // Başvuru bugün açık olmalı: start <= today <= deadline
        expect(startDate!.isAfter(today), false, reason: '${ch.id} Açık ama başlangıç bugünden sonra: ${ch.date}');
        expect(deadlineDate!.isBefore(today), false, reason: '${ch.id} Açık ama bitiş bugünden önce: ${ch.deadline}');
      } else if (ch.status == "Yakında") {
        upcomingCount++;
        expect(startDate!.isAfter(today), true, reason: '${ch.id} Yakında ama başlangıç bugün veya önce: ${ch.date}');
      } else {
        resultCount++;
      }
    }

    print('Open: $openCount, Upcoming: $upcomingCount, Others: $resultCount');
    expect(openCount >= 10, true);
    expect(upcomingCount >= 5, true);

    // 6.500 Uzman Erbaş geçmiş alım olduğu için dürüstçe 'Kapalı' olmalı
    final jandarma = catalog.firstWhere((c) => c.id == "jandarma-01");
    expect(jandarma.status, "Kapalı");
    expect(jandarma.officialUrl, "https://personeltemin.jandarma.gov.tr");
  });
}
