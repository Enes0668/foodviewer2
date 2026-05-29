import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka planda gelen bildirim — FCM zaten gösterir, ekstra işlem gerekmez
}

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static SupabaseClient get _supabase => Supabase.instance.client;

  static Future<void> initialize() async {
    if (kIsWeb) return;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final authorized =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (authorized) {
      await _saveToken();
    }

    // Token yenilenince Supabase'i güncelle
    _messaging.onTokenRefresh.listen((token) => _updateToken(token));
  }

  static Future<void> _saveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('user_notification_settings').upsert(
        {'user_id': userId, 'fcm_token': token},
        onConflict: 'user_id',
      );
    } catch (_) {}
  }

  static Future<void> _updateToken(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('user_notification_settings')
          .update({'fcm_token': token})
          .eq('user_id', userId);
    } catch (_) {}
  }

  static Future<void> updatePreference({
    required bool breakfastEnabled,
    required bool dinnerEnabled,
    String? city,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final token = await _messaging.getToken();

      await _supabase.from('user_notification_settings').upsert(
        {
          'user_id': userId,
          if (token != null) 'fcm_token': token,
          'breakfast_enabled': breakfastEnabled,
          'dinner_enabled': dinnerEnabled,
          if (city != null) 'city': city,
        },
        onConflict: 'user_id',
      );
    } catch (_) {}
  }
}
