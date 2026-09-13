# KamuRadar - DigitalOcean Sunucu & Firebase Kurulum Rehberi

Bu rehber, **KamuRadar** backend servisini **DigitalOcean** sanal sunucusunda (Droplet) 7/24 kesintisiz çalıştırmak, **Firebase Cloud Messaging (FCM)** ile anlık push bildirimleri entegre etmek ve her gün saat 12:00'de otomatik tarih taraması yaptırmak için hazırlanmıştır.

---

## 🚀 1. Adım: DigitalOcean Sunucu (Droplet) Oluşturma

1. [DigitalOcean](https://www.digitalocean.com/) hesabınıza giriş yapın.
2. **Create > Droplets** butonuna tıklayın:
   - **Image:** Ubuntu 24.04 LTS x64 (veya 22.04 LTS)
   - **Plan:** Basic (Regular)
   - **CPU:** 1 GB RAM / 1 vCPU / 25 GB SSD (Aylık 4$ veya 6$ fazlasıyla yeterlidir)
   - **Region:** Frankfurt veya Amsterdam (Türkiye'ye en düşük gecikme süresi)
   - **Authentication:** SSH Key (veya Güçlü Parola)
3. Droplet oluştuktan sonra verilen **IPv4 Adresi** ile terminalden bağlanın:
   ```bash
   ssh root@SUNUCU_IP_ADRESINIZ
   ```

---

## 📦 2. Adım: Sunucu Hazırlığı & Projenin Kurulması

Sunucuya bağlandıktan sonra sırasıyla şu komutları çalıştırın:

```bash
# 1. Sistem paketlerini güncelle
sudo apt update && sudo apt upgrade -y

# 2. Python, git, nginx ve curl kur
sudo apt install -y python3-pip python3-venv git nginx curl

# 3. Proje dizinini oluştur ve klonla (veya dosyaları yükle)
mkdir -p /var/www/kamuradar
cd /var/www/kamuradar

# Proje dosyalarını aktarın (git clone veya scp ile)
# Örnek: git clone https://github.com/kullanici/kamuradar.git .

# 4. Python Sanal Ortamı (venv) oluştur ve aktif et
python3 -m venv venv
source venv/bin/activate

# 5. Gereksinimleri yükle
pip install --upgrade pip
pip install -r backend/requirements.txt
```

---

## 🔥 3. Adım: Firebase Hesabı & Bildirim Anahtarı Alma

1. [Firebase Console](https://console.firebase.google.com/)'a gidin ve **"Proje Ekle"** (Örn: `kamuradar-app`) deyin.
2. Sol üstteki **Proje Ayarları (Dişli İkonu) > Hizmet Hesapları (Service Accounts)** sekmesine geçin.
3. **"Yeni özel anahtar oluştur" (Generate new private key)** butonuna basın.
4. İndirilen JSON dosyasının adını **`firebase_credentials.json`** olarak değiştirin.
5. Bu dosyayı DigitalOcean sunucunuzdaki backend klasörüne atın:
   ```bash
   /var/www/kamuradar/backend/firebase_credentials.json
   ```

---

## ⚙️ 4. Adım: 7/24 Kesintisiz Çalışma (Systemd Servisi)

Uygulamanın sunucu yeniden başlasa bile otomatik açılması ve 7/24 ayakta kalması için systemd servisi tanımlayın:

```bash
sudo nano /etc/systemd/system/kamuradar.service
```

İçerisine şu yapılandırmayı yapıştırın (`Ctrl + O`, `Enter`, `Ctrl + X` ile kaydedin):

```ini
[Unit]
Description=KamuRadar FastAPI & Scraper Servisi
After=network.target

[Service]
User=root
WorkingDirectory=/var/www/kamuradar/backend
Environment="PATH=/var/www/kamuradar/venv/bin"
Environment="FIREBASE_CREDENTIALS_PATH=/var/www/kamuradar/backend/firebase_credentials.json"
ExecStart=/var/www/kamuradar/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000 --workers 2
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Servisi başlatın ve otomatik başlangıca ekleyin:
```bash
sudo systemctl daemon-reload
sudo systemctl start kamuradar
sudo systemctl enable kamuradar
sudo systemctl status kamuradar
```

---

## 🌐 5. Adım: Nginx & Ücretsiz SSL (HTTPS) Kurulumu

Dış dünyadan ve Flutter mobil uygulamasından güvenli `https://api.domaininiz.com` ile erişebilmek için Nginx ayarı:

```bash
sudo nano /etc/nginx/sites-available/kamuradar
```

Aşağıdaki satırları ekleyin:
```nginx
server {
    server_name api.kamuradar.com; # veya Sunucu IP adresiniz

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Aktif edin ve Nginx'i yeniden başlatın:
```bash
sudo ln -s /etc/nginx/sites-available/kamuradar /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

*(Opsiyonel)* Alan adınız varsa ücretsiz SSL (HTTPS) kurun:
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.kamuradar.com
```

---

## ⏰ 6. Adım: Saat 12:00 Otomatik Tarama (Linux Crontab)

Her gün saat 12:00'de toplu taramayı tetiklemek için cron tanımlayın:

```bash
crontab -e
```

En alta şu satırı ekleyin:
```bash
0 12 * * * curl -s -X POST http://127.0.0.1:8000/api/cron/trigger-12pm >> /var/log/kamuradar_cron.log 2>&1
```

Bu komut her gün saat tam 12:00'de:
1. Resmî kamu sitelerini ve kullanıcının özel linklerini tarar.
2. Başvuru tarihlerini **günün tarihiyle (`date.today()`)** karşılaştırır.
3. Eğer bugün başlamışsa:
   - Durumu **"Açık (Bugün Başladı! 🔔)"** olarak işaretler.
   - Firebase üzerinden ilgili alımın alarmını açmış olan kullanıcıların telefonlarına **anında Push Bildirim fırlatır!**
