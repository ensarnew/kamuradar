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

        // Yeni kullanıcının cihazda eski hesaptan kalan VIP haklarını kesinlikle sıfırla
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyIsVip, false);
        await prefs.setString(_keyVipPlan, 'free');
        await prefs.setBool("is_family_group_owner", false);
        await prefs.remove("joined_family_code");
        await prefs.remove("user_family_invite_code");
        await prefs.remove("family_members_list");
        return null;
      }

      final data = doc.data()!;
      final prefs = await SharedPreferences.getInstance();

      // VIP Durumu Geri Yükle
      final bool isVipCloud = data['is_vip'] == true;
      final String planCloud = (data['vip_plan'] ?? 'free').toString();
      final bool isOwner = isVipCloud && (planCloud == 'yearly_vip' || planCloud == 'monthly_vip' || planCloud == 'vip_family_plan');

      await prefs.setBool(_keyIsVip, isVipCloud);
      await prefs.setString(_keyVipPlan, planCloud);
      await prefs.setBool("is_family_group_owner", isOwner);

      // Alarmları Geri Yükle
      if (data.containsKey('active_alarms')) {
        final List<dynamic> alarmsCloud = data['active_alarms'] ?? [];
        final list = alarmsCloud.map((e) => e.toString()).toList();
        await CacheService.saveActiveAlarms(list);
      }

      if (kDebugMode) {
        print("✅ Firebase: Kullanıcı profili buluttan geri yüklendi (${user.email}) - VIP: $isVipCloud, Yönetici: $isOwner");
      }
      return data;
    } catch (e) {
      if (kDebugMode) print("Buluttan geri yükleme hatası: $e");
      return null;
    }
  }

  // Kullanıcı çıkış yaptığında tüm yerel VIP ve hesap artıklarını temizle
  static Future<void> clearLocalUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsVip, false);
      await prefs.setString(_keyVipPlan, "free");
      await prefs.setBool("is_family_group_owner", false);
      await prefs.remove("joined_family_code");
      await prefs.remove("user_family_invite_code");
      await prefs.remove("family_members_list");
      await prefs.setBool(_keyIsGoogleLoggedIn, false);
      await prefs.setBool(_keyIsGuest, false);
    } catch (_) {}
  }

  // 6. Google ile Giriş Yapılmış mı / Oturum Kalıcı mı Kontrolü
  static Future<bool> hasCompletedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isGoogle = prefs.getBool(_keyIsGoogleLoggedIn) ?? false;
      final isGuest = prefs.getBool(_keyIsGuest) ?? false;
      if (isGoogle || isGuest) return true;

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await prefs.setBool(_keyIsGoogleLoggedIn, true);
          return true;
        }
      } catch (_) {}

      return false;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        return (prefs.getBool(_keyIsGoogleLoggedIn) ?? false) || (prefs.getBool(_keyIsGuest) ?? false);
      } catch (_) {
        return false;
      }
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
