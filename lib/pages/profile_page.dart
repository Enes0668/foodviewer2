import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController();
  
  String? _gender;

  double _bmi = 0;
  String _bmiStatus = "";

  double _todaySelectedCalories = 0;
  double totalCalories = 0;
  int recommendedSteps = 0;

  double _burnedCalories = 0;
  double _calorieBalance = 0;
  double _enteredSteps = 0;
  String? _city;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Color _fieldBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade200;
  }

  Color darken(Color color, [double amount = .08]) {
  final hsl = HSLColor.fromColor(color);
  final hslDark =
      hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}

  Color _orangeBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.orange.shade900
        : Colors.orange.shade100;
  }

  Color _greenBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.green.shade900
        : Colors.green.shade100;
  }

  // -------------------------------------------------------------
  // 📌 SharedPreferences Yükleme
  // -------------------------------------------------------------
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    _heightController.text = prefs.getString("height") ?? "";
    _weightController.text = prefs.getString("weight") ?? "";
    _ageController.text = prefs.getString("age") ?? "";
    _gender = prefs.getString("gender");

    _city = prefs.getString("selected_city");

    _bmi = prefs.getDouble("bmi") ?? 0;
    _bmiStatus = prefs.getString("bmiStatus") ?? "";

    final todayKey =
    "todayCalories_${DateTime.now().toIso8601String().substring(0, 10)}";

    _todaySelectedCalories = prefs.getDouble(todayKey) ?? 0;
    totalCalories = _todaySelectedCalories;


    _stepsController.text = prefs.getString("steps") ?? "";
    
    setState(() {});
    
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("height", _heightController.text);
    prefs.setString("weight", _weightController.text);
    prefs.setString("age", _ageController.text);
    if (_gender != null) prefs.setString("gender", _gender!);
  }

  Future<void> _saveBMI() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble("bmi", _bmi);
    prefs.setString("bmiStatus", _bmiStatus);
  }

  Future<void> _saveSteps() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("steps", _stepsController.text);
  }

  // -------------------------------------------------------------
  // 🧮 VKİ Hesapla
  // -------------------------------------------------------------
  void _calculateBMI() {
    final h = double.tryParse(_heightController.text);
    final w = double.tryParse(_weightController.text);

    if (h == null || w == null || h <= 0 || w <= 0) {
      _show("Lütfen geçerli boy ve kilo girin.");
      return;
    }

    // 📏 VALIDATION: Boy ve Kilo
    if (h < 100 || h > 250) {
      _show("Boy 100 ile 250 cm arasında olmalıdır.");
      return;
    }
    if (w < 30 || w > 250) {
      _show("Kilo 30 ile 250 kg arasında olmalıdır.");
      return;
    }

    final bmi = w / ((h / 100) * (h / 100));

    String status;
    if (bmi < 18.5) status = "Zayıf";
    else if (bmi < 25) status = "Normal";
    else if (bmi < 30) status = "Fazla kilolu";
    else status = "Obez";

    setState(() {
      _bmi = double.parse(bmi.toStringAsFixed(1));
      _bmiStatus = status;
    });

    _saveBMI();
    _saveDailyDataToSupabase();
  }

  // -------------------------------------------------------------
  // ⚡ Adım Önerme Algoritması (Motivasyon Odaklı)
  // -------------------------------------------------------------
  int _calculateSmartSteps({
    required double calories,
    required double bmi,
    required String gender,
  }) {
    int base = 8000;

    if (bmi < 18.5) base = 7000;
    else if (bmi < 25) base = 8000;
    else if (bmi < 30) base = 9000;
    else base = 8500;

    if (calories > 1200) base += 1000;
    else if (calories > 800) base += 500;
    else if (calories < 600) base -= 700;

    if (gender == "erkek") base += 300;

    return base.clamp(5000, 12000);
  }

  // -------------------------------------------------------------
  // 🔥 Kalori & Adım Hesaplama
  // -------------------------------------------------------------
  Future<void> _calculateMeals() async {
  if (_bmi == 0) return _show("Önce VKİ hesaplayın.");
  if (_gender == null) return _show("Lütfen cinsiyet seçin.");

  // 1. Validasyon Kontrolleri (Önce bunları yapalım)
  final h = double.tryParse(_heightController.text);
  final w = double.tryParse(_weightController.text);
  final age = int.tryParse(_ageController.text);
  final steps = double.tryParse(_stepsController.text);

  if (h == null || h < 100 || h > 250) {
    _show("Boy 100 ile 250 cm arasında olmalıdır.");
    return;
  }
  if (w == null || w < 30 || w > 250) {
    _show("Kilo 30 ile 250 kg arasında olmalıdır.");
    return;
  }
  if (age == null || age < 16 || age > 60) {
    _show("Yaş 16 ile 60 arasında olmalıdır.");
    return;
  }
  
  if (steps == null || steps < 0 || steps > 60000) {
    _show("Günlük adım sayısı 0 ile 60.000 arasında olmalıdır.");
    return;
  }

  final prefs = await SharedPreferences.getInstance();

  // 🔒 PROFİL HER ZAMAN BUGÜNÜ OKUR
  final todayKey =
      "todayCalories_${DateTime.now().toIso8601String().substring(0, 10)}";

  final calories = prefs.getDouble(todayKey) ?? 0;

  final burned = steps * 0.04;

  final suggested = _calculateSmartSteps(
    calories: calories,
    bmi: _bmi,
    gender: _gender!,
  );

  setState(() {
    _enteredSteps = steps;
    totalCalories = calories;
    _burnedCalories = double.parse(burned.toStringAsFixed(1));
    _calorieBalance =
        double.parse((calories - burned).toStringAsFixed(1));
    recommendedSteps = suggested;
  });

  await _saveDailyDataToSupabase();
}

