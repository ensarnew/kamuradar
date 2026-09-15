import os
import json
import logging
from typing import Optional, Dict, Any

logger = logging.getLogger("kamuradar.firebase")

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    FIREBASE_INSTALLED = True
except ImportError:
    FIREBASE_INSTALLED = False

class FirebaseNotificationService:
    """
    Firebase Cloud Messaging (FCM) Servisi:
    - DigitalOcean sunucusunda çalışırken saat 12:00 taramasında bugün açılan ilanları
      o ilanın alarmını açmış olan kullanıcıların telefonlarına anlık Push Bildirim olarak gönderir.
    """

    _app = None
    _initialized = False

    @classmethod
    def initialize(cls) -> bool:
        """
        Firebase Admin SDK'yı 'firebase_credentials.json' dosyasıyla başlatır.
        Dosya yoksa simülasyon modunda devam eder.
        """
        if cls._initialized:
            return True

        if not FIREBASE_INSTALLED:
            logger.info("ℹ️ firebase-admin kütüphanesi kurulu değil, simülasyon modunda çalışıyor.")
            return False

        cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase_credentials.json")
        if os.path.exists(cred_path):
            try:
                cred = credentials.Certificate(cred_path)
                cls._app = firebase_admin.initialize_app(cred)
                cls._initialized = True
                logger.info(f"✅ Firebase Admin SDK başarıyla bağlandı: {cred_path}")
                return True
            except Exception as e:
                logger.warning(f"⚠️ Firebase başlatılırken hata oluştu: {e}")
                return False
        else:
            logger.info(f"ℹ️ '{cred_path}' bulunamadı. Bildirimler konsola simüle edilecek.")
            return False

    @classmethod
    def send_push_notification(
        cls,
        topic: str,
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """
        Belirli bir konuya (Topic - Örn: 'kpss', 'jandarma', 'pomem') abone olan
        tüm kullanıcılara anında bildirim gönderir.
        """
        data = data or {}
        cls.initialize()

        if cls._initialized and FIREBASE_INSTALLED:
            try:
                message = messaging.Message(
                    notification=messaging.Notification(
                        title=title,
                        body=body,
                    ),
                    data=data,
                    topic=topic
                )
                response = messaging.send(message)
                logger.info(f"🚀 Firebase bildirimi gönderildi [{topic}]: {response}")
                return {
                    "success": True,
                    "status": "sent",
                    "topic": topic,
                    "message_id": response
                }
            except Exception as e:
                logger.error(f"❌ Firebase gönderim hatası: {e}")
                return {
                    "success": False,
                    "status": "error",
                    "error": str(e)
                }
        else:
            # Simülasyon Logu (Sunucu veya yerel testlerde)
            sim_log = f"[FCM SİMÜLASYONU] Konu: {topic} | Başlık: '{title}' | İçerik: '{body}'"
            print(sim_log)
            return {
                "success": True,
                "status": "simulated",
                "topic": topic,
                "title": title,
                "body": body,
                "note": "Canlı Firebase dosyası eklendiğinde gerçek cihazlara ulaşacaktır."
            }

    @classmethod
    def notify_announcement_opened_today(
        cls,
        title: str,
        organization: str,
        official_url: str,
        category: str = "genel"
    ) -> Dict[str, Any]:
        """
        Bugün başvuru tarihi başlayan ilan için alarm bildirimini fırlatır.
        """
        topic = f"channel_{category.lower()}"
        notif_title = f"🔔 {organization}: Başvurular BUGÜN Başladı!"
        notif_body = f"{title} başvuruları resmen açıldı. Resmî başvuru adresi için tıklayın."
        
        return cls.send_push_notification(
            topic=topic,
            title=notif_title,
            body=notif_body,
            data={
                "url": official_url,
                "organization": organization,
                "type": "announcement_opened"
            }
        )

    @classmethod
    def notify_daily_scan_completed(cls, open_count: int = 0) -> Dict[str, Any]:
        """
        Her gün her taramadan sonra tüm kullanıcılara push bildirim gönderir:
        '📢 Yeni Kamu İlanları Listelendi! Bugünün güncel memur, polis ve kamu alım ilanları yayında. Hemen bak!'
        """
        notif_title = "📢 Yeni Kamu İlanları Listelendi!"
        notif_body = f"Bugünün güncel memur, polis ve kamu işçi alım ilanları güncellendi ({open_count} açık ilan). Fırsatları kaçırmamak için hemen bak!"
        
        # 'kamuradar_all' ve 'announcements' konularına gönder
        res1 = cls.send_push_notification(
            topic="kamuradar_all",
            title=notif_title,
            body=notif_body,
            data={
                "type": "daily_scan_completed",
                "open_count": str(open_count),
                "click_action": "FLUTTER_NOTIFICATION_CLICK"
            }
        )
        cls.send_push_notification(
            topic="announcements",
            title=notif_title,
            body=notif_body,
            data={
                "type": "daily_scan_completed",
                "open_count": str(open_count),
                "click_action": "FLUTTER_NOTIFICATION_CLICK"
            }
        )
        return res1

    @classmethod
    def notify_targeted_alarm_subscribers(
        cls,
        channel_id: str,
        title: str,
        organization: str,
        official_url: str,
        target_tokens: list
    ) -> Dict[str, Any]:
        """
        Kişiye Özel Bildirim Motoru:
        Müşteri neyin bildirimini açtıysa SADECE ona bildirim gider.
        İlgili channel_id'ye abone olan cihazların FCM tokenlarına push gönderir.
        """
        notif_title = f"🔔 {organization} Alarmı: Başvuru Açıldı!"
        notif_body = f"Takip ettiğiniz '{title}' için başvurular başladı. Detaylar ve başvuru için dokunun."

        if not target_tokens:
            logger.info(f"ℹ️ [{channel_id}] için aktif alarm kurmuş kullanıcı bulunamadı.")
            return {"success": True, "sent_count": 0, "message": "No active alarm subscribers for this channel"}

        cls.initialize()
        sent_count = 0

        for token in target_tokens:
            if cls._initialized and FIREBASE_INSTALLED:
                try:
                    message = messaging.Message(
                        notification=messaging.Notification(
                            title=notif_title,
                            body=notif_body
                        ),
                        data={"url": official_url, "channel_id": channel_id},
                        token=token
                    )
                    messaging.send(message)
                    sent_count += 1
                except Exception as e:
                    logger.error(f"FCM token gönderim hatası ({token[:10]}...): {e}")
            else:
                # Simülasyon modu
                print(f"[HEDEFLİ PUSH SİMÜLASYONU] Token: {token[:10]}... | İlan: {channel_id} | Başlık: {notif_title}")
                sent_count += 1

        logger.info(f"🎯 [{channel_id}] alarmını açmış {sent_count} kişiye özel bildirim iletildi.")
        return {
            "success": True,
            "channel_id": channel_id,
            "sent_count": sent_count,
            "title": notif_title
        }
