import 'package:flutter/material.dart';
import 'package:foodviewer/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fcm_service.dart';
import 'theme_page.dart';
import 'feedback_page.dart';
import 'help_us_page.dart';
import '../widgets/custom_loading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _breakfastNotificationEnabled = false;
  bool _dinnerNotificationEnabled = false;
  bool _loading = true;
  bool _isDeleting = false;

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

  Future<void> _onToggleBreakfast(bool value) async {
    setState(() => _breakfastNotificationEnabled = value);
    await _saveBreakfastNotification(value);
    await FCMService.updatePreference(
      breakfastEnabled: value,
      dinnerEnabled: _dinnerNotificationEnabled,
      city: _selectedCity,
    );
  }

  Future<void> _onToggleDinner(bool value) async {
    setState(() => _dinnerNotificationEnabled = value);
    await _saveDinnerNotification(value);
    await FCMService.updatePreference(
      breakfastEnabled: _breakfastNotificationEnabled,
      dinnerEnabled: value,
      city: _selectedCity,
    );
  }

  Future<void> _saveSelectedCity(String? city) async {
    if (city == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("selected_city", city);
  }

  Future<void> _deleteAccount() async {
    // Onay dialogu
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı Kalıcı Olarak Sil'),
        content: const Text(
          'Bu işlem geri alınamaz.\n\n'
          'Hesabınız ve tüm kişisel verileriniz (yemek seçimleri, sağlık bilgileri, ara öğünler) kalıcı olarak silinecektir.\n\n'
          'Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      // Bildirimleri iptal et
      if (_breakfastNotificationEnabled) await _onToggleBreakfast(false);
      if (_dinnerNotificationEnabled) await _onToggleDinner(false);

      // Supabase RPC ile tüm verileri + auth hesabını sil
      await Supabase.instance.client.rpc('delete_user_account');

      // SharedPreferences'ı temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;

      // WelcomePage'e yönlendir, tüm route stack'ini temizle
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (_) => false,
      );
    } catch (e) {
      debugPrint('Hesap silme hatası: $e');
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hesap silinirken bir hata oluştu. Lütfen tekrar deneyin.'),
        ),
      );
    }
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

                  // 🗑️ HESAP SİLME (yalnızca kayıtlı kullanıcılara göster)
                  if (Supabase.instance.client.auth.currentUser?.isAnonymous == false) ...[
                    const SizedBox(height: 32),
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
                                Icon(Icons.manage_accounts, color: Colors.red.shade400),
                                const SizedBox(width: 8),
                                const Text(
                                  'Hesap',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Hesabınızı sildiğinizde tüm kişisel verileriniz (yemek seçimleri, sağlık bilgileri, ara öğünler) kalıcı olarak silinir. Bu işlem geri alınamaz.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isDeleting ? null : _deleteAccount,
                                icon: _isDeleting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.red,
                                        ),
                                      )
                                    : const Icon(Icons.delete_forever, color: Colors.red),
                                label: Text(
                                  _isDeleting ? 'Siliniyor...' : 'Hesabı Kalıcı Olarak Sil',
                                  style: const TextStyle(color: Colors.red),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
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
