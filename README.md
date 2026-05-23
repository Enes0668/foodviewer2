# 🍽️ Günün Menüsü - KYK Yurtları İçin Akıllı Beslenme Takip Uygulaması

**Sağlıklı beslenmenin akıllı takipçisi** — KYK yurtlarında kalan öğrencilerin günlük menüyü görüp, kalori ve sağlık durumlarını takip etmeleri için geliştirilmiş mobil uygulama.

---

## 📱 Uygulamaya Genel Bakış

Günün Menüsü, KYK yurtlarında sunulan yemekleri dinamik olarak görüntüleyen ve öğrencilerin kişisel sağlık verilerini (VKİ, kalori, adım sayısı) takip etmelerine olanak sağlayan **Flutter tabanlı cross-platform mobil uygulamasıdır**.

**Ana Hedef:** Öğrencilerin beslenme alışkanlıklarını bilinçlendirerek, sağlıklı yaşamı desteklemek.

---

## ✨ Temel Özellikler

### 🍴 **1. Dinamik Menü Yönetimi**
- **Konum Bazlı Menü Görüntüleme**: Öğrencinin bulunduğu şehirdeki KYK yurdunun günlük menüsünü otomatik olarak gösterir
- **Kahvaltı & Akşam Yemeği Takibi**: Her öğün için detaylı malzeme listesi ve kalori bilgisi
- **Seçilebilir Yemekler**: Farklı seçenekler arasından tercih yaparak kalori hesaplama
- **Tarih Seçimi**: Geçmiş ve gelecek günlerin menüsünü görüntüleme
- **İnternet Engelliyken Cache**: Ay bazında veri cachelenmiş olarak saklama (6 saatte bir güncellenme)

### 💪 **2. Kişisel Sağlık Takibi (Profil Sayfası)**
- **VKİ Hesaplama**: Boy, kilo ve cinsiyet verilerine göre otomatik Vücut Kitle İndeksi hesaplaması
- **VKİ Durumu**: Zayıf, Normal, Fazla Kilolu, Obez kategorileri
- **Kalori Takibi**: 
  - Alınan kalori (menüden seçilen yemeklerden)
  - Yakılan kalori (adım sayısından hesaplanan)
  - Günlük kalori dengesi
- **Akıllı Adım Önerisi**: Kişinin BMI'ına, cinsiyetine ve aldığı kaloriye göre önerilen günlük adım sayısı hesaplaması
- **İlerleme Yüzdesi**: Hedeflenen adım sayısına ulaşma yüzdesinin görsel gösterimi

### 🎯 **3. Ara Öğünler Yönetimi**
- Öğrenci ekleyebileceği ek yiyecekler (çay, kahve, meyve vb.) ve kalorileri
- Konum bazlı ara öğün veritabanı

### 📍 **4. Konum Hizmetleri**
- Otomatik şehir tespiti
- Şehir değiştiğinde menü ve ara öğünler otomatik güncelleme
- İzin yönetimi ve hassas bir şekilde implementasyon

### 🎨 **5. Tema & UX**
- Açık (Light) ve Koyu (Dark) Tema Desteği
- Dinamik renk şeması
- Responsive tasarım (tüm cihaz boyutlarına uyum)

### 🔔 **6. Bildirim Sistemi**
- Belirli saatlerde yemek hatırlatmaları
- Android Alarm Manager entegrasyonu
- Hizmet yönetimi (WorkManager)

### 📹 **7. Rehber Videosu**
- İlk kullanımda uygulamanın nasıl kullanılacağını gösteren video talimatı

### 🔐 **8. Güvenlik & Gizlilik**
- Supabase Anonim Kimlik Doğrulama (Authentication)
- Row Level Security (RLS) ile veri koruma
- KVKK Uyumluluğu
- SharedPreferences ile lokal veri şifreleme

---

## 🛠️ Teknik Stack

### Frontend
- **Framework**: Flutter 3.8.1+
- **State Management**: Provider 6.1.2
- **UI Library**: Material Design 3

