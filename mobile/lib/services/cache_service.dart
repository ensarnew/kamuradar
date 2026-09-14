import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _keySchedules = "cache_exam_schedules";
  static const String _keyActiveAlarms = "cache_active_alarms";
  static const String _keyAnnouncements = "cache_open_announcements";

  // 1. Sınav Takvimleri Önbelleği (Offline Mod)
  static Future<void> saveExamSchedules(List<dynamic> jsonList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySchedules, json.encode(jsonList));
    } catch (_) {}
  }

  static Future<List<dynamic>?> getCachedExamSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_keySchedules);
      if (data != null && data.isNotEmpty) {
        return json.decode(data) as List<dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 2. Kullanıcının Açık Alarmları (Telefon Hafızasında Saklama)
  static Future<void> saveActiveAlarms(List<String> activeIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyActiveAlarms, activeIds);
    } catch (_) {}
  }

  static Future<List<String>> getActiveAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_keyActiveAlarms) ?? ["ch-01", "ch-02"];
    } catch (_) {
      return ["ch-01", "ch-02"];
    }
  }

  // 3. Açık İlanlar Önbelleği
  static Future<void> saveAnnouncements(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAnnouncements, json.encode(data));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getCachedAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_keyAnnouncements);
      if (data != null && data.isNotEmpty) {
        return json.decode(data) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // 4. Reklamla Kazanılan Bildirim Hakları (Aylık Bildirim Kotası)
  static const String _keyBonusNotifications = "cache_bonus_notifications";
  static const String _keyUsedNotifications = "cache_used_notifications";

  static Future<void> saveBonusNotifications(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyBonusNotifications, count);
    } catch (_) {}
  }

  static Future<int> getBonusNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyBonusNotifications) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> saveUsedNotifications(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyUsedNotifications, count);
    } catch (_) {}
  }

  static Future<int> getUsedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyUsedNotifications) ?? 1; // Başlangıçta 1 bildirim örnek kullanılmış
    } catch (_) {
      return 1;
    }
  }
}

