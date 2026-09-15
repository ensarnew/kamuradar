import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_service.dart';

class FirebaseSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _keyIsVip = "cache_is_vip";
  static const String _keyVipPlan = "cache_vip_plan";
  static const String _keyIsGoogleLoggedIn = "is_google_logged_in";
  static const String _keyIsGuest = "is_guest_mode";

  // 1. VIP Durumunu Oku (Önce Yerel Hızlı Önbellek)
  static Future<bool> isVip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsVip) ?? false;
    } catch (_) {
      return false;
    }
  }

  // 2. VIP Durumunu Hem Telefona Hem Firebase Firestore'a Kaydet
  static Future<void> setVipStatus(bool isVip, {String plan = "vip_family_plan"}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsVip, isVip);
      await prefs.setString(_keyVipPlan, plan);

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'is_vip': isVip,
          'vip_plan': plan,
          'vip_updated_at': FieldValue.serverTimestamp(),
          'email': user.email ?? '',
          'display_name': user.displayName ?? '',
          'last_active': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (kDebugMode) {
          print("☁️ Firebase: Kullanıcı VIP durumu '${isVip ? 'VIP' : 'STANDART'}' olarak kaydedildi (${user.uid})");
        }
      } else {
        if (kDebugMode) {
          print("💾 Cihaz: Kullanıcı oturumu açık değil, VIP yerel olarak kaydedildi.");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Firebase VIP kayıt hatası: $e");
      }
    }
  }

  // 3. Alarmları Firebase'e ve Telefona Kaydet
  static Future<void> syncAlarms(List<String> activeAlarms) async {
    try {
      await CacheService.saveActiveAlarms(activeAlarms);

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'active_alarms': activeAlarms,
          'alarm_count': activeAlarms.length,
          'last_alarm_update': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (kDebugMode) {
          print("☁️ Firebase: ${activeAlarms.length} adet alarm buluta yedeklendi.");
        }
      }
    } catch (e) {
      if (kDebugMode) print("Alarmları Firebase'e senkronize etme hatası: $e");
    }
  }

  // 4. Özel Linkleri (URL Watchers) Firebase'e ve Telefona Kaydet
  static Future<void> syncCustomWatchers(List<Map<String, dynamic>> watchersJson) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'custom_watchers': watchersJson,
          'custom_watchers_count': watchersJson.length,
          'last_watcher_update': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (kDebugMode) {
          print("☁️ Firebase: ${watchersJson.length} adet özel link buluta yedeklendi.");
        }
      }
    } catch (e) {
      if (kDebugMode) print("Özel linkleri Firebase'e senkronize etme hatası: $e");
    }
  }

  // 5. Oturum Açıldığında Kullanıcının Tüm Verilerini Buluttan İndir (Bulut Geri Yükleme)
  static Future<Map<String, dynamic>?> restoreUserDataFromCloud() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data() == null) {
        // Yeni kullanıcı dokümanını ilk defa oluştur
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'display_name': user.displayName ?? 'KamuRadar Üyesi',
          'photo_url': user.photoURL ?? '',
          'created_at': FieldValue.serverTimestamp(),
          'last_active': FieldValue.serverTimestamp(),
          'is_vip': false,
          'vip_plan': 'free',
          'active_alarms': ["ch-01", "ch-02"],
        }, SetOptions(merge: true));
        return null;
      }

      final data = doc.data()!;
      final prefs = await SharedPreferences.getInstance();

      // VIP Durumu Geri Yükle
      if (data.containsKey('is_vip')) {
        final bool isVipCloud = data['is_vip'] == true;
        await prefs.setBool(_keyIsVip, isVipCloud);
      }
      if (data.containsKey('vip_plan')) {
        await prefs.setString(_keyVipPlan, data['vip_plan'].toString());
      }

      // Alarmları Geri Yükle
      if (data.containsKey('active_alarms')) {
        final List<dynamic> alarmsCloud = data['active_alarms'] ?? [];
        final list = alarmsCloud.map((e) => e.toString()).toList();
        await CacheService.saveActiveAlarms(list);
      }

      if (kDebugMode) {
        print("✅ Firebase: Kullanıcı profili buluttan geri yüklendi (${user.email})");
      }
      return data;
    } catch (e) {
      if (kDebugMode) print("Buluttan geri yükleme hatası: $e");
      return null;
    }
  }

  // 6. Google ile Giriş Yapılmış mı / Oturum Kalıcı mı Kontrolü
  static Future<bool> hasCompletedAuth() async {
    try {
      if (_auth.currentUser != null) return true;
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getBool(_keyIsGoogleLoggedIn) ?? false) || (prefs.getBool(_keyIsGuest) ?? false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> markGoogleLoggedIn(bool loggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGoogleLoggedIn, loggedIn);
    if (loggedIn) {
      await prefs.setBool(_keyIsGuest, false);
    }
  }

  static Future<void> setGuestMode(bool isGuest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGuest, isGuest);
  }
}
