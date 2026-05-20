import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:foodviewer/pages/entry_page.dart';
import 'package:foodviewer/pages/welcome_page.dart';
import 'package:foodviewer/pages/kvkk_page.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'theme_provider.dart';
import 'services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foodviewer/pages/video_instruction_screen.dart';
import 'package:media_kit/media_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Load env.txt
  await dotenv.load(fileName: "env.txt");

  // Supabase init
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_KEY']!,
  );

  // Oturum kontrolü — kayıtlı kullanıcı yoksa anonim oturum aç (RLS için şart)
  try {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      await Supabase.instance.client.auth.signInAnonymously();
      debugPrint("👤 Anonim oturum açıldı");
    } else {
      debugPrint("👤 Oturum devam ediyor — anonim: ${session.user.isAnonymous}, id: ${session.user.id}");
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

  final prefs = await SharedPreferences.getInstance();
  final welcomeShown = prefs.getBool('welcome_shown') ?? false;
  final kvkkAccepted = prefs.getBool('kvkk_accepted') ?? false;

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: FoodViewerApp(
        showWelcome: !welcomeShown,
        kvkkAccepted: kvkkAccepted,
      ),
    ),
  );
}

class FoodViewerApp extends StatelessWidget {
  final bool showWelcome;
  final bool kvkkAccepted;
  const FoodViewerApp({
    super.key,
    required this.showWelcome,
    required this.kvkkAccepted,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    Widget home;
    if (!kvkkAccepted) {
      home = KvkkPage(showWelcome: showWelcome);
    } else if (showWelcome) {
      home = const WelcomePage();
    } else {
      home = const EntryPage();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      home: home,
    );
  }
}