Future<String> getDeviceId() async {
  // 🔒 GÜVENLİK GÜNCELLEMESİ:
  // Artık rastgele bir ID yerine, Supabase'in gerçek User ID'sini kullanıyoruz.
  // Bu sayede veritabanında "Sadece kendi verini gör/düzenle" (RLS) kuralları çalışabilir.
  final userId = Supabase.instance.client.auth.currentUser?.id;
  
  if (userId == null) {
    // Eğer internet yoksa veya auth başarısızsa geçici olarak eski yönteme dön
    // Amaç: Uygulama çökmesin.
    final prefs = await SharedPreferences.getInstance();
    var localId = prefs.getString("device_id");
    if (localId == null) {
      localId = const Uuid().v4();
      await prefs.setString("device_id", localId);
    }
    return localId;
  }
  
  return userId;
}

Future<void> _saveDailyDataToSupabase() async {
  final supabase = Supabase.instance.client;

  final deviceId = await getDeviceId();
  final today = DateTime.now().toIso8601String().substring(0, 10);

  final data = {
    "device_id": deviceId,
    "date": today,

    "city": _city,

    "height": double.tryParse(_heightController.text),
    "weight": double.tryParse(_weightController.text),
    "age": int.tryParse(_ageController.text),
    "gender": _gender,

    "bmi": _bmi,
    "bmi_status": _bmiStatus,

    "steps": _enteredSteps.toInt(),
    "recommended_steps": recommendedSteps,

    "total_calories": totalCalories,
    "burned_calories": _burnedCalories,
    "calorie_balance": _calorieBalance,
  };

  await supabase
      .from('daily_health')
      .upsert(
        data,
        onConflict: 'device_id,date',
      );
}


  // -------------------------------------------------------------
  // Yardımcı
  // -------------------------------------------------------------
  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -------------------------------------------------------------
  // Cinsiyet Kartı
  // -------------------------------------------------------------
  Widget genderSelector() {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        const Text("Cinsiyetiniz",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _genderCard(
                "Erkek",
                Icons.male,
                Colors.blue,
                _gender == "erkek",
                () {
                  setState(() => _gender = "erkek");
                  _saveUserData();
                },
                dark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _genderCard(
                "Kadın",
                Icons.female,
                Colors.pink,
                _gender == "kadın",
                () {
                  setState(() => _gender = "kadın");
                  _saveUserData();
                },
                dark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _genderCard(
      String text, IconData icon, Color color, bool selected, VoidCallback tap, bool dark) {
    return GestureDetector(
      onTap: tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color : (dark ? Colors.grey.shade700 : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 32,
                color: selected ? Colors.white : (dark ? Colors.white : Colors.black)),
            const SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(
                color: selected ? Colors.white : (dark ? Colors.white : Colors.black),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bmiBar() {
    if (_bmi == 0) return const SizedBox();

    double pos = (_bmi / 40).clamp(0, 1);

    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          "Vücut Kitle İndeksi (VKİ)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            return Container(
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.green, Colors.orange, Colors.red],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 500),
                    left: pos * c.maxWidth - 2,
                    child: Container(
                      width: 4,
                      height: 30,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          "VKİ: $_bmi ($_bmiStatus)",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  

  // -------------------------------------------------------------
  // 📌 BUILD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // 🔥 Hedef ilerlemesi — %100’den yukarı gösterim çıkmayacak
    double progressValue = recommendedSteps > 0
        ? (_enteredSteps / recommendedSteps * 100)
        : 0;
    Color cardBg(BuildContext context) {
  final theme = Theme.of(context);
  return isDark
      ? theme.primaryColor.withOpacity(0.35)
      : theme.primaryColor.withOpacity(0.15);
}
    String progressText = progressValue.clamp(0, 100).toStringAsFixed(0);
    final theme = Theme.of(context);
final primary = theme.primaryColor;
final buttonColor = isDark ? darken(primary, 0.08) : primary;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        centerTitle: true,
        title: Text(
  "Profil",
  style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Kişisel Bilgiler",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            TextField(
              controller: _heightController,
              decoration: InputDecoration(
                labelText: "Boy (cm)",
                labelStyle: TextStyle(color: dark ? Colors.white : Colors.black),
                filled: true,
                fillColor: _fieldBg(context),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _saveUserData(),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _weightController,
              decoration: InputDecoration(
                labelText: "Kilo (kg)",
                labelStyle: TextStyle(color: dark ? Colors.white : Colors.black),
                filled: true,
                fillColor: _fieldBg(context),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _saveUserData(),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _ageController,
              decoration: InputDecoration(
                labelText: "Yaş",
                labelStyle: TextStyle(color: dark ? Colors.white : Colors.black),
                filled: true,
                fillColor: _fieldBg(context),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _saveUserData(),
            ),

            const SizedBox(height: 25),

            genderSelector(),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _calculateBMI,
              child: Text("VKİ Hesapla", style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),),
            ),

            if (_bmi > 0) _bmiBar(),

            const SizedBox(height: 30),

            TextField(
              controller: _stepsController,
              decoration: InputDecoration(
                labelText: "Bugün attığınız adım sayısı",
                labelStyle: TextStyle(color: dark ? Colors.white : Colors.black),
                filled: true,
                fillColor: _fieldBg(context),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _saveSteps(),
            ),

            const SizedBox(height: 30),


// Koyu temadaysa koyu tonunu kullan
            ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: buttonColor,
    foregroundColor: Colors.white, // Yazı rengi her zaman beyaz
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  onPressed: _calculateMeals,
  child: Text(
    "Kalori ve Adım Hesapla",
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
  ),
),

            const SizedBox(height: 25),

            if (totalCalories > 0 || _burnedCalories > 0)
              Column(
                children: [
                  // ----------------- Kalori Kartı -----------------
                  Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: cardBg(context),
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        "Aldığınız Kalori: ${totalCalories.toStringAsFixed(0)} kcal",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        "Yaktığınız Kalori: ${_burnedCalories.toStringAsFixed(0)} kcal",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: textColor,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        "Günlük Kalori Dengesi: ${_calorieBalance.toStringAsFixed(0)} kcal",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: textColor,
        ),
      ),
    ],
  ),
),


                  const SizedBox(height: 15),

                  // ----------------- Adım Kartı -----------------
                  if (recommendedSteps > 0)
                    Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: cardBg(context),
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        "Önerilen Günlük Adım: $recommendedSteps",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        "Bugünkü Adımınız: ${_enteredSteps.toStringAsFixed(0)}",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: textColor,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        "Hedefe Yakınlık: %$progressText",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: textColor,
        ),
      ),
    ],
  ),
),

                ],
              ),
          ],
        ),
      ),
    );
  }
}
