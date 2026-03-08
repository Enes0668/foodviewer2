import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> backgroundBreakfastTask() async {
  debugPrint("⏰ [BACKGROUND] Breakfast Alarm Triggered!");
  await _processDailyNotification(
    mealType: 'kahvalti',
    defaultTitle: "🍳 Kahvaltı Zamanı!",
    defaultBody: "Gün güzel bir kahvaltıyla başlar!",
    notificationId: 200,
  );
  
  // Reschedule for tomorrow
  final now = DateTime.now();
  final scheduleTime = DateTime(now.year, now.month, now.day, 6, 0).add(const Duration(days: 1));
  await AndroidAlarmManager.oneShotAt(
    scheduleTime,
    200, // Alarm ID
    backgroundBreakfastTask,
    exact: true,
    wakeup: true,
    rescheduleOnReboot: true,
  );
}

@pragma('vm:entry-point')
Future<void> backgroundDinnerTask() async {
  debugPrint("⏰ [BACKGROUND] Dinner Alarm Triggered!");
  await _processDailyNotification(
    mealType: 'aksam',
    defaultTitle: "🍽 Akşam Yemeği Zamanı!",
    defaultBody: "Akşam yemeği seni bekliyor!",
    notificationId: 201,
  );

  // Reschedule for tomorrow
  final now = DateTime.now();
  final scheduleTime = DateTime(now.year, now.month, now.day, 16, 0).add(const Duration(days: 1));
  await AndroidAlarmManager.oneShotAt(
    scheduleTime,
    201, // Alarm ID
    backgroundDinnerTask,
    exact: true,
    wakeup: true,
    rescheduleOnReboot: true,
  );
}

Future<void> _processDailyNotification({
  required String mealType,
  required String defaultTitle,
  required String defaultBody,
  required int notificationId,
}) async {
  // Ensure we have loaded necessary plugins
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  
  try {
    // 1. Load preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Ensure fresh preferences are loaded in the background isolate
    final isEnabled = prefs.getBool(mealType == 'kahvalti' ? "breakfast_notification" : "dinner_notification") ?? false;
    
    if (!isEnabled) {
      debugPrint("🚫 [BACKGROUND] $mealType notifications are disabled.");
      return; 
    }

    final savedCity = prefs.getString("selected_city") ?? "Karaman";
    
    final favVar = prefs.getBool("${mealType}_favori_var") ?? false;
    
    String bodyText = defaultBody;

    // We don't necessarily need to fetch Supabase if we rely on cached favName,
    // but the issue was that the daily notification didn't fetch the day's fresh meal. 
    // To fix this accurately in the background, we MUST fetch Supabase for TODAY'S MEY!
    
    // 2. Initialize env and Supabase if not active
    try {
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        // dotenv might already be loaded
      }

      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseKey = dotenv.env['SUPABASE_KEY'];

      if (supabaseUrl != null && supabaseKey != null) {
        try {
          await Supabase.initialize(
            url: supabaseUrl,
            anonKey: supabaseKey,
          );
        } catch (e) {
          // Supabase might already be initialized
        }
      }
    } catch (e) {
      debugPrint("⚠️ Background Supabase init error: $e");
    }

    // 3. Query today's meal if we have access to Supabase client
    try {
        final dateKey = DateFormat("yyyy-MM-dd").format(DateTime.now());
        final supabase = Supabase.instance.client;
        
        final tableName = mealType == 'kahvalti' ? 'kahvaltilar' : 'aksam_yemekleri';
        final dateColumn = mealType == 'kahvalti' ? 'kahvalti_tarihi' : 'aksam_tarihi';

        final response = await supabase
            .from(tableName)
            .select()
            .eq(dateColumn, dateKey)
            .eq('city', savedCity);

        final meals = List<Map<String, dynamic>>.from(response);
        
        // Define favorites list
        final favorites = mealType == 'kahvalti' 
            ? ["patates kızartması", "sade pişi", "karışık pizza", "menemen"]
            : ["tavuk tantuni", "tavuk ızgara", "çökertme kebabı", "tavuk şiş", "tavuk külbastı", "çıtır tavuk", "tavuk şinitzel", "et tantuni"];
        
        final fields = mealType == 'kahvalti' 
            ? ["ana_kahvalti", "diger1", "diger2", "diger3"]
            : ["yemek1", "yemek2", "pilav_makarna", "ekstra"];

        String? foundFavorite;
        
        for (final meal in meals) {
          for (final field in fields) {
            if (!meal.containsKey(field)) continue;
            final mealStr = meal[field]?.toString() ?? "";
            final mealLower = mealStr.toLowerCase();
            for (final fav in favorites) {
              if (mealLower.contains(fav.toLowerCase())) {
                foundFavorite = mealStr;
                break;
              }
            }
            if (foundFavorite != null) break;
          }
          if (foundFavorite != null) break;
        }

        if (foundFavorite != null) {
            bodyText = mealType == 'kahvalti' 
               ? "Bugün kahvaltıda $foundFavorite var"
               : "Bu akşam favorilerden $foundFavorite var";
        }
    } catch (dbError) {
        debugPrint("⚠️ Background DB fetch error: $dbError");
        // Fallback to cached favorite
        final favName = prefs.getString("${mealType}_favori_adi") ?? "";
        if (favVar && favName.isNotEmpty) {
           bodyText = mealType == 'kahvalti' 
               ? "Bugün kahvaltıda $favName var"
               : "Bu akşam favorilerden $favName var";
        }
    }

    // 4. Show Notification!
    await NotificationService.initializeNotification(requestPermissions: false);
    await NotificationService.showImmediate(
      id: notificationId,
      title: defaultTitle,
      body: bodyText,
    );
    
    debugPrint("✅ [BACKGROUND] Notification Shown: $bodyText");
  } catch (e) {
    debugPrint("❌ [BACKGROUND] Error in _processDailyNotification: $e");
  }
}
