import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:foodviewer/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';
import '../services/background_task_service.dart';
import 'theme_page.dart';
import 'feedback_page.dart';
import 'help_us_page.dart';
import '../widgets/custom_loading.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _breakfastNotificationEnabled = false;
  bool _dinnerNotificationEnabled = false;
  bool _loading = true;

  // 81 İl
  final List<String> _cities = [
    "Adana",
    "Adıyaman",
    "Afyonkarahisar",
    "Ağrı",
    "Aksaray",
    "Amasya",
    "Ankara",
    "Antalya",
    "Ardahan",
    "Artvin",
    "Aydın",
    "Balıkesir",
    "Bartın",
    "Batman",
    "Bilecik",
    "Bingöl",
    "Bitlis",
    "Bolu",
    "Burdur",
    "Bursa",
    "Çanakkale",
    "Çankırı",
    "Çorum",
    "Denizli",
    "Diyarbakır",
    "Düzce",
    "Edirne",
    "Elazığ",
    "Erzincan",
    "Erzurum",
    "Eskişehir",
    "Gaziantep",
    "Giresun",
    "Gümüşhane",
    "Hakkari",
    "Hatay",
    "Iğdır",
    "Isparta",
    "İstanbul",
    "İzmir",
    "Kahramanmaraş",
    "Karabük",
    "Karaman",
    "Kastamonu",
    "Kayseri",
    "Kırıkkale",
    "Kırklareli",
    "Kırşehir",
    "Kocaeli",
    "Konya",
    "Kütahya",
    "Malatya",
    "Manisa",
    "Mardin",
    "Mersin",
    "Muğla",
    "Muş",
    "Nevşehir",
    "Niğde",
    "Ordu",
    "Osmaniye",
    "Rize",
    "Sakarya",
    "Samsun",
    "Siirt",
    "Sinop",
    "Sivas",
    "Tekirdağ",
    "Tokat",
    "Trabzon",
    "Tunceli",
    "Şanlıurfa",
    "Uşak",
    "Van",
    "Yalova",
    "Yozgat",
    "Zonguldak",
  ];

  String normalizeCity(String city) {
    final map = {
      "Istanbul": "İstanbul",
      "ISTANBUL": "İstanbul",
      "Izmir": "İzmir",
      "IZMIR": "İzmir",
      "Sanliurfa": "Şanlıurfa",
      "SANLIURFA": "Şanlıurfa",
      "Canakkale": "Çanakkale",
      "Eskisehir": "Eskişehir",
      "Kutahya": "Kütahya",
      "Mugla": "Muğla",
      "Corum": "Çorum",
      "Igdir": "Iğdır",
    };

    return map[city] ?? city;
  }

  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _breakfastNotificationEnabled =
        prefs.getBool("breakfast_notification") ?? false;
    _dinnerNotificationEnabled = prefs.getBool("dinner_notification") ?? false;

    final savedCity = prefs.getString("selected_city");
    final fixedCity = savedCity != null ? normalizeCity(savedCity) : "Karaman";

    _selectedCity = _cities.contains(fixedCity) ? fixedCity : "Karaman";

    setState(() {
      _loading = false;
    });
  }

  Future<void> _saveBreakfastNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("breakfast_notification", value);
  }

  Future<void> _saveDinnerNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("dinner_notification", value);
  }

  Future<void> _checkExactAlarmPermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final status = await Permission.scheduleExactAlarm.status;
    if (!status.isGranted) {
      // Android 12+ (API 31+) için kullanıcıdan izin isteşi
      await Permission.scheduleExactAlarm.request();
    }
  }

  Future<bool> _checkBatteryOptimization() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      // Eğer optimizasyon açıksa (uygulama kısıtlamadaysa) kullanıcıya sor
      final result = await Permission.ignoreBatteryOptimizations.request();
      if (result.isGranted) {
        debugPrint("🔋 Pil optimizasyonu başarıyla kapatıldı.");
        return true;
      }
      return false; // İzin verilmedi
    }
    return true; // Zaten izin verilmiş
  }

  Future<void> _onToggleBreakfast(bool value) async {
    if (value) {
      final hasBatteryOpt = await _checkBatteryOptimization();
      if (!hasBatteryOpt) {
        setState(() => _breakfastNotificationEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Pil optimizasyonu reddedildi. Arka plan işlemleri kısıtlanabilir.',
              ),
            ),
          );
        }
        return;
      }

      await _checkExactAlarmPermission();
      final status = await Permission.scheduleExactAlarm.status;
      if (!kIsWeb && Platform.isAndroid && status.isDenied) {
        // Eğer kullanıcı reddettiyse switch'i açtırma
        setState(() => _breakfastNotificationEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Lütfen ayarlardan "Alarmlar ve hatırlatıcılar" iznini verin.',
              ),
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _breakfastNotificationEnabled = value;
    });

    await _saveBreakfastNotification(value);

    if (value) {
      // Start Alarm Manager for 06:00
      final now = DateTime.now();
      DateTime scheduleTime = DateTime(now.year, now.month, now.day, 6, 0);
      if (scheduleTime.isBefore(now)) {
        scheduleTime = scheduleTime.add(const Duration(days: 1));
      }

      await AndroidAlarmManager.oneShotAt(
        scheduleTime,
        200, // Alarm ID
        backgroundBreakfastTask,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      // YEDEK: Native Local Notification (Her zaman çalışır)
      await NotificationService.scheduleDaily(
        hour: 6,
        minute: 0,
        title: "🍳 Kahvaltı Zamanı!",
        body: "Gün güzel bir kahvaltıyla başlar!",
        id: 200,
      );
    } else {
      // Cancel Alarm
      await AndroidAlarmManager.cancel(200);
      await NotificationService.notifications.cancel(200);
    }
  }

  Future<void> _onToggleDinner(bool value) async {
    if (value) {
      final hasBatteryOpt = await _checkBatteryOptimization();
      if (!hasBatteryOpt) {
        setState(() => _dinnerNotificationEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Pil optimizasyonu reddedildi. Arka plan işlemleri kısıtlanabilir.',
              ),
            ),
          );
        }
        return;
      }

      await _checkExactAlarmPermission();
      final status = await Permission.scheduleExactAlarm.status;
      if (!kIsWeb && Platform.isAndroid && status.isDenied) {
        // Eğer kullanıcı reddettiyse switch'i açtırma
        setState(() => _dinnerNotificationEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Lütfen ayarlardan "Alarmlar ve hatırlatıcılar" iznini verin.',
              ),
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _dinnerNotificationEnabled = value;
    });

    await _saveDinnerNotification(value);

    if (value) {
      // Start Alarm Manager for 16:00
      final now = DateTime.now();
      DateTime scheduleTime = DateTime(now.year, now.month, now.day, 16, 0);
      if (scheduleTime.isBefore(now)) {
        scheduleTime = scheduleTime.add(const Duration(days: 1));
      }

      await AndroidAlarmManager.oneShotAt(
        scheduleTime,
        201, // Alarm ID
        backgroundDinnerTask,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      // YEDEK: Native Local Notification (Her zaman çalışır)
      await NotificationService.scheduleDaily(
        hour: 16,
        minute: 0,
        title: "🍽 Akşam Yemeği Zamanı!",
        body: "Akşam yemeği seni bekliyor!",
        id: 201,
      );
    } else {
      // Cancel Alarm
      await AndroidAlarmManager.cancel(201);
      await NotificationService.notifications.cancel(201);
    }
  }

  Future<void> _saveSelectedCity(String? city) async {
    if (city == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("selected_city", city);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.effectivePrimaryColor;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Ayarlar",
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: themeColor,
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: CustomLoadingAnimation(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // 📍 KONUM AYARLARI
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: primaryColor),
                              SizedBox(width: 8),
                              Text(
                                "Konum Ayarları",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _cities.contains(_selectedCity)
                                ? _selectedCity
                                : null,
                            items: _cities
                                .map(
                                  (city) => DropdownMenuItem(
                                    value: city,
                                    child: Text(city),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) async {
                              setState(() {
                                _selectedCity = value;
                              });
                              await _saveSelectedCity(value);

                              // 🛑 Şehir değiştiğinde mevcut bildirimleri kapat
                              if (_breakfastNotificationEnabled) {
                                await _onToggleBreakfast(false);
                              }
                              if (_dinnerNotificationEnabled) {
                                await _onToggleDinner(false);
                              }

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Konum değiştiği için bildirimler kapatıldı.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Bulunduğun İl",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🔔 BİLDİRİM AYARLARI
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notifications_active,
                                color: primaryColor,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Bildirim Ayarları",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      "Günlük kahvaltı bildirimi al",
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  Switch(
                                    value: _breakfastNotificationEnabled,
                                    activeColor:
                                        themeProvider.rawPrimaryColor.value ==
                                            ThemePage.customGrey.value
                                        ? ThemePage.customGrey
                                        : themeProvider.primaryColor,
                                    onChanged: _onToggleBreakfast,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      "Günlük akşam yemeği bildirimi al",
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  Switch(
                                    value: _dinnerNotificationEnabled,
                                    activeColor:
                                        themeProvider.rawPrimaryColor.value ==
                                            ThemePage.customGrey.value
                                        ? ThemePage.customGrey
                                        : themeProvider.primaryColor,
                                    onChanged: _onToggleDinner,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 🎨 TEMA
                  _navTile(
                    icon: Icons.color_lens,
                    title: "Tema",
                    subtitle: "Renk ve karanlık mod ayarları",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ThemePage()),
                      );
                    },
                    iconColor: primaryColor, // buraya istediğin rengi ver
                  ),

                  const SizedBox(height: 12),

                  // 💬 GERİ BİLDİRİM
                  _navTile(
                    icon: Icons.chat,
                    title: "Geri Bildirim",
                    subtitle: "Görüş ve önerilerini ilet",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FeedbackPage()),
                      );
                    },
                    iconColor: primaryColor,
                  ),

                  const SizedBox(height: 12),

                  // ❤️ BİZE YARDIMCI OL
                  _navTile(
                    icon: Icons.volunteer_activism,
                    title: "Bize Yardımcı Olmak İster Misiniz?",
                    subtitle: "KYK yemek listesini paylaş",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpUsPage()),
                      );
                    },
                    iconColor: primaryColor,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? Theme.of(context).colorScheme.primary,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
