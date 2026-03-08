import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  // CONTROLLER'LAR
  final TextEditingController nameController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  final uuid = const Uuid();
  String? _city;
  // Dropdown seçimi
  String selectedCategory = "Uygulama";

  @override
void initState() {
  super.initState();
  _loadCity(); // sayfa açılır açılmaz city yüklenir
}

  @override
  void dispose() {
    nameController.dispose();
    messageController.dispose();
    super.dispose();
  }

  // -----------------------------
  // ZAMAN KISITLAMALARI
  // -----------------------------
  Future<bool> checkLimit() async {
    final prefs = await SharedPreferences.getInstance();
    String key = "";

    if (selectedCategory == "Uygulama") {
      key = "lastAppFeedbackDate";
    } else if (selectedCategory == "Kahvaltı") {
      key = "lastBreakfastFeedbackDate";
    } else {
      key = "lastDinnerFeedbackDate";
    }

    final lastDate = prefs.getString(key);
    final today = DateFormat("yyyy-MM-dd").format(DateTime.now());

    if (selectedCategory == "Uygulama") {
      if (lastDate == null) return true;
      return DateTime.now().difference(DateTime.parse(lastDate)).inDays >= 7;
    } else {
      return lastDate != today;
    }
  }

  Future<void> _loadCity() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _city = prefs.getString("selected_city") ?? "Adana";
  });
}

  Future<void> saveLimitDate() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat("yyyy-MM-dd").format(DateTime.now());
    final now = DateTime.now().toIso8601String();

    if (selectedCategory == "Uygulama") {
      await prefs.setString("lastAppFeedbackDate", now);
    } else if (selectedCategory == "Kahvaltı") {
      await prefs.setString("lastBreakfastFeedbackDate", today);
    } else {
      await prefs.setString("lastDinnerFeedbackDate", today);
    }
  }

  // -----------------------------
  // Firebase Kayıt
  // -----------------------------
  Future<void> sendFeedback() async {
  final now = DateTime.now();
  final tarih = DateFormat("yyyy-MM-dd HH:mm").format(now);

  // Flutter Supabase client
  final supabase = Supabase.instance.client;

  // Mesaj ve isim
  final mesaj = messageController.text.trim();
  final isim = nameController.text.trim().isEmpty
      ? null
      : nameController.text.trim();

  // Hangi tabloya yazılacak?
  String tableName = "";

  if (selectedCategory == "Uygulama") {
    tableName = "uygulama_feedback";
  } else if (selectedCategory == "Kahvaltı") {
    tableName = "kahvalti_feedback";
  } else if (selectedCategory == "AksamYemegi") {
    tableName = "aksam_feedback";
  }

  // Supabase insert işlemi
  await supabase.from(tableName).insert({
    "mesaj": mesaj,
    "isim": isim,
    "tarih": tarih,
    "city": _city,
  });
}


  // -----------------------------
  // UI BAŞLANGIÇ
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
  "Geri Bildirim",
  style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
),
        centerTitle: true,
        backgroundColor: themeColor,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------------------------
            // DROPDOWN MENÜ
            // ---------------------------
            Container(
  padding: const EdgeInsets.symmetric(horizontal: 12),
  decoration: BoxDecoration(
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.black     // Karanlık tema → siyah arka plan
        : Colors.white,    // Açık tema → beyaz arka plan
    borderRadius: BorderRadius.circular(10),
    border: Border.all(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white54
          : Colors.black54,
    ),
  ),

  child: DropdownButtonHideUnderline(
    child: DropdownButton<String>(
      value: selectedCategory,

      dropdownColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.white,

      style: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),

      icon: Icon(
        Icons.arrow_drop_down,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
      ),

      items: [
        DropdownMenuItem(
          value: "Uygulama",
          child: Text(
            "Uygulama Geri Bildirimi",
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ),
        DropdownMenuItem(
          value: "Kahvaltı",
          child: Text(
            "Kahvaltı Geri Bildirimi",
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ),
        DropdownMenuItem(
          value: "AksamYemegi",
          child: Text(
            "Akşam Yemeği Geri Bildirimi",
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ),
      ],

      onChanged: (value) {
  setState(() {
    selectedCategory = value!;
    nameController.clear();
    messageController.clear();
  });
},
    ),
  ),
),



            const SizedBox(height: 20),

            // ---------------------------
            // FORM TASARIMI (MODERN)
            // ---------------------------
            Expanded(
              child: Card(
                elevation: 5,
                shadowColor: Colors.black38,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      Center(
                      child: Text(
                        selectedCategory == "Uygulama"
                            ? "Uygulama Hakkında"
                            : selectedCategory == "Kahvaltı"
                                ? "Kahvaltı Hakkında"
                                : "Akşam Yemeği Hakkında",
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
  controller: nameController,
  style: TextStyle(
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.white      // Karanlık tema → yazı beyaz
        : Colors.black,     // Açık tema → yazı siyah
  ),
  decoration: InputDecoration(
    labelText: "İsminiz (opsiyonel)",
    labelStyle: TextStyle(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white70   // Karanlık tema → label açık beyaz
          : Colors.black87,  // Açık tema → label siyah
    ),
    filled: true,
    fillColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade800   // Karanlık tema → koyu arka plan
        : Colors.grey.shade100,  // Açık tema → açık gri arka plan
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white38
            : Colors.black26,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Theme.of(context).primaryColor, // Tema rengi
        width: 2,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
  ),
),


                      const SizedBox(height: 16),

                      TextField(
  controller: messageController,
  maxLines: 5,

  style: TextStyle(
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.white        // Karanlık tema → beyaz yazı
        : Colors.black,       // Açık tema → siyah yazı
  ),

  decoration: InputDecoration(
    hintText: "Görüşleriniz...",
    hintStyle: TextStyle(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white70    // Karanlık tema → açık beyaz hint
          : Colors.black54,   // Açık tema → koyu gri hint
    ),

    filled: true,
    fillColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade800   // Karanlık tema → koyu arka plan
        : Colors.grey.shade100,  // Açık tema → açık gri arka plan

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),

    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white30
            : Colors.black26,
      ),
      borderRadius: BorderRadius.circular(12),
    ),

    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: Theme.of(context).primaryColor,
        width: 2,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
  ),
),


                      const SizedBox(height: 25),

                      // ---------------------------
                      // GÖNDER BUTTON
                      // ---------------------------
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: themeColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            
                            final message = messageController.text.trim();

                            if (message.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text("Lütfen bir mesaj yazın."),
                                ),
                              );
                              return;
                            }

                            if (!await checkLimit()) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    selectedCategory == "Uygulama"
                                        ? "Bu kategoride haftada 1 kez geri bildirim gönderebilirsiniz."
                                        : "Bu kategoride günde 1 geri bildirim gönderebilirsiniz.",
                                  ),
                                ),
                              );
                              return;
                            }

                            await sendFeedback();
                            await saveLimitDate();

                            messageController.clear();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Geri bildiriminiz gönderildi!"),
                              ),
                            );
                          },
                          child: Text(
  "Gönder",
  style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
