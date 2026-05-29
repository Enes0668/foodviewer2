import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodviewer/pages/araogun_page.dart';
import 'package:foodviewer/services/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../theme_provider.dart';
import '../services/location_service.dart';
import '../widgets/custom_loading.dart';
import 'package:foodviewer/pages/video_instruction_screen.dart';
import 'package:foodviewer/pages/welcome_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  DateTime selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isAraOgunLoading = true;
  String? _deviceId;
  List<Map<String, dynamic>> kahvaltilar = [];
  List<Map<String, dynamic>> aksamYemekleri = [];
  List<Map<String, dynamic>> araOgunler = [];

  /// 📌 SharedPreferences’te saklanacak seçim map'i
  final Map<String, bool> _selectedItems = {};
  String? _userCity;
  final ValueNotifier<List<Map<String, dynamic>>> araOgunlerNotifier =
      ValueNotifier([]);
  final Map<String, String> _labels = {
    "ana_kahvalti": "Ana Kahvaltı",
    "diger1": "Ekstra 1",
    "diger2": "Ekstra 2",
    "diger3": "Ekstra 3",
    "yemek1": "Ana Yemek",
    "yemek2": "Çorba",
    "pilav_makarna": "Pilav / Makarna",
    "ekstra": "Ekstra",
  };

  final List<String> kahvaltiFavoriler = [
    "patates kızartması",
    "sade pişi",
    "karışık pizza",
    "menemen",
  ];

  final List<String> aksamFavoriler = [
    "tavuk tantuni",
    "tavuk ızgara",
    "çökertme kebabı",
    "tavuk şiş",
    "tavuk külbastı",
    "çıtır tavuk",
    "tavuk şinitzel",
    "et tantuni",
    "burger",
    "tavuk burger",
    "fırında köri soslu tavuk",
    "tavuk çökertme",
    "fırında beşamel soslu tavuk",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 🔒 Auth Bekleme Mekanizması
      // Eğer kullanıcı henüz giriş yapmamışsa (null ise),
      // Supabase'in auth state değişimini bekle.
      // Bu sayede "Unauthorized" hatası almaktan kurtuluruz.

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        debugPrint("⏳ Auth bekleniyor...");
        // Auth state değişimini dinle (ilk event gelene kadar)
        await Supabase.instance.client.auth.onAuthStateChange.first;
        debugPrint("✅ Auth tamamlandı!");
      }

      await _initDeviceId();
      await _loadSelections();
      await _loadUserCity(); // İlk olarak Konum izni
      
      await _fetchMeals();
      
      _syncSelectionsWithDB(); // Yemekler yüklendikten sonra DB'den seçim durumunu getir (bloklamadan)
      NotificationService.requestPermissionsAsync(); // Bildirim izni (Bloklamadan sorulsun)
      // İzinden ve verilerden sonra video gösterme mantığı
      final prefs = await SharedPreferences.getInstance();

      final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
      if (isFirstLaunch) {
        await prefs.setBool('is_first_launch', false);
        if (mounted) {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false, // Arkaplanı saydam yapar, arkada menü görünür
              pageBuilder: (context, _, __) => const VideoInstructionScreen(),
              transitionsBuilder: (context, animation, _, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      }
    });
  }

  Future<void> _loadSelections() async {
    // 1. Önce SharedPreferences'tan yükle (Hızlı açılış için)
    final prefs = await SharedPreferences.getInstance();
    final savedMap = prefs.getStringList("selected_items") ?? [];

    _selectedItems.clear();
    for (final key in savedMap) {
      _selectedItems[key] = true;
    }
    setState(() {});
  }

  // Yeni Senkronizasyon Metodu (FetchMeals sonrasında da çağrılabilir)
  Future<void> _syncSelectionsWithDB() async {
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id;

    if (userId == null) return;

    final dateKey = DateFormat("yyyy-MM-dd").format(selectedDate);
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('user_selected_meals')
          .select()
          .eq('device_id', userId)
          .eq('meal_date', dateKey);

      final dbSelections = List<Map<String, dynamic>>.from(response);

      // Kahvaltılar eşleştirme
      for (int i = 0; i < kahvaltilar.length; i++) {
        final meal = kahvaltilar[i];
        for (final field in ["ana_kahvalti", "diger1", "diger2", "diger3"]) {
          final mealNameStr = meal[field];
          if (mealNameStr == null) continue;
          final kcalStr = meal["${field}_kalori"] ?? "";
          
          final options = _parseMealOptions(mealNameStr.toString(), kcalStr.toString());

          for (int optIdx = 0; optIdx < options.length; optIdx++) {
            final exists = dbSelections.any(
              (item) =>
                  item["meal_type"] == "kahvalti" &&
                  item["meal_field"] == field &&
                  item["meal_name"] == options[optIdx].name,
            );

            if (exists) {
              final key = _buildSelectionKey("kahvalti", i, field, optIdx: optIdx);
              _selectedItems[key] = true;
            }
          }
        }
      }

      // Akşam Yemekleri eşleştirme
      for (int i = 0; i < aksamYemekleri.length; i++) {
        final meal = aksamYemekleri[i];
        for (final field in ["yemek1", "yemek2", "pilav_makarna", "ekstra"]) {
          final mealNameStr = meal[field];
          if (mealNameStr == null) continue;
          final kcalStr = meal["${field}_kalori"] ?? "";

          final options = _parseMealOptions(mealNameStr.toString(), kcalStr.toString());

          for (int optIdx = 0; optIdx < options.length; optIdx++) {
            final exists = dbSelections.any(
              (item) =>
                  item["meal_type"] == "aksam" &&
                  item["meal_field"] == field &&
                  item["meal_name"] == options[optIdx].name,
            );

            if (exists) {
              final key = _buildSelectionKey("aksam", i, field, optIdx: optIdx);
              _selectedItems[key] = true;
            }
          }
        }
      }

      setState(() {});
      _saveSelections(); // SharedPrefs'i de güncelle
    } catch (e) {
      debugPrint("DB Sync Hatası: $e");
    }
  }

  bool _containsFavorite({
    required List<Map<String, dynamic>> meals,
    required List<String> fields,
    required List<String> favorites,
  }) {
    for (final meal in meals) {
      for (final field in fields) {
        if (!meal.containsKey(field)) continue;

        final yemek = meal[field]?.toString().toLowerCase() ?? "";
        for (final fav in favorites) {
          if (yemek.contains(fav.toLowerCase())) {
            return true;
          }
        }
      }
    }
    return false;
  }

  String? _findFavoriteMealName({
    required List<Map<String, dynamic>> meals,
    required List<String> fields,
    required List<String> favorites,
  }) {
    for (final meal in meals) {
      for (final field in fields) {
        if (!meal.containsKey(field)) continue;

        final yemek = meal[field]?.toString() ?? "";
        final yemekLower = yemek.toLowerCase();

        for (final fav in favorites) {
          if (yemekLower.contains(fav.toLowerCase())) {
            return yemek; // ⭐ ilk bulunan favori
          }
        }
      }
    }
    return null;
  }

  Future<void> _saveFavoriteMeals() async {
    final prefs = await SharedPreferences.getInstance();

    final kahvaltiFavoriAdi = _findFavoriteMealName(
      meals: kahvaltilar,
      fields: ["ana_kahvalti", "diger1", "diger2", "diger3"],
      favorites: kahvaltiFavoriler,
    );

    final aksamFavoriAdi = _findFavoriteMealName(
      meals: aksamYemekleri,
      fields: ["yemek1", "yemek2", "pilav_makarna", "ekstra"],
      favorites: aksamFavoriler,
    );

    await prefs.setString("kahvalti_favori_adi", kahvaltiFavoriAdi ?? "");
    await prefs.setBool("kahvalti_favori_var", kahvaltiFavoriAdi != null);

    await prefs.setString("aksam_favori_adi", aksamFavoriAdi ?? "");
    await prefs.setBool("aksam_favori_var", aksamFavoriAdi != null);
  }

  Future<void> _fetchAraOgunler() async {
    final deviceId = _deviceId;
    if (deviceId == null) return;

    final supabase = Supabase.instance.client;
    final dateKey = DateFormat("yyyy-MM-dd").format(selectedDate);

    try {
      final response = await supabase
          .from('ara_ogunler')
          .select()
          .eq('device_id', deviceId)
          .eq('date', dateKey)
          .eq('city', _userCity ?? "Karaman");

      final loadedList = List<Map<String, dynamic>>.from(response);
      araOgunler = loadedList;
      araOgunlerNotifier.value = loadedList;
    } catch (e) {
      debugPrint("Ara öğün fetch error: $e");
    }
  }

  Future<void> _initDeviceId() async {
    // 🔒 GÜVENLİK GÜNCELLEMESİ (RLS UYUMU)
    // Rastgele ID yerine Supabase Auth ID'sini kullanıyoruz.
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId != null) {
      _deviceId = userId;
    } else {
      // Auth henüz hazır değilse (nadir durum), yine de prefs'ten okumayı dene
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("device_id");
      if (id == null) {
        id = const Uuid().v4();
        await prefs.setString("device_id", id);
      }
      _deviceId = id;
    }
  }

  Future<void> _toggleMealInDB({
    required bool isSelected,
    required String sectionKey,
    required String field,
    required String mealName,
    required double calories,
  }) async {
    // 🔒 DOĞRUDAN AUTH ID KULLAN (Stale variable riskini önle)
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint("❌ HATA: Kullanıcı oturum açmamış, kayıt yapılamaz.");
      return;
    }

    final supabase = Supabase.instance.client;
    final date = DateFormat("yyyy-MM-dd").format(selectedDate);

    try {
      if (isSelected) {
        // DELETE existing entry for the same meal_field to avoid unique constraint violations
        await supabase
            .from("user_selected_meals")
            .delete()
            .eq("device_id", userId)
            .eq("meal_date", date)
            .eq("meal_type", sectionKey)
            .eq("meal_field", field);

        // INSERT
        await supabase.from("user_selected_meals").insert({
          "device_id": userId,
          "meal_date": date,
          "meal_type": sectionKey,
          "meal_field": field,
          "meal_name": mealName,
          "calories": calories,
          "city": _userCity,
        });
      } else {
        // DELETE
        await supabase
            .from("user_selected_meals")
            .delete()
            .eq("device_id", userId)
            .eq("meal_date", date)
            .eq("meal_type", sectionKey)
            .eq("meal_field", field);
      }
    } catch (e) {
      debugPrint("Toggle DB Hatası: $e");
    }
  }

  /// 📌 Seçimleri SharedPreferences'a kaydetme
  Future<void> _saveSelections() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedKeys = _selectedItems.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .whereType<String>() // sadece String olanları al
        .toList();
    await prefs.setStringList("selected_items", selectedKeys);
  }

  String formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return "$day.$month.${d.year}";
  }

  String getTurkishWeekday(DateTime d) {
    const weekdays = {
      1: "Pazartesi",
      2: "Salı",
      3: "Çarşamba",
      4: "Perşembe",
      5: "Cuma",
      6: "Cumartesi",
      7: "Pazar",
    };
    return weekdays[d.weekday]!;
  }

  double _parseCalorie(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();

    if (v is String) {
      final cleaned = v.replaceAll(",", ".");
      final matches = RegExp(r'(\d+(\.\d+)?)').allMatches(cleaned);

      double sum = 0;
      int count = 0;
      for (final m in matches) {
        final parsed = double.tryParse(m.group(1)!);
        if (parsed != null) {
          sum += parsed;
          count++;
        }
      }
      return count == 0 ? 0 : sum / count;
    }

    return 0;
  }
  
  List<_MealOption> _parseMealOptions(String mealStr, String kcalStr) {
    List<String> names = mealStr.split('/').map((e) => e.trim()).toList();
    List<double> kcals = [];

    // "-" veya "/" ile ayrılmış kalorileri destekle
    List<String> kcalParts = kcalStr.split(RegExp(r'[-/]')).map((e) => e.trim()).toList();
    final parsedKcals = kcalParts.map((k) {
      final matches = RegExp(r'(\d+(\.\d+)?)').allMatches(k.replaceAll(",", "."));
      if (matches.isNotEmpty) return double.parse(matches.first.group(1)!);
      return 0.0;
    }).toList();

    if (names.length > 1 && parsedKcals.length == names.length) {
      kcals = parsedKcals;
    } else {
      double fallbackKcal = _parseCalorie(kcalStr);
      kcals = List.generate(names.length, (_) => fallbackKcal);
    }

    List<_MealOption> options = [];
    for (int i = 0; i < names.length; i++) {
        // Option 1 numaralı ise ve diğeri 2 ise isimlerine göre ayrılmazsa karışır, ama zaten list order'ı map mantığı kuruyoruz.
      options.add(_MealOption(name: names[i], kcal: kcals[i]));
    }
    return options;
  }

  double _calculateAraOgunCalories() {
    double total = 0;

    for (final item in araOgunler) {
      final c = item["calories"];

      if (c is num) {
        total += c.toDouble();
      } else if (c is String) {
        total += double.tryParse(c) ?? 0;
      }
    }

    return total;
  }

  Future<void> _clearCacheIfCityChanged(String newCity) async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString("current_cached_city");
    
    if (savedCity != null && savedCity != newCity) {
      final keys = prefs.getKeys();
      for (final k in keys) {
        if (k.startsWith("cache_kahvalti_") || 
            k.startsWith("cache_aksam_") || 
            k.startsWith("cache_time_")) {
          await prefs.remove(k);
        }
      }
    }
    await prefs.setString("current_cached_city", newCity);
  }

  Future<void> _fetchMeals() async {
    setState(() => _isLoading = true);

    final currentMonthStr = DateFormat("yyyy-MM").format(selectedDate);
    final dateKeyStr = DateFormat("yyyy-MM-dd").format(selectedDate);
    final city = _userCity ?? "Karaman";
    
    await _clearCacheIfCityChanged(city);

    // Cache'den verileri yüklemeyi dene
    bool hasCache = await _loadMonthFromCache(currentMonthStr, dateKeyStr);

    if (hasCache) {
      setState(() => _isLoading = false);
      // Arka planda 6 saatten eskiyse güncelle
      _refreshMonthInBackgroundIfNeeded(currentMonthStr, city);
    } else {
      // Önbellekte yoksa Supabase'den çek
      await _fetchMonthFromSupabase(currentMonthStr, city);
      await _loadMonthFromCache(currentMonthStr, dateKeyStr);
      setState(() => _isLoading = false);
    }

    if (mounted) setState(() => _isAraOgunLoading = true);
    await _fetchAraOgunler(); // Ara öğünler anlık çekilmeye devam eder
    if (mounted) setState(() => _isAraOgunLoading = false);
    
    await _saveFavoriteMeals();
  }

  Future<bool> _loadMonthFromCache(String monthStr, String targetDate) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKeyKahvalti = "cache_kahvalti_$monthStr";
    final cacheKeyAksam = "cache_aksam_$monthStr";

    final kahvaltiJson = prefs.getString(cacheKeyKahvalti);
    final aksamJson = prefs.getString(cacheKeyAksam);

    if (kahvaltiJson != null && aksamJson != null) {
      try {
        List<dynamic> kList = json.decode(kahvaltiJson);
        List<dynamic> aList = json.decode(aksamJson);

        final kToday = kList.where((e) => e['kahvalti_tarihi'] == targetDate).toList();
        final aToday = aList.where((e) => e['aksam_tarihi'] == targetDate).toList();

        kahvaltilar = List<Map<String, dynamic>>.from(kToday);
        aksamYemekleri = List<Map<String, dynamic>>.from(aToday);
        return true;
      } catch (e) {
        debugPrint("Cache okunurken hata: $e");
      }
    }
    return false;
  }

  Future<void> _refreshMonthInBackgroundIfNeeded(String monthStr, String city) async {
    final prefs = await SharedPreferences.getInstance();
    final timeKey = "cache_time_$monthStr";
    final lastRefreshStr = prefs.getString(timeKey);

    if (lastRefreshStr != null) {
      final lastRefresh = DateTime.tryParse(lastRefreshStr);
      if (lastRefresh != null && DateTime.now().difference(lastRefresh).inHours < 6) {
        return; // 6 saat geçmemiş
      }
    }

    debugPrint("Arka planda (sessizce) aylık veri yenileniyor...");
    await _fetchMonthFromSupabase(monthStr, city);
    
    if (DateFormat("yyyy-MM").format(selectedDate) == monthStr) {
      final dateKeyStr = DateFormat("yyyy-MM-dd").format(selectedDate);
      await _loadMonthFromCache(monthStr, dateKeyStr);
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchMonthFromSupabase(String monthStr, String city) async {
    final supabase = Supabase.instance.client;
    
    final int year = int.parse(monthStr.split("-")[0]);
    final int month = int.parse(monthStr.split("-")[1]);
    
    final startDateKey = "$monthStr-01";
    // o ayın kaç çektiğini hesapla:
    final lastDay = DateTime(year, month + 1, 0).day;
    final endDateKey = "$monthStr-${lastDay.toString().padLeft(2, '0')}";

    try {
      final kResponse = await supabase
          .from('kahvaltilar')
          .select()
          .gte('kahvalti_tarihi', startDateKey)
          .lte('kahvalti_tarihi', endDateKey)
          .eq('city', city);

      final aResponse = await supabase
          .from('aksam_yemekleri')
          .select()
          .gte('aksam_tarihi', startDateKey)
          .lte('aksam_tarihi', endDateKey)
          .eq('city', city);

      // Cache'e şifrelenmiş halde kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("cache_kahvalti_$monthStr", json.encode(kResponse));
      await prefs.setString("cache_aksam_$monthStr", json.encode(aResponse));
      await prefs.setString("cache_time_$monthStr", DateTime.now().toIso8601String());
      
    } catch (e) {
      debugPrint("Aylık veri çekilirken hata: $e");
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      cancelText: "İptal",
      confirmText: "Seç",
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
      _fetchMeals();
    }
  }

  Future<void> _saveTodayCalories(double calories) async {
    final prefs = await SharedPreferences.getInstance();

    final today = DateTime.now();
    final isToday =
        today.year == selectedDate.year &&
        today.month == selectedDate.month &&
        today.day == selectedDate.day;

    if (!isToday) return; // 🚫 BUGÜN DEĞİLSE KAYDETME

    final todayKey =
        "todayCalories_${today.toIso8601String().substring(0, 10)}";

    await prefs.setDouble(todayKey, calories);
  }

  Future<void> _loadUserCity() async {
    final city = await LocationService.getCityName();
    _userCity = city ?? "Karaman";
  }

  bool _isTodaySelected() {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  String _buildSelectionKey(String sectionKey, int mealIndex, String field, {int optIdx = 0}) {
    return "$sectionKey-$mealIndex-$field-$optIdx-${formatDate(selectedDate)}";
  }

  double _calculateSectionCalories(
    List<Map<String, dynamic>> meals,
    List<String> fields,
    String sectionKey,
  ) {
    double total = 0;

    for (int i = 0; i < meals.length; i++) {
      final meal = meals[i];

      for (final field in fields) {
        if (!meal.containsKey(field)) continue;

        final mealNameStr = meal[field]?.toString() ?? "";
        final kcalStr = meal["${field}_kalori"]?.toString() ?? "";
        final options = _parseMealOptions(mealNameStr, kcalStr);

        for (int optIdx = 0; optIdx < options.length; optIdx++) {
          final itemKey = _buildSelectionKey(sectionKey, i, field, optIdx: optIdx);
          final selected = _selectedItems[itemKey] ?? false;

          if (selected) {
            total += options[optIdx].kcal;
          }
        }
      }
    }
    return total;
  }

  double _calculateTotalCaloriesWithAraOgun(
    List<Map<String, dynamic>> araOgunList,
  ) {
    final kahvaltiTotal = _calculateSectionCalories(kahvaltilar, [
      "ana_kahvalti",
      "diger1",
      "diger2",
      "diger3",
    ], "kahvalti");

    final aksamTotal = _calculateSectionCalories(aksamYemekleri, [
      "yemek1",
      "yemek2",
      "pilav_makarna",
      "ekstra",
    ], "aksam");

    final araOgunTotal = araOgunList.fold<double>(
      0,
      (sum, item) => sum + (item["calories"] ?? 0),
    );

    return kahvaltiTotal + aksamTotal + araOgunTotal;
  }

  Widget _mealCard(
    String title,
    IconData icon,
    List<Map<String, dynamic>> meals,
    List<String> fields,
    String timeLabel,
    String sectionKey, {
    Color? iconColor,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = iconColor ?? themeProvider.effectivePrimaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge!.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (meals.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: primaryColor),
              const SizedBox(width: 10),
              Text(
                "$title bulunamadı",
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sectionCalories = _calculateSectionCalories(
      meals,
      fields,
      sectionKey,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(meals.length, (mealIndex) {
          final meal = meals[mealIndex];

          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// -------- BAŞLIK --------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          timeLabel,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  /// -------- YEMEKLER --------
                  // Yemek bölümlerini filtreleyelim
                  ...() {
                    final activeFields = fields.where((field) => meal.containsKey(field)).toList();
                    final List<Widget> widgets = [];

                    for (int fieldIdx = 0; fieldIdx < activeFields.length; fieldIdx++) {
                      final field = activeFields[fieldIdx];
                      final label = _labels[field]!;
                      final yemekGroup = meal[field] ?? "-";
                      final kcalGroup = meal["${field}_kalori"] ?? "";

                      final options = _parseMealOptions(yemekGroup.toString(), kcalGroup.toString());

                      // Eğer ilk bölüm değilse, üstüne temaya uygun, şık bir ayırıcı çizgi ekle
                      if (fieldIdx > 0) {
                         widgets.add(Divider(
                           color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white24 
                              : Colors.black12,
                           thickness: 1,
                           height: 16,
                         ));
                      }

                      for (int optIdx = 0; optIdx < options.length; optIdx++) {
                        final option = options[optIdx];
                        final yemek = option.name;
                        final kcal = option.kcal;

                        final itemKey = _buildSelectionKey(
                          sectionKey,
                          mealIndex,
                          field,
                          optIdx: optIdx,
                        );
                        final isSelected = _selectedItems[itemKey] ?? false;

                        widgets.add(
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Yemek adı + favori yıldızı
                                Expanded(
                                  child: Builder(
                                    builder: (context) {
                                      final yemekLower = yemek.toLowerCase();
                                      final isFavorite =
                                          (sectionKey == "kahvalti" &&
                                              kahvaltiFavoriler.any(
                                                (f) => yemekLower.contains(f),
                                              )) ||
                                          (sectionKey == "aksam" &&
                                              aksamFavoriler.any(
                                                (f) => yemekLower.contains(f),
                                              ));

                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 85,
                                            child: Text(
                                              optIdx == 0 ? "$label:" : "",
                                              style: TextStyle(
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    yemek,
                                                    style: TextStyle(
                                                      color: Theme.of(context).brightness == Brightness.dark
                                                          ? Colors.grey[300]
                                                          : Colors.grey[800],
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                if (isFavorite)
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 4, top: 1),
                                                    child: Icon(
                                                      Icons.star,
                                                      color: primaryColor,
                                                      size: 18,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Kalori değeri
                                Text(
                                  "${kcal.toStringAsFixed(0)} kcal",
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // 🔘 Seçim butonu
                                if (_isTodaySelected())
                                  InkWell(
                                    onTap: () async {
                                      final newValue = !isSelected;
                                      final List<Future> deleteOps = [];

                                      setState(() {
                                        // Radio button mantığı (eğer açıldıysa, diğerlerini kapat)
                                        if (newValue && options.length > 1) {
                                          for (int k = 0; k < options.length; k++) {
                                            if (k != optIdx) {
                                              final otherKey = _buildSelectionKey(sectionKey, mealIndex, field, optIdx: k);
                                              if (_selectedItems[otherKey] == true) {
                                                  _selectedItems[otherKey] = false;
                                                  deleteOps.add(
                                                    _toggleMealInDB(
                                                        isSelected: false,
                                                        sectionKey: sectionKey,
                                                        field: field,
                                                        mealName: options[k].name,
                                                        calories: options[k].kcal,
                                                    )
                                                  );
                                              }
                                            }
                                          }
                                        }
                                        
                                        _selectedItems[itemKey] = newValue;
                                      });

                                      // Önce eski seçimlerin DB'den silinmesini bekle (Unique constraint hatasını önlemek için)
                                      if (deleteOps.isNotEmpty) {
                                        await Future.wait(deleteOps);
                                      }

                                      // Sonra yeni seçimi DB'ye yaz
                                      await _toggleMealInDB(
                                        isSelected: newValue,
                                        sectionKey: sectionKey,
                                        field: field,
                                        mealName: yemek,
                                        calories: kcal,
                                      );

                                      _saveSelections();
                                    },
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: isSelected
                                          ? primaryColor
                                          : Theme.of(context).disabledColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }
                    }
                    return widgets;
                  }(),
                ],
              ),
            ),
          );
        }),

        if (sectionCalories > 0)
          Center(
            child: Text(
              "Seçtiğiniz ${title.toLowerCase()} için aldığınız kalori: ${sectionCalories.toStringAsFixed(0)} kcal",
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _araOgunCard() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final color = themeProvider.effectivePrimaryColor;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(Icons.cookie, color: color),
        title: const Text(
          "Ara Öğünler",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          araOgunler.isEmpty
              ? "Henüz ara öğün eklenmedi"
              : "${_calculateAraOgunCalories().toStringAsFixed(0)} kcal",
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () async {
          final deviceId = _deviceId;
          if (deviceId == null) return;

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AraOgunPage(
                initialAraOgunler: araOgunler,
                selectedDate: selectedDate,
                deviceId: deviceId,
              ),
            ),
          );

          if (result != null) {
            setState(() {
              araOgunler = List<Map<String, dynamic>>.from(result);
              araOgunlerNotifier.value = araOgunler;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.effectivePrimaryColor;
    final textColor = themeProvider.isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: primaryColor.withOpacity(.08),
      appBar: AppBar(
        backgroundColor: themeColor,
        centerTitle: true,
        title: Text(
          "Günün Menüsü",
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (Supabase.instance.client.auth.currentUser?.isAnonymous == false)
            TextButton.icon(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                await Supabase.instance.client.auth.signInAnonymously();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomePage()),
                  (_) => false,
                );
              },
              icon: Icon(Icons.logout, size: 18,
                  color: Theme.of(context).colorScheme.onPrimary),
              label: Text('Çıkış Yap',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600)),
            )
          else
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WelcomePage()),
                );
              },
              icon: Icon(Icons.login, size: 18,
                  color: Theme.of(context).colorScheme.onPrimary),
              label: Text('Giriş Yap',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(
                            () => selectedDate = selectedDate.subtract(
                              const Duration(days: 1),
                            ),
                          );
                          _fetchMeals();
                        },
                  icon: Icon(Icons.arrow_back_ios, color: primaryColor),
                ),
                GestureDetector(
                  onTap: _selectDate,
                  child: Column(
                    children: [
                      Text(
                        formatDate(selectedDate),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        getTurkishWeekday(selectedDate),
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(
                            () => selectedDate = selectedDate.add(
                              const Duration(days: 1),
                            ),
                          );
                          _fetchMeals();
                        },
                  icon: Icon(Icons.arrow_forward_ios, color: primaryColor),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _isLoading
                ? Center(child: CustomLoadingAnimation(color: primaryColor))
                : Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _mealCard(
                            "Kahvaltılar",
                            Icons.free_breakfast, // sadece IconData gönder
                            kahvaltilar,
                            ["ana_kahvalti", "diger1", "diger2", "diger3"],
                            "06:00 - 12:00",
                            "kahvalti",
                            iconColor: primaryColor, // buraya renk ekledik
                          ),
                          const SizedBox(height: 20),
                          _mealCard(
                            "Akşam Yemekleri",
                            Icons.dinner_dining,
                            aksamYemekleri,
                            ["yemek1", "yemek2", "pilav_makarna", "ekstra"],
                            "16:00 - 22:00",
                            "aksam",
                            iconColor: primaryColor, // renk buraya
                          ),
                          if (_isTodaySelected()) _araOgunCard(),
                        ],
                      ),
                    ),
                  ),

            ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: araOgunlerNotifier,
              builder: (context, araOgunlerValue, _) {
                final total = _calculateTotalCaloriesWithAraOgun(
                  araOgunlerValue,
                );
                _saveTodayCalories(total);

                if (!_isTodaySelected() || total == 0) return const SizedBox();

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(.20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _isAraOgunLoading
                        ? "Kalori Yükleniyor..."
                        : "Aldığınız Toplam Kalori: ${total.toStringAsFixed(0)} kcal",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Eğer kullanıcı bugün sekmesindeyse, yeni gün gelmiş mi kontrol et ve tarihi güncelle.
      if (_isTodaySelected()) {
        final now = DateTime.now();
        if (selectedDate.day != now.day || selectedDate.month != now.month || selectedDate.year != now.year) {
          setState(() {
            selectedDate = now;
          });
        }
      }
      // Uygulama arka plandan döndüğünde güncel veriyi (ve 6 saat kuralını) tekrar kontrol et
      _fetchMeals();
    }
  }
}

class _MealOption {
  final String name;
  final double kcal;
  
  _MealOption({required this.name, required this.kcal});
}
