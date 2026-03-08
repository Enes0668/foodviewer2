import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:foodviewer/main_layout.dart';
import 'nointernet_page.dart';

class EntryPage extends StatefulWidget {
  const EntryPage({super.key});

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _checkInitialInternet();

    // Sürekli internet durumunu dinle
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
  // Eğer birden fazla sonucu liste olarak dönerse, biz sadece ilkini kontrol edebiliriz
  final hasInternet = results.isNotEmpty && results[0] != ConnectivityResult.none;
  if (hasInternet != _hasInternet) {
    setState(() {
      _hasInternet = hasInternet;
    });
  }
});
  }

  Future<void> _checkInitialInternet() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    setState(() {
      _hasInternet = result != ConnectivityResult.none;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel(); // null güvenliği
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Eğer internet yoksa NoInternetPage, varsa MainLayout
    return _hasInternet ? const MainLayout() : const NoInternetPage();
  }
}
