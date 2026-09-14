import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/announcement.dart';
import '../models/custom_link.dart';
import '../models/exam_schedule.dart';

class ApiService {
  // Render üzerinde çalışan canlı FastAPI sunucu adresi
  static const String baseUrl = "https://kamuradar.onrender.com";

  static Map<String, String> get _headers => {
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  // 1. Sınav & Başvuru/Sonuç Takvimleri (20 Adet)
  static Future<List<ExamSchedule>> getExamSchedules() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/exam-schedules"),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((jsonItem) => ExamSchedule.fromJson(jsonItem)).toList();
      } else {
        throw Exception("Sınav takvimleri alınamadı: ${response.statusCode}");
      }
    } catch (e) {
      print("API Hatası (getExamSchedules): $e");
      rethrow;
    }
  }

  // 2. Açık İlanlar (İlk 4 Ücretsiz, Kalanlar VIP Kilitli)
  static Future<Map<String, dynamic>> getOpenAnnouncements({
    String userId = "user-guest",
    String? category,
  }) async {
    try {
      String url = "$baseUrl/api/announcements/open?user_id=$userId";
      if (category != null) {
        url += "&category=$category";
      }

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> items = data["announcements"] ?? [];
        return {
          "user_is_premium": data["user_is_premium"] ?? false,
          "total_count": data["total_count"] ?? 0,
          "unlocked_count": data["unlocked_count"] ?? 4,
          "announcements": items.map((a) => Announcement.fromJson(a)).toList(),
        };
      } else {
        throw Exception("Açık ilanlar alınamadı: ${response.statusCode}");
      }
    } catch (e) {
      print("API Hatası (getOpenAnnouncements): $e");
      rethrow;
    }
  }

  // 3. Özel Link İzleme (URL Watcher - VIP)
  static Future<List<CustomLinkWatcher>> getCustomWatchers(String userId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/custom-watchers?user_id=$userId"),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        return data.map((item) => CustomLinkWatcher.fromJson(item)).toList();
      } else if (response.statusCode == 403) {
        throw Exception("VIP_REQUIRED");
      } else {
        throw Exception("Özel linkler alınamadı: ${response.statusCode}");
      }
    } catch (e) {
      print("API Hatası (getCustomWatchers): $e");
      rethrow;
    }
  }

  static Future<CustomLinkWatcher> addCustomWatcher({
    required String userId,
    required String url,
    required String label,
    String notes = "",
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/custom-watchers"),
        headers: _headers,
        body: json.encode({
          "user_id": userId,
          "url": url,
          "label": label,
          "notes": notes,
        }),
      );

      if (response.statusCode == 200) {
        return CustomLinkWatcher.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 403) {
        throw Exception("VIP_REQUIRED");
      } else {
        throw Exception("Özel link eklenemedi: ${response.statusCode}");
      }
    } catch (e) {
      print("API Hatası (addCustomWatcher): $e");
      rethrow;
    }
  }

  // 4. Aile Planı & Abonelik Servisleri
  static Future<Map<String, dynamic>> purchasePremium({
    required String ownerId,
    required String ownerName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/subscription/purchase"),
        headers: _headers,
        body: json.encode({
          "owner_id": ownerId,
          "owner_name": ownerName,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception("Ödeme işlemi başarısız: ${response.statusCode}");
      }
    } catch (e) {
      print("API Hatası (purchasePremium): $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> joinFamilyPlan({
    required String inviteCode,
    required String userId,
    required String userName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/subscription/join"),
        headers: _headers,
        body: json.encode({
          "invite_code": inviteCode,
          "user_id": userId,
          "user_name": userName,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        final err = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(err["detail"] ?? "Koda katılma başarısız.");
      }
    } catch (e) {
      print("API Hatası (joinFamilyPlan): $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> cancelSubscriptionCascade(String ownerId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/subscription/cancel"),
        headers: _headers,
        body: json.encode({"owner_id": ownerId}),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception("İptal işlemi başarısız: ${response.statusCode}");
      }
    } catch (e) {
      print("API Hatası (cancelSubscriptionCascade): $e");
      rethrow;
    }
  }

  // 5. RadarAI (Gemini Flash) Soru-Cevap & Kota
  static Future<Map<String, dynamic>> askRadarAI({
    required String userId,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/radar-ai/chat"),
        headers: _headers,
        body: json.encode({
          "user_id": userId,
          "message": message,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception("RadarAI yanıt vermedi: ${response.statusCode}");
      }
    } catch (e) {
      print("API Hatası (askRadarAI): $e");
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getRadarAIQuota(String userId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/radar-ai/quota/$userId"),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        throw Exception("Kota bilgisi alınamadı: ${response.statusCode}");
      }
    } catch (e) {
      print("API Hatası (getRadarAIQuota): $e");
      rethrow;
    }
  }
}
