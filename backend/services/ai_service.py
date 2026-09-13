import os
import re
from typing import Dict, Optional, Tuple
from services.family_plan import FamilyPlanService

# Try importing google-genai
try:
    from google import genai
    from google.genai import types
    GENAI_AVAILABLE = True
except ImportError:
    GENAI_AVAILABLE = False


class RadarAIService:
    """
    RadarAI: KamuRadar Akıllı Sınav ve Kamu Alımları Asistanı.
    - Free kullanıcı: Günlük 3 soru kotası.
    - VIP / Aile Planı: Günlük 10 soru kotası.
    - Kota aşıldığında zorunlu yanıt: 'Sistem şu an aktif değil'
    - Gemini 2.5 Flash API entegrasyonu + Offline Akıllı Bilgi Tabanı.
    """
    
    # Kullanıcı günlük soru sayaçları (user_id -> soru sayısı)
    user_usage_counts: Dict[str, int] = {}

    FREE_LIMIT = 3
    VIP_LIMIT = 10

    SYSTEM_INSTRUCTION = """
    Sen KamuRadar uygulamasının resmî yapay zekâ asistanı 'RadarAI'sın.
    Görevin Türk kamu personeli alımları (KPSS, ÖSYM, MSÜ, POMEM, Jandarma, Bekçilik, Adalet ve Sağlık Bakanlığı) hakkında adaylara net, doğru ve doğrudan bilgi vermektir.
    Başvuru şartları (boy, kilo, yaş, KPSS puan türü), sınav tarihleri ve resmî başvuru bağlantıları konularında uzmansın.
    Kullanıcı resmi duyuru veya başvuru linki istediğinde, KamuRadar'ın 'Özel Linkler' sekmesine ekleyebileceği güncel ve doğrulanmış resmî web adresini (örn: ais.osym.gov.tr, personeltemin.msb.gov.tr, vatandas.jandarma.gov.tr, pa.edu.tr, kariyerkapisi.cbiko.gov.tr) açıkça ver ve Özel Linkler sekmesine eklemesini öner.
    Cevapların kısa, madde imli ve Türkçe olsun.
    """

    # Hızlı ve doğrulanmış kamu bağlantıları eşleştirmesi
    KNOWN_OFFICIAL_URLS = {
        "jandarma": "https://vatandas.jandarma.gov.tr/PTM/Giris",
        "msu": "https://personeltemin.msb.gov.tr",
        "msb": "https://personeltemin.msb.gov.tr",
        "pomem": "https://www.pa.edu.tr",
        "polis": "https://www.pa.edu.tr",
        "osym": "https://ais.osym.gov.tr",
        "kpss": "https://ais.osym.gov.tr",
        "saglik": "https://yhgm.saglik.gov.tr",
        "adalet": "https://pgm.adalet.gov.tr",
        "kariyer": "https://kariyerkapisi.cbiko.gov.tr"
    }

    @classmethod
    def get_user_quota_info(cls, user_id: str) -> Tuple[int, int, bool]:
        """
        Döndürür: (kalan_hak, maksimum_hak, is_vip)
        """
        is_vip = FamilyPlanService.is_user_premium(user_id)
        max_quota = cls.VIP_LIMIT if is_vip else cls.FREE_LIMIT
        used = cls.user_usage_counts.get(user_id, 0)
        remaining = max(0, max_quota - used)
        return remaining, max_quota, is_vip

    @classmethod
    def reset_quotas_for_testing(cls):
        """Test amaçlı kotaları sıfırlar."""
        cls.user_usage_counts.clear()

    @classmethod
    def ask_radar_ai(cls, user_id: str, message: str) -> dict:
        """
        RadarAI soru sorma metodudur.
        Kotayı kontrol eder. Aşılmışsa 'Sistem şu an aktif değil' döner.
        """
        clean_msg = message.strip()
        remaining, max_quota, is_vip = cls.get_user_quota_info(user_id)

        # KOTA DOLMUŞSA: Kullanıcının kesin kuralı: "Sistem şu an aktif değil"
        if remaining <= 0:
            return {
                "reply": "Sistem şu an aktif değil",
                "remaining_quota": 0,
                "max_quota": max_quota,
                "is_vip": is_vip,
                "status": "quota_exceeded",
                "suggested_url": None
            }

        # Kotadan 1 düş (kullanımı artır)
        cls.user_usage_counts[user_id] = cls.user_usage_counts.get(user_id, 0) + 1
        new_remaining = max(0, max_quota - cls.user_usage_counts[user_id])

        # Link önerisi algılama
        suggested_url = cls._detect_suggested_url(clean_msg)

        # 1. Gerçek Gemini 2.5 Flash çağrısı (API Key varsa)
        api_key = os.getenv("GEMINI_API_KEY")
        if GENAI_AVAILABLE and api_key:
            try:
                client = genai.Client(api_key=api_key)
                response = client.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=clean_msg,
                    config=types.GenerateContentConfig(
                        system_instruction=cls.SYSTEM_INSTRUCTION,
                        temperature=0.3,
                        max_output_tokens=600
                    )
                )
                ai_text = response.text if response and response.text else cls._fallback_response(clean_msg)
                return {
                    "reply": ai_text.strip(),
                    "remaining_quota": new_remaining,
                    "max_quota": max_quota,
                    "is_vip": is_vip,
                    "status": "ok",
                    "suggested_url": suggested_url
                }
            except Exception as e:
                # API hatası olursa sessizce zengin yedek motora geç
                pass

        # 2. Akıllı Bilgi Tabanı Yanıtı (Offline / Fallback)
        reply_text = cls._fallback_response(clean_msg)
        return {
            "reply": reply_text,
            "remaining_quota": new_remaining,
            "max_quota": max_quota,
            "is_vip": is_vip,
            "status": "ok",
            "suggested_url": suggested_url
        }

    @classmethod
    def _detect_suggested_url(cls, message: str) -> Optional[str]:
        lower = message.lower()
        for key, url in cls.KNOWN_OFFICIAL_URLS.items():
            if key in lower:
                return url
        return None

    @classmethod
    def _fallback_response(cls, message: str) -> str:
        """
        Kamu alımlarına özel yerleşik uzman bilgi tabanı.
        """
        lower = message.lower()

        if "jandarma" in lower or "uzman erbaş" in lower:
            return (
                "🎯 **Jandarma 2.500 Uzman Erbaş Alım Şartları:**\n\n"
                "• **Öğrenim:** En az lise ve dengi okul mezunu olmak.\n"
                "• **Yaş Sınırı:** 01 Ocak 2026 itibarıyla 27 yaşını bitirmemiş olmak (01.01.1999 ve sonrası doğumlular).\n"
                "• **Boy/Kilo:** En az 167 cm boy ve boy-kilo tablosuna uygun VKİ (19-26 aralığı).\n"
                "• **Resmî Başvuru:** Doğrudan https://vatandas.jandarma.gov.tr/PTM/Giris adresinden yapılır.\n\n"
                "💡 *İpucu:* Bu linki KamuRadar'ın 'Özel Linkler' sekmesine ekleyerek günlük saat 12:00 taramasında değişiklik alarmlarını alabilirsin!"
            )

        if "polis" in lower or "pomem" in lower:
            return (
                "👮 **32. Dönem POMEM Polis Alım Şartları:**\n\n"
                "• **Kontenjan:** 8.000 Lisans + 2.000 Önlisans (Toplam 10.000 polis memuru).\n"
                "• **KPSS:** Lisans için P3 en az 60, Önlisans için P93 en az 65 taban puan.\n"
                "• **Yaş:** 30 yaşından gün almamış olmak (01.01.1997 ve sonrası doğumlular).\n"
                "• **Boy Şartı:** Erkeklerde en az 167 cm, kadınlarda en az 162 cm.\n"
                "• **Resmî Başvuru Adresi:** https://www.pa.edu.tr\n\n"
                "💡 *İpucu:* PA duyurularını kaçırmamak için Özel Linkler'e 'https://www.pa.edu.tr' ekleyin."
            )

        if "msü" in lower or "msu" in lower or "askeri" in lower:
            return (
                "🎖️ **Milli Savunma Üniversitesi (MSÜ) Başvuru Detayları:**\n\n"
                "• **Okullar:** Harp Okulları (Subay) ve Astsubay Meslek Yüksekokulları.\n"
                "• **Sınav:** ÖSYM tarafından uygulanan MSÜ Askeri Öğrenci Belirleme Sınavı.\n"
                "• **Yaş Sınırı:** Harp Okulları için en fazla 20 yaş, MYO için en fazla 21 yaş.\n"
                "• **Resmî Portal:** https://personeltemin.msb.gov.tr\n\n"
                "💡 2. seçim aşamaları (fiziki yeterlilik ve mülakat) tarihlerini KamuRadar Alarm Radarı üzerinden takip edebilirsiniz."
            )

        if "kpss" in lower or "65" in lower or "70" in lower:
            return (
                "📊 **KPSS Taban Puanları ve Tercih Rehberi:**\n\n"
                "• **65 Puan ile:** Adalet Bakanlığı İnfaz Koruma Memuru (İKM), zabıt katipliği, belediye zabıta kadroları ve POMEM polislik alımlarına başvurulabilir.\n"
                "• **70 Puan ile:** Bakanlıkların taşra ve merkez sözleşmeli büro personeli, GSB yurt yönetim memuru vb. kadrolarına başvurabilirsiniz.\n"
                "• **Resmî Takvim:** https://ais.osym.gov.tr\n\n"
                "💡 Güncel tercih kılavuzları yayınlandığında KamuRadar'ın 'Açık İlanlar (VIP)' sekmesinde listelenecektir."
            )

        if "link" in lower or "nereden" in lower or "adres" in lower:
            return (
                "🔗 **Kamu Alımları Resmî Başvuru Bağlantıları:**\n\n"
                "• **ÖSYM İşlemleri:** https://ais.osym.gov.tr\n"
                "• **MSB Personel Temin:** https://personeltemin.msb.gov.tr\n"
                "• **Jandarma PTM:** https://vatandas.jandarma.gov.tr/PTM/Giris\n"
                "• **Polis Akademisi:** https://www.pa.edu.tr\n"
                "• **Kariyer Kapısı (Cumhurbaşkanlığı):** https://kariyerkapisi.cbiko.gov.tr\n\n"
                "📌 Bu linklerden dilediğini kopyalayıp KamuRadar **Özel Linkler** sekmesine yapıştırabilirsin. Sistem her gün saat 12:00'de değişiklikleri tarar!"
            )

        # Genel Yanıt
        return (
            "🤖 **RadarAI Kamu Danışmanı:**\n\n"
            f"Sorunuzu analiz ettim: '{message}'.\n"
            "Belirttiğiniz unvan veya kurum için alım koşulları Resmî Gazete ve ilgili kurumun personel temin sayfasında duyurulur.\n\n"
            "• **Öneri:** Takip etmek istediğiniz kurumun resmî duyuru sayfasını KamuRadar'ın **Özel Linkler** sekmesine ekleyebilir, her gün 12:00'de otomatik taranmasını sağlayabilirsiniz.\n"
            "• Resmî Kariyer Portalı: https://kariyerkapisi.cbiko.gov.tr"
        )
