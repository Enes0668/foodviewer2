-- Supabase SQL Editor'da çalıştır
-- Tablo: user_consents
-- Amaç: KVKK aydınlatma metni kabul kayıtlarını tutmak

CREATE TABLE IF NOT EXISTS user_consents (
  id               uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id          uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kvkk_accepted_at timestamptz NOT NULL DEFAULT now(),
  app_version      text,
  platform         text
);

-- Her kullanıcı için sadece kendi satırlarına erişim
ALTER TABLE user_consents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Kullanıcı kendi rızasını ekleyebilir"
  ON user_consents FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Kullanıcı kendi rıza kayıtlarını görebilir"
  ON user_consents FOR SELECT
  USING (auth.uid() = user_id);

-- Yeni metni kabul etme zamanına göre hızlı sıralama için
CREATE INDEX IF NOT EXISTS idx_user_consents_user_id
  ON user_consents (user_id, kvkk_accepted_at DESC);
