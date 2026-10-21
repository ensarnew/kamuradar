from fastapi import FastAPI, HTTPException, Query, Header
from fastapi.responses import HTMLResponse
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
            "privacy": "/privacy",
            "terms": "/terms",
            "exam_schedules": "/api/exam-schedules",
            "open_announcements": "/api/announcements/open"
        }
    }

# ----------------- 0.1 GİZLİLİK POLİTİKASI & KULLANIM KOŞULLARI (GOOGLE PLAY COMPLIANT) -----------------

@app.get("/privacy", response_class=HTMLResponse)
def get_privacy_policy():
    """Google Play kurallarına tam uyumlu Gizlilik Politikası ve Sorumluluk Reddi sayfası."""
    return """<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>KamuRadar - Gizlilik Politikası & Sorumluluk Reddi</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #1e293b; background: #f8fafc; margin: 0; padding: 20px; }
        .container { max-width: 800px; margin: 0 auto; background: #ffffff; padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); border: 1px solid #e2e8f0; }
        h1 { color: #0f172a; border-bottom: 2px solid #38bdf8; padding-bottom: 10px; font-size: 24px; }
        h2 { color: #0284c7; margin-top: 24px; font-size: 18px; }
        .alert-box { background: #fef2f2; border-left: 4px solid #ef4444; padding: 14px; border-radius: 6px; margin: 20px 0; font-size: 14px; color: #991b1b; }
        .alert-box strong { color: #b91c1c; display: block; margin-bottom: 4px; }
        ul { padding-left: 20px; }
        li { margin-bottom: 6px; }
        a { color: #0284c7; text-decoration: underline; }
        .footer { margin-top: 30px; padding-top: 15px; border-top: 1px solid #e2e8f0; font-size: 12px; color: #64748b; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <h1>KamuRadar Gizlilik Politikası & Kullanım Koşulları</h1>
        <p><strong>Son Güncelleme:</strong> 21 Ekim 2026</p>

        <div class="alert-box">
            <strong>ÖNEMLİ RESMÎ SORUMLULUK REDDİ BEYANI (DISCLAIMER):</strong>
            KamuRadar bağımsız bir mobil bilgilendirme ve sınav/ilan takip servisidir. <strong>KamuRadar herhangi bir devlet kurumunu, bakanlığı, silahlı kuvvetleri veya resmî kamu kuruluşunu TEMSİL ETMEZ ve bu kurumlarla kurumsal bir bağı bulunmamaktadır.</strong> Uygulamada yer alan tüm ilanlar, kamunun erişimine açık resmî portallardan derlenmektedir. Kesin başvuru şartları ve resmî başvurular yalnızca ilgili kurumun resmî web sayfası üzerinden yapılmalıdır.
        </div>

        <h2>1. Resmî Bilgi ve İlan Kaynaklarımız</h2>
        <p>Uygulamada sunulan kamu personeli alımı, KPSS ve sınav takvimi bilgileri aşağıdaki doğrulanabilir resmî kaynaklardan temin edilmektedir:</p>
        <ul>
            <li><strong>T.C. Resmî Gazete:</strong> <a href="https://www.resmigazete.gov.tr" target="_blank" rel="noopener">https://www.resmigazete.gov.tr</a></li>
            <li><strong>Kariyer Kapısı (Cumhurbaşkanlığı İnsan Kaynakları Ofisi):</strong> <a href="https://kariyerkapisi.gov.tr" target="_blank" rel="noopener">https://kariyerkapisi.gov.tr</a></li>
            <li><strong>Kamu İlan Portalı (Strateji ve Bütçe Bşk.):</strong> <a href="https://kamuilan.sbb.gov.tr" target="_blank" rel="noopener">https://kamuilan.sbb.gov.tr</a></li>
            <li><strong>Türkiye İş Kurumu (İŞKUR):</strong> <a href="https://www.iskur.gov.tr" target="_blank" rel="noopener">https://www.iskur.gov.tr</a></li>
            <li><strong>Ölçme, Seçme ve Yerleştirme Merkezi (ÖSYM):</strong> <a href="https://www.osym.gov.tr" target="_blank" rel="noopener">https://www.osym.gov.tr</a></li>
            <li><strong>Jandarma Personel Temin Sistemi:</strong> <a href="https://personeltemin.jandarma.gov.tr" target="_blank" rel="noopener">https://personeltemin.jandarma.gov.tr</a></li>
            <li><strong>Polis Akademisi Başkanlığı:</strong> <a href="https://pa.edu.tr" target="_blank" rel="noopener">https://pa.edu.tr</a></li>
            <li><strong>Millî Savunma Bakanlığı (MSB):</strong> <a href="https://personeltemin.msb.gov.tr" target="_blank" rel="noopener">https://personeltemin.msb.gov.tr</a></li>
            <li><strong>Sağlık Bakanlığı:</strong> <a href="https://www.saglik.gov.tr" target="_blank" rel="noopener">https://www.saglik.gov.tr</a></li>
            <li><strong>Millî Eğitim Bakanlığı:</strong> <a href="https://www.meb.gov.tr" target="_blank" rel="noopener">https://www.meb.gov.tr</a></li>
        </ul>

        <h2>2. Toplanan Veriler ve Kullanım Amaçları</h2>
        <p>KamuRadar, kullanıcı deneyimini sağlamak için yalnızca asgari düzeyde teknik veri işler:</p>
        <ul>
            <li><strong>Oturum Bilgisi (İsteğe Bağlı):</strong> Google ile giriş yapıldığında yalnızca kullanıcı ID'si, e-posta ve görünen isim bulut yedekleme amacıyla Firebase üzerinde saklanır. Şifrenize asla erişilmez. Misafir modu ile giriş yapmadan da uygulama kullanılabilir.</li>
            <li><strong>Bildirim Belirteci (FCM Token):</strong> Takip ettiğiniz kamu ilanları veya kurduğunuz alarmlarla ilgili telefonunuza anlık bildirim göndermek amacıyla kullanılır.</li>
            <li><strong>Yerel Tercihler:</strong> Favori ilanlarınız ve takip ettiğiniz web adresleri cihazınızın yerel hafızasında saklanır.</li>
        </ul>

        <h2>3. Üçüncü Taraf Servisler</h2>
        <p>Uygulamamız aşağıdaki güvenli ve endüstri standardı altyapıları kullanır:</p>
        <ul>
            <li><strong>Google Firebase:</strong> Kimlik doğrulama, Firestore veritabanı ve bildirim iletimi (FCM).</li>
            <li><strong>Google Play Billing:</strong> VIP aboneliklerin güvenli şekilde faturalandırılması (kredi kartı bilgileriniz doğrudan Google Play tarafından işlenir, sunucularımızda tutulmaz).</li>
            <li><strong>Unity Ads:</strong> Ücretsiz kullanıcılara ödüllü ilan açma ve bildirim hakkı tanımlama reklamları sunmak için kullanılır.</li>
        </ul>

        <h2>4. Veri Güvenliği ve Silme Hakkı</h2>
        <p>Verileriniz SSL/TLS şifreleme ile korunur. Kullanıcılar diledikleri zaman Profil sayfasından oturumlarını kapatabilir veya hesaplarının ve alarmlarının silinmesini talep edebilirler.</p>

        <h2>5. İletişim</h2>
        <p>Gizlilik politikamız veya uygulamayla ilgili her türlü soru ve geri bildiriminiz için bizimle iletişime geçebilirsiniz:</p>
        <p><strong>E-posta:</strong> kamuradar.destek@gmail.com</p>

        <div class="footer">
            &copy; 2026 KamuRadar. Tüm hakları saklıdır.
        </div>
    </div>
</body>
</html>"""

