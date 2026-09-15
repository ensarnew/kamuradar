from datetime import datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field

class ContentType(str, Enum):
    ILAN = "ILAN"
    SINAV = "SINAV"
    MULAKAT = "MULAKAT"
    SONUC = "SONUC"

class AnnouncementCategory(str, Enum):
    ASKERI_EMNIYET = "Askeri & Emniyet"
    BAKANLIKLAR = "Bakanlıklar"
    BELEDIYELER = "Belediyeler & Mahalli İdareler"
    AKADEMIK = "Üniversiteler & Akademik"
    ISKUR_ISCI = "İŞKUR & Kamu İşçi"
    KIT_BANKALAR = "KİT & Bankalar"
    OSYM_SINAVLAR = "ÖSYM & Sınavlar"
    # Geriye dönük uyumluluk
    JANDARMA = "jandarma"
    MSU_ASKERI = "msu_askeri"
    POLIS_POMEM = "polis_pomem"
    KAMU_MEMUR = "kamu_memur"
    SINAVLAR_OSYM = "sinavlar_osym"
    SOZLESMELI = "sozlesmeli"

class ExamStatus(str, Enum):
    ACTIVE = "Başvurular Açık"
    UPCOMING = "Yakında Başlayacak"
    ANNOUNCED = "Sonuçlar Açıklandı"
    COMPLETED = "completed"

class ExamScheduleItem(BaseModel):
    id: str
    title: str
    organization: str  # ÖSYM, MSB, JSGA, EGM vb.
    category: Optional[str] = "ÖSYM & Sınavlar"
    content_type: ContentType = ContentType.SINAV
    education_level: Optional[str] = "Lisans"
    kpss_status: Optional[str] = "KPSS'li"
    application_dates: str
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    exam_date: Optional[str] = None
    result_date: Optional[str] = None
    status: ExamStatus
    official_url: str

class Announcement(BaseModel):
    id: str
    title: str
    organization: str
    category: str
    content_type: ContentType = ContentType.ILAN
    education_level: Optional[str] = "Lisans"  # Okuryazar, Lise, Ön Lisans, Lisans
    kpss_status: Optional[str] = "KPSS'li"      # KPSS'li, KPSS'siz, Muaf
    exam_date: Optional[str] = None
    application_deadline: Optional[str] = None
    summary: str
    requirements: List[str] = []
    application_start: Optional[str] = None
    official_url: str
    published_at: str
    scanned_at_12pm: str
    is_hot: bool = False
    is_premium_only: bool = False  # İlk 4 ilan False, 5+ ilanlar True (Paywall)

class CustomUrlWatcher(BaseModel):
    id: str
    user_id: str
    url: str
    label: str
    last_checked_12pm: Optional[str] = None
    last_content_hash: Optional[str] = None
    last_change_detected: Optional[str] = None
    has_update: bool = False
    notes: Optional[str] = None

class FamilyMember(BaseModel):
    user_id: str
    name: str
    joined_at: str

class FamilyPlan(BaseModel):
    plan_id: str
    owner_id: str
    owner_name: str
    price_monthly: float = 39.99
    invite_code: str  # 6 haneli kod (Örn: "KMR742")
    max_extra_members: int = 3  # Kendi + 3 kişi = 4
    members: List[FamilyMember] = []
    is_active: bool = True
    created_at: str

class RadarAIChatRequest(BaseModel):
    user_id: str
    message: str

class RadarAIChatResponse(BaseModel):
    reply: str
    remaining_quota: int
    max_quota: int
    is_vip: bool
    status: str  # "ok" or "quota_exceeded"
    suggested_url: Optional[str] = None

