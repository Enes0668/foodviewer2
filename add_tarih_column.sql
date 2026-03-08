-- ==============================================================================
-- 📅 TABLO GÜNCELLEMESİ (Tarih Sütunu Ekleme)
-- 'kyk_meal_contributions' tablosuna Türkiye saatini doğru tutmak için yeni sütun ekler.
-- ==============================================================================

-- 1. Yeni 'tarih' sütununu ekle (timestamp with time zone)
-- 'timestamptz' kullanmak en doğrusudur, böylece saat dilimi (UTC+3) bilgisi korunur.
ALTER TABLE public.kyk_meal_contributions 
ADD COLUMN IF NOT EXISTS tarih timestamp with time zone DEFAULT now();

-- Not: Mevcut veriler için 'tarih' sütunu şu anki zamanla doldurulacaktır (DEFAULT now()).

-- 🔚 BİTTİ