@app.get("/terms", response_class=HTMLResponse)
def get_terms_of_service():
    """Kullanım Koşulları sayfası (Gizlilik Politikasına yönlendirir veya aynısını sunar)."""
    return get_privacy_policy()


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


# ----------------- 5. GÜNDÜZ PERİYODİK TARAMA MOTORU (10, 12, 14, 16, 18, 20, 22) -----------------

@app.post("/api/cron/trigger-12pm")
@app.post("/api/cron/trigger-slot")
def trigger_periodic_cron(slot_hour: Optional[int] = None):
    """
    10:00, 12:00, 14:00, 16:00, 18:00, 20:00, 22:00 periyotlarında
    canlı kamu kaynaklarını (Resmî Gazete, İŞKUR, CBİKO) tarar,
    yeni ilanları Firestore 'announcements' koleksiyonuna doğrudan basar
    ve 'kamuradar_all' ile 'announcements' konularına anlık push bildirim fırlatır.
    """
    try:
        report = Daily12PMScheduler.run_daily_12pm_batch()
        return report
    except Exception as e:
        import traceback
        err_msg = f"Tarama sırasında hata oluştu: {str(e)}"
        print(err_msg)
        traceback.print_exc()
        return {
            "status": "partial_success",
            "message": err_msg,
            "error_detail": traceback.format_exc(),
            "last_run_stats": Daily12PMScheduler.last_run_stats
        }

