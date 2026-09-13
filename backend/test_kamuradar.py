import pytest
from database import db
from services.family_plan import FamilyPlanService
from scrapers.custom_url_watcher import CustomUrlWatcherService
from scrapers.scheduler_12pm import Daily12PMScheduler

def test_exam_schedules_twenty_items():
    """Tam 20 adet sınav ve başvuru/sonuç takvimi kaydı olduğunu doğrular."""
    assert len(db.exam_schedules) == 20
    titles = [item.title for item in db.exam_schedules]
    assert any("KPSS" in t for t in titles)
    assert any("MSÜ" in t for t in titles)
    assert any("POMEM" in t for t in titles)
    assert any("JSGA" in t for t in titles)
    assert any("Bekçilik" in t for t in titles)
    assert any("Öğretmen" in t for t in titles)


def test_paywall_four_free_announcements():
    """Ücretsiz kullanıcının sadece 4 ilana tam erişebildiğini doğrular."""
    guest_id = "test-guest-user"
    assert FamilyPlanService.is_user_premium(guest_id) is False

    from main import get_open_announcements
    res = get_open_announcements(user_id=guest_id)
    assert res["user_is_premium"] is False
    assert res["unlocked_count"] == 4
    assert res["announcements"][0]["is_locked"] is False
    assert res["announcements"][3]["is_locked"] is False
    assert res["announcements"][4]["is_locked"] is True

def test_cascade_cancellation():
    """
    İptal Zinciri Testi:
    Ana kullanıcı aboneliği iptal edince arkadaşının da Premium yetkisinin düştüğünü doğrular.
    """
    owner_id = "test-owner-ali"
    friend_id = "test-friend-mehmet"

    # 1. Ana kullanıcı 39.99 ₺ ile Premium başlatır
    plan = FamilyPlanService.purchase_premium_and_create_plan(owner_id, "Ali")
    assert FamilyPlanService.is_user_premium(owner_id) is True
    assert len(plan.invite_code) == 6

    # 2. Arkadaş bu kodla katılır
    success, _, _ = FamilyPlanService.join_family_plan(plan.invite_code, friend_id, "Mehmet")
    assert success is True
    assert FamilyPlanService.is_user_premium(friend_id) is True

    # 3. Ana kullanıcı aboneliği iptal eder
    success_cancel, _, affected = FamilyPlanService.cancel_subscription_cascade(owner_id)
    assert success_cancel is True
    assert affected == 1

    # 4. KONTROL: Hem ana kullanıcının hem arkadaşın Premium'u bitmiş olmalıdır!
    assert FamilyPlanService.is_user_premium(owner_id) is False
    assert FamilyPlanService.is_user_premium(friend_id) is False

def test_radar_ai_free_quota_and_exhaustion():
    """
    RadarAI Ücretsiz Kota Testi:
    - Ücretsiz kullanıcı günde en fazla 3 soru sorabilir.
    - 4. soruda zorunlu olarak 'Sistem şu an aktif değil' yanıtı dönmelidir.
    """
    from services.ai_service import RadarAIService
    RadarAIService.reset_quotas_for_testing()
    test_user = "guest-free-101"

    # İlk 3 soru başarılı olmalı
    for i in range(1, 4):
        res = RadarAIService.ask_radar_ai(test_user, f"Test sorusu {i}")
        assert res["status"] == "ok"
        assert res["remaining_quota"] == (3 - i)
        assert res["reply"] != "Sistem şu an aktif değil"

    # 4. soru kotayı aşar ve kesin kural tetiklenir:
    res_exceeded = RadarAIService.ask_radar_ai(test_user, "4. soru (kota aşımı)")
    assert res_exceeded["status"] == "quota_exceeded"
    assert res_exceeded["remaining_quota"] == 0
    assert res_exceeded["reply"] == "Sistem şu an aktif değil"

def test_radar_ai_vip_ten_questions_quota():
    """
    RadarAI VIP Kota Testi:
    - VIP / Aile Planı üyesi günde 10 soru sorabilir.
    - 11. soruda 'Sistem şu an aktif değil' döner.
    """
    from services.ai_service import RadarAIService
    RadarAIService.reset_quotas_for_testing()
    vip_user = "vip-owner-ayse"
    FamilyPlanService.purchase_premium_and_create_plan(vip_user, "Ayşe")

    # 10 soru başarılı olmalı
    for i in range(1, 11):
        res = RadarAIService.ask_radar_ai(vip_user, f"VIP Soru {i}")
        assert res["status"] == "ok"
        assert res["remaining_quota"] == (10 - i)
        assert res["is_vip"] is True

    # 11. soru kotayı aşar
    res_11 = RadarAIService.ask_radar_ai(vip_user, "11. soru")
    assert res_11["status"] == "quota_exceeded"
    assert res_11["remaining_quota"] == 0
    assert res_11["reply"] == "Sistem şu an aktif değil"

def test_radar_ai_suggested_url():
    """RadarAI'ın resmî kamu linki önerisini doğrular."""
    from services.ai_service import RadarAIService
    RadarAIService.reset_quotas_for_testing()
    user = "user-link-test"
    res = RadarAIService.ask_radar_ai(user, "Jandarma uzman erbaş başvuru linki nedir?")
    assert res["status"] == "ok"
    assert "https://vatandas.jandarma.gov.tr" in (res.get("suggested_url") or "")

def test_date_checker_open_status():
    """
    Tarih Karşılaştırma Testi:
    - İlan başvuru aralığı bugünü kapsıyorsa 'is_open=True' döner.
    - Tam bugün başladıysa 'is_started_today=True' olup bildirim tetikler.
    - Süresi geçmişse 'is_open=False' döner.
    """
    from datetime import date
    from services.date_checker import DateCheckerService

    # 1. Bugün başlayan ilan
    test_today = date(2026, 9, 13)
    res_today_start = DateCheckerService.check_is_open_today("13.09.2026 - 28.09.2026", current_date=test_today)
    assert res_today_start["is_open"] is True
    assert res_today_start["is_started_today"] is True
    assert "Bugün Başladı" in res_today_start["status_label"]

    # 2. Devam eden ilan (aralık ortası)
    res_ongoing = DateCheckerService.check_is_open_today("10.09.2026 - 28.09.2026", current_date=test_today)
    assert res_ongoing["is_open"] is True
    assert res_ongoing["is_started_today"] is False
    assert "Devam Ediyor" in res_ongoing["status_label"]

    # 3. Henüz başlamamış ilan (gelecek)
    res_future = DateCheckerService.check_is_open_today("20.09.2026 - 05.10.2026", current_date=test_today)
    assert res_future["is_open"] is False
    assert "Yakında Başlayacak" in res_future["status_label"]

    # 4. Süresi dolmuş ilan (geçmiş)
    res_expired = DateCheckerService.check_is_open_today("01.08.2026 - 20.08.2026", current_date=test_today)
    assert res_expired["is_open"] is False
    assert "Kapandı" in res_expired["status_label"]

def test_scheduler_runs_with_date_check():
    """12:00 taramasının tarihleri kontrol edip açık ilanları doğruladığını test eder."""
    from datetime import date
    from scrapers.scheduler_12pm import Daily12PMScheduler

    stats = Daily12PMScheduler.run_daily_12pm_batch(check_date=date(2026, 9, 13))
    assert stats["status"] == "success"
    assert stats["open_announcements_today"] >= 1
    assert "notifications_sent_count" in stats


