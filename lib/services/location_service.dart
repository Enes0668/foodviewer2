import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const String _cityKey = 'selected_city';

  // =========================================================
  // 1️⃣ LEGACY KOD (Mobilde aynen çalışacak)
  // =========================================================
  static Future<String?> _getCityFromDevice() async {
    try {
      // 🌐 Web için → konum sormadan direkt default şehir/koordinat
      if (kIsWeb) {
        return "Ankara"; // Buraya dilediğin default şehri yazabilirsin
      }

      // 🔹 Mobil kısmı aynen legacy
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 5),
      );

      final List<Placemark> placemarks =
          await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) return null;

      return placemarks.first.administrativeArea;
    } catch (e) {
      debugPrint("Location error: $e");
      return null;
    }
  }

  // =========================================================
  // 2️⃣ KAYITLI ŞEHRİ OKU
  // =========================================================
  static Future<String?> getSavedCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cityKey);
  }

  // =========================================================
  // 3️⃣ ANA FONKSİYON
  // =========================================================
  static Future<String?> getCityName() async {
    final savedCity = await getSavedCity();
    if (savedCity != null && savedCity.isNotEmpty) {
      return savedCity;
    }

    final city = await _getCityFromDevice();

    if (city != null && city.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cityKey, city);
    }

    return city;
  }

  // =========================================================
  // 4️⃣ ŞEHİR SIFIRLA / DEĞİŞTİR
  // =========================================================
  static Future<void> clearSavedCity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cityKey);
  }
}
