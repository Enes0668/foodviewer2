import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodviewer/pages/entry_page.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'theme_provider.dart';
import 'services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env
  await dotenv.load(fileName: ".env");

  // Supabase init
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_KEY']!,
  );

  // 🔒 Anonymous Auth (Gizli Oturum Açma)
  // Bu sayede veritabanına sadece "giriş yapmış" kullanıcılar erişebilir (RLS için şart).
  try {
    final session = await Supabase.instance.client.auth.currentSession;
    if (session == null) {
      await Supabase.instance.client.auth.signInAnonymously();
      debugPrint(
        "👤 Yeni anonim kullanıcı oluşturuldu: ${Supabase.instance.client.auth.currentUser?.id}",
      );
    } else {
      debugPrint("👤 Mevcut kullanıcı ile devam ediliyor: ${session.user.id}");
    }
  } catch (e) {
    debugPrint("⚠️ Auth Error: $e");
  }

  // Notification service init
  await NotificationService.initializeNotification(requestPermissions: false);
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await AndroidAlarmManager.initialize();
    } catch (e) {
      debugPrint("AlarmManager init failed: $e");
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const FoodViewerApp(),
    ),
  );
}

class FoodViewerApp extends StatelessWidget {
  const FoodViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      home: const EntryPage(),
    );
  }
}
