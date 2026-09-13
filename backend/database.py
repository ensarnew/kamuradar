from typing import List, Optional, Dict
from models import (
    Announcement, AnnouncementCategory, CustomUrlWatcher,
    FamilyPlan, FamilyMember, ExamScheduleItem, ExamStatus
)

class InMemoryDB:
    def __init__(self):
        self.announcements: Dict[str, Announcement] = {}
        self.exam_schedules: List[ExamScheduleItem] = []
        self.custom_watchers: Dict[str, CustomUrlWatcher] = {}
        self.family_plans: Dict[str, FamilyPlan] = {}  # invite_code -> FamilyPlan
        self.user_plans: Dict[str, str] = {}           # user_id -> invite_code (hangi planda olduğu)
        self.users_premium: Dict[str, bool] = {}       # user_id -> is_premium
        self._seed_initial_data()

    def _seed_initial_data(self):
        # 1. Tam 20 Adet Sınav ve Başvuru/Sonuç Takvimi
        self.exam_schedules = [
            ExamScheduleItem(
                id="exam-01",
                title="2026-KPSS Lisans (GY-GK & Eğitim Bilimleri) Başvuruları",
                organization="ÖSYM",
                application_dates="06.05.2026 - 20.05.2026",
                exam_date="19.07.2026",
                result_date="28.08.2026",
                status=ExamStatus.UPCOMING,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-02",
                title="2026-KPSS Lisans Sınavı & Alan Bilgisi Sonuçları",
                organization="ÖSYM",
                application_dates="Geç Başvuru: 27.05.2026",
                exam_date="26.07.2026",
                result_date="28.08.2026",
                status=ExamStatus.UPCOMING,
                official_url="https://sonuc.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-03",
                title="2026-KPSS Önlisans Başvuru ve Sınav Takvimi",
                organization="ÖSYM",
                application_dates="13.06.2026 - 02.07.2026",
                exam_date="06.09.2026",
                result_date="02.10.2026",
                status=ExamStatus.UPCOMING,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-04",
                title="2026-KPSS Önlisans Sınav Sonuçları Açıklanması",
                organization="ÖSYM",
                application_dates="Geç Başvuru: 09.07.2026",
                exam_date="06.09.2026",
                result_date="02.10.2026",
                status=ExamStatus.UPCOMING,
                official_url="https://sonuc.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-05",
                title="2026-KPSS Ortaöğretim (Lise Düzeyi) Başvuruları",
                organization="ÖSYM",
                application_dates="18.07.2026 - 05.08.2026",
                exam_date="04.10.2026",
                result_date="30.10.2026",
                status=ExamStatus.UPCOMING,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-06",
                title="2026-KPSS Ortaöğretim Sınav Sonuçları Açıklanması",
                organization="ÖSYM",
                application_dates="Geç Başvuru: 12.08.2026",
                exam_date="04.10.2026",
                result_date="30.10.2026",
                status=ExamStatus.UPCOMING,
                official_url="https://sonuc.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-07",
                title="2026-MSÜ Askeri Öğrenci Aday Belirleme Sınavı Başvurusu",
                organization="ÖSYM & MSB",
                application_dates="03.01.2026 - 30.01.2026",
                exam_date="08.03.2026",
                result_date="02.04.2026",
                status=ExamStatus.ACTIVE,
                official_url="https://personeltemin.msb.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-08",
                title="2026-MSÜ Harp Okulları & Astsubay MYO Mülakat Sonuçları",
                organization="Milli Savunma Bakanlığı (MSB)",
                application_dates="Seçim Aşamaları: 25.06.2026 - 20.07.2026",
                exam_date=None,
                result_date="15.08.2026",
                status=ExamStatus.ANNOUNCED,
                official_url="https://personeltemin.msb.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-09",
                title="EGM Polis Akademisi 32. Dönem POMEM Polis Alımı Başvuruları",
                organization="Polis Akademisi Başkanlığı",
                application_dates="20.09.2026 - 05.10.2026",
                exam_date="Ön Sağlık: 15.10.2026",
                result_date="25.11.2026",
                status=ExamStatus.ACTIVE,
                official_url="https://www.pa.edu.tr"
            ),
            ExamScheduleItem(
                id="exam-10",
                title="EGM 32. Dönem POMEM Fiziki Parkur ve Mülakat Sonuçları",
                organization="Polis Akademisi Başkanlığı",
                application_dates="Fiziki Parkur: 01.11.2026",
                exam_date=None,
                result_date="25.11.2026",
                status=ExamStatus.ACTIVE,
                official_url="https://www.pa.edu.tr"
            ),
            ExamScheduleItem(
                id="exam-11",
                title="PMYO Polis Meslek Yüksekokulu Başvuru & Taban Puanları",
                organization="Polis Akademisi Başkanlığı",
                application_dates="25.07.2026 - 10.08.2026",
                exam_date="TYT Barajı",
                result_date="05.09.2026",
                status=ExamStatus.UPCOMING,
                official_url="https://www.pa.edu.tr"
            ),
            ExamScheduleItem(
                id="exam-12",
                title="Jandarma JSGA Subay ve Astsubay Temini Başvuru Takvimi",
                organization="Jandarma Genel Komutanlığı",
                application_dates="15.09.2026 - 05.10.2026",
                exam_date="Fiziki Parkur: 20.10.2026",
                result_date="10.11.2026",
                status=ExamStatus.ACTIVE,
                official_url="https://vatandas.jandarma.gov.tr/PTM/Giris"
            ),
            ExamScheduleItem(
                id="exam-13",
                title="Jandarma 2.500 Uzman Erbaş Alımı Başvuruları ve Parkur",
                organization="Jandarma Genel Komutanlığı",
                application_dates="10.09.2026 - 28.09.2026",
                exam_date="Ön Kontrol: 12.10.2026",
                result_date="02.11.2026",
                status=ExamStatus.ACTIVE,
                official_url="https://vatandas.jandarma.gov.tr/PTM/Giris"
            ),
            ExamScheduleItem(
                id="exam-14",
                title="EGM Çarşı ve Mahalle Bekçiliği Alımı ve Mülakat Takvimi",
                organization="Polis Akademisi Başkanlığı",
                application_dates="05.10.2026 - 22.10.2026",
                exam_date="Yazılı Sınav: 15.11.2026",
                result_date="10.12.2026",
                status=ExamStatus.UPCOMING,
                official_url="https://www.pa.edu.tr"
            ),
            ExamScheduleItem(
                id="exam-15",
                title="Adalet Bakanlığı 5.400 İKM, Zabıt Katibi & Mübaşir Alımı",
                organization="Adalet Bakanlığı (PGM)",
                application_dates="25.09.2026 - 12.10.2026",
                exam_date="Klavye Uygulama: 24.10.2026",
                result_date="20.11.2026",
                status=ExamStatus.ACTIVE,
                official_url="https://pgm.adalet.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-16",
                title="Sağlık Bakanlığı 18.000 Sözleşmeli Personel & İşçi Alımı",
                organization="Sağlık Bakanlığı (YHGM)",
                application_dates="22.09.2026 - 08.10.2026",
                exam_date="KPSS Merkezi Yerleştirme",
                result_date="18.10.2026",
                status=ExamStatus.ACTIVE,
                official_url="https://yhgm.saglik.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-17",
                title="MEB 20.000 Sözleşmeli Öğretmen Ataması ve Tercih Dönemi",
                organization="Milli Eğitim Bakanlığı",
                application_dates="10.10.2026 - 25.10.2026",
                exam_date="Mülakat Süreci: 05.11.2026",
                result_date="30.11.2026",
                status=ExamStatus.UPCOMING,
                official_url="https://personel.meb.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-18",
                title="2026-DGS Dikey Geçiş Sınavı Başvuru & Tercih Sonuçları",
                organization="ÖSYM",
                application_dates="10.05.2026 - 25.05.2026",
                exam_date="05.07.2026",
                result_date="11.08.2026",
                status=ExamStatus.UPCOMING,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-19",
                title="2026-ALES / 1 ve ALES / 2 Akademik Sınav & Sonuç Takvimi",
                organization="ÖSYM",
                application_dates="01.03.2026 - 15.03.2026",
                exam_date="26.04.2026",
                result_date="15.05.2026",
                status=ExamStatus.UPCOMING,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="exam-20",
                title="GSB Yurt Yönetim Personeli & Gençlik Lideri Alımları",
                organization="Gençlik ve Spor Bakanlığı",
                application_dates="15.10.2026 - 30.10.2026",
                exam_date="Sözlü Sınav: 15.11.2026",
                result_date="05.12.2026",
                status=ExamStatus.UPCOMING,
                official_url="https://pgm.gsb.gov.tr"
            )
        ]


        # 2. Açık İlanlar (İlk 4 tanesi ÜCRETSİZ açık, kalanlar sadece PREMIUM üyeler için açık!)
        seed_announcements = [
            # İlan 1 (Açık - Ücretsiz)
            Announcement(
                id="jnd-2026-01",
                title="Jandarma Genel Komutanlığı 2.500 Uzman Erbaş Alımı",
                organization="Jandarma Genel Komutanlığı",
                category=AnnouncementCategory.JANDARMA,
                summary="Asayiş, komando ve sıhhiye branşlarında en az lise mezunu 2.500 uzman erbaş alımı.",
                requirements=["T.C. vatandaşı ve erkek olmak", "Lise mezunu olmak", "27 yaşını aşmamış olmak"],
                application_start="10.09.2026",
                application_deadline="28.09.2026",
                official_url="https://vatandas.jandarma.gov.tr/PTM/Giris",
                published_at="2026-09-10 10:00",
                scanned_at_12pm="2026-09-13 12:00",
                is_hot=True,
                is_premium_only=False
            ),
            # İlan 2 (Açık - Ücretsiz)
            Announcement(
                id="msu-2026-02",
                title="Milli Savunma Üniversitesi Askeri Öğrenci Belirleme ve Başvuru Kılavuzu",
                organization="Milli Savunma Bakanlığı (MSÜ)",
                category=AnnouncementCategory.MSU_ASKERI,
                summary="Harp Okulları ve Astsubay MYO askeri öğrenci temin süreci başladı.",
                requirements=["En fazla 20 yaşında olmak", "MSÜ sınavına katılmış olmak"],
                application_start="01.10.2026",
                application_deadline="25.10.2026",
                official_url="https://personeltemin.msb.gov.tr",
                published_at="2026-09-12 11:30",
                scanned_at_12pm="2026-09-13 12:00",
                is_hot=True,
                is_premium_only=False
            ),
            # İlan 3 (Açık - Ücretsiz)
            Announcement(
                id="osym-2026-03",
                title="2026-KPSS B Grubu Kadrolar Merkezi Tercih Kılavuzu",
                organization="ÖSYM & Kariyer Kapısı",
                category=AnnouncementCategory.KAMU_MEMUR,
                summary="Kamu kurumlarına B grubu lisans ve önlisans memur alımları tercih kılavuzu.",
                requirements=["En az 65/70 KPSS puanı", "657 Sayılı Kanunun 48. maddesi şartları"],
                application_start="15.09.2026",
                application_deadline="30.09.2026",
                official_url="https://ais.osym.gov.tr",
                published_at="2026-09-13 09:15",
                scanned_at_12pm="2026-09-13 12:00",
                is_hot=False,
                is_premium_only=False
            ),
            # İlan 4 (Açık - Ücretsiz)
            Announcement(
                id="pomem-2026-04",
                title="EGM 32. Dönem POMEM 10.000 Polis Memuru Alımı",
                organization="Polis Akademisi Başkanlığı",
                category=AnnouncementCategory.POLIS_POMEM,
                summary="8.000 lisans, 2.000 önlisans toplam 10.000 polis memuru alımı.",
                requirements=["KPSS P3 en az 60, P93 en az 65", "30 yaşından gün almamış olmak"],
                application_start="20.09.2026",
                application_deadline="05.10.2026",
                official_url="https://www.pa.edu.tr",
                published_at="2026-09-08 14:00",
                scanned_at_12pm="2026-09-13 12:00",
                is_hot=True,
                is_premium_only=False
            ),
            # İlan 5 (🔒 Sadece Premium)
            Announcement(
                id="saglik-2026-05",
                title="Sağlık Bakanlığı 18.000 Sözleşmeli Sağlık Personeli ve İşçi Alımı",
                organization="Sağlık Bakanlığı",
                category=AnnouncementCategory.SOZLESMELI,
                summary="Hemşire, ebe, sağlık teknikeri ve destek personeli branşlarında 18.000 alım.",
                requirements=["İlgili sağlık önlisans/lisans mezuniyeti", "KPSS ilgili puan türü"],
                application_start="22.09.2026",
                application_deadline="08.10.2026",
                official_url="https://yhgm.saglik.gov.tr",
                published_at="2026-09-13 08:30",
                scanned_at_12pm="2026-09-13 12:00",
                is_hot=True,
                is_premium_only=True
            ),
            # İlan 6 (🔒 Sadece Premium)
            Announcement(
                id="adalet-2026-06",
                title="Adalet Bakanlığı 5.400 Zabıt Katibi, İnfaz Koruma Memuru (İKM) Alımı",
                organization="Adalet Bakanlığı",
                category=AnnouncementCategory.KAMU_MEMUR,
                summary="Cezaevlerine ve adliyelere İKM, zabıt katibi ve mübaşir istihdamı.",
                requirements=["En az lise mezunu olmak", "Zabıt katipliği için klavye uygulama sınavı", "KPSS en az 70 puan"],
                application_start="25.09.2026",
                application_deadline="12.10.2026",
                official_url="https://pgm.adalet.gov.tr",
                published_at="2026-09-12 16:00",
                scanned_at_12pm="2026-09-13 12:00",
                is_hot=False,
                is_premium_only=True
            ),
            # İlan 7 (🔒 Sadece Premium)
            Announcement(
                id="msb-er-2026-07",
                title="Milli Savunma Bakanlığı 2026 Yılı Sözleşmeli Er Temini",
                organization="Milli Savunma Bakanlığı (MSB)",
                category=AnnouncementCategory.MSU_ASKERI,
                summary="Kara, Deniz ve Hava Kuvvetleri Komutanlıklarına sözleşmeli erbaş ve er temini.",
                requirements=["En az ilköğretim mezunu olmak", "25 yaşını bitirmemiş olmak"],
                application_start="15.09.2026",
                application_deadline="20.10.2026",
                official_url="https://personeltemin.msb.gov.tr",
                published_at="2026-09-11 14:00",
                scanned_at_12pm="2026-09-13 12:00",
                is_hot=False,
                is_premium_only=True
            ),
            # İlan 8 (🔒 Sadece Premium)
            Announcement(
                id="belediye-2026-08",
                title="Ankara Büyükşehir Belediyesi 300 Zabıta ve İtfaiye Eri Alımı",
                organization="Ankara Büyükşehir Belediyesi",
                category=AnnouncementCategory.KAMU_MEMUR,
                summary="Zabıta ve itfaiye teşkilatında istihdam edilmek üzere önlisans mezunu memur alımı.",
                requirements=["En az B sınıfı sürücü belgesi", "KPSS P93 en az 65 puan", "Fiziki boy ve kilo şartları"],
                application_start="28.09.2026",
                application_deadline="10.10.2026",
                official_url="https://www.ankara.bel.tr",
                published_at="2026-09-13 10:00",
                scanned_at_12pm="2026-09-13 12:00",
                is_hot=False,
                is_premium_only=True
            )
        ]

        for a in seed_announcements:
            self.announcements[a.id] = a

db = InMemoryDB()
