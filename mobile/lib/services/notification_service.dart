import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String channelId = "kamuradar_alerts_channel";
  static const String channelName = "KamuRadar İlan & Sınav Bildirimleri";
  static const String channelDescription = "Kamu personeli alımı, KPSS ve sınav alarmları bildirimleri";

  static Future<void> initialize({
    Function(RemoteMessage)? onForegroundMessage,
  }) async {
    try {
      // 1. Android & iOS Local Notifications Başlatma
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(initSettings);

      // 2. Android 8.0+ için Yüksek Öncelikli Bildirim Kanalı Oluştur
      final AndroidNotificationChannel androidChannel = const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
        // Android 13+ (Tiramisu) için yerel bildirim izni iste
        await androidPlugin.requestNotificationsPermission();
      }

      // 3. Firebase Messaging İzni İste (iOS ve Android 13+)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print("✅ Firebase Bildirim izni verildi.");
        }
      }

      // 4. Arka plan dinleyicisini bağla
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 5. Ön plandayken gelen bildirimleri dinle ve ekranda pop-up olarak göster
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print("🔔 [Ön Plan Bildirimi]: ${message.notification?.title}");
        }

        final notification = message.notification;
        if (notification != null) {
          showLocalNotification(
            title: notification.title ?? "Yeni Kamu İlanı",
            body: notification.body ?? "Radara yeni bir duyuru düştü.",
          );
        }

        if (onForegroundMessage != null) {
          onForegroundMessage(message);
        }
      });

      // 6. Cihaz FCM Token'ı al ve Genel Duyuru Başlıklarına Abone Ol
      try {
        await _messaging.subscribeToTopic('kamuradar_all');
        await _messaging.subscribeToTopic('announcements');
        if (kDebugMode) print("📢 Cihaz 'kamuradar_all' ve 'announcements' bildirim kanallarına abone edildi.");
      } catch (_) {}

      String? token = await _messaging.getToken();
      if (kDebugMode) {
        print("📱 Cihaz FCM Token: $token");
      }
    } catch (e) {
      if (kDebugMode) {
        print("⚠️ Firebase Messaging başlatılamadı: $e");
      }
    }
  }

  // Telefonda anında bildirim gösterme (Test, Radar Uyarısı veya Özel Link Algılama)
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id,
        title,
        body,
        platformDetails,
      );
      if (kDebugMode) {
        print("📣 Yerel bildirim gösterildi: $title - $body");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Yerel bildirim gösterme hatası: $e");
      }
    }
  }

  // Kullanıcı bir alımın zilini açtığında o konuya (Topic) abone olur
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
