import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_service.dart';
import 'notification_service.dart';

class FirebaseSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _keyIsVip = "cache_is_vip";
  static const String _keyVipPlan = "cache_vip_plan";
  static const String _keyIsGoogleLoggedIn = "is_google_logged_in";
  static const String _keyIsGuest = "is_guest_mode";

  // 1. VIP Durumunu Oku (Önce Yerel Hızlı Önbellek, Oturum Açıksa Buluttan Doğrula)
  static Future<bool> isVip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool localVip = prefs.getBool(_keyIsVip) ?? false;

      // Kullanıcının oturumu varsa Firestore'dan güncel VIP durumunu kontrol et
      final user = _auth.currentUser;
      if (user != null) {
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            final bool cloudVip = data['is_vip'] == true;
            if (cloudVip != localVip) {
              localVip = cloudVip;
              await prefs.setBool(_keyIsVip, cloudVip);
              if (data['vip_plan'] != null) {
                await prefs.setString(_keyVipPlan, data['vip_plan'].toString());
              }
            }
          }
        } catch (_) {}
      }

      return localVip;
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
      final fcmToken = await NotificationService.getToken();

      // A. Kullanıcı kendi profiline kaydeder (yedekleme ve senkronizasyon)
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'custom_watchers': watchersJson,
          'custom_watchers_count': watchersJson.length,
          'fcm_token': fcmToken ?? '',
          'last_watcher_update': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // B. Sunucu Botunun (Cloud Bot) doğrudan erişebileceği 'custom_watchers' global koleksiyonuna yaz
      for (var w in watchersJson) {
        final wid = (w['id'] ?? 'w_${DateTime.now().millisecondsSinceEpoch}').toString();
        await _firestore.collection('custom_watchers').doc(wid).set({
          ...w,
          'user_id': user?.uid ?? 'guest_device',
          'user_email': user?.email ?? '',
          'fcm_token': fcmToken ?? '',
          'is_active': w['is_notification_active'] ?? true,
          'synced_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (kDebugMode) {
        print("☁️ Firebase: ${watchersJson.length} adet özel link buluta ve sunucu botuna yedeklendi.");
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

      // Sabit Davet Kodu veya Katılınan Kodu Buluttan Geri Yükle
      if (data.containsKey('invite_code') && data['invite_code'] != null) {
        await prefs.setString("user_family_invite_code", data['invite_code'].toString());
      }
      if (data.containsKey('joined_family_code') && data['joined_family_code'] != null) {
        await prefs.setString("joined_family_code", data['joined_family_code'].toString());
      }

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

  // 7. Tüm Kullanıcılara Canlı Bildirim Yayınla (Firestore ve FCM Kanallarına)
  static Future<void> publishBroadcastNotification({
    required String title,
    required String body,
    String? targetUrl,
    String topic = "kamuradar_all",
  }) async {
    try {
      // A. Firestore 'notifications' koleksiyonuna ekle (Bütün cihazların canlı listener'ı anında yakalar)
      await _firestore.collection('notifications').add({
        'title': title,
        'body': body,
        'url': targetUrl ?? '',
        'topic': topic,
        'created_at': FieldValue.serverTimestamp(),
      });

      // B. Render Cloud FCM Push Bildirim Tetiklemesi (Uygulama kapalı/arka plandayken kilit ekranına düşürür)
      try {
        final fcmUri = Uri.parse("https://kamuradar.onrender.com/api/admin/broadcast-notification");
        await http.post(
          fcmUri,
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            "title": title,
            "body": body,
            "promo_url": targetUrl ?? "",
            "target_topic": topic,
          }),
        ).timeout(const Duration(seconds: 8));
        if (kDebugMode) {
          print("🚀 Render Cloud FCM Push Bildirimi başarıyla tetiklendi.");
        }
      } catch (err) {
        if (kDebugMode) {
          print("⚠️ Render FCM API bağlantı uyarısı (Offline/Timeout): $err");
        }
      }

      // C. Yönetici cihazında da yerel olarak göster
      await NotificationService.showLocalNotification(
        title: title,
        body: body,
      );

      if (kDebugMode) {
        print("📢 Bildirim yayınlandı: $title - $body ($topic)");
      }
    } catch (e) {
      if (kDebugMode) print("Bildirim yayınlama hatası: $e");
    }
  }

  // 8. İlanları Toplu Olarak Firestore 'announcements' Koleksiyonuna Eşitle
  static Future<int> uploadAnnouncementsBatch(List<Map<String, dynamic>> items) async {
    try {
      int saved = 0;
      WriteBatch batch = _firestore.batch();
      for (var item in items) {
        final id = (item['id'] ?? 'ann_${saved + 1}').toString();
        final docRef = _firestore.collection('announcements').doc(id);
        batch.set(docRef, {
          ...item,
          'synced_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        saved++;
        if (saved % 400 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
      await batch.commit();
      return saved;
    } catch (e) {
      if (kDebugMode) print("Toplu ilan yükleme hatası: $e");
      return 0;
    }
  }

  // 9. Firestore'dan Canlı İlanları Getir / Dinle
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAnnouncementsStream() {
    return _firestore.collection('announcements').snapshots();
  }

  // 10. Kullanıcı Ara (Kullanıcı Adı veya E-posta İle)
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final cleanQuery = query.trim().toLowerCase();
      final Map<String, Map<String, dynamic>> userMap = {};

      // 1. Strateji: Backend Admin API'den tüm gerçek kullanıcıları çek (Firebase Admin yetkisiyle eksiksiz)
      try {
        final res = await http.get(
          Uri.parse("https://kamuradar.onrender.com/api/admin/users"),
        ).timeout(const Duration(seconds: 7));
        if (res.statusCode == 200) {
          final List<dynamic> list = jsonDecode(utf8.decode(res.bodyBytes));
          for (var item in list) {
            final uid = (item['uid'] ?? '').toString();
            final email = (item['email'] ?? '').toString().toLowerCase();
            final name = (item['display_name'] ?? '').toString().toLowerCase();
            if (cleanQuery.isEmpty || email.contains(cleanQuery) || name.contains(cleanQuery) || uid.toLowerCase().contains(cleanQuery)) {
              userMap[uid] = Map<String, dynamic>.from(item);
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print("Backend admin users listesi notu: $e");
      }

      // 2. Strateji: Doğrudan e-posta veya UID tam eşleşme araması (Firestore)
      if (cleanQuery.isNotEmpty && userMap.isEmpty) {
        try {
          final directEmailSnap = await _firestore.collection('users').where('email', isEqualTo: cleanQuery).get();
          for (var doc in directEmailSnap.docs) {
            final data = doc.data();
            userMap[doc.id] = {
              'uid': doc.id,
              'email': data['email'] ?? 'E-posta Yok',
              'display_name': data['display_name'] ?? 'İsimsiz Üye',
              'is_vip': data['is_vip'] == true,
              'vip_plan': data['vip_plan'] ?? 'free',
              'last_active': data['last_active'],
            };
          }
        } catch (_) {}
      }

      // 3. Strateji: Mevcut oturum açmış kullanıcı varsa ve henüz listede yoksa gerçek VIP durumuyla ekle
      final currentAuthUser = _auth.currentUser;
      if (currentAuthUser != null) {
        final curEmail = (currentAuthUser.email ?? '').toLowerCase();
        final curName = (currentAuthUser.displayName ?? '').toLowerCase();
        if (cleanQuery.isEmpty || curEmail.contains(cleanQuery) || curName.contains(cleanQuery) || currentAuthUser.uid.toLowerCase().contains(cleanQuery)) {
          if (!userMap.containsKey(currentAuthUser.uid)) {
            final isCurVip = await isVip();
            userMap[currentAuthUser.uid] = {
              'uid': currentAuthUser.uid,
              'email': currentAuthUser.email ?? 'Aktif Oturum',
              'display_name': currentAuthUser.displayName ?? 'Yönetici Hesabı',
              'is_vip': isCurVip,
              'vip_plan': isCurVip ? 'vip_family_plan' : 'free',
              'last_active': 'Şimdi Aktif',
            };
          }
        }
      }

      return userMap.values.toList();
    } catch (e) {
      if (kDebugMode) print("Kullanıcı arama hatası: $e");
      return [];
    }
  }

  // 11. Admin Tarafından Kullanıcıya VIP Ver veya Kaldır
  static Future<bool> setUserVipByAdmin(String uid, bool isVip, {String plan = "vip_family_plan"}) async {
    // A. Önce Render Backend Admin API'sini çağır (Firebase Admin SDK ile tam yetkili yazar)
    try {
      await http.post(
        Uri.parse("https://kamuradar.onrender.com/api/admin/set-user-vip"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "uid": uid,
          "is_vip": isVip,
          "plan": isVip ? plan : "free"
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    // B. İstemci Firestore Doğrudan Yazma (Yedek)
    try {
      await _firestore.collection('users').doc(uid).set({
        'is_vip': isVip,
        'vip_plan': isVip ? plan : 'free',
        'vip_updated_at': FieldValue.serverTimestamp(),
        'vip_granted_by_admin': true,
      }, SetOptions(merge: true));
    } catch (_) {}

    // Eğer mevcut oturum açmış kullanıcı ise yerel hafızayı anında güncelle
    if (_auth.currentUser?.uid == uid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsVip, isVip);
      await prefs.setString(_keyVipPlan, isVip ? plan : 'free');
    }

    return true;
  }
}
