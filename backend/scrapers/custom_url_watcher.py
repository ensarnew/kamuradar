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
    def load_watchers_from_firestore() -> int:
        """
        Firebase Firestore 'custom_watchers' koleksiyonundaki tüm kullanıcı linklerini botun hafızasına çeker.
        """
        try:
            from services.firebase_service import FirebaseNotificationService
            FirebaseNotificationService.initialize()
            from firebase_admin import firestore
            db_client = firestore.client()
            docs = db_client.collection('custom_watchers').stream()
            count = 0
            for doc in docs:
                data = doc.to_dict()
                wid = doc.id
                url = data.get('url', '')
                if not url:
                    continue
                watcher = CustomUrlWatcher(
                    id=wid,
                    user_id=data.get('user_id', 'unknown'),
                    url=url,
                    label=data.get('label', 'Özel Takip Linki'),
                    last_checked_12pm=data.get('last_checked_12pm', 'Sunucu Taraması Bekleniyor'),
                    last_content_hash=data.get('last_content_hash'),
                    last_change_detected=data.get('last_change_detected'),
                    has_update=data.get('has_update', False),
                    notes=data.get('ai_criteria', '') or data.get('notes', '')
                )
                # target_keywords ve fcm_token ek öznitelikler
                setattr(watcher, 'target_keywords', data.get('target_keywords', []))
                setattr(watcher, 'fcm_token', data.get('fcm_token', ''))
                db.custom_watchers[wid] = watcher
                count += 1
            return count
        except Exception as e:
            return 0

    @staticmethod
    def scan_watcher_12pm(watcher: CustomUrlWatcher, incoming_content: Optional[str] = None) -> Tuple[bool, str]:
        """
        Gündüz periyotlarında botun URL'yi kontrol etme fonksiyonu.
        Kullanıcının belirlediği arama kriterlerine göre:
        - Eğer aranan duyuru/ilan sayfada bulunduysa: '🎯 [VAR] Yeni Duyuru Tespit Edildi!' bildirir.
        - Eğer aranan duyuru bulunamadıysa: '❌ [YOK] Aradığınız kriterler henüz yayında değil.' bildirir.
        """
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M")
        
        raw_html = incoming_content if incoming_content is not None else fetch_live_url(watcher.url)
        clean_text = normalize_text_content(raw_html)
        new_hash = compute_hash(clean_text)

        watcher.last_checked_12pm = now_str

        # 1. Hedef kelime kontrolü (Target Keywords)
        target_keywords = getattr(watcher, 'target_keywords', []) or []
        if not target_keywords and watcher.notes:
            target_keywords = [k.strip().lower() for k in watcher.notes.split(',') if len(k.strip()) >= 2]

        matched_keywords = []
        if target_keywords:
            for kw in target_keywords:
                clean_kw = kw.strip().lower()
                if clean_kw and clean_kw in clean_text:
                    matched_keywords.append(clean_kw)

        # A. Kriter odaklı arama sonucu:
        if target_keywords:
            if matched_keywords:
                watcher.last_content_hash = new_hash
                watcher.last_change_detected = now_str
                watcher.has_update = True
                kw_str = ", ".join(matched_keywords[:3])
                msg = f"🎯 [BULUNDU] '{watcher.label}' sayfasında aradığınız '{kw_str}' duyurusu tespit edildi!"
                return True, msg
            else:
                watcher.has_update = False
                kw_str = ", ".join(target_keywords[:3])
                msg = f"🔍 [BULUNAMADI] '{watcher.label}' sayfası incelendi: Aradığınız '{kw_str}' kriterleri henüz yayında değil."
                return False, msg

        # B. Genel sayfa değişiklik kontrolü (Hash tabanlı)
        if not watcher.last_content_hash:
            watcher.last_content_hash = new_hash
            watcher.has_update = False
            return False, f"🔍 '{watcher.label}' sayfası taranıp referans alındı. Henüz yeni bir duyuru yok."

        if new_hash != watcher.last_content_hash:
            watcher.last_content_hash = new_hash
            watcher.last_change_detected = now_str
            watcher.has_update = True
            return True, f"🎯 [YENİ İLAN] '{watcher.label}' sayfasında yeni bir duyuru / içerik güncellendi!"
        else:
            watcher.has_update = False
            return False, f"🔍 [STABİL] '{watcher.label}' sayfasında yeni bir değişiklik yok, sayfa takibimizde."