### Backend & Veritabanı
- **Backend**: Supabase (PostgreSQL)
- **Kimlik Doğrulama**: Supabase Auth
- **Veritabanı**: PostgreSQL (RLS ile güvenlik)

### Önemli Kütüphaneler
| Kütüphane | Versiyon | Kullanım |
|-----------|----------|---------|
| `supabase_flutter` | 2.5.0 | Backend ve Veritabanı |
| `shared_preferences` | 2.1.1 | Lokal veri depolama |
| `connectivity_plus` | 7.0.0 | İnternet bağlantısı kontrolü |
| `geolocator` | 10.1.0 | GPS ve konum hizmetleri |
| `geocoding` | 3.0.0 | Koordinat → Şehir dönüşümü |
| `flutter_local_notifications` | 17.0.0 | Push bildirimler |
| `android_alarm_manager_plus` | 5.0.0 | Android arka plan görevleri |
| `workmanager` | 0.9.0+3 | Periyodik arka plan işleri |
| `provider` | 6.1.2 | Tema yönetimi |
| `image_picker` | 1.0.7 | Profil fotoğrafı seçimi |
| `media_kit` | 1.2.6 | Video oynatma (rehber videosu) |
| `intl` | 0.20.2 | Türkçe lokalizasyon |

### Desteklenen Platformlar
- ✅ Android (Min SDK 21)
- ✅ Web 
- ⏳ İos
- ⏳ Linux & macOS

---

## 📊 Veritabanı Mimarisi

### Tablolar

#### `kahvaltilar`
```sql
- kahvalti_tarihi (DATE)
- city (VARCHAR)
- ana_kahvalti, diger1, diger2, diger3 (TEXT)
- ana_kahvalti_kalori, diger1_kalori, ... (NUMERIC)
```

#### `aksam_yemekleri`
```sql
- aksam_tarihi (DATE)
- city (VARCHAR)
- yemek1, yemek2, pilav_makarna, ekstra (TEXT)
- yemek1_kalori, yemek2_kalori, ... (NUMERIC)
```

#### `user_selected_meals`
```sql
- device_id (UUID) - Supabase Auth ID
- meal_date (DATE)
- meal_type ('kahvalti' | 'aksam')
- meal_field (VARCHAR)
- meal_name (TEXT)
- calories (NUMERIC)
- city (VARCHAR)
```

#### `ara_ogunler`
```sql
- device_id (UUID)
- date (DATE)
- food_name (TEXT)
- calories (NUMERIC)
- city (VARCHAR)
```

#### `daily_health`
```sql
- device_id (UUID)
- date (DATE)
- height, weight (NUMERIC)
- age (INT)
- gender (VARCHAR)
- bmi (NUMERIC)
- bmi_status (VARCHAR)
- steps, recommended_steps (INT)
- total_calories, burned_calories, calorie_balance (NUMERIC)
```

---

## 🚀 Başlangıç

### Gereksinimler
- Flutter SDK 3.8.1 veya üstü
- Android SDK (API 21+)
- Xcode (iOS için)
- Supabase Projesi

### Kurulum Adımları

1. **Repoyu klonlayın**
   ```bash
   git clone https://github.com/Enes0668/foodviewer2.git
   cd foodviewer2
   ```

2. **Bağımlılıkları yükleyin**
   ```bash
   flutter pub get
   ```

