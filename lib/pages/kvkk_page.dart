import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:foodviewer/pages/welcome_page.dart';
import 'package:foodviewer/pages/entry_page.dart';

class KvkkPage extends StatefulWidget {
  final bool showWelcome;
  const KvkkPage({super.key, required this.showWelcome});

  @override
  State<KvkkPage> createState() => _KvkkPageState();
}

class _KvkkPageState extends State<KvkkPage> {
  bool _accepted = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onAccept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kvkk_accepted', true);

    await _saveConsentToSupabase();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            widget.showWelcome ? const WelcomePage() : const EntryPage(),
      ),
    );
  }

  Future<void> _saveConsentToSupabase() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      String platform;
      if (kIsWeb) {
        platform = 'web';
      } else if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else {
        platform = 'unknown';
      }

      await Supabase.instance.client.from('user_consents').insert({
        'user_id': userId,
        'kvkk_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'app_version': '1.0.0+3',
        'platform': platform,
      });
    } catch (e) {
      debugPrint('KVKK consent kayıt hatası: $e');
    }
  }

  void _onReject() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uygulamayı Kullanamazsınız'),
        content: const Text(
          'Kişisel Verilerin Korunması Kanunu kapsamındaki aydınlatma metnini kabul etmeden uygulamayı kullanamazsınız.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Geri Dön'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KVKK Aydınlatma Metni'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: _KvkkText(theme: theme, colorScheme: colorScheme),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _accepted = !_accepted),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _accepted,
                          onChanged: (v) =>
                              setState(() => _accepted = v ?? false),
                          activeColor: colorScheme.primary,
                        ),
                        Expanded(
                          child: Text(
                            'Kişisel Verilerin Korunması Kanunu kapsamındaki Aydınlatma Metnini okudum, anladım ve kabul ediyorum.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _accepted ? _onAccept : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Kabul Et ve Devam Et',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _onReject,
                    child: Text(
                      'Reddet',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KvkkText extends StatelessWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _KvkkText({required this.theme, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GÜNÜN MENÜSÜ UYGULAMASI\nKİŞİSEL VERİLERİN KORUNMASI KANUNU KAPSAMINDA AYDINLATMA METNİ',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        _buildParagraph(
          'Bu aydınlatma metni, 6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca, Günün Menüsü mobil uygulaması kullanıcılarını kişisel verilerinin işlenmesine ilişkin bilgilendirmek amacıyla hazırlanmıştır.',
        ),

        // ─── 1. VERİ SORUMLUSU ────────────────────────────────────────
        _buildSection('1. Veri Sorumlusu'),
        _buildParagraph(
          'Günün Menüsü, bağımsız bir öğrenci yazılım projesidir. Herhangi bir devlet kurumu veya üniversite ile resmi bağlantısı bulunmamaktadır.\n\n'
          'Veri Sorumlusu  : Enes Melih Eroğlu\n'
          'E-posta             : melihenes2@gmail.com\n'
          'Web Sitesi          : https://gunun-menusu.com.tr/',
        ),

        // ─── 2. İŞLENEN KİŞİSEL VERİLER ─────────────────────────────
        _buildSection('2. İşlenen Kişisel Veriler'),
        _buildParagraph(
          'Uygulama aşağıdaki kategorilerde kişisel veri işlemektedir:',
        ),
        _buildSubSection('2.1. Hesap Bilgileri (Kayıtlı Kullanıcılar)'),
        _buildParagraph(
          'Kayıt ve giriş yapan kullanıcılar için:\n'
          '• Ad ve soyad\n'
          '• E-posta adresi\n'
          '• Şifre (Supabase altyapısı tarafından şifrelenmiş olarak saklanır; düz metin olarak işlenmez)\n\n'
          'Giriş yapmadan kullanan ("anonim") kullanıcılar için yalnızca rastgele üretilmiş anonim bir oturum kimliği (UUID) oluşturulur. Bu kimlik herhangi bir kişisel bilgiyle ilişkilendirilmez.',
        ),
        _buildSubSection('2.2. Sağlık Verileri (Özel Nitelikli Kişisel Veri)'),
        _buildParagraph(
          'Profil sayfasında girdiğiniz ve bulut sunucuya kaydedilen bilgiler:\n'
          '• Boy (cm)\n'
          '• Kilo (kg)\n'
          '• Yaş\n'
          '• Cinsiyet\n'
          '• Vücut Kitle İndeksi (VKİ) ve VKİ sınıflaması (Zayıf / Normal / Fazla kilolu / Obez)\n'
          '• Günlük adım sayısı (sizin girdiğiniz değer)\n'
          '• Adım başına tahmini yakılan kalori\n'
          '• Günlük toplam alınan kalori\n'
          '• Günlük kalori dengesi (alınan eksi yakılan)\n'
          '• Uygulama tarafından hesaplanan önerilen günlük adım hedefi\n\n'
          'Bu veriler KVKK madde 6 kapsamında özel nitelikli kişisel veri sayılmakta olup yalnızca açık rızanıza dayanılarak işlenmektedir.',
        ),
        _buildSubSection('2.3. Beslenme ve Yemek Seçim Verileri'),
        _buildParagraph(
          'Ana ekranda işaretlediğiniz yemekler ve eklediğiniz ara öğünler:\n'
          '• Seçtiğiniz kahvaltı yemekleri ve kalori değerleri\n'
          '• Seçtiğiniz akşam yemekleri ve kalori değerleri\n'
          '• Eklediğiniz ara öğün adları ve kalori değerleri\n'
          '• Her seçime ait tarih bilgisi\n\n'
          'Bu veriler kalori takibi ve kişiselleştirme amacıyla bulut sunucuya kaydedilmektedir.',
        ),
        _buildSubSection('2.4. Konum Verisi'),
        _buildParagraph(
          'Konuma göre menü görüntüleme özelliği için:\n'
          '• İzin verirseniz GPS aracılığıyla il düzeyinde konum belirlenir.\n'
          '• Ayarlar ekranından il seçimini kendiniz de yapabilirsiniz.\n'
          '• Yalnızca il adı (örn. "Karaman") işlenmekte; kesin konum koordinatları saklanmamaktadır.\n'
          '• Seçilen il, menü verilerinizle birlikte bulut sunucuya kaydedilir.',
        ),
        _buildSubSection('2.5. Bildirim Tercihleri'),
        _buildParagraph(
          'Ayarlar ekranından etkinleştirdiğiniz bildirimler için:\n'
          '• Kahvaltı bildirimi tercihi ve saati (06:00)\n'
          '• Akşam yemeği bildirimi tercihi ve saati (16:00)\n\n'
          'Bu tercihler yalnızca cihazınızda (SharedPreferences) saklanır; bulut sunucuya gönderilmez.',
        ),
        _buildSubSection('2.6. Teknik Kimlik Bilgisi'),
        _buildParagraph(
          '• Supabase kimlik doğrulama sistemi tarafından otomatik olarak atanan kullanıcı kimliği (UUID). Bu kimlik, yukarıdaki tüm verilerin sizinle ilişkilendirilmesini sağlar ve Row Level Security (RLS) güvenlik kurallarının çalışması için zorunludur.',
        ),

        // ─── 3. VERİLERİN İŞLENME AMAÇLARI ──────────────────────────
        _buildSection('3. Kişisel Verilerin İşlenme Amaçları'),
        _buildParagraph(
          '• Hesabınızın oluşturulması, doğrulanması ve güvenli bir şekilde yönetilmesi\n'
          '• Bulunduğunuz ile göre günlük kahvaltı ve akşam yemeği menüsünün gösterilmesi\n'
          '• Seçtiğiniz yemekler üzerinden günlük kalori takibinin yapılması\n'
          '• Ara öğün kaydı ve toplam kalori hesabı\n'
          '• Boy, kilo, yaş ve cinsiyetinize göre VKİ hesaplanması\n'
          '• Adım sayısı ve kalori verilerine dayalı kişiselleştirilmiş günlük adım önerisi sunulması\n'
          '• Yakılan kalori tahmini ve kalori denge analizi\n'
          '• Öğün zamanlarında hatırlatıcı bildirim gönderilmesi\n'
          '• Güvenli veri erişimi için Row Level Security (RLS) politikalarının uygulanması',
        ),

        // ─── 4. HUKUKİ DAYANAK ───────────────────────────────────────
        _buildSection('4. Hukuki İşleme Dayanağı'),
        _buildParagraph(
          'Kişisel verileriniz aşağıdaki hukuki dayanaklara göre işlenmektedir:\n\n'
          '• Hesap bilgileri (ad, e-posta, şifre): KVKK madde 5/2-c — sözleşmenin kurulması veya ifası için zorunluluk.\n\n'
          '• Sağlık verileri (boy, kilo, yaş, cinsiyet, VKİ, adım, kalori): KVKK madde 6/3 — açık rızanıza dayanılarak işlenmektedir. Bu verilerin işlenmesini istemiyorsanız uygulamayı yalnızca menü görüntüleme amacıyla kullanabilir; profil sayfasına bilgi girmekten kaçınabilirsiniz.\n\n'
          '• Beslenme seçimleri ve ara öğün kayıtları: KVKK madde 6/3 — sağlık verisi niteliğindedir; açık rızanız gereklidir.\n\n'
          '• Konum verisi (il): KVKK madde 5/2-a — açık rızanız; iznin verilmemesi durumunda ayarlardan manuel seçim yapılabilir.\n\n'
          '• Bildirim tercihleri ve teknik kimlik: KVKK madde 5/2-c — sözleşmenin ifası ve meşru menfaat.',
        ),

        // ─── 5. VERİLERİN SAKLANDIĞI YERLER ──────────────────────────
        _buildSection('5. Verilerin Saklandığı Yerler'),
        _buildParagraph(
          'a) Bulut Sunucu (Supabase):\n'
          'Hesap bilgileri, sağlık verileri, yemek seçimleri, ara öğünler ve konum (il) bilgisi Supabase güvenli bulut altyapısında şifrelenmiş olarak saklanmaktadır. Supabase, AB Genel Veri Koruma Tüzüğü (GDPR) ile uyumlu bir altyapı sağlamaktadır.\n\n'
          'b) Cihaz Hafızası (SharedPreferences):\n'
          'Menü cache verileri (6 saatlik), bildirim tercihleri, tema ve şehir seçimi gibi uygulama tercihleri yalnızca kendi cihazınızda saklanır; bulut sunucuya gönderilmez. Bu veriler uygulamayı kaldırdığınızda otomatik olarak silinir.',
        ),

        // ─── 6. VERİ GÜVENLİĞİ VE AKTARIM ───────────────────────────
        _buildSection('6. Veri Güvenliği ve Üçüncü Taraf Aktarımı'),
        _buildParagraph(
          '• Tüm ağ trafiği HTTPS protokolüyle şifrelenmektedir.\n'
          '• Veritabanında Row Level Security (RLS) uygulanmaktadır; her kullanıcı yalnızca kendi verilerine erişebilir.\n'
          '• Şifreler açık metin olarak hiçbir zaman saklanmaz veya iletilmez.\n'
          '• Verileriniz yasal bir zorunluluk (mahkeme kararı, resmi talep vb.) olmadıkça hiçbir üçüncü tarafla paylaşılmamaktadır.\n'
          '• Uygulama; reklam ağı, üçüncü taraf analitik aracı veya sosyal medya izleyicisi içermemektedir.',
        ),

        // ─── 7. VERİ SAKLAMA SÜRESİ ──────────────────────────────────
        _buildSection('7. Veri Saklama Süresi'),
        _buildParagraph(
          '• Kayıtlı kullanıcı verileri hesabınız aktif olduğu sürece saklanır.\n'
          '• Hesabınızı silmeniz durumunda tüm kişisel verileriniz (sağlık, yemek seçimleri, ara öğünler) kalıcı olarak ve geri alınamaz biçimde silinir.\n'
          '• Anonim kullanıcılara ait veriler, anonim oturum kimliğiyle ilişkilendirilmiş olmakla birlikte, ilgili kişiyi tanımlamaya yetecek herhangi bir bilgi içermez.\n'
          '• Cihazda saklanan veriler (cache, tercihler) uygulama kaldırıldığında veya uygulama verilerini temizlediğinizde otomatik olarak silinir.',
        ),

        // ─── 8. HAKLARINIZ ───────────────────────────────────────────
        _buildSection('8. KVKK Kapsamındaki Haklarınız'),
        _buildParagraph(
          'KVKK\'nın 11. maddesi kapsamında aşağıdaki haklara sahipsiniz:\n\n'
          '• Kişisel verilerinizin işlenip işlenmediğini öğrenme\n'
          '• İşleniyorsa buna ilişkin bilgi talep etme\n'
          '• İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme\n'
          '• Yurt içinde veya yurt dışında verilerin aktarıldığı üçüncü kişileri bilme\n'
          '• Eksik veya yanlış işlenmişse düzeltilmesini isteme\n'
          '• KVKK\'da öngörülen şartlar çerçevesinde silinmesini veya yok edilmesini isteme\n'
          '• Düzeltme ve silme işlemlerinin üçüncü kişilere bildirilmesini isteme\n'
          '• Otomatik sistemlerle analiz sonucu aleyhinize bir sonuç doğmasına itiraz etme\n'
          '• Kanuna aykırı işleme nedeniyle uğradığınız zararın giderilmesini talep etme\n\n'
          'Bu haklarınızı kullanmak için:\n'
          '• Hesabınızı Ayarlar → Profil üzerinden kalıcı olarak silebilirsiniz.\n'
          '• melihenes2@gmail.com adresine e-posta gönderebilirsiniz.\n'
          '• Talepleriniz en geç 30 gün içinde yanıtlanacaktır.',
        ),

        // ─── 9. AÇIK RIZA VE GERİ ALMA ───────────────────────────────
        _buildSection('9. Açık Rıza ve Rızanızı Geri Alma'),
        _buildParagraph(
          'Sağlık ve beslenme verilerinizin işlenmesi açık rızanıza dayanmaktadır. Rızanızı her zaman geri alma hakkına sahipsiniz. '
          'Rızanızı geri almak için melihenes2@gmail.com adresine e-posta gönderebilirsiniz. '
          'Rızanızı geri almanız, geri alma tarihinden önceki işlemlerin hukuka aykırılığına yol açmaz. '
          'Sağlık verisi işlemeye onay vermeden uygulamayı yalnızca menü görüntüleme amacıyla kullanabilirsiniz; ancak bu durumda profil ve kalori hesaplama özellikleri çalışmayacaktır.',
        ),

        // ─── 10. ÇEREZ VE ANALİZ ─────────────────────────────────────
        _buildSection('10. Çerez, Analitik ve Reklam'),
        _buildParagraph(
          'Uygulama; çerez, üçüncü taraf analitik aracı (Firebase Analytics, Mixpanel vb.), reklam ağı veya sosyal medya izleme pikseli kullanmamaktadır.',
        ),

        // ─── 11. DEĞİŞİKLİKLER ───────────────────────────────────────
        _buildSection('11. Aydınlatma Metnindeki Değişiklikler'),
        _buildParagraph(
          'Bu metin, uygulamanın yeni özellikler kazanması veya yasal düzenlemelerin değişmesi durumunda güncellenebilir. '
          'Önemli değişiklikler uygulama içi bildirim veya e-posta ile duyurulacaktır. '
          'Güncel metne her zaman uygulama içinden ulaşabilirsiniz.',
        ),

        const SizedBox(height: 12),
        Text(
          'Son güncelleme: 20 Mayıs 2026',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildSubSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        height: 1.6,
      ),
    );
  }
}