@app.get("/api/cron/status")
def get_cron_status():
    import os
    from services.firebase_service import FirebaseNotificationService
    FirebaseNotificationService.initialize()
    return {
        "schedule": "Gündüz Periyodik: 10:00, 12:00, 14:00, 16:00, 18:00, 20:00, 22:00",
        "last_run": Daily12PMScheduler.last_run_timestamp,
        "last_run_stats": Daily12PMScheduler.last_run_stats,
        "firebase_connected": FirebaseNotificationService._initialized,
        "has_env_creds": bool(os.getenv("FIREBASE_CREDENTIALS_JSON"))
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
    target_topic: str = "kamuradar_all"

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

class SetUserVipRequest(BaseModel):
    uid: str
    is_vip: bool = True
    plan: str = "vip_family_plan"

@app.post("/api/admin/set-user-vip")
def admin_set_user_vip(req: SetUserVipRequest):
    """
    Yöneticinin herhangi bir kullanıcıya doğrudan VIP tanımlamasını sağlar.
    Firebase Admin yetkisiyle kurallara takılmadan doğrudan Firestore'a yazar.
    """
    from services.firebase_service import FirebaseNotificationService
    FirebaseNotificationService.initialize()
    try:
        from firebase_admin import firestore
        db_client = firestore.client()
        db_client.collection('users').document(req.uid).set({
            'is_vip': req.is_vip,
            'vip_plan': req.plan if req.is_vip else 'free',
            'vip_updated_at': firestore.SERVER_TIMESTAMP,
            'vip_granted_by_admin': True,
        }, merge=True)
        return {
            "success": True,
            "message": f"Kullanıcı ({req.uid}) VIP durumu '{req.is_vip}' olarak güncellendi.",
            "uid": req.uid,
            "is_vip": req.is_vip
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/admin/users")
def admin_list_users():
    """
    Tüm kayıtlı kullanıcıları ve gerçek VIP durumlarını Firestore'dan çeker.
    Admin paneli için eksiksiz liste döndürür.
    """
    from services.firebase_service import FirebaseNotificationService
    FirebaseNotificationService.initialize()
    try:
        from firebase_admin import firestore
        db_client = firestore.client()
        docs = db_client.collection('users').stream()
        user_list = []
        for doc in docs:
            data = doc.to_dict() or {}
            user_list.append({
                "uid": doc.id,
                "email": data.get("email") or "E-posta Yok",
                "display_name": data.get("display_name") or "İsimsiz Üye",
                "is_vip": data.get("is_vip", False) == True,
                "vip_plan": data.get("vip_plan", "free"),
                "last_active": "Aktif",
                "invite_code": data.get("invite_code", ""),
            })
        return user_list
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

