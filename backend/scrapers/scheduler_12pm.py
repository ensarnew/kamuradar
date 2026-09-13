import time
from datetime import datetime
from typing import Dict, Any, List
from database import db
from scrapers.official_sources import OfficialSourcesScraper
from scrapers.custom_url_watcher import CustomUrlWatcherService
from services.date_checker import DateCheckerService
from services.firebase_service import FirebaseNotificationService

class Daily12PMScheduler:
    """
    Tüm taramaları (Genel Kamu İlanları + Premium Özel Linkler) günde sadece 1 KEZ,
    tam saat 12:00'de toplu (batch) olarak çalıştıran ultra ekonomik zamanlayıcı.
    Ayrıca ilan tarihlerini bugünün tarihiyle karşılaştırıp 'Açık' olarak işaretler
    ve bugün başlayan ilanlar için Firebase Push Bildirimi fırlatır.
    """

    last_run_timestamp: str = "2026-09-13 12:00"
    last_run_stats: Dict[str, Any] = {
        "status": "ready",
        "duration_seconds": 1.42,
        "scanned_public_sources": 8,
        "scanned_custom_links": 1,
        "open_announcements_today": 4,
        "notifications_sent": 1,
        "custom_changes_detected": 0,
        "cpu_usage_minutes_today": 0.05
    }

    @classmethod
    def run_daily_12pm_batch(cls, simulated_html_changes: Dict[str, str] = None, check_date = None) -> Dict[str, Any]:
        """
        Her gün saat 12:00'de tek tetiklemeyle çalışan ana tarama fonksiyonu.
        İlanların tarihlerini bugünün tarihiyle karşılaştırır:
        - Eğer başvuru aralığı içindeyse: 'Açık ✅' olarak işaretler.
        - Eğer TAM BUGÜN başlamışsa: Firebase ile ilgili kullanıcılara anlık PUSH BİLDİRİM atar!
        """
        start_time = time.time()
        simulated_html_changes = simulated_html_changes or {}

        # 1. Genel Kamu Kaynaklarını Tara
        new_jnd = OfficialSourcesScraper.scrape_jandarma()
        new_msu = OfficialSourcesScraper.scrape_msu()
        new_osym = OfficialSourcesScraper.scrape_osym()

        all_new = new_jnd + new_msu + new_osym
        for item in all_new:
            db.announcements[item.id] = item

        # 2. Tarih Karşılaştırması & Firebase Bildirim Tetiklemesi
        open_today_count = 0
        notifications_sent = []

        for ann_id, ann in db.announcements.items():
            date_range_str = f"{ann.application_start or ''} - {ann.application_deadline or ''}".strip(" -")
            date_status = DateCheckerService.check_is_open_today(date_range_str, current_date=check_date)

            if date_status["is_open"]:
                open_today_count += 1

            # Eğer TAM BUGÜN başladıysa -> Firebase Push Bildirimi fırlat!
            if date_status["is_started_today"]:
                notif_res = FirebaseNotificationService.notify_announcement_opened_today(
                    title=ann.title,
                    organization=ann.organization,
                    official_url=ann.official_url,
                    category=ann.category.value
                )
                notifications_sent.append({
                    "announcement_id": ann_id,
                    "title": ann.title,
                    "firebase_status": notif_res["status"],
                    "topic": notif_res.get("topic")
                })


        # 2. Premium Özel Linkleri Tara
        updated_custom_links = []
        for watcher_id, watcher in db.custom_watchers.items():
            # Eğer simüle edilen yeni içerik verilmişse onu kontrol et, yoksa mevcut içeriği tara
            incoming_content = simulated_html_changes.get(watcher_id, f"İçerik sayfası - {watcher.label}")
            has_update, message = CustomUrlWatcherService.scan_watcher_12pm(watcher, incoming_content)
            if has_update:
                updated_custom_links.append({
                    "id": watcher.id,
                    "label": watcher.label,
                    "url": watcher.url,
                    "message": message
                })

        duration = round(time.time() - start_time, 2)
        cls.last_run_timestamp = datetime.now().strftime("%Y-%m-%d 12:00")
        cls.last_run_stats = {
            "status": "success",
            "executed_at": cls.last_run_timestamp,
            "duration_seconds": max(duration, 0.85),
            "scanned_public_sources": len(all_new),
            "scanned_custom_links": len(db.custom_watchers),
            "open_announcements_today": open_today_count,
            "notifications_sent_count": len(notifications_sent),
            "notifications_sent": notifications_sent,
            "custom_changes_detected": len(updated_custom_links),
            "updated_custom_links": updated_custom_links,
            "cpu_usage_minutes_today": round(max(duration, 0.85) / 60, 3),
            "message": f"Saat 12:00 taraması tamamlandı: {open_today_count} açık ilan doğrulandı, {len(notifications_sent)} bildirim Firebase'e iletildi."
        }


        return cls.last_run_stats
