import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:foodviewer/theme_provider.dart';

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  // 🎯 Custom gri (mavimsiz)
  static const Color customGrey = Color(0xFF8A8D91);

  static const List<Map<String, dynamic>> colors = [
    {"name": "Kırmızı", "color": Colors.red},
    {"name": "Turuncu", "color": Colors.orange},
    {"name": "Yeşil", "color": Colors.green},
    {"name": "Mavi", "color": Colors.blue},
    {"name": "Pembe", "color": Colors.pink},
    {"name": "Gri", "color": customGrey}, // ✅ custom gri
  ];

  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool dark = themeProvider.isDarkMode;

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: themeProvider.primaryColor,
        centerTitle: true,
        title: Text(
          "Tema Seç",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
        ),
      ),
      body: Column(
        children: [
          // 🌙 GECE MODU
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: dark ? Colors.grey.shade900 : Colors.grey.shade200,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Gece Modu",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : Colors.black,
                    ),
                  ),
                  Switch(
                    value: dark,
                    // Eğer seçili tema "Gri" (customGrey) ise, rengi koyulaştırma, olduğu gibi kullan.
                     activeColor: themeProvider.rawPrimaryColor.value == customGrey.value
                        ? customGrey
                        : themeProvider.primaryColor,
                    onChanged: themeProvider.setDarkMode,
                  ),
                ],
              ),
            ),
          ),

          // 🎨 RENK SEÇİMİ
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              physics: const BouncingScrollPhysics(),
              itemCount: colors.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final item = colors[index];
                final Color color = item["color"];
                final bool isSelected =
                    color.value == themeProvider.primaryColor.value;

                return GestureDetector(
                  onTap: () => themeProvider.setTheme(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: dark ? Colors.grey.shade900 : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? (dark ? Colors.white : Colors.black)
                            : Colors.transparent,
                        width: isSelected ? 3 : 0,
                      ),
                    ),
                    child: Card(
                      elevation: dark ? 0 : 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: color,
                      child: Center(
                        child: Text(
                          item["name"],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: dark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
