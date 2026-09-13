# 🎯 KamuRadar - Kamu & Sınav İlanları Takip Uygulaması

Türkiye'deki kamu personeli, Jandarma alımları, MSÜ (Milli Savunma Üniversitesi), POMEM ve ÖSYM sınav duyurularını tek ekranda toplayan; ayrıca **Premium üyeler için özel web linki takibi** ve **39.99 ₺/ay (+3 kişi) Aile Planı** sunan, **ultra düşük sunucu maliyetli** mobil uygulama sistemi.

---

## ⚡ Maliyet Koruma Mimarisi: "Günde 1 Kez Saat 12:00 Tarama Modeli"

Dakika başı veya saat başı tarama yapmak sunucu maliyetlerini katlayacağı için, bu projede **tam optimizasyonlu tek merkezli zamanlama** uygulanmıştır:

1. **Toplu Tarama (Batch Cron)**: Hem genel kamu kaynakları (Jandarma, MSÜ, ÖSYM) hem de Premium üyelerin eklediği tüm özel linkler her gün **tam saat 12:00'de tek bir seferde** taranır.
2. **Aktif CPU Süresi**: Sunucu günde yalnızca 1-2 dakika çalışır; günün kalan 23 saat 58 dakikasında minimum bellek ve CPU harcar. Aylık sunucu gideri 1-2 doları geçmez.
3. **Kullanıcı Alışkanlığı**: Kullanıcılar her gün saat 12:05'te toplu günlük bülten ve takip ettikleri sayfalardaki değişiklik bildirimini alır.

---

## 💎 Premium Özellikler & 39.99 ₺ Aile/Ekip Planı (+3 Kişi)

* **Özel Link İzleme (URL Watcher)**: Kullanıcı istediği bir kamu, üniversite veya sınav sonuç sayfasının linkini ekler. Sayfada değişiklik veya yeni duyuru algılandığında anında bildirim düşer.
* **1 Öde, 4 Kişi Kullan (Siz + 3 Yakınınız)**:
  - Ana kullanıcı 39.99 ₺/ay ile planı başlatır.
  - Sistem 6 haneli özel bir **Aile Davet Kodu** üretir (Örn: `KAMU77`).
  - Ana kullanıcı bu kodu 3 arkadaşıyla paylaşır.
  - Kod ile katılan 3 kişi hiçbir ek ücret ödemeden tüm Premium avantajları kullanır (kişi başı maliyet ayda sadece ~10 ₺'ye gelir!).

---

## 📁 Proje Dizin Yapısı

```
kamuradar/
├── backend/
│   ├── main.py                     # FastAPI REST API sunucusu
│   ├── models.py                   # Pydantic veri modelleri
│   ├── database.py                 # Veritabanı ve tohum ilan verileri
│   ├── scrapers/
│   │   ├── scheduler_12pm.py       # Her gün saat 12:00'de çalışan toplu tarayıcı motoru
│   │   ├── official_sources.py     # Jandarma, MSÜ, ÖSYM kazıyıcıları
│   │   └── custom_url_watcher.py   # Özel linkler için SHA-256 hash fark dedektörü
│   ├── services/
│   │   └── family_plan.py          # 1 + 3 kişilik davet kodu ve kota yönetimi
│   ├── test_kamuradar.py           # Birim testler (+3 kişi sınırı, hash diff, 12:00 batch)
│   └── requirements.txt            # Python gereksinimleri
│
└── mobile/
    ├── pubspec.yaml                # Flutter konfigürasyonu
    └── lib/
        ├── main.dart               # Alt navigasyon ve ana tema
        ├── models/
        │   ├── announcement.dart   # İlan veri modeli
        │   └── custom_link.dart    # Özel link veri modeli
        └── screens/
            ├── home_feed_screen.dart           # İlan akışı ve 12:00 durum bandı
            ├── announcement_detail_screen.dart # Başvuru şartları ve resmi link
            ├── custom_watcher_screen.dart      # Özel link ekleme (URL Watcher)
            └── family_subscription_screen.dart # 39.99 ₺ Aile Planı ve davet yuvaları
```

---

## 🚀 Çalıştırma Talimatları

### 1. Backend API & Tarayıcıyı Başlatma:
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```
* API Dokümantasyonu: `http://127.0.0.1:8000/docs`
* 12:00 Taramasını Test Etme: `POST http://127.0.0.1:8000/api/cron/trigger-12pm`

### 2. Testleri Çalıştırma:
```bash
pytest test_kamuradar.py
```

### 3. Mobil Uygulamayı Başlatma (Flutter):
```bash
cd mobile
flutter pub get
flutter run
```
