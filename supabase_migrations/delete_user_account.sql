-- Supabase SQL Editor'da çalıştır
-- Kullanıcının kendi hesabını ve tüm verilerini silebilmesi için
-- SECURITY DEFINER: fonksiyon postgres yetkisiyle çalışır, auth.users'ı silebilir

CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  _uid      uuid := auth.uid();
  _uid_text text := auth.uid()::text;
BEGIN
  -- device_id kolonları text tipinde olduğu için text cast kullanılıyor
  DELETE FROM public.user_selected_meals WHERE device_id = _uid_text;
  DELETE FROM public.ara_ogunler        WHERE device_id = _uid_text;
  DELETE FROM public.daily_health       WHERE device_id = _uid_text;
  DELETE FROM public.user_consents      WHERE user_id   = _uid;

  -- Auth hesabını sil
  DELETE FROM auth.users WHERE id = _uid;
END;
$$;

-- Hem kayıtlı hem anonim kullanıcılar çağırabilsin
GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated, anon;
