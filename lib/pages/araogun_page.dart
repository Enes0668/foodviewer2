import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:foodviewer/theme_provider.dart';

class AraOgunPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialAraOgunler;
  final DateTime selectedDate;
  final String deviceId;

  const AraOgunPage({
    super.key,
    required this.initialAraOgunler,
    required this.selectedDate,
    required this.deviceId,
  });

  @override
  State<AraOgunPage> createState() => _AraOgunPageState();
}

class _AraOgunPageState extends State<AraOgunPage> {
  late List<Map<String, dynamic>> araOgunler;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController calorieController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String _userCity = "Karaman"; // default

  @override
  void initState() {
    super.initState();
    araOgunler = List.from(widget.initialAraOgunler);
    _init(); // async init
  }

  Future<void> _init() async {
    await _loadUserCity();
    await _loadAraOgunler();
  }

  Future<void> _loadAraOgunlerFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = DateFormat("yyyy-MM-dd").format(selectedDate);

    final jsonString = prefs.getString("ara_ogunler_$dateKey");
    if (jsonString == null) {
      setState(() {
        araOgunler = [];
      });
      return;
    }

    setState(() {
      araOgunler =
          List<Map<String, dynamic>>.from(jsonDecode(jsonString));
    });
  }

  /// Kullanıcının seçtiği ili yükle
  Future<void> _loadUserCity() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userCity = prefs.getString("selected_city") ?? "Karaman";
    });
  }

  /// Hem prefs hem veritabanından yükle
  Future<void> _loadAraOgunler() async {
    await _loadAraOgunlerFromPrefs();
    await _loadAraOgunlerFromDatabase();
  }

  Future<void> _addAraOgun() async {
    final name = nameController.text.trim();
    final calories = double.tryParse(calorieController.text);

    if (name.isEmpty || calories == null) return;

    final newItem = {"name": name, "calories": calories};

    setState(() {
      araOgunler.add(newItem);
    });

    await _saveAraOgunlerToPrefs();
    await _saveToDatabase(newItem);

    nameController.clear();
    calorieController.clear();
  }

  /// Supabase'e kaydet
  Future<void> _saveToDatabase(Map<String, dynamic> item) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('ara_ogunler').insert({
        'device_id': userId, // 🔥 Doğrudan Auth ID
        'date': widget.selectedDate.toIso8601String().substring(0, 10),
        'city': _userCity,
        'name': item['name'],
        'calories': item['calories'],
      });
      debugPrint("Ara Öğün Eklendi: $response");
    } catch (e) {
      debugPrint("Ara Öğün Ekleme Hatası: $e");
    }
  }

  /// SharedPreferences kaydet
  Future<void> _saveAraOgunlerToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = widget.selectedDate.toIso8601String().substring(0, 10);
    final jsonString = jsonEncode(araOgunler);
    await prefs.setString("ara_ogunler_$dateKey", jsonString);
  }

  /// Supabase'ten yükle ve prefs ile senkronize et
  Future<void> _loadAraOgunlerFromDatabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('ara_ogunler')
          .select()
          .eq('device_id', userId) // 🔥 Doğrudan Auth ID
          .eq('date', widget.selectedDate.toIso8601String().substring(0, 10));
          // .eq('city', _userCity); // Şehir değiştirenler de görsün

      if (response != null) {
        final List<Map<String, dynamic>> dbList =
            List<Map<String, dynamic>>.from(response);
        
        setState(() {
          araOgunler = dbList;
        });
        await _saveAraOgunlerToPrefs(); // prefs güncelle
      }
    } catch (e) {
      debugPrint("Ara Öğün Yükleme Hatası (DB): $e");
    }
  }

  double _totalCalories() {
    return araOgunler.fold(0, (sum, item) => sum + (item["calories"] ?? 0));
  }

  /// Silme işlemi
  Future<void> _deleteAraOgun(int index) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final item = araOgunler[index];
    setState(() {
      araOgunler.removeAt(index);
    });

    await _saveAraOgunlerToPrefs();

    try {
      await Supabase.instance.client
          .from('ara_ogunler')
          .delete()
          .eq('device_id', userId) // 🔥 Doğrudan Auth ID
          .eq('date', widget.selectedDate.toIso8601String().substring(0, 10))
          .eq('name', item["name"]);
    } catch (e) {
      debugPrint("Ara Öğün Silme Hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = themeProvider.primaryColor;
    final dark = themeProvider.isDarkMode;

    return PopScope(
  canPop: false,
  onPopInvoked: (didPop) {
    if (didPop) return;

    // 📌 Telefonun geri tuşu da buraya düşer
    Navigator.pop(context, araOgunler);
  },
  child: Scaffold(
    appBar: AppBar(
      backgroundColor: primaryColor,
      title: Text("Ara Öğünler ($_userCity)", style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),),
      leading: IconButton(
icon: Icon(
  Icons.arrow_back,
  color: Theme.of(context).colorScheme.onSurface,
),        onPressed: () {
          // 📌 AppBar geri tuşu
          Navigator.pop(context, araOgunler);
        },
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: "Ara öğün adı",
              border: const OutlineInputBorder(),
              filled: true,
              fillColor:
                  dark ? Colors.grey.shade800 : Colors.grey.shade100,
            ),
            style: TextStyle(color: dark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: calorieController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Kalori (kcal)",
              border: const OutlineInputBorder(),
              filled: true,
              fillColor:
                  dark ? Colors.grey.shade800 : Colors.grey.shade100,
            ),
            style: TextStyle(color: dark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addAraOgun,
              icon: Icon(
  Icons.add,
  color: Theme.of(context).colorScheme.onSurface,
),
              label: Text("Ekle", style: Theme.of(context).textTheme.labelLarge?.copyWith( fontWeight: FontWeight.bold, ),),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: araOgunler.isEmpty
                ? Center(
                    child: Text(
                      "Henüz ara öğün eklenmedi",
                      style: TextStyle(
                        color:
                            dark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: araOgunler.length,
                    itemBuilder: (context, index) {
                      final item = araOgunler[index];
                      return Card(
                        color: dark
                            ? Colors.grey.shade900
                            : Colors.white,
                        child: ListTile(
                          title: Text(
                            item["name"],
                            style: TextStyle(
                              color:
                                  dark ? Colors.white : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            "${item["calories"]} kcal",
                            style: TextStyle(
                              color: dark
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red),
                            onPressed: () => _deleteAraOgun(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Text(
            "Toplam: ${_totalCalories().toStringAsFixed(0)} kcal",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: dark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
