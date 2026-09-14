import hashlib
import re
import urllib.request
import ssl
from datetime import datetime
from typing import Dict, Any, Tuple, Optional
from models import CustomUrlWatcher
from database import db

def fetch_live_url(url: str, timeout: int = 10) -> str:
    """Canlı web sayfasına HTTP GET isteği atarak HTML içeriğini çeker."""
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, context=ctx, timeout=timeout) as response:
            return response.read().decode('utf-8', errors='ignore')
    except Exception as e:
        return f"Fetch Error: {str(e)}"

def normalize_text_content(html_or_text: str) -> str:
    """HTML taglerini ve boşlukları temizleyerek sadece anlamlı metni çıkarır."""
    clean_text = re.sub(r"<script[\s\S]*?</script>", " ", html_or_text, flags=re.IGNORECASE)
    clean_text = re.sub(r"<style[\s\S]*?</style>", " ", clean_text, flags=re.IGNORECASE)
    clean_text = re.sub(r"<[^>]+>", " ", clean_text)
    clean_text = re.sub(r"\s+", " ", clean_text).strip().lower()
    return clean_text

def compute_hash(text: str) -> str:
    """Metnin SHA-256 özetini üretir."""
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]

class CustomUrlWatcherService:
    @staticmethod
    def register_watcher(user_id: str, url: str, label: str, notes: str = "", fetch_now: bool = True) -> CustomUrlWatcher:
        """
        Kullanıcı yeni bir URL eklediğinde çalışır.
        fetch_now=True ise bot sayfaya ANINDA bağlanıp ilk referans parmak izini kaydeder.
        """
        watcher_id = f"watch-{len(db.custom_watchers) + 1}"
        initial_hash = None
        status_msg = "Henüz taranmadı (İlk tarama saat 12:00)"

        if fetch_now:
            raw_html = fetch_live_url(url)
            clean_text = normalize_text_content(raw_html)
            initial_hash = compute_hash(clean_text)
            status_msg = f"İlk tarama yapıldı ({datetime.now().strftime('%H:%M')})"

        watcher = CustomUrlWatcher(
            id=watcher_id,
            user_id=user_id,
            url=url,
            label=label,
            last_checked_12pm=status_msg,
            last_content_hash=initial_hash,
            last_change_detected=None,
            has_update=False,
            notes=notes
        )
        db.custom_watchers[watcher.id] = watcher
        return watcher

    @staticmethod
    def scan_watcher_12pm(watcher: CustomUrlWatcher, incoming_content: Optional[str] = None) -> Tuple[bool, str]:
        """
        Saat 12:00'de botun URL'yi kontrol etme fonksiyonu.
        Canlı ortamda doğrudan internetten sayfayı çeker ve hash karşılaştırması yapar.
        """
        now_str = datetime.now().strftime("%Y-%m-%d 12:00")
        
        # Eğer dışarıdan içerik verilmediyse canlı URL'yi çek
        raw_html = incoming_content if incoming_content is not None else fetch_live_url(watcher.url)
        clean_text = normalize_text_content(raw_html)
        new_hash = compute_hash(clean_text)

        watcher.last_checked_12pm = now_str

        # İlk tarama durumu
        if not watcher.last_content_hash:
            watcher.last_content_hash = new_hash
            watcher.has_update = False
            return False, "İlk tarama tamamlandı, sayfa referans tabanı oluşturuldu."

        # İçerik değişmiş mi? (Yeni duyuru / ilan eklendi mi?)
        if new_hash != watcher.last_content_hash:
            watcher.last_content_hash = new_hash
            watcher.last_change_detected = now_str
            watcher.has_update = True
            return True, f"DİKKAT: '{watcher.label}' sayfasında yeni bir duyuru veya ilan tespit edildi!"
        else:
            watcher.has_update = False
            return False, "Sayfada yeni bir değişiklik yok."
