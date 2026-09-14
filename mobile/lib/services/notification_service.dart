import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Arka planda gelen bildirimleri yakalayan üst düzey fonksiyon
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("🔔 [Arka Plan Bildirimi]: ${message.notification?.title} - ${message.notification?.body}");
  }
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize({
    Function(RemoteMessage)? onForegroundMessage,
  }) async {
    try {
      // 1. Bildirim İzni İste (iOS ve Android 13+)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print("✅ Bildirim izni verildi.");
        }
      }

      // 2. Arka plan dinleyicisini bağla
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Ön plandayken gelen bildirimleri dinle
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print("🔔 [Ön Plan Bildirimi]: ${message.notification?.title}");
        }
        if (onForegroundMessage != null) {
          onForegroundMessage(message);
        }
      });

      // 4. Cihaz FCM Token'ı al (Bireysel bildirimler için)
      String? token = await _messaging.getToken();
      if (kDebugMode) {
        print("📱 Cihaz FCM Token: $token");
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Firebase Messaging başlatılamadı (Henüz google-services.json eklenmemiş olabilir): $e");
      }
    }
  }

  // Kullanıcı bir alımın zilini açtığında o konuya (Topic) abone olur
  // Örn: 'channel_jandarma', 'channel_kpss', 'channel_pomem'
  static Future<void> subscribeToChannel(String channelTopic) async {
    try {
      final cleanTopic = channelTopic.toLowerCase().replaceAll(" ", "_");
      await _messaging.subscribeToTopic(cleanTopic);
      if (kDebugMode) {
        print("🔔 Abone olundu: $cleanTopic");
      }
    } catch (e) {
      if (kDebugMode) print("Abone olma hatası: $e");
    }
  }

  // Zil kapatıldığında abonelikten çıkar
  static Future<void> unsubscribeFromChannel(String channelTopic) async {
    try {
      final cleanTopic = channelTopic.toLowerCase().replaceAll(" ", "_");
      await _messaging.unsubscribeFromTopic(cleanTopic);
      if (kDebugMode) {
        print("🔕 Abonelikten çıkıldı: $cleanTopic");
      }
    } catch (e) {
      if (kDebugMode) print("Abonelikten çıkma hatası: $e");
    }
  }
}
