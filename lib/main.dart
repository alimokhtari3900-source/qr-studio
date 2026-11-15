import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const publicSiteUrl = String.fromEnvironment(
  'PUBLIC_SITE_URL',
  defaultValue: 'https://alimokhtari3900-source.github.io/qr-studio/pro',
);
const productImageBucket = 'product-images';
const maxProductImages = 6;
const maxImageBytes = 8 * 1024 * 1024;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configured = supabaseUrl.startsWith('https://') &&
      supabasePublishableKey.isNotEmpty;
  if (configured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }
  runApp(QRStudioApp(configured: configured));
}

class QRStudioApp extends StatelessWidget {
  const QRStudioApp({super.key, required this.configured});
  final bool configured;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'QR Studio Pro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF21163D),
            primary: const Color(0xFF21163D),
            secondary: const Color(0xFFD9A441),
          ),
          scaffoldBackgroundColor: const Color(0xFFF6F5F8),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF6F5F8),
            foregroundColor: Color(0xFF21163D),
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: configured ? const AuthGate() : const SetupRequired(),
      );
}

class SetupRequired extends StatelessWidget {
  const SetupRequired({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(),
                const SizedBox(height: 20),
                const Text(
                  'QR Studio Pro',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'برای فعال‌سازی پنل مدیریت، تنظیمات اتصال Supabase را کامل کنید.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 18),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'متغیرهای SUPABASE_URL و SUPABASE_PUBLISHABLE_KEY باید در تنظیمات GitHub ثبت شوند و APK دوباره ساخته شود.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const Text(
                  'کلید Secret یا Service Role نباید داخل اپلیکیشن قرار بگیرد.',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ],
            ),
          ),
        ),
      );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(color: Color(0x33332248), blurRadius: 28, offset: Offset(0, 11)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset('assets/branding/qr-studio-pro-icon.png', fit: BoxFit.cover),
      );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  bool allowed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() { loading = false; allowed = false; });
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('admin_users')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();
      if (mounted) setState(() { allowed = row != null; loading = false; });
    } catch (_) {
      if (mounted) setState(() { allowed = false; loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (Supabase.instance.client.auth.currentUser == null) {
      return LoginScreen(onLogin: _check);
    }
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('QR Studio')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                const Text('این حساب دسترسی مدیر ندارد.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    _check();
                  },
                  child: const Text('خروج'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const DashboardScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});
  final Future<void> Function() onLogin;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> login() async {
    setState(() { busy = true; error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
      await widget.onLogin();
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'اتصال برقرار نشد. اینترنت گوشی را بررسی کنید و دوباره تلاش کنید.');
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  const BrandMark(),
                  const SizedBox(height: 18),
                  const Text(
                    'QR Studio',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('مدیریت حرفه‌ای محصولات و QR Code'),
                  const SizedBox(height: 30),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'ایمیل مدیر',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    onSubmitted: (_) => busy ? null : login(),
                    decoration: const InputDecoration(
                      labelText: 'رمز عبور',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : login,
                      child: Text(busy ? 'در حال ورود...' : 'ورود به پنل مدیریت'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final search = TextEditingController();
  late Future<List<Map<String, dynamic>>> productsFuture;
  String filter = 'all';
  String sort = 'newest';
  String selectedCategory = 'همه دسته‌ها';
  String selectedBrand = 'همه برندها';

  @override
  void initState() {
    super.initState();
    productsFuture = load();
  }

  Future<List<Map<String, dynamic>>> load() async {
    final rows = await Supabase.instance.client
        .from('products').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => productsFuture = next);
    await next;
  }

  Future<void> editor([Map<String, dynamic>? product]) async {
    await Navigator.push(context,
      MaterialPageRoute(builder: (_) => ProductEditor(product: product)));
    if (mounted) await refresh();
  }

  String productUrl(Map<String, dynamic> product) {
    final base = publicSiteUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return base + '/product.html?id=' +
        Uri.encodeQueryComponent(product['id'].toString());
  }

  Future<void> copyLink(Map<String, dynamic> product) async {
    await Clipboard.setData(ClipboardData(text: productUrl(product)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لینک اختصاصی محصول کپی شد.')));
  }

  Future<void> changeActive(Map<String, dynamic> product) async {
    final next = product['is_active'] != true;
    try {
      await Supabase.instance.client.from('products')
          .update({'is_active': next}).eq('id', product['id']);
      await refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(next ? 'محصول دوباره فعال شد.' : 'محصول بایگانی شد.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تغییر وضعیت محصول انجام نشد.')));
    }
  }

  Future<void> duplicate(Map<String, dynamic> product) async {
    try {
      final data = <String, dynamic>{
        'name': (product['name']?.toString() ?? 'محصول') + ' - نسخه جدید',
        'code': null,
        'brand': product['brand'],
        'category': product['category'],
        'description': product['description'],
        'images': product['images'] ?? [],
        'attachments': product['attachments'] ?? [],
        'specifications': product['specifications'] ?? {},
        'custom_fields': product['custom_fields'] ?? {},
        'translations': product['translations'] ?? {},
        'contact': product['contact'] ?? {},
        'is_published': false,
        'is_active': true,
      };
      await Supabase.instance.client.from('products').insert(data);
      await refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نسخهٔ پیش‌نویس محصول ساخته شد. کد آن را جداگانه ثبت کنید.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کپی محصول انجام نشد.')));
    }
  }

  Future<void> exportCsv(List<Map<String, dynamic>> rows) async {
    String cell(dynamic value) =>
        '"' + (value?.toString() ?? '').replaceAll('"', '""') + '"';
    final lines = <String>[
      ['نام محصول', 'کد', 'برند', 'دسته‌بندی', 'وضعیت', 'تعداد اسکن'].map(cell).join(','),
      ...rows.map((p) => [
        p['name'], p['code'], p['brand'], p['category'],
        p['is_active'] != true ? 'بایگانی' : (p['is_published'] == true ? 'منتشرشده' : 'پیش‌نویس'),
        p['scan_count'] ?? 0,
      ].map(cell).join(',')),
    ];
    try {
      final directory = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String()
          .replaceAll(':', '-').split('.').first;
      final file = File('${directory.path}/qr-studio-pro-products-$stamp.csv');
      await file.writeAsString(
        '\uFEFF' + lines.join('\r\n'),
        encoding: utf8,
        flush: true,
      );
      await SharePlus.instance.share(ShareParams(
        title: 'گزارش محصولات QR Studio Pro',
        text: 'گزارش محصولات برای بازکردن در Excel یا ذخیره در فایل‌ها.',
        files: [XFile(file.path)],
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فایل CSV آمادهٔ ارسال یا ذخیره است.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ساخت یا اشتراک‌گذاری فایل CSV انجام نشد.')),
      );
    }
  }

  Widget statCard(String label, String value, IconData icon, Color tint) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFECE7F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: tint, size: 20),
          const SizedBox(height: 9),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF251936))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF82778F), fontWeight: FontWeight.w600)),
        ]),
      ));

  Widget productThumbnail(Map<String, dynamic> product) {
    final raw = product['images'];
    final url = raw is List && raw.isNotEmpty
        ? (raw.first is String ? raw.first as String
            : (raw.first is Map ? raw.first['url']?.toString() : null))
        : null;
    if (url == null || url.isEmpty) {
      return Container(width: 88, height: 100,
        decoration: BoxDecoration(color: const Color(0xFFF0EBF6), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.inventory_2_outlined, size: 32, color: Color(0xFF7652A0)));
    }
    return ClipRRect(borderRadius: BorderRadius.circular(16),
      child: Image.network(url, width: 88, height: 100, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(width: 88, height: 100,
          color: const Color(0xFFF0EBF6), child: const Icon(Icons.broken_image_outlined))));
  }

  Widget statusPill(Map<String, dynamic> product) {
    final archived = product['is_active'] != true;
    final published = product['is_published'] == true;
    final label = archived ? 'بایگانی' : (published ? 'منتشرشده' : 'پیش‌نویس');
    final color = archived ? const Color(0xFF77717E)
        : (published ? const Color(0xFF217A5B) : const Color(0xFF9A6B16));
    final bg = archived ? const Color(0xFFF0EEF2)
        : (published ? const Color(0xFFE7F5EE) : const Color(0xFFFFF4DE));
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)));
  }

  Widget productCard(Map<String, dynamic> product) => Card(
    margin: const EdgeInsets.only(bottom: 11), elevation: 0, color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21),
      side: const BorderSide(color: Color(0xFFECE7F0))),
    child: InkWell(borderRadius: BorderRadius.circular(21),
      onTap: () => Navigator.push(context,
        MaterialPageRoute(builder: (_) => QRScreen(product: product))),
      child: Padding(padding: const EdgeInsets.all(12),
        child: Row(children: [
          productThumbnail(product),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(product['name']?.toString() ?? 'بدون نام',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF251936)))),
              const SizedBox(width: 4), statusPill(product),
            ]),
            const SizedBox(height: 7),
            Text([product['brand'], product['category'],
              if ((product['code'] ?? '').toString().isNotEmpty) 'کد ' + product['code'].toString()]
              .where((v) => v != null && v.toString().trim().isNotEmpty).join('  •  '),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF82778F))),
            const SizedBox(height: 11),
            Row(children: [
              const Icon(Icons.qr_code_2_rounded, size: 16, color: Color(0xFF8B6AA8)),
              const SizedBox(width: 4),
              Text((product['scan_count'] ?? 0).toString() + ' اسکن',
                style: const TextStyle(fontSize: 11, color: Color(0xFF665B72))),
              const SizedBox(width: 12),
              const Icon(Icons.photo_library_outlined, size: 15, color: Color(0xFF8B6AA8)),
              const SizedBox(width: 4),
              Text(((product['images'] is List ? (product['images'] as List).length : 0)).toString() + ' عکس',
                style: const TextStyle(fontSize: 11, color: Color(0xFF665B72))),
            ]),
          ])),
          PopupMenuButton<String>(tooltip: 'عملیات محصول',
            onSelected: (value) {
              if (value == 'edit') editor(product);
              if (value == 'qr') Navigator.push(context, MaterialPageRoute(builder: (_) => QRScreen(product: product)));
              if (value == 'copy') copyLink(product);
              if (value == 'duplicate') duplicate(product);
              if (value == 'archive') changeActive(product);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('ویرایش'), dense: true)),
              const PopupMenuItem(value: 'qr', child: ListTile(leading: Icon(Icons.qr_code_2), title: Text('نمایش QR'), dense: true)),
              const PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.link), title: Text('کپی لینک'), dense: true)),
              const PopupMenuItem(value: 'duplicate', child: ListTile(leading: Icon(Icons.copy_all_outlined), title: Text('ساخت نسخهٔ کپی'), dense: true)),
              PopupMenuItem(value: 'archive', child: ListTile(
                leading: Icon(product['is_active'] == true ? Icons.archive_outlined : Icons.unarchive_outlined),
                title: Text(product['is_active'] == true ? 'بایگانی محصول' : 'فعال‌سازی دوباره'), dense: true)),
            ]),
        ]),
      ),
    ),
  );

  @override
  void dispose() { search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F5F9),
    appBar: AppBar(backgroundColor: const Color(0xFFF7F5F9),
      title: const Row(children: [
        Icon(Icons.auto_awesome, color: Color(0xFFC79B4A), size: 19),
        SizedBox(width: 7),
        Text('QR Studio Pro', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -.3)),
      ]),
      actions: [
        IconButton(tooltip: 'به‌روزرسانی فهرست', onPressed: refresh, icon: const Icon(Icons.refresh_rounded)),
        IconButton(tooltip: 'خروج از حساب', onPressed: () async {
          await Supabase.instance.client.auth.signOut();
          if (!context.mounted) return;
          Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const AuthGate()), (_) => false);
        }, icon: const Icon(Icons.logout_rounded)),
      ]),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: const Color(0xFF2A1B3D), foregroundColor: Colors.white,
      onPressed: () => editor(), icon: const Icon(Icons.add_rounded),
      label: const Text('محصول جدید', style: TextStyle(fontWeight: FontWeight.bold))),
    body: RefreshIndicator(onRefresh: refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(future: productsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ListView(children: const [
            SizedBox(height: 140), Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFF8F829B)),
            SizedBox(height: 12), Center(child: Text('دریافت اطلاعات انجام نشد. اتصال اینترنت را بررسی کنید.')),
          ]);
          final allRows = snap.data ?? [];
          final categories = allRows.map((p) => (p['category'] ?? '').toString().trim())
              .where((value) => value.isNotEmpty).toSet().toList()..sort();
          final brands = allRows.map((p) => (p['brand'] ?? '').toString().trim())
              .where((value) => value.isNotEmpty).toSet().toList()..sort();
          final categoryOptions = ['همه دسته‌ها', ...categories];
          final brandOptions = ['همه برندها', ...brands];
          final activeCategory = categoryOptions.contains(selectedCategory)
              ? selectedCategory : 'همه دسته‌ها';
          final activeBrand = brandOptions.contains(selectedBrand)
              ? selectedBrand : 'همه برندها';
          final published = allRows.where((p) => p['is_active'] == true && p['is_published'] == true).length;
          final drafts = allRows.where((p) => p['is_active'] == true && p['is_published'] != true).length;
          final archived = allRows.where((p) => p['is_active'] != true).length;
          final query = search.text.trim().toLowerCase();
          var visible = allRows.where((p) {
            final haystack = [p['name'], p['code'], p['brand'], p['category']]
                .where((v) => v != null).join(' ').toLowerCase();
            final matchesText = query.isEmpty || haystack.contains(query);
            final active = p['is_active'] == true;
            final matchesFilter = filter == 'all' ||
                (filter == 'published' && active && p['is_published'] == true) ||
                (filter == 'draft' && active && p['is_published'] != true) ||
                (filter == 'archived' && !active);
            final matchesCategory = activeCategory == 'همه دسته‌ها' ||
                (p['category'] ?? '').toString().trim() == activeCategory;
            final matchesBrand = activeBrand == 'همه برندها' ||
                (p['brand'] ?? '').toString().trim() == activeBrand;
            return matchesText && matchesFilter && matchesCategory && matchesBrand;
          }).toList();
          if (sort == 'name') {
            visible.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
          } else if (sort == 'scans') {
            visible.sort((a, b) => ((b['scan_count'] ?? 0) as num).compareTo((a['scan_count'] ?? 0) as num));
          } else {
            visible.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
          }
          return ListView(physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
            children: [
              Container(padding: const EdgeInsets.all(21),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(25),
                  gradient: const LinearGradient(colors: [Color(0xFF171222), Color(0xFF39234E), Color(0xFF64417A)],
                    begin: Alignment.topRight, end: Alignment.bottomLeft),
                  boxShadow: const [BoxShadow(color: Color(0x22301A48), blurRadius: 22, offset: Offset(0, 10))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFE8C37C), size: 30)),
                    const Spacer(),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(color: const Color(0x33D9B56B), borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0x66D9B56B))),
                      child: const Text('PRO  •  نسخه ۲', style: TextStyle(color: Color(0xFFF2D8A2), fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: .5))),
                  ]),
                  const SizedBox(height: 18),
                  const Text('مدیریت هوشمند کاتالوگ محصولات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                  const SizedBox(height: 6),
                  const Text('از ثبت مشخصات تا معرفی دیجیتال و QR اختصاصی؛ همه‌چیز یک‌جا و مرتب.',
                    style: TextStyle(color: Color(0xFFD7CEDF), height: 1.7, fontSize: 12)),
                  const SizedBox(height: 15),
                  Row(children: [
                    const Icon(Icons.verified_user_outlined, color: Color(0xFFE8C37C), size: 16),
                    const SizedBox(width: 6),
                    Text(allRows.length.toString() + ' محصول در فضای کاری شما',
                      style: const TextStyle(color: Color(0xFFE7DDEC), fontSize: 11)),
                  ]),
                ])),
              const SizedBox(height: 14),
              Row(children: [
                statCard('کل محصولات', allRows.length.toString(), Icons.inventory_2_outlined, const Color(0xFF7652A0)),
                const SizedBox(width: 8),
                statCard('منتشرشده', published.toString(), Icons.public_rounded, const Color(0xFF21845E)),
                const SizedBox(width: 8),
                statCard('پیش‌نویس', drafts.toString(), Icons.edit_note_rounded, const Color(0xFFB17B22)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.archive_outlined, size: 15, color: Color(0xFF82778F)),
                const SizedBox(width: 5),
                Text(archived.toString() + ' محصول بایگانی‌شده', style: const TextStyle(fontSize: 11, color: Color(0xFF82778F))),
                const Spacer(),
                TextButton.icon(onPressed: allRows.isEmpty ? null : () => exportCsv(allRows),
                  icon: const Icon(Icons.file_download_outlined, size: 17), label: const Text('گزارش CSV')),
              ]),
              const SizedBox(height: 8),
              TextField(controller: search, onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'جست‌وجوی نام، کد، برند یا دسته‌بندی',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty ? null : IconButton(tooltip: 'پاک کردن جست‌وجو',
                    onPressed: () { search.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded)),
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(color: Color(0xFFECE7F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(color: Color(0xFFECE7F0))),
                )),
              const SizedBox(height: 13),
              SingleChildScrollView(scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _filterChip('همه', 'all'), _filterChip('منتشرشده', 'published'),
                  _filterChip('پیش‌نویس', 'draft'), _filterChip('بایگانی', 'archived'),
                ])),
              const SizedBox(height: 10),
              Row(children: [
                _facetDropdown(
                  value: activeCategory,
                  options: categoryOptions,
                  onChanged: (value) => setState(() =>
                      selectedCategory = value ?? 'همه دسته‌ها'),
                ),
                const SizedBox(width: 8),
                _facetDropdown(
                  value: activeBrand,
                  options: brandOptions,
                  onChanged: (value) => setState(() =>
                      selectedBrand = value ?? 'همه برندها'),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Text('فهرست محصولات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF2B2038))),
                const Spacer(),
                Text(visible.length.toString() + ' مورد', style: const TextStyle(color: Color(0xFF8A8093), fontSize: 11)),
                const SizedBox(width: 8),
                DropdownButton<String>(value: sort, underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(14),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF51445F)),
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('جدیدترین')),
                    DropdownMenuItem(value: 'name', child: Text('نام محصول')),
                    DropdownMenuItem(value: 'scans', child: Text('بیشترین اسکن')),
                  ],
                  onChanged: (value) { if (value != null) setState(() => sort = value); }),
              ]),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                Container(padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFECE7F0))),
                  child: Column(children: [
                    const Icon(Icons.search_off_rounded, size: 42, color: Color(0xFF9B8DA8)),
                    const SizedBox(height: 10),
                    Text(allRows.isEmpty ? 'هنوز محصولی ثبت نشده است.' : 'محصولی با این فیلتر پیدا نشد.',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF5E526A))),
                    const SizedBox(height: 6),
                    const Text('با افزودن محصول یا تغییر جست‌وجو شروع کنید.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF93899B))),
                  ]))
              else
                ...visible.map(productCard),
              const SizedBox(height: 12),
              const Center(child: Text('QR Studio Pro  •  معرفی هوشمند محصولات',
                style: TextStyle(color: Color(0xFF9A91A2), fontSize: 10))),
            ]);
        })),
  );

  Widget _facetDropdown({
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) => Expanded(
    child: Container(
      height: 50,
      padding: const EdgeInsetsDirectional.only(start: 12, end: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFECE7F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value : options.first,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, size: 19),
          style: const TextStyle(
            color: Color(0xFF594B66),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          items: options.map((option) => DropdownMenuItem<String>(
            value: option,
            child: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    ),
  );

  Widget _filterChip(String label, String value) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 7),
    child: ChoiceChip(label: Text(label), selected: filter == value,
      onSelected: (_) => setState(() => filter = value),
      selectedColor: const Color(0xFFE9DDF2), backgroundColor: Colors.white,
      side: BorderSide(color: filter == value ? const Color(0xFFB79ACB) : const Color(0xFFECE7F0)),
      labelStyle: TextStyle(color: filter == value ? const Color(0xFF4C2F66) : const Color(0xFF786D83),
        fontWeight: FontWeight.bold, fontSize: 11)),
  );
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, this.product});
  final Map<String, dynamic>? product;
  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final form = GlobalKey<FormState>();
  final picker = ImagePicker();
  late final name = TextEditingController(
    text: widget.product?['name']?.toString() ?? '',
  );
  late final code = TextEditingController(
    text: widget.product?['code']?.toString() ?? '',
  );
  late final brand = TextEditingController(
    text: widget.product?['brand']?.toString() ?? '',
  );
  late final category = TextEditingController(
    text: widget.product?['category']?.toString() ?? '',
  );
  late final description = TextEditingController(
    text: widget.product?['description']?.toString() ?? '',
  );
  late final specifications = TextEditingController(
    text: _formatMap(widget.product?['specifications']),
  );
  late final contactPhone = TextEditingController(
    text: _contactValue('phone'),
  );
  late final contactWhatsapp = TextEditingController(
    text: _contactValue('whatsapp'),
  );
  late final contactWebsite = TextEditingController(
    text: _contactValue('website'),
  );
  late final customFields = TextEditingController(
    text: _formatMap(widget.product?['custom_fields']),
  );
  late final englishName = TextEditingController(
    text: _translationValue('name'),
  );
  late final englishDescription = TextEditingController(
    text: _translationValue('description'),
  );
  late final catalogUrl = TextEditingController(
    text: _attachmentValue('catalog'),
  );
  late final videoUrl = TextEditingController(
    text: _attachmentValue('video'),
  );
  final List<XFile> selectedImages = [];
  List<String> existingImages = [];
  List<dynamic> preservedAttachments = [];
  bool published = false;
  bool active = true;
  bool busy = false;
  bool picking = false;

  @override
  void initState() {
    super.initState();
    published = widget.product?['is_published'] == true;
    active = widget.product?['is_active'] != false;
    final rawAttachments = widget.product?['attachments'];
    if (rawAttachments is List) {
      preservedAttachments = rawAttachments.where((item) {
        if (item is! Map) return false;
        final type = item['type']?.toString();
        return type != 'catalog' && type != 'video';
      }).toList();
    }
    final rawImages = widget.product?['images'];
    if (rawImages is List) {
      existingImages = rawImages
          .map((item) {
            if (item is String) return item;
            if (item is Map) return item['url']?.toString() ?? '';
            return '';
          })
          .where((url) => url.startsWith('https://'))
          .toList();
    }
  }


  String _contactValue(String key) {
    final raw = widget.product?['contact'];
    if (raw is Map) return raw[key]?.toString() ?? '';
    return '';
  }

  String _translationValue(String key) {
    final raw = widget.product?['translations'];
    if (raw is Map && raw['en'] is Map) {
      return raw['en'][key]?.toString() ?? '';
    }
    return '';
  }

  String _attachmentValue(String type) {
    final raw = widget.product?['attachments'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map && item['type']?.toString() == type) {
          return item['url']?.toString() ?? '';
        }
      }
    }
    return '';
  }

  String _formatMap(dynamic value) {
    if (value is! Map) return '';
    return value.entries
        .where((entry) => entry.value != null && entry.value.toString().trim().isNotEmpty)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(String.fromCharCode(10));
  }

  Map<String, String> _parseLines(String text) {
    final result = <String, String>{};
    for (final line in text.split(String.fromCharCode(10))) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) result[key] = value;
    }
    return result;
  }

  Future<void> pickImages() async {
    final remaining = maxProductImages - existingImages.length -
        selectedImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حداکثر ۶ عکس برای هر محصول مجاز است.')),
      );
      return;
    }
    setState(() => picking = true);
    try {
      final files = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (!mounted) return;
      setState(() {
        selectedImages.addAll(files.take(remaining));
        picking = false;
      });
      if (files.length > remaining && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فقط ۶ عکس اول اضافه شدند.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => picking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('انتخاب عکس انجام نشد. دوباره تلاش کنید.')),
        );
      }
    }
  }

  String imageExtension(XFile file) {
    final extension = file.name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'webp'].contains(extension)) return extension;
    throw Exception('فرمت عکس باید JPG، PNG یا WEBP باشد.');
  }

  String imageMimeType(String extension) {
    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final client = Supabase.instance.client;
    final uploadedPaths = <String>[];
    try {
      final imageUrls = [...existingImages];
      final userId = client.auth.currentUser?.id;
      if (selectedImages.isNotEmpty && userId == null) {
        throw Exception('نشست مدیر منقضی شده است. دوباره وارد شوید.');
      }
      final bucket = client.storage.from(productImageBucket);
      for (var index = 0; index < selectedImages.length; index++) {
        final file = selectedImages[index];
        final extension = imageExtension(file);
        final bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > maxImageBytes) {
          throw Exception('حجم هر عکس نباید بیشتر از ۸ مگابایت باشد.');
        }
        final path =
            '$userId/${DateTime.now().microsecondsSinceEpoch}_$index.$extension';
        await bucket.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            contentType: imageMimeType(extension),
            upsert: false,
          ),
        );
        uploadedPaths.add(path);
        imageUrls.add(bucket.getPublicUrl(path));
      }

      final data = {
        'name': name.text.trim(),
        'code': code.text.trim().isEmpty ? null : code.text.trim(),
        'brand': brand.text.trim(),
        'category': category.text.trim(),
        'description': description.text.trim(),
        'images': imageUrls,
        'specifications': _parseLines(specifications.text),
        'custom_fields': _parseLines(customFields.text),
        'attachments': [
          ...preservedAttachments,
          if (catalogUrl.text.trim().isNotEmpty)
            {'title': 'دانلود کاتالوگ', 'type': 'catalog', 'url': catalogUrl.text.trim()},
          if (videoUrl.text.trim().isNotEmpty)
            {'title': 'ویدئوی معرفی', 'type': 'video', 'url': videoUrl.text.trim()},
        ],
        'translations': {
          if (englishName.text.trim().isNotEmpty || englishDescription.text.trim().isNotEmpty)
            'en': {
              if (englishName.text.trim().isNotEmpty) 'name': englishName.text.trim(),
              if (englishDescription.text.trim().isNotEmpty) 'description': englishDescription.text.trim(),
            },
        },
        'contact': {
          if (contactPhone.text.trim().isNotEmpty) 'phone': contactPhone.text.trim(),
          if (contactWhatsapp.text.trim().isNotEmpty) 'whatsapp': contactWhatsapp.text.trim(),
          if (contactWebsite.text.trim().isNotEmpty) 'website': contactWebsite.text.trim(),
        },
        'is_published': published,
        'is_active': active,
      };
      final query = client.from('products');
      if (widget.product == null) {
        await query.insert(data);
      } else {
        await query.update(data).eq('id', widget.product!['id']);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await client.storage.from(productImageBucket).remove(uploadedPaths);
        } catch (_) {
          // The database error is more useful than a cleanup error.
        }
      }
      if (mounted) {
        final message = e is StorageException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ذخیره انجام نشد: $message')),
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Widget imageTile(Widget image, VoidCallback onRemove) => SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: image,
              ),
            ),
            Positioned(
              top: 3,
              right: 3,
              child: InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xBB17152D),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    brand.dispose();
    category.dispose();
    description.dispose();
    specifications.dispose();
    contactPhone.dispose();
    contactWhatsapp.dispose();
    contactWebsite.dispose();
    customFields.dispose();
    englishName.dispose();
    englishDescription.dispose();
    catalogUrl.dispose();
    videoUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.product == null ? 'ثبت محصول جدید' : 'ویرایش محصول'),
        ),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تصاویر محصول',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'تا ۶ عکس واضح از زوایای مختلف اضافه کنید. عکس‌ها پس از ذخیره در صفحه QR نمایش داده می‌شوند.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: [
                          ...existingImages.asMap().entries.map(
                                (entry) => imageTile(
                                  Image.network(
                                    entry.value,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const ColoredBox(
                                      color: Color(0xFFEDE8F4),
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                  () => setState(
                                    () => existingImages.removeAt(entry.key),
                                  ),
                                ),
                              ),
                          ...selectedImages.asMap().entries.map(
                                (entry) => imageTile(
                                  FutureBuilder<Uint8List>(
                                    future: entry.value.readAsBytes(),
                                    builder: (context, snapshot) =>
                                        snapshot.hasData
                                            ? Image.memory(
                                                snapshot.data!,
                                                fit: BoxFit.cover,
                                              )
                                            : const ColoredBox(
                                                color: Color(0xFFEDE8F4),
                                                child: Center(
                                                  child: Icon(Icons.image_outlined),
                                                ),
                                              ),
                                  ),
                                  () => setState(
                                    () => selectedImages.removeAt(entry.key),
                                  ),
                                ),
                              ),
                          if (existingImages.length + selectedImages.length <
                              maxProductImages)
                            SizedBox(
                              width: 96,
                              height: 96,
                              child: OutlinedButton(
                                onPressed: busy || picking ? null : pickImages,
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: picking
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate_outlined),
                                          SizedBox(height: 5),
                                          Text('افزودن عکس'),
                                        ],
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'نام محصول *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'نام محصول الزامی است'
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'کد محصول'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: brand,
                decoration: const InputDecoration(labelText: 'برند / تولیدکننده'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: 'دسته‌بندی'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                maxLines: 6,
                maxLength: 3000,
                decoration: const InputDecoration(
                  labelText: 'توضیحات محصول',
                  hintText: 'ویژگی‌ها، کاربرد، جنس، روش استفاده و سایر توضیحات...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              const Text('مشخصات فنی و ویژگی‌ها', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 5),
              const Text('هر ویژگی را در یک خط بنویسید؛ قالب هر خط: عنوان: مقدار', style: TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: specifications,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'مثال: جنس: سنگ طبیعی، ابعاد: ۴۰ × ۴۰، رنگ: کرم',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              const Text('ویژگی‌های برجسته', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 5),
              const Text('موارد مهمی که می‌خواهید جداگانه در صفحه مشتری دیده شوند؛ هر خط: عنوان: مقدار', style: TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: customFields,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'مثال: ضمانت: ۲۴ ماه، ساخت: ایران، کاربرد: فضای داخلی',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              const Text('اطلاعات انگلیسی (اختیاری)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(controller: englishName, textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'Product name (English)')),
              const SizedBox(height: 10),
              TextField(controller: englishDescription, textDirection: TextDirection.ltr,
                maxLines: 3, decoration: const InputDecoration(labelText: 'Product description (English)')),
              const SizedBox(height: 18),
              const Text('کاتالوگ و ویدئوی معرفی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 5),
              const Text('لینک مستقیم فایل یا صفحهٔ کاتالوگ و ویدئو را وارد کنید.', style: TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(controller: catalogUrl, textDirection: TextDirection.ltr,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'لینک کاتالوگ / فایل PDF', prefixIcon: Icon(Icons.picture_as_pdf_outlined))),
              const SizedBox(height: 10),
              TextField(controller: videoUrl, textDirection: TextDirection.ltr,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'لینک ویدئوی معرفی', prefixIcon: Icon(Icons.play_circle_outline))),
              const SizedBox(height: 18),
              const Text('راه‌های ارتباط با مجموعه (اختیاری)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: contactPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'شماره تماس', prefixIcon: Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contactWhatsapp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'شماره واتساپ با کد کشور', prefixIcon: Icon(Icons.chat_outlined)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contactWebsite,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'وب‌سایت مجموعه', hintText: 'https://example.com', prefixIcon: Icon(Icons.language_outlined)),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: Column(children: [
                  SwitchListTile(
                    value: published,
                    onChanged: busy ? null : (value) => setState(() => published = value),
                    secondary: const Icon(Icons.public_rounded),
                    title: const Text('انتشار عمومی محصول'),
                    subtitle: const Text('با فعال‌کردن این گزینه، صفحه محصول از طریق QR برای همه قابل مشاهده می‌شود.'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    value: active,
                    onChanged: busy ? null : (value) => setState(() => active = value),
                    secondary: const Icon(Icons.inventory_2_outlined),
                    title: const Text('محصول فعال باشد'),
                    subtitle: const Text('محصول غیرفعال در فهرست عمومی نمایش داده نمی‌شود؛ اطلاعاتش حذف نخواهد شد.'),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: busy ? null : save,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(busy ? 'در حال ذخیره محصول و عکس‌ها...' : 'ذخیره محصول'),
                ),
              ),
            ],
          ),
        ),
      );
}

class QRScreen extends StatelessWidget {
  const QRScreen({super.key, required this.product});
  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context) {
    final baseUrl = publicSiteUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final id = Uri.encodeQueryComponent(product['id'].toString());
    final url = baseUrl + '/product.html?id=' + id;
    final isPublished = product['is_published'] == true && product['is_active'] == true;
    final rawImages = product['images'];
    final imageCount = rawImages is List ? rawImages.length : 0;
    final specs = product['specifications'];
    final specCount = specs is Map ? specs.length : 0;
    final qrCaptureKey = GlobalKey();

    Future<void> shareQrImage() async {
      try {
        final renderObject = qrCaptureKey.currentContext?.findRenderObject();
        if (renderObject is! RenderRepaintBoundary) {
          throw StateError('QR هنوز آمادهٔ خروجی نیست.');
        }
        final image = await renderObject.toImage(pixelRatio: 4.0);
        try {
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) throw StateError('تبدیل تصویر QR انجام نشد.');
          final directory = await getTemporaryDirectory();
          final safeCode = (product['code'] ?? product['id'] ?? 'product')
              .toString().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
          final file = File('${directory.path}/QR-Studio-Pro-$safeCode.png');
          await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
          await SharePlus.instance.share(ShareParams(
            title: 'QR اختصاصی ${product['name'] ?? ''}',
            text: 'کد QR برای مشاهدهٔ صفحهٔ معرفی محصول:\\n$url',
            files: [XFile(file.path)],
          ));
        } finally {
          image.dispose();
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تصویر QR با کیفیت بالا آمادهٔ ارسال یا ذخیره است.')),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ساخت تصویر QR انجام نشد؛ دوباره تلاش کنید.')),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F9),
      appBar: AppBar(
        title: const Text('پروفایل QR محصول'),
        backgroundColor: const Color(0xFFF7F5F9),
        actions: [
          IconButton(
            tooltip: 'ویرایش محصول',
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ProductEditor(product: product))),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF171222), Color(0xFF49325F)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFFE8C37C), size: 18),
                        const SizedBox(width: 7),
                        const Text('QR STUDIO PRO', style: TextStyle(
                          color: Color(0xFFE8C37C), fontWeight: FontWeight.w900,
                          fontSize: 10, letterSpacing: 1.2)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPublished ? const Color(0x332BBD83) : const Color(0x33E8B35C),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text(isPublished ? 'عمومی و فعال' : 'خصوصی / غیرفعال',
                            style: TextStyle(color: isPublished ? const Color(0xFF9AF0C8) : const Color(0xFFFFD99B),
                              fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      const SizedBox(height: 18),
                      Text(product['name']?.toString() ?? 'محصول بدون نام',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 21)),
                      const SizedBox(height: 7),
                      Text([
                        if ((product['brand'] ?? '').toString().isNotEmpty) product['brand'].toString(),
                        if ((product['category'] ?? '').toString().isNotEmpty) product['category'].toString(),
                        if ((product['code'] ?? '').toString().isNotEmpty) 'کد ' + product['code'].toString(),
                      ].join('  •  '),
                        style: const TextStyle(color: Color(0xFFD9D0E2), fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!isPublished)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3DD),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: const Color(0xFFF1D9AE)),
                    ),
                    child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF996515)),
                      SizedBox(width: 10),
                      Expanded(child: Text(
                        'برای اینکه مشتری بعد از اسکن بتواند صفحه محصول را ببیند، محصول باید فعال و انتشار عمومی آن روشن باشد.',
                        style: TextStyle(color: Color(0xFF795312), height: 1.6, fontSize: 12))),
                    ]),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFECE7F0)),
                    boxShadow: const [BoxShadow(color: Color(0x0E271438), blurRadius: 24, offset: Offset(0, 10))],
                  ),
                  child: Column(children: [
                    const Text('کد اختصاصی معرفی محصول', style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF2D203A))),
                    const SizedBox(height: 5),
                    const Text('با دوربین گوشی اسکن کنید', style: TextStyle(
                      color: Color(0xFF8B8095), fontSize: 11)),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCFBFD),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFEFEAF2)),
                      ),
                      child: RepaintBoundary(
                        key: qrCaptureKey,
                        child: QrImageView(
                        data: url,
                        size: 248,
                        backgroundColor: const Color(0xFFFCFBFD),
                        foregroundColor: const Color(0xFF241A32),
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        embeddedImage: const AssetImage('assets/branding/qr-studio-pro-icon.png'),
                        embeddedImageStyle: const QrEmbeddedImageStyle(
                          size: Size(42, 42),
                        ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      _metricPill(Icons.photo_library_outlined, imageCount.toString() + ' تصویر'),
                      const SizedBox(width: 8),
                      _metricPill(Icons.fact_check_outlined, specCount.toString() + ' مشخصه'),
                      const SizedBox(width: 8),
                      _metricPill(Icons.qr_code_scanner_rounded, (product['scan_count'] ?? 0).toString() + ' اسکن'),
                    ]),
                    const SizedBox(height: 17),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2A1B3D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: url));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('لینک صفحه محصول کپی شد.')));
                        },
                        icon: const Icon(Icons.content_copy_rounded),
                        label: const Text('کپی لینک صفحه محصول'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: shareQrImage,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5A426C),
                          side: const BorderSide(color: Color(0xFFDCCFE5)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('دریافت و اشتراک‌گذاری تصویر QR (PNG)'),
                      ),
                    ),
                    const SizedBox(height: 7),
                    SelectableText(url, textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF71518C), fontSize: 10)),
                  ]),
                ),
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFECE7F0))),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFC0923F)),
                    SizedBox(width: 10),
                    Expanded(child: Text(
                      'پیشنهاد: این QR را روی برچسب، بسته‌بندی یا کارت معرفی محصول چاپ کنید. قبل از چاپ، آن را با یک گوشی دیگر آزمایش کنید.',
                      style: TextStyle(color: Color(0xFF74697F), fontSize: 11, height: 1.65))),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricPill(IconData icon, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
      decoration: BoxDecoration(color: const Color(0xFFF6F2F8), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 13, color: const Color(0xFF84639D)),
        const SizedBox(width: 4),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, color: Color(0xFF65566F), fontWeight: FontWeight.w700))),
      ]),
    ),
  );
}

