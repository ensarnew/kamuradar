import re
from datetime import datetime, date
from typing import Optional, Tuple, Dict, Any

class DateCheckerService:
    """
    Kamu duyuruları ve sınav takvimlerinin başvuru tarihlerini
    GÜNÜN TARİHİ ile karşılaştırıp 'Açık ✅', 'Bugün Başladı 🔔' veya 'Kapalı ❌'
    durumunu dinamik olarak hesaplayan motor.
    """

    DATE_REGEX = r"(\d{2})[./-](\d{2})[./-](\d{4})"

    @classmethod
    def parse_first_date(cls, text: str) -> Optional[date]:
        """Metin içindeki ilk tarihi date objesi olarak çeker."""
        if not text:
            return None
        match = re.search(cls.DATE_REGEX, text)
        if match:
            day, month, year = map(int, match.groups())
            try:
                return date(year, month, day)
            except ValueError:
                return None
        return None

    @classmethod
    def parse_date_range(cls, text: str) -> Tuple[Optional[date], Optional[date]]:
        """
        '10.09.2026 - 28.09.2026' gibi aralıkları (başlangıç, bitiş) olarak ayıklar.
        """
        if not text:
            return None, None
        matches = list(re.finditer(cls.DATE_REGEX, text))
        if len(matches) >= 2:
            start_d, start_m, start_y = map(int, matches[0].groups())
            end_d, end_m, end_y = map(int, matches[1].groups())
            try:
                return date(start_y, start_m, start_d), date(end_y, end_m, end_d)
            except ValueError:
                return None, None
        elif len(matches) == 1:
            d, m, y = map(int, matches[0].groups())
            try:
                parsed = date(y, m, d)
                return parsed, parsed
            except ValueError:
                return None, None
        return None, None

    @classmethod
    def check_is_open_today(
        cls, 
        date_text: str, 
        current_date: Optional[date] = None
    ) -> Dict[str, Any]:
        """
        Verilen tarih metnini (başvuru aralığını) bugünün tarihiyle karşılaştırır:
        - is_open: Başvurular bugün açık mı? (start <= today <= end)
        - is_started_today: Başvurular TAM BUGÜN mü başladı? (start == today) -> Push Bildirimi tetikler!
        - is_last_day: Bugün son gün mü? (end == today)
        - status_label: 'Açık (Bugün Başladı! ✅)', 'Açık (Başvurular Devam Ediyor ✅)' vb.
        """
        today = current_date or date.today()
        start_date, end_date = cls.parse_date_range(date_text)

        if not start_date and not end_date:
            return {
                "is_open": False,
                "is_started_today": False,
                "is_last_day": False,
                "status_label": "Tarih Belirtilmemiş",
                "days_left": None
            }

        # Sadece başlangıç tarihi varsa
        if start_date and not end_date:
            if today == start_date:
                return {
                    "is_open": True,
                    "is_started_today": True,
                    "is_last_day": False,
                    "status_label": "Açık (Bugün Başladı! 🔔)",
                    "days_left": None
                }
            elif today > start_date:
                return {
                    "is_open": True,
                    "is_started_today": False,
                    "is_last_day": False,
                    "status_label": "Açık (Devam Ediyor ✅)",
                    "days_left": None
                }
            else:
                return {
                    "is_open": False,
                    "is_started_today": False,
                    "is_last_day": False,
                    "status_label": f"Yakında Başlayacak ({(start_date - today).days} gün kaldı)",
                    "days_left": (start_date - today).days
                }

        # Aralık varsa (start_date ve end_date)
        if start_date and end_date:
            if today < start_date:
                days_to_start = (start_date - today).days
                return {
                    "is_open": False,
                    "is_started_today": False,
                    "is_last_day": False,
                    "status_label": f"Yakında Başlayacak ({days_to_start} gün kaldı ⏳)",
                    "days_left": days_to_start
                }
            elif today == start_date:
                days_remaining = (end_date - today).days
                return {
                    "is_open": True,
                    "is_started_today": True,
                    "is_last_day": False,
                    "status_label": f"AÇIK (Bugün Başladı! 🔔 - Son {days_remaining} gün)",
                    "days_left": days_remaining
                }
            elif start_date < today < end_date:
                days_remaining = (end_date - today).days
                return {
                    "is_open": True,
                    "is_started_today": False,
                    "is_last_day": False,
                    "status_label": f"AÇIK (Başvurular Devam Ediyor ✅ - Son {days_remaining} gün)",
                    "days_left": days_remaining
                }
            elif today == end_date:
                return {
                    "is_open": True,
                    "is_started_today": False,
                    "is_last_day": True,
                    "status_label": "AÇIK (BUGÜN SON GÜN! ⚠️)",
                    "days_left": 0
                }
            else: # today > end_date
                return {
                    "is_open": False,
                    "is_started_today": False,
                    "is_last_day": False,
                    "status_label": "Başvurular Kapandı (Süresi Doldu ❌)",
                    "days_left": -1
                }
