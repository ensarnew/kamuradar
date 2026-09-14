from typing import List, Optional, Dict, Set
from datetime import datetime
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
        self.user_plans: Dict[str, str] = {}           # user_id -> invite_code
        self.users_premium: Dict[str, bool] = {}       # user_id -> is_premium
        self.user_subscriptions: Dict[str, str] = {}   # user_id -> plan_type ('ad_free', 'monthly_vip', 'yearly_vip')
        self.user_alarms: Dict[str, Set[str]] = {}     # user_id -> set of channel_ids
        self._seed_initial_data()

    def _seed_initial_data(self):
        # 54 Adet Canlı Kamu ve KPSS Sınav/Alım Takvimi
        self.exam_schedules = [
            ExamScheduleItem(
                id="saglik-01",
                category="kamu_memur",
                title="36.000 Sözleşmeli Sağlık Personeli ve İşçi Alımı",
                organization="Sağlık Bakanlığı",
                application_dates="08.09.2026 - 25.09.2026",
                start_date="2026-09-08",
                end_date="2026-09-25",
                status=ExamStatus.ACTIVE,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="polis-01",
                category="polis_pomem",
                title="32. Dönem POMEM 10.000 Polis Memuru Alımı",
                organization="Polis Akademisi",
                application_dates="05.09.2026 - 22.09.2026",
                start_date="2026-09-05",
                end_date="2026-09-22",
                status=ExamStatus.ACTIVE,
                official_url="https://pa.edu.tr"
            ),
            ExamScheduleItem(
                id="adalet-01",
                category="kamu_memur",
                title="12.500 Zabıt Katibi, Mübaşir ve İnfaz Koruma Memuru (İKM)",
                organization="Adalet Bakanlığı",
                application_dates="10.09.2026 - 28.09.2026",
                start_date="2026-09-10",
                end_date="2026-09-28",
                status=ExamStatus.ACTIVE,
                official_url="https://pgm.adalet.gov.tr"
            ),
            ExamScheduleItem(
                id="jandarma-01",
                category="jandarma",
                title="6.500 Sözleşmeli Uzman Erbaş ve Jandarma Asayiş Alımı",
                organization="Jandarma Genel Komutanlığı",
                application_dates="07.09.2026 - 24.09.2026",
                start_date="2026-09-07",
                end_date="2026-09-24",
                status=ExamStatus.ACTIVE,
                official_url="https://vatandas.jandarma.gov.tr"
            ),
            ExamScheduleItem(
                id="polis-bekci",
                category="polis_pomem",
                title="Çarşı ve Mahalle Bekçiliği 3.200 Kontenjan Başvurusu",
                organization="Emniyet Genel Müdürlüğü",
                application_dates="05.09.2026 - 22.09.2026",
                start_date="2026-09-05",
                end_date="2026-09-22",
                status=ExamStatus.ACTIVE,
                official_url="https://pa.edu.tr"
            ),
            ExamScheduleItem(
                id="gib-guy",
                category="kamu_memur",
                title="1.271 Gelir Uzman Yardımcısı (GUY) Giriş Sınavı",
                organization="Gelir İdaresi Başkanlığı",
                application_dates="01.09.2026 - 20.09.2026",
                start_date="2026-09-01",
                end_date="2026-09-20",
                status=ExamStatus.ACTIVE,
                official_url="https://gib.gov.tr"
            ),
            ExamScheduleItem(
                id="sayistay-01",
                category="sinavlar_osym",
                title="2026-Sayıştay Denetçi Yardımcılığı Eleme Sınavı",
                organization="ÖSYM • Sayıştay",
                application_dates="01.09.2026 - 18.09.2026",
                start_date="2026-09-01",
                end_date="2026-09-18",
                status=ExamStatus.ACTIVE,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="msb-er",
                category="msu_askeri",
                title="Kara ve Hava Kuvvetleri 8.000 Sözleşmeli Er Temini",
                organization="Milli Savunma Bakanlığı",
                application_dates="01.09.2026 - 25.09.2026",
                start_date="2026-09-01",
                end_date="2026-09-25",
                status=ExamStatus.ACTIVE,
                official_url="https://personeltemin.msb.gov.tr"
            ),
            ExamScheduleItem(
                id="meb-ogretmen",
                category="kamu_memur",
                title="20.000 Sözleşmeli Öğretmenlik Tercih ve Sözlü Sınavı",
                organization="Milli Eğitim Bakanlığı",
                application_dates="06.09.2026 - 21.09.2026",
                start_date="2026-09-06",
                end_date="2026-09-21",
                status=ExamStatus.ACTIVE,
                official_url="https://ilkatama.meb.gov.tr"
            ),
            ExamScheduleItem(
                id="iskur-typ-okul",
                category="kamu_memur",
                title="Toplum Yararına Program (TYP) 40.000 Okul Güvenlik & Temizlik",
                organization="İŞKUR • MEB",
                application_dates="09.09.2026 - 23.09.2026",
                start_date="2026-09-09",
                end_date="2026-09-23",
                status=ExamStatus.ACTIVE,
                official_url="https://esube.iskur.gov.tr"
            ),
            ExamScheduleItem(
                id="gsb-yurt",
                category="kamu_memur",
                title="1.500 Yurt Yönetim Personeli ve Destek Elemanı Alımı",
                organization="Gençlik ve Spor Bakanlığı",
                application_dates="11.09.2026 - 26.09.2026",
                start_date="2026-09-11",
                end_date="2026-09-26",
                status=ExamStatus.ACTIVE,
                official_url="https://isealimkariyerkapisi.cbiko.gov.tr"
            ),
            ExamScheduleItem(
                id="belediye-zbt",
                category="kamu_memur",
                title="İBB, ABB ve İZBB 1.800 Zabıta Memuru ve İtfaiye Eri Alımı",
                organization="Büyükşehir Belediyeleri",
                application_dates="08.09.2026 - 22.09.2026",
                start_date="2026-09-08",
                end_date="2026-09-22",
                status=ExamStatus.ACTIVE,
                official_url="https://turkiye.gov.tr"
            ),
            ExamScheduleItem(
                id="osym-dhbt",
                category="sinavlar_osym",
                title="2026-KPSS Din Hizmetleri Alan Bilgisi (DHBT) Başvuruları",
                organization="ÖSYM",
                application_dates="01.10.2026 - 15.10.2026",
                start_date="2026-10-01",
                end_date="2026-10-15",
                status=ExamStatus.UPCOMING,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="kaymakam-01",
                category="kamu_memur",
                title="2026 Yılı 113. Dönem Kaymakam Adaylığı Giriş Sınavı",
                organization="İçişleri Bakanlığı",
                application_dates="08.10.2026 - 22.10.2026",
                start_date="2026-10-08",
                end_date="2026-10-22",
                status=ExamStatus.UPCOMING,
                official_url="https://icisleri.gov.tr"
            ),
            ExamScheduleItem(
                id="hakim-savci-01",
                category="sinavlar_osym",
                title="2026-Adli ve İdari Yargı Hakim & Savcı Yardımcılığı Sınavı",
                organization="Adalet Bakanlığı • ÖSYM",
                application_dates="15.10.2026 - 30.10.2026",
                start_date="2026-10-15",
                end_date="2026-10-30",
                status=ExamStatus.UPCOMING,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="msb-deniz-01",
                category="msu_askeri",
                title="Deniz Kuvvetleri 2.500 Sözleşmeli Er ve Dalgıç Temini",
                organization="Milli Savunma Bakanlığı",
                application_dates="05.10.2026 - 25.10.2026",
                start_date="2026-10-05",
                end_date="2026-10-25",
                status=ExamStatus.UPCOMING,
                official_url="https://personeltemin.msb.gov.tr"
            ),
            ExamScheduleItem(
                id="paem-01",
                category="polis_pomem",
                title="PAEM 8. Dönem Emniyet Mensubu Olmayan Komiser Yardımcısı",
                organization="Polis Akademisi",
                application_dates="12.10.2026 - 28.10.2026",
                start_date="2026-10-12",
                end_date="2026-10-28",
                status=ExamStatus.UPCOMING,
                official_url="https://pa.edu.tr"
            ),
            ExamScheduleItem(
                id="jandarma-subay-01",
                category="jandarma",
                title="2026 Yılı Muvazzaf/Sözleşmeli Subay ve Astsubay Alımı",
                organization="Jandarma ve Sahil Güvenlik",
                application_dates="16.10.2026 - 05.11.2026",
                start_date="2026-10-16",
                end_date="2026-11-05",
                status=ExamStatus.UPCOMING,
                official_url="https://vatandas.jandarma.gov.tr"
            ),
            ExamScheduleItem(
                id="dsi-muhendis-01",
                category="kamu_memur",
                title="DSİ 1.253 Sözleşmeli Mühendis, Mimar ve Şehir Plancısı Alımı",
                organization="Devlet Su İşleri (DSİ)",
                application_dates="20.10.2026 - 06.11.2026",
                start_date="2026-10-20",
                end_date="2026-11-06",
                status=ExamStatus.UPCOMING,
                official_url="https://dsi.gov.tr"
            ),
            ExamScheduleItem(
                id="karayollari-01",
                category="kamu_memur",
                title="KGM 850 Düz İşçi, Asfalt ve Operatör Kadrosu Temini",
                organization="Karayolları Genel Müdürlüğü (KGM)",
                application_dates="24.10.2026 - 10.11.2026",
                start_date="2026-10-24",
                end_date="2026-11-10",
                status=ExamStatus.UPCOMING,
                official_url="https://kgm.gov.tr"
            ),
            ExamScheduleItem(
                id="sgk-denetmen-01",
                category="kamu_memur",
                title="500 Sosyal Güvenlik Denetmen Yardımcısı Alımı",
                organization="Sosyal Güvenlik Kurumu (SGK)",
                application_dates="01.11.2026 - 18.11.2026",
                start_date="2026-11-01",
                end_date="2026-11-18",
                status=ExamStatus.UPCOMING,
                official_url="https://sgk.gov.tr"
            ),
            ExamScheduleItem(
                id="gumruk-muhafaza-01",
                category="kamu_memur",
                title="1.500 Gümrük Muhafaza Memuru ve Muayene Memuru Alımı",
                organization="Ticaret Bakanlığı",
                application_dates="05.11.2026 - 22.11.2026",
                start_date="2026-11-05",
                end_date="2026-11-22",
                status=ExamStatus.UPCOMING,
                official_url="https://ticaret.gov.tr"
            ),
            ExamScheduleItem(
                id="aile-bakanligi-01",
                category="kamu_memur",
                title="2.400 ASDEP ve Sosyal Hizmet Uzmanı Sözleşmeli Alımı",
                organization="Aile ve Sosyal Hizmetler Bakanlığı",
                application_dates="10.11.2026 - 28.11.2026",
                start_date="2026-11-10",
                end_date="2026-11-28",
                status=ExamStatus.UPCOMING,
                official_url="https://aile.gov.tr"
            ),
            ExamScheduleItem(
                id="osym-yds-sonbahar",
                category="sinavlar_osym",
                title="2026-YDS/2 Yabancı Dil Bilgisi Seviye Tespit Sınavı",
                organization="ÖSYM",
                application_dates="12.10.2026 - 24.10.2026",
                start_date="2026-10-12",
                end_date="2026-10-24",
                status=ExamStatus.UPCOMING,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="osym-ales-sonbahar",
                category="sinavlar_osym",
                title="2026-ALES/3 Akademik Personel ve Lisansüstü Eğitimi Sınavı",
                organization="ÖSYM",
                application_dates="21.10.2026 - 04.11.2026",
                start_date="2026-10-21",
                end_date="2026-11-04",
                status=ExamStatus.UPCOMING,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="tcdd-personel-01",
                category="kamu_memur",
                title="450 Tren Makinisti ve Demiryolu Hat Bakım Onarımcısı",
                organization="TCDD Taşımacılık A.Ş.",
                application_dates="02.11.2026 - 16.11.2026",
                start_date="2026-11-02",
                end_date="2026-11-16",
                status=ExamStatus.UPCOMING,
                official_url="https://tcddtasimacilik.gov.tr"
            ),
            ExamScheduleItem(
                id="osym-kpss-l-res",
                category="sinavlar_osym",
                title="2026-KPSS Lisans & Alan Bilgisi Nihai Sonuçları",
                organization="ÖSYM • Sonuç",
                application_dates="Sonuç Tarihi: 28.08.2026",
                start_date="2026-08-28",
                end_date="2026-08-28",
                status=ExamStatus.COMPLETED,
                official_url="https://sonuc.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="osym-kpss-onlisans-res",
                category="sinavlar_osym",
                title="2026-KPSS Önlisans Sınav Sonuç Takvimi",
                organization="ÖSYM • Sonuç",
                application_dates="Sonuç: 20.09.2026 Saat 10:00",
                start_date="2026-09-20",
                end_date="2026-09-20",
                status=ExamStatus.UPCOMING,
                official_url="https://sonuc.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="osym-yks-ek-res",
                category="sinavlar_osym",
                title="2026-YKS Üniversite Ek Yerleştirme Sonuçları",
                organization="ÖSYM • Sonuç",
                application_dates="Sonuç Tarihi: 12.09.2026",
                start_date="2026-09-12",
                end_date="2026-09-12",
                status=ExamStatus.COMPLETED,
                official_url="https://sonuc.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="polis-pmyo-res",
                category="polis_pomem",
                title="2026 PMYO Polis Meslek Yüksekokulu Giriş Sınavı Sonuçları",
                organization="Polis Akademisi • Sonuç",
                application_dates="Sonuç Tarihi: 04.09.2026",
                start_date="2026-09-04",
                end_date="2026-09-04",
                status=ExamStatus.COMPLETED,
                official_url="https://pa.edu.tr"
            ),
            ExamScheduleItem(
                id="msu-tercih-res",
                category="msu_askeri",
                title="2026 MSÜ Harp Okulları & Astsubay MYO Ek Yerleştirme",
                organization="Milli Savunma Bakanlığı • Sonuç",
                application_dates="Sonuç: 18.09.2026",
                start_date="2026-09-18",
                end_date="2026-09-18",
                status=ExamStatus.UPCOMING,
                official_url="https://personeltemin.msb.gov.tr"
            ),
            ExamScheduleItem(
                id="adli-tip-res",
                category="kamu_memur",
                title="Adli Tıp Kurumu Merkez ve Taşra Personel Alımı Nihai Sonuçları",
                organization="Adli Tıp Kurumu • Sonuç",
                application_dates="Sonuç Tarihi: 02.09.2026",
                start_date="2026-09-02",
                end_date="2026-09-02",
                status=ExamStatus.COMPLETED,
                official_url="https://atk.gov.tr"
            ),
            ExamScheduleItem(
                id="meb-ekys-res",
                category="sinavlar_osym",
                title="2026-MEB-EKYS Eğitim Kurumlarına Yönetici Seçme Sonuçları",
                organization="ÖSYM • Sonuç",
                application_dates="Sonuç Tarihi: 15.08.2026",
                start_date="2026-08-15",
                end_date="2026-08-15",
                status=ExamStatus.COMPLETED,
                official_url="https://sonuc.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="osym-dus-res",
                category="sinavlar_osym",
                title="2026-DUS Diş Hekimliğinde Uzmanlık Eğitimi Sınavı Sonuçları",
                organization="ÖSYM • Sonuç",
                application_dates="Sonuç Tarihi: 10.08.2026",
                start_date="2026-08-10",
                end_date="2026-08-10",
                status=ExamStatus.COMPLETED,
                official_url="https://sonuc.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="osym-tus-res",
                category="sinavlar_osym",
                title="2026-TUS Tıpta Uzmanlık Eğitimi Giriş Sınavı 2. Dönem Sonuçları",
                organization="ÖSYM • Sonuç",
                application_dates="Sonuç: 25.09.2026",
                start_date="2026-09-25",
                end_date="2026-09-25",
                status=ExamStatus.UPCOMING,
                official_url="https://sonuc.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="cezaevi-ikm-boykilo-res",
                category="kamu_memur",
                title="İKM Boy-Kilo Ölçümü ve Mülakata Hak Kazananlar Listesi",
                organization="Adalet Bakanlığı • CTE",
                application_dates="Sonuç Tarihi: 07.09.2026",
                start_date="2026-09-07",
                end_date="2026-09-07",
                status=ExamStatus.COMPLETED,
                official_url="https://cte.adalet.gov.tr"
            ),
            ExamScheduleItem(
                id="vakiflar-res",
                category="kamu_memur",
                title="VGM Sözleşmeli Koruma ve Güvenlik Görevlisi Alım Sonuçları",
                organization="Vakıflar Genel Müdürlüğü",
                application_dates="Sonuç Tarihi: 01.09.2026",
                start_date="2026-09-01",
                end_date="2026-09-01",
                status=ExamStatus.COMPLETED,
                official_url="https://vgm.gov.tr"
            ),
            ExamScheduleItem(
                id="jandarma-uzm-yedek-res",
                category="jandarma",
                title="2026 Yılı Jandarma Uzman Erbaş 2. Yedek Çağrı Sonuçları",
                organization="Jandarma • Sonuç",
                application_dates="Sonuç Tarihi: 08.09.2026",
                start_date="2026-09-08",
                end_date="2026-09-08",
                status=ExamStatus.COMPLETED,
                official_url="https://vatandas.jandarma.gov.tr"
            ),
            ExamScheduleItem(
                id="osym-kpss-lisans",
                category="sinavlar_osym",
                title="2026-KPSS Lisans (GY-GK & Eğitim Bilimleri) Başvuruları",
                organization="ÖSYM",
                application_dates="06.05.2026 - 20.05.2026 (Sona Erdi)",
                start_date="2026-05-06",
                end_date="2026-05-20",
                status=ExamStatus.COMPLETED,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="osym-kpss-onlisans-b",
                category="sinavlar_osym",
                title="2026-KPSS Önlisans Başvuru Takvimi",
                organization="ÖSYM",
                application_dates="13.06.2026 - 02.07.2026 (Sona Erdi)",
                start_date="2026-06-13",
                end_date="2026-07-02",
                status=ExamStatus.COMPLETED,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="osym-kpss-ortaogretim-b",
                category="sinavlar_osym",
                title="2026-KPSS Ortaöğretim (Lise Düzeyi) Başvuruları",
                organization="ÖSYM",
                application_dates="18.07.2026 - 30.07.2026 (Sona Erdi)",
                start_date="2026-07-18",
                end_date="2026-07-30",
                status=ExamStatus.COMPLETED,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="osym-yks-2026",
                category="sinavlar_osym",
                title="2026-YKS Yükseköğretim Kurumları Sınavı Başvuruları",
                organization="ÖSYM",
                application_dates="01.02.2026 - 26.02.2026 (Sona Erdi)",
                start_date="2026-02-01",
                end_date="2026-02-26",
                status=ExamStatus.COMPLETED,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="msu-2026-sinav",
                category="msu_askeri",
                title="2026-MSÜ Askeri Öğrenci Belirleme Sınavı Başvuruları",
                organization="ÖSYM • MSÜ",
                application_dates="03.01.2026 - 30.01.2026 (Sona Erdi)",
                start_date="2026-01-03",
                end_date="2026-01-30",
                status=ExamStatus.COMPLETED,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="polis-pmyo-2026-b",
                category="polis_pomem",
                title="2026 PMYO 2.500 Polis Öğrenci Alımı Başvuruları",
                organization="Polis Akademisi",
                application_dates="15.07.2026 - 29.07.2026 (Sona Erdi)",
                start_date="2026-07-15",
                end_date="2026-07-29",
                status=ExamStatus.COMPLETED,
                official_url="https://pa.edu.tr"
            ),
            ExamScheduleItem(
                id="saglik-2026-1",
                category="kamu_memur",
                title="Sağlık Bakanlığı 2026/1 27.000 Personel Alımı",
                organization="Sağlık Bakanlığı",
                application_dates="21.02.2026 - 28.02.2026 (Sona Erdi)",
                start_date="2026-02-21",
                end_date="2026-02-28",
                status=ExamStatus.COMPLETED,
                official_url="https://ais.osym.gov.tr"
            ),
            ExamScheduleItem(
                id="danistay-zabita",
                category="kamu_memur",
                title="Danıştay 50 Zabıt Katibi ve Şoför Alımı",
                organization="Danıştay Başkanlığı",
                application_dates="05.06.2026 - 15.06.2026 (Sona Erdi)",
                start_date="2026-06-05",
                end_date="2026-06-15",
                status=ExamStatus.COMPLETED,
                official_url="https://danistay.gov.tr"
            ),
            ExamScheduleItem(
                id="yargitay-memur",
                category="kamu_memur",
                title="Yargıtay 120 Sözleşmeli Zabıt Katibi ve Güvenlik Alımı",
                organization="Yargıtay Başkanlığı",
                application_dates="10.05.2026 - 20.05.2026 (Sona Erdi)",
                start_date="2026-05-10",
                end_date="2026-05-20",
                status=ExamStatus.COMPLETED,
                official_url="https://yargitay.gov.tr"
            ),
            ExamScheduleItem(
                id="afad-arama-kurtarma",
                category="kamu_memur",
                title="AFAD 1.101 Arama ve Kurtarma Teknisyeni Alımı",
                organization="AFAD",
                application_dates="12.04.2026 - 27.04.2026 (Sona Erdi)",
                start_date="2026-04-12",
                end_date="2026-04-27",
                status=ExamStatus.COMPLETED,
                official_url="https://afad.gov.tr"
            ),
            ExamScheduleItem(
                id="diyanet-sozlesmeli-1",
                category="kamu_memur",
                title="Diyanet 4.538 4/B Sözleşmeli Personel Alımı",
                organization="Diyanet İşleri Başkanlığı",
                application_dates="01.04.2026 - 15.04.2026 (Sona Erdi)",
                start_date="2026-04-01",
                end_date="2026-04-15",
                status=ExamStatus.COMPLETED,
                official_url="https://diyanet.gov.tr"
            ),
            ExamScheduleItem(
                id="tarim-orman-1",
                category="kamu_memur",
                title="OGM 3.000 Yangın İşçisi ve Orman Muhafaza Memuru Alımı",
                organization="Tarım ve Orman Bakanlığı",
                application_dates="15.03.2026 - 29.03.2026 (Sona Erdi)",
                start_date="2026-03-15",
                end_date="2026-03-29",
                status=ExamStatus.COMPLETED,
                official_url="https://ogm.gov.tr"
            ),
            ExamScheduleItem(
                id="tubitak-arastirmaci",
                category="kamu_memur",
                title="TÜBİTAK BİLGEM & MAM 450 Proje Personeli ve Araştırmacı Alımı",
                organization="TÜBİTAK",
                application_dates="01.06.2026 - 21.06.2026 (Sona Erdi)",
                start_date="2026-06-01",
                end_date="2026-06-21",
                status=ExamStatus.COMPLETED,
                official_url="https://kariyer.tubitak.gov.tr"
            ),
            ExamScheduleItem(
                id="cevre-sehircilik-1",
                category="kamu_memur",
                title="650 Kentsel Dönüşüm Uzman Yardımcısı ve Mühendis Alımı",
                organization="Çevre, Şehircilik ve İklim Değişikliği Bakanlığı",
                application_dates="10.05.2026 - 25.05.2026 (Sona Erdi)",
                start_date="2026-05-10",
                end_date="2026-05-25",
                status=ExamStatus.COMPLETED,
                official_url="https://csb.gov.tr"
            ),
            ExamScheduleItem(
                id="kyk-yurt-temizlik-1",
                category="kamu_memur",
                title="GSB 2026 Bahar Dönemi 2.000 Güvenlik ve Temizlik Görevlisi",
                organization="GSB",
                application_dates="10.02.2026 - 20.02.2026 (Sona Erdi)",
                start_date="2026-02-10",
                end_date="2026-02-20",
                status=ExamStatus.COMPLETED,
                official_url="https://gsb.gov.tr"
            ),
            ExamScheduleItem(
                id="kultur-bakanligi-1",
                category="kamu_memur",
                title="Kültür Varlıkları ve Müzeler 350 Arkeolog & Restoratör Alımı",
                organization="Kültür ve Turizm Bakanlığı",
                application_dates="01.03.2026 - 15.03.2026 (Sona Erdi)",
                start_date="2026-03-01",
                end_date="2026-03-15",
                status=ExamStatus.COMPLETED,
                official_url="https://ktb.gov.tr"
            )
        ]

        # 2. Örnek Açık İlanlar (VIP Bölümü)
        self.announcements = {
            "ann-01": Announcement(
                id="ann-01",
                title="Jandarma 2.500 Uzman Erbaş Alımı (Asayiş & Komando)",
                organization="Jandarma Genel Komutanlığı",
                category=AnnouncementCategory.JANDARMA,
                summary="En az lise mezunu, 27 yaşını bitirmemiş erkek adaylar arasından 2.500 uzman erbaş temin edilecek.",
                requirements=["En az lise mezunu olmak", "01 Ocak 1999 ve sonrası doğumlu olmak", "En az 167 cm boyunda olmak"],
                application_start="15.05.2026",
                application_deadline="02.06.2026",
                official_url="https://vatandas.jandarma.gov.tr/PTM/Giris",
                published_at="15.05.2026 12:00",
                scanned_at_12pm="15.05.2026 12:00",
                is_hot=True,
                is_premium_only=False
            ),
            "ann-02": Announcement(
                id="ann-02",
                title="32. Dönem POMEM 10.000 Polis Memuru Alımı",
                organization="Polis Akademisi Başkanlığı",
                category=AnnouncementCategory.POLIS_POMEM,
                summary="Lisans mezunu 8.160, önlisans mezunu 2.040 olmak üzere toplam 10.000 polis alımı gerçekleştirilecek.",
                requirements=["Lisans P3 en az 60, Önlisans P93 en az 65 puan", "30 yaşından gün almamış olmak"],
                application_start="04.04.2026",
                application_deadline="25.04.2026",
                official_url="https://www.pa.edu.tr",
                published_at="04.04.2026 12:00",
                scanned_at_12pm="04.04.2026 12:00",
                is_hot=True,
                is_premium_only=False
            ),
            "ann-03": Announcement(
                id="ann-03",
                title="2026-MSÜ Harp Okulları & Astsubay MYO Askeri Öğrenci Alımı",
                organization="Milli Savunma Bakanlığı",
                category=AnnouncementCategory.MSU_ASKERI,
                summary="Kara, Deniz ve Hava Harp Okulları ile Bando dahil Astsubay MYO öğrenci aday belirleme süreci.",
                requirements=["Türkiye Cumhuriyeti vatandaşı olmak", "Harp Okulları için en fazla 20 yaşında olmak"],
                application_start="03.01.2026",
                application_deadline="30.01.2026",
                official_url="https://personeltemin.msb.gov.tr",
                published_at="03.01.2026 12:00",
                scanned_at_12pm="03.01.2026 12:00",
                is_hot=True,
                is_premium_only=False
            )
        }

        # 3. Örnek Nöbetçi URL
        self.custom_watchers = {
            "watch-01": CustomUrlWatcher(
                id="watch-01",
                user_id="user-demo-ensar",
                url="https://vatandas.jandarma.gov.tr/PTM/Giris",
                label="Jandarma Personel Temin Duyuruları",
                last_checked_12pm="Bugün 12:00",
                has_update=False
            )
        }

    def get_open_announcements(self, current_date_str: Optional[str] = None) -> List[ExamScheduleItem]:
        """
        Günün tarihine göre şu an başvuru süresi AÇIK olan ilanları döndürür.
        """
        today = current_date_str or datetime.now().strftime("%Y-%m-%d")
        open_items = []
        for item in self.exam_schedules:
            if item.start_date and item.end_date:
                if item.start_date <= today <= item.end_date:
                    open_items.append(item)
            elif item.status == ExamStatus.ACTIVE:
                open_items.append(item)
        return open_items

    def toggle_user_alarm(self, user_id: str, channel_id: str, is_active: bool):
        """
        Kullanıcının belirli bir ilan için alarmını açar veya kapatır.
        """
        if user_id not in self.user_alarms:
            self.user_alarms[user_id] = set()
        if is_active:
            self.user_alarms[user_id].add(channel_id)
        else:
            self.user_alarms[user_id].discard(channel_id)

    def get_users_for_channel_alarm(self, channel_id: str) -> List[str]:
        """
        SADECE bu ilanın alarmını açmış olan kullanıcı ID'lerini döndürür.
        Müşteri neyin bildirimini açtıysa yalnızca ona bildirim gider.
        """
        return [uid for uid, alarms in self.user_alarms.items() if channel_id in alarms]

    def purge_expired_announcements(self, today_str: Optional[str] = None) -> int:
        """
        Başvuru tarihi veya süresi bitmiş (günü dolmuş) ilanları otomatik siler/arşivler.
        Böylece ana akışta yalnızca aktif ve yaklaşan güncel ilanlar yer alır.
        """
        today = today_str or datetime.now().strftime("%Y-%m-%d")
        initial_count = len(self.exam_schedules)
        
        # Süresi dolan ve sonuç niteliğinde olmayan geçmiş ilanları temizle
        self.exam_schedules = [
            item for item in self.exam_schedules
            if not (item.end_date and item.end_date < today and "Sonuç" not in item.title)
        ]
        
        purged = initial_count - len(self.exam_schedules)
        return purged

    def get_live_radar_announcements(self, today_str: Optional[str] = None) -> List[ExamScheduleItem]:
        """
        Kullanıcıya sunulacak güncel akış:
        Günü bitenler elenmiş; şu an açık olanlar ve yaklaşan alımlar.
        """
        today = today_str or datetime.now().strftime("%Y-%m-%d")
        self.purge_expired_announcements(today)
        return self.exam_schedules

    def set_user_subscription(self, user_id: str, plan_type: str):
        """
        Firebase Firestore mantığı: Plan türünü kullanıcıya özel kaydeder.
        plan_type: 'monthly_vip', 'yearly_vip'
        """
        self.user_subscriptions[user_id] = plan_type
        if plan_type in ['monthly_vip', 'yearly_vip']:
            self.users_premium[user_id] = True

db = InMemoryDB()
