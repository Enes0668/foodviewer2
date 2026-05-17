import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foodviewer/pages/login_page.dart';
import 'package:foodviewer/pages/register_page.dart';
import 'package:foodviewer/pages/entry_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  Future<void> _continueWithoutLogin(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('welcome_shown', true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const EntryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo & branding
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  size: 52,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Günün Menüsü',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sağlıklı beslenmenin akıllı takipçisi',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 2),
              // Feature highlights
              _FeatureRow(
                icon: Icons.track_changes,
                text: 'Günlük kalori ve besin takibi',
              ),
              const SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.location_on_outlined,
                text: 'Konumuna göre menü keşfi',
              ),
              const SizedBox(height: 12),
              _FeatureRow(
                icon: Icons.bar_chart,
                text: 'Kişisel sağlık istatistikleri',
              ),
              const Spacer(flex: 3),
              // Buttons
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Giriş Yap',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Kayıt Ol',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _continueWithoutLogin(context),
                child: Text(
                  'Girişsiz devam et',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
        ),
      ],
    );
  }
}
