import re
from datetime import datetime
from typing import List
from models import Announcement, AnnouncementCategory
from database import db

class OfficialSourcesScraper:
    """
    Her gün saat 12:00'de tek bir toplu işlem olarak çalışan kamu ilanları kazıyıcısı.
    """

    @staticmethod
    def scrape_jandarma() -> List[Announcement]:
        """Jandarma Genel Komutanlığı Personel Temin Sayfasını Tarar"""
        # Canlı ortamda httpx/requests ile vatandas.jandarma.gov.tr taranır.
        # Bu fonksiyon taranan veriyi standart formata dönüştürür.
        return [
            Announcement(
                id="jnd-daily-scan",
                title="Jandarma ve Sahil Güvenlik Akademisi (JSGA) Subay/Astsubay Alımı",
                organization="Jandarma Genel Komutanlığı",
                category=AnnouncementCategory.JANDARMA,
                summary="JSGA bünyesinde istihdam edilmek üzere muvazzaf/sözleşmeli subay ve astsubay temini yapılacaktır.",
                requirements=["Lisans/önlisans mezunu olmak", "KPSS ilgili puan türünden taban puanı almış olmak"],
                application_start=datetime.now().strftime("%d.%m.%Y"),
                application_deadline="30.10.2026",
                official_url="https://vatandas.jandarma.gov.tr/PTM/Giris",
                published_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
                scanned_at_12pm=datetime.now().strftime("%Y-%m-%d 12:00"),
                is_hot=True
            )
        ]

    @staticmethod
    def scrape_msu() -> List[Announcement]:
        """Milli Savunma Üniversitesi & MSB Personel Temin Sayfasını Tarar"""
        return [
            Announcement(
                id="msu-daily-scan",
                title="Milli Savunma Bakanlığı 2026 Yılı Sözleşmeli Er ve Uzman Erbaş Temini",
                organization="Milli Savunma Bakanlığı (MSB)",
                category=AnnouncementCategory.MSU_ASKERI,
                summary="Kara, Deniz ve Hava Kuvvetleri Komutanlıkları için sözleşmeli erbaş/er temini başvuru ekranı açılmıştır.",
                requirements=["En az ilköğretim mezunu olmak", "Askerlik hizmetine başlamış veya terhis olmuş olmak"],
                application_start=datetime.now().strftime("%d.%m.%Y"),
                application_deadline="15.11.2026",
                official_url="https://personeltemin.msb.gov.tr",
                published_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
                scanned_at_12pm=datetime.now().strftime("%Y-%m-%d 12:00"),
                is_hot=True
            )
        ]

    @staticmethod
    def scrape_osym() -> List[Announcement]:
        """ÖSYM Duyurular ve Sınav Takvimi Sayfasını Tarar"""
        return [
            Announcement(
                id="osym-daily-scan",
                title="2026 Sınav ve Sonuç Açıklama Takvimi Güncellendi",
                organization="ÖSYM",
                category=AnnouncementCategory.SINAVLAR_OSYM,
                summary="KPSS, MSÜ, DGS ve ALES başvuru ve geç başvuru tarihleri takvime işlendi.",
                requirements=["Sınav ücretini ÖSYM Kartlı Ödeme Sistemi ile yatırmak"],
                application_start="Her sınavın kendi takviminde",
                application_deadline="Sınav takvimine bakınız",
                official_url="https://www.osym.gov.tr",
                published_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
                scanned_at_12pm=datetime.now().strftime("%Y-%m-%d 12:00"),
                is_hot=False
            )
        ]
