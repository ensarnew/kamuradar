import hashlib
import re
from datetime import datetime
from typing import Dict, Any, Tuple
from models import CustomUrlWatcher
from database import db

def normalize_text_content(html_or_text: str) -> str:
    """HTML taglerini ve boşlukları temizleyerek sadece anlamlı metni çıkarır."""
    # HTML taglerini kaldır
    clean_text = re.sub(r"<[^>]+>", " ", html_or_text)
    # Birden fazla boşluk ve satır başlarını teke indir
    clean_text = re.sub(r"\s+", " ", clean_text).strip().lower()
    return clean_text

def compute_hash(text: str) -> str:
    """Metnin SHA-256 özetini üretir."""
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]

class CustomUrlWatcherService:
    @staticmethod
    def register_watcher(user_id: str, url: str, label: str, notes: str = "") -> CustomUrlWatcher:
        watcher_id = f"watch-{len(db.custom_watchers) + 1}"
        watcher = CustomUrlWatcher(
            id=watcher_id,
            user_id=user_id,
            url=url,
            label=label,
            last_checked_12pm="Henüz taranmadı (İlk tarama saat 12:00)",
            last_content_hash=None,
            last_change_detected=None,
            has_update=False,
            notes=notes
        )
        db.custom_watchers[watcher.id] = watcher
        return watcher

    @staticmethod
    def scan_watcher_12pm(watcher: CustomUrlWatcher, incoming_content: str) -> Tuple[bool, str]:
        """
        Saat 12:00'de tek seferde çalıştırılan içerik doğrulama fonksiyonu.
        Hash değişmişse yeni bildirim tetikler.
        """
        now_str = datetime.now().strftime("%Y-%m-%d 12:00")
        clean_text = normalize_text_content(incoming_content)
        new_hash = compute_hash(clean_text)

        watcher.last_checked_12pm = now_str

        # İlk tarama durumu
        if not watcher.last_content_hash:
            watcher.last_content_hash = new_hash
            watcher.has_update = False
            return False, "İlk tarama tamamlandı, sayfa referans tabanı oluşturuldu."

        # İçerik değişmiş mi?
        if new_hash != watcher.last_content_hash:
            watcher.last_content_hash = new_hash
            watcher.last_change_detected = now_str
            watcher.has_update = True
            return True, f"DİKKAT: '{watcher.label}' sayfasında yeni bir duyuru/değişiklik tespit edildi!"
        else:
            watcher.has_update = False
            return False, "Sayfada yeni bir değişiklik yok."