3. **Supabase Yapılandırması**
   - `env.txt` dosyasında Supabase URL ve API Key'i ayarlayın
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_KEY=your-anon-key
   ```

4. **Uygulamayı çalıştırın**
   ```bash
   flutter run
   ```

### Android Build
```bash
flutter build apk --release
```

### iOS Build
```bash
flutter build ios --release
```

---

## 📂 Proje Yapısı

```
lib/
├── main.dart                    # App Entry Point
├── main_layout.dart             # Ana Layout (Bottom Navigation)
├── theme_provider.dart          # Tema Yönetimi
│
├── pages/
│   ├── entry_page.dart         # İnternet Kontrolü
│   ├── welcome_page.dart       # Hoş Geldiniz Ekranı
│   ├── home_page.dart          # ⭐ Ana Sayfa (Menü)
│   ├── profile_page.dart       # 💪 Profil (Sağlık Takibi)
│   ├── settings_page.dart      # ⚙️ Ayarlar
│   ├── login_page.dart         # Giriş
│   ├── register_page.dart      # Kayıt
│   ├── kvkk_page.dart          # KVKK Onayı
│   ├── video_instruction_screen.dart  # 📹 Rehber Videosu
│   ├── araogun_page.dart       # 🍪 Ara Öğünler
│   └── nointernet_page.dart    # Bağlantı Yok Uyarısı
│
├── services/
│   ├── notification_service.dart   # 🔔 Bildirim Yönetimi
│   └── location_service.dart       # 📍 Konum Hizmetleri
│
├── widgets/
│   └── custom_loading.dart      # Loading Animation

assets/
├── icon/
│   └── app_icon.png
└── video/
    └── tutorial.mp4            # Rehber Videosu
```

---

## 🔑 Ana Algoritmalar

### 1. **VKİ Hesaplama**
```
VKİ = Kilo (kg) / (Boy (m))²

Kategoriler:
- < 18.5  → Zayıf
- 18.5-25 → Normal
- 25-30   → Fazla Kilolu  
- ≥ 30    → Obez
```

### 2. **Kalori Yakma Hesaplama**
```
Yakılan Kalori = Adım Sayısı × 0.04
```

### 3. **Akıllı Adım Önerisi (Motivasyon Odaklı)**
```
Base Adım = VKİ'ye göre belirlenir (7000-9000)
+ Kalori katkısı (0-1000 adım)
+ Cinsiyet katkısı (Erkekler +300)
+ Minimum 5000, Maksimum 12000 adım
```

---

## 🎯 Geliştirme Özellikleri (Roadmap)

- [ ] Sosyal Paylaşım (Arkadaşlarla kalori karşılaştırması)
- [ ] Beslenme Puanlaması (Beslenme skoru hesaplama)
- [ ] AI Tavsiyeler (Kişiye uygun yemek tavsiyeleri)
- [ ] Yemek Fotoğrafı OCR (Kamera ile kalori tanıması)
- [ ] Gelişmiş İstatistikler (Haftalık/Aylık grafikler)
- [ ] Wearables Entegrasyonu (Smartwatch ile senkronizasyon)
- [ ] Diyetisyen Görüşü (In-app danışmanlık)

---

## 🤝 Katkıda Bulunma

Bu proje **açık kaynak kodlu değildir**, ancak:
- 🐛 Bug raporları için [Issues](https://github.com/Enes0668/foodviewer2/issues) açın
- 💡 Önerileriniz için [Discussions](https://github.com/Enes0668/foodviewer2/discussions) kullanın
- 📧 İletişim: melihenes2@gmail.com

---

## 📜 Lisans

Bu proje şu anda **kapalı kaynak kodludur**. Ticari kullanım için izin alınız.

---

## 👤 Geliştirici

**Enes Melih Eroğlu** - Flutter & Full-Stack Developer

- 🌐 [GitHub](https://github.com/Enes0668)
- 💼 [LinkedIn](https://www.linkedin.com/in/enes-melih-ero%C4%9Flu-77609a2b3/)

---

## 🏆 Önemli Notlar

✅ **Üretim Hazırı**: Gerçek KYK yurtları tarafından kullanıma hazır
✅ **Veritabanı Güvenliği**: Supabase RLS ile tam korumalı
✅ **Türkçe Lokalizasyon**: Tamamen Türkçe arayüz ve takip
✅ **KVKK Uyumlu**: Kullanıcı gizliliği korumalı

---

## 📞 Destek & Geri Bildirim

📧 Email: melihenes2@gmail.com

Herhangi bir sorun veya geri bildirim için lütfen [Issues](https://github.com/Enes0668/foodviewer2/issues) sekmesinde bir sorun açın.

---

**Made with ❤️ for students' health** 🏥
