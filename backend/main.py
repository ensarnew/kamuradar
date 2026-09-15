from fastapi import FastAPI, HTTPException, Query, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

from models import (
    Announcement, AnnouncementCategory, ContentType, CustomUrlWatcher,
    FamilyPlan, ExamScheduleItem, RadarAIChatRequest, RadarAIChatResponse
)
from database import db
from services.family_plan import FamilyPlanService
from services.ai_service import RadarAIService
from scrapers.custom_url_watcher import CustomUrlWatcherService
from scrapers.scheduler_12pm import Daily12PMScheduler


app = FastAPI(
    title="KamuRadar API",
    description="10 Temel Sınav Takvimi, Açık İlanlar Paywall (İlk 4 Ücretsiz), Özel Link Dedektörü ve Aile Planı Servisi",
    version="2.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----------------- 0. SAĞLIK KONTROLÜ (RENDER HEALTH CHECK) -----------------

@app.get("/")
@app.head("/")
def health_check():
    """Render ve izleme servisleri için ana sağlık kontrolü rotası."""
    return {
        "status": "ok",
        "service": "KamuRadar API",
        "version": "2.0.0",
        "endpoints": {
            "docs": "/docs",
            "exam_schedules": "/api/exam-schedules",
            "open_announcements": "/api/announcements/open"
        }
    }

# ----------------- 1. SINAV TAKVİMİ & BAŞVURU ZAMANLARI (10 ADET) -----------------

@app.get("/api/exam-schedules", response_model=List[ExamScheduleItem])
def get_exam_schedules():
    """KPSS, MSÜ, ÖSYM vb. tam 10 adet sınavın başvuru ve sonuç takvimini döndürür."""
    return db.exam_schedules


# ----------------- 2. AÇIK İLANLAR & 4 İLAN SINIRI (PAYWALL) -----------------

@app.get("/api/announcements/open")
def get_open_announcements(
    user_id: str = "user-guest",
    category: Optional[str] = None,
    content_type: Optional[ContentType] = None,
    education_level: Optional[str] = None,
    kpss_status: Optional[str] = None
):
    """
    Açık ilanları listeler.
    Ücretsiz kullanıcılara sadece ilk 4 ilan tam gösterilir.
    Kalan ilanlar kilitlenir (Paywall).
    Premium kullanıcılara tüm ilanlar sınırsız açılır.
    """
    is_premium = FamilyPlanService.is_user_premium(user_id)
    all_announcements = list(db.announcements.values())

    if category:
        all_announcements = [a for a in all_announcements if a.category.lower() == category.lower() or category.lower() in a.category.lower()]
    if content_type:
        all_announcements = [a for a in all_announcements if a.content_type == content_type]
    if education_level:
        all_announcements = [a for a in all_announcements if a.education_level and education_level.lower() in a.education_level.lower()]
    if kpss_status:
        all_announcements = [a for a in all_announcements if a.kpss_status and a.kpss_status.lower() == kpss_status.lower()]

    FREE_ANNOUNCEMENT_IDS = {"ann-01", "ann-02", "ann-03", "ann-04"}

    results = []
    for a in all_announcements:
        if is_premium or a.id in FREE_ANNOUNCEMENT_IDS:
            # Kullanıcı Premium veya sabit ücretsiz ilanlardan biri
            item_dict = a.dict()
            item_dict["is_locked"] = False
            results.append(item_dict)
        else:
            # 5. ve sonraki ilanlar ücretsiz kullanıcıya kilitli
            item_dict = {
                "id": a.id,
                "title": a.title,
                "organization": a.organization,
                "category": a.category,
                "content_type": a.content_type,
                "education_level": a.education_level,
                "kpss_status": a.kpss_status,
                "exam_date": a.exam_date,
                "summary": "🔒 Bu ilanın başvuru şartları, kılavuz detayları ve resmî başvuru adresi sadece Premium üyelere açıktır.",
                "requirements": ["Premium Üyelere Özel"],
                "application_start": a.application_start,
                "application_deadline": a.application_deadline,
                "official_url": "#premium-locked",
                "published_at": a.published_at,
                "scanned_at_12pm": a.scanned_at_12pm,
                "is_hot": a.is_hot,
                "is_locked": True,
                "lock_message": "Kalan tüm ilanları görmek için Aylık 39.99 ₺ ile Premium'a geçin veya Aile Davet Kodu kullanın."
            }
            results.append(item_dict)

    return {
        "user_is_premium": is_premium,
        "total_count": len(all_announcements),
        "unlocked_count": len(all_announcements) if is_premium else min(4, len(all_announcements)),
        "announcements": results
    }


# ----------------- 3. ÖZEL LİNK İZLEME (SADECE PREMİUM) -----------------

class CreateWatcherRequest(BaseModel):
    user_id: str
    url: str
    label: str
    notes: Optional[str] = ""

@app.get("/api/custom-watchers")
def list_custom_watchers(user_id: str):
    is_premium = FamilyPlanService.is_user_premium(user_id)
    if not is_premium:
        raise HTTPException(
            status_code=403,
            detail="Özel link takibi ve 12:00 anlık bildirimleri sadece Premium üyelere açıktır. Lütfen Premium plana geçin."
        )
    return [w for w in db.custom_watchers.values() if w.user_id == user_id]

@app.post("/api/custom-watchers")
def add_custom_watcher(req: CreateWatcherRequest):
    is_premium = FamilyPlanService.is_user_premium(req.user_id)
    if not is_premium:
        raise HTTPException(
            status_code=403,
            detail="Özel link eklemek için Premium üye olmanız gerekmektedir."
        )
    return CustomUrlWatcherService.register_watcher(
        user_id=req.user_id,
        url=req.url,
        label=req.label,
        notes=req.notes or ""
    )


# ----------------- 4. PREMİUM, 6 HANELİ KOD VE İPTAL ZİNCİRİ -----------------

class PurchasePremiumRequest(BaseModel):
    owner_id: str
    owner_name: str

class JoinPlanRequest(BaseModel):
    invite_code: str
    user_id: str
    user_name: str

class CancelSubscriptionRequest(BaseModel):
    owner_id: str

@app.post("/api/subscription/purchase")
def purchase_premium(req: PurchasePremiumRequest):
    """Kullanıcı 39.99 ₺ öder, Premium olur ve 6 haneli davet kodu üretilir."""
    plan = FamilyPlanService.purchase_premium_and_create_plan(
        owner_id=req.owner_id,
        owner_name=req.owner_name
    )
    return {
        "success": True,
        "message": f"Aylık 39.99 ₺ ödeme onaylandı! Premium aktif. Davet kodunuz: {plan.invite_code}",
        "plan": plan
    }

@app.post("/api/subscription/join")
def join_plan_with_code(req: JoinPlanRequest):
    """Arkadaşın davet kodunu girmesi. Anında Premium olur."""
    success, message, plan = FamilyPlanService.join_family_plan(
        invite_code=req.invite_code,
        user_id=req.user_id,
        user_name=req.user_name
    )
    if not success:
        raise HTTPException(status_code=400, detail=message)
    return {"success": True, "message": message, "plan": plan}

@app.post("/api/subscription/cancel")
def cancel_subscription(req: CancelSubscriptionRequest):
    """
    İptal Zinciri:
    Ana kullanıcı iptal ettiği anda onun kodunu kullanan tüm üyelerin (+3 kişi)
    Premium hakkı derhal sonlanır.
    """
    success, message, affected = FamilyPlanService.cancel_subscription_cascade(req.owner_id)
    if not success:
        raise HTTPException(status_code=400, detail=message)
    return {
        "success": True,
        "message": message,
        "affected_members_count": affected
    }

@app.get("/api/user/status/{user_id}")
def get_user_status(user_id: str):
    is_premium = FamilyPlanService.is_user_premium(user_id)
    plan_code = db.user_plans.get(user_id)
    return {
        "user_id": user_id,
        "is_premium": is_premium,
        "plan_code": plan_code
    }


# ----------------- 5. SAAT 12:00 GÜNLÜK TOPLU TARAMA MOTORU -----------------

@app.post("/api/cron/trigger-12pm")
def trigger_12pm_cron():
    report = Daily12PMScheduler.run_daily_12pm_batch()
    return report

@app.get("/api/cron/status")
def get_cron_status():
    return {
        "schedule": "Her gün tek seferlik - Saat 12:00 (Öğlen)",
        "last_run": Daily12PMScheduler.last_run_timestamp,
        "last_run_stats": Daily12PMScheduler.last_run_stats
    }


# ----------------- 6. RADARAI (GEMİNİ FLASH) ENTEGRASYONU -----------------

@app.post("/api/radar-ai/chat", response_model=RadarAIChatResponse)
def chat_with_radar_ai(req: RadarAIChatRequest):
    """
    RadarAI ile soru-cevap servisi.
    - Ücretsiz kullanıcı: Günlük 3 soru kotası.
    - VIP üye / Aile Planı: Günlük 10 soru kotası.
    - Kota dolduğunda: 'Sistem şu an aktif değil' döner.
    """
    result = RadarAIService.ask_radar_ai(
        user_id=req.user_id,
        message=req.message
    )
    return result

@app.get("/api/radar-ai/quota/{user_id}")
def get_radar_ai_quota(user_id: str):
    """Kullanıcının kalan ve toplam RadarAI soru haklarını döndürür."""
    remaining, max_quota, is_vip = RadarAIService.get_user_quota_info(user_id)
    return {
        "user_id": user_id,
        "remaining_quota": remaining,
        "max_quota": max_quota,
        "is_vip": is_vip,
        "used_quota": max_quota - remaining
    }


# ----------------- 7. YÖNETİCİ ÖZEL BİLDİRİM & REKLAM/VİDEO YÖNLENDİRME (FCM) -----------------

class AdminBroadcastNotificationRequest(BaseModel):
    title: str
    body: str
    promo_url: Optional[str] = None
    target_topic: str = "all_users"

@app.post("/api/admin/broadcast-notification")
def send_admin_broadcast_notification(req: AdminBroadcastNotificationRequest):
    """
    Yöneticinin tüm kullanıcılara veya belirli hedefe anlık push bildirimi fırlatmasını sağlar.
    Kullanıcı bildirime tıkladığında doğrudan yöneticinin belirttiği özel video (YouTube/TikTok),
    Instagram veya reklam anlaşması yapılan web sitesi linkine yönlendirilir!
    """
    from services.firebase_service import FirebaseNotificationService
    
    result = FirebaseNotificationService.send_push_notification(
        topic=req.target_topic,
        title=req.title,
        body=req.body,
        data={
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
            "url": req.promo_url or "",
            "type": "promo_ad",
            "is_external_link": "true" if req.promo_url else "false"
        }
    )
    return {
        "status": "success",
        "message": f"'{req.title}' bildirimi tüm kullanıcılara fırlatıldı!",
        "target_url": req.promo_url,
        "fcm_response": result
    }

