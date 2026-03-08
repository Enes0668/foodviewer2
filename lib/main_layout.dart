import 'package:flutter/material.dart';
import 'package:foodviewer/pages/home_page.dart';
import 'package:foodviewer/pages/profile_page.dart';
import 'package:foodviewer/pages/settings_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Ana Sayfa ortada olacağı için başlangıç index = 1
  int _selectedIndex = 1;

  // SIRA ÖNEMLİ
  final List<Widget> _pages = const [
    SettingsPage(), // 0 → Sol
    HomePage(),     // 1 → Orta
    ProfilePage(),  // 2 → Sağ
  ];

  void _onTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Ayarlar",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Ana Sayfa",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profil",
          ),
        ],
      ),
    );
  }
}
