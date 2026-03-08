import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../theme_provider.dart';

class HelpUsPage extends StatefulWidget {
  const HelpUsPage({super.key});

  @override
  State<HelpUsPage> createState() => _HelpUsPageState();
}

class _HelpUsPageState extends State<HelpUsPage> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String? _selectedCity;
  bool _loading = false;

  final List<String> _cities = [
    "Adana","Adıyaman","Afyonkarahisar","Ağrı","Amasya","Ankara","Antalya",
    "Artvin","Aydın","Balıkesir","Bilecik","Bingöl","Bitlis","Bolu","Burdur",
    "Bursa","Çanakkale","Çankırı","Çorum","Denizli","Diyarbakır","Edirne",
    "Elazığ","Erzincan","Erzurum","Eskişehir","Gaziantep","Giresun","Gümüşhane",
    "Hakkari","Hatay","Isparta","Mersin","İstanbul","İzmir","Kars","Kastamonu",
    "Kayseri","Kırklareli","Kırşehir","Kocaeli","Konya","Kütahya","Malatya",
    "Manisa","Kahramanmaraş","Mardin","Muğla","Muş","Nevşehir","Niğde","Ordu",
    "Rize","Sakarya","Samsun","Siirt","Sinop","Sivas","Tekirdağ","Tokat",
    "Trabzon","Tunceli","Şanlıurfa","Uşak","Van","Yozgat","Zonguldak",
    "Aksaray","Bayburt","Karaman","Kırıkkale","Batman","Şırnak","Bartın",
    "Ardahan","Iğdır","Yalova","Karabük","Kilis","Osmaniye","Düzce"
  ];

  Future<void> _checkPermissionsAndPickImage(ImageSource source) async {
    PermissionStatus status;

    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      if (Platform.isAndroid) {
        // Request both storage and photos to handle different Android versions
        Map<Permission, PermissionStatus> statuses = await [
          Permission.storage,
          Permission.photos,
        ].request();
        
        if (statuses[Permission.photos]!.isGranted || statuses[Permission.storage]!.isGranted) {
          status = PermissionStatus.granted;
        } else if (statuses[Permission.photos]!.isPermanentlyDenied || statuses[Permission.storage]!.isPermanentlyDenied) {
          status = PermissionStatus.permanentlyDenied;
        } else {
          status = PermissionStatus.denied;
        }
      } else {
        status = await Permission.photos.request();
      }
    }

    if (status.isGranted || status.isLimited) {
      _pickImage(source);
    } else if (status.isPermanentlyDenied) {
      _showSettingsDialog();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu işlemi yapmak için izin vermeniz gerekmektedir.")),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Görsel seçerken hata oluştu: $e")),
      );
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İzin Gerekli"),
        content: const Text("Galeri veya Kamera erişim izni kalıcı olarak reddedildi. Lütfen ayarlardan izin verin."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text("Ayarları Aç"),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _selectedCity == null ||
        _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm alanları doldurun")),
      );
      return;
    }

    try {
      setState(() => _loading = true);

      final supabase = Supabase.instance.client;

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(_selectedImage!.path)}';

      // 📤 STORAGE
      await supabase.storage.from('kyk-meals').upload(
            fileName,
            _selectedImage!,
          );

      // 🌍 PUBLIC URL
      final imageUrl =
          supabase.storage.from('kyk-meals').getPublicUrl(fileName);

      // 🗄 DATABASE
      await supabase.from('kyk_meal_contributions').insert({
        'name': _nameController.text.trim(),
        'city': _selectedCity,
        'image_url': imageUrl,
        'tarih': DateTime.now().toIso8601String(), // 🕒 Türkiye saati (cihaz saati) eklendi
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
  content: Center(
    child: Text("Teşekkürler! 🙏"),
  ),
),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata oluştu: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool dark = themeProvider.isDarkMode;
    final Color primaryColor = themeProvider.primaryColor;
    final backgroundColor = dark ? Colors.grey.shade900 : Colors.grey.shade200;
    final textColor = dark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
  "Bize Yardımcı Ol",
  style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
),
        centerTitle: true,
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "Bilgilerini doldur ve KYK yemek listesini paylaş",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "İsmin",
                labelStyle: TextStyle(color: textColor),
                filled: true,
                fillColor: dark ? Colors.grey.shade800 : Colors.white,
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedCity,
              items: _cities
                  .map((city) => DropdownMenuItem(
                        value: city,
                        child: Text(city, style: TextStyle(color: textColor)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCity = value;
                });
              },
              dropdownColor: dark ? Colors.grey.shade800 : Colors.white,
              decoration: InputDecoration(
                labelText: "Bulunduğun İl",
                labelStyle: TextStyle(color: textColor),
                filled: true,
                fillColor: dark ? Colors.grey.shade800 : Colors.white,
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                "KYK Yemek Listesi Fotoğrafı",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.photo),
                    label: Text("Galeri", style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                    onPressed: () => _checkPermissionsAndPickImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: Text("Kamera", style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                    onPressed: () => _checkPermissionsAndPickImage(ImageSource.camera),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text("Gönder", style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
