import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const publicSiteUrl = String.fromEnvironment('PUBLIC_SITE_URL',
    defaultValue: 'https://alimokhtari3900-source.github.io/qr-studio');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configured = supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;
  if (configured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(QRStudioApp(configured: configured));
}

class QRStudioApp extends StatelessWidget {
  const QRStudioApp({super.key, required this.configured});
  final bool configured;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QR Studio',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF18162F), primary: const Color(0xFF18162F), secondary: const Color(0xFFD99A32)),
      scaffoldBackgroundColor: const Color(0xFFF6F4F9),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF6F4F9), foregroundColor: Color(0xFF18162F), elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    ),
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: configured ? const AuthGate() : const SetupRequired(),
  );
}

class SetupRequired extends StatelessWidget {
  const SetupRequired({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const BrandMark(),
        const SizedBox(height: 20),
        const Text('QR Studio', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('اپلیکیشن نصب شده است؛ برای فعال‌سازی پنل مدیریت باید پروژه Supabase به آن متصل شود.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        const SizedBox(height: 18),
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('مدیر سیستم باید متغیرهای SUPABASE_URL و SUPABASE_ANON_KEY را در تنظیمات GitHub وارد کند و نسخه را دوباره بسازد.', textAlign: TextAlign.center))),
        const Text('کلید Service Role هرگز نباید در اپلیکیشن قرار بگیرد.', style: TextStyle(color: Colors.redAccent)),
      ]),
    )),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 112, height: 112,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      gradient: const LinearGradient(colors: [Color(0xFF17152D), Color(0xFF47207A), Color(0xFF111B44)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      boxShadow: const [BoxShadow(color: Color(0x443A1B75), blurRadius: 24, offset: Offset(0, 10))],
    ),
    child: Stack(alignment: Alignment.center, children: [
      const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 76),
      Positioned(right: 14, top: 12, child: Icon(Icons.auto_awesome, color: Colors.amber.shade300, size: 20)),
      Positioned(bottom: 12, left: 16, child: Container(width: 28, height: 5, decoration: BoxDecoration(color: Colors.amber.shade400, borderRadius: BorderRadius.circular(9)))),
    ]),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override State<AuthGate> createState() => _AuthGateState();
}
class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  bool allowed = false;
  @override void initState() { super.initState(); _check(); }
  Future<void> _check() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) { if (mounted) setState(() { loading = false; allowed = false; }); return; }
    try {
      final row = await Supabase.instance.client.from('admin_users').select('user_id').eq('user_id', user.id).maybeSingle();
      if (mounted) setState(() { allowed = row != null; loading = false; });
    } catch (_) { if (mounted) setState(() { allowed = false; loading = false; }); }
  }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (Supabase.instance.client.auth.currentUser == null) return LoginScreen(onLogin: _check);
    if (!allowed) return Scaffold(appBar: AppBar(title: const Text('QR Studio')), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.lock_outline, size: 48), const SizedBox(height: 12), const Text('این حساب دسترسی مدیر ندارد.'), const SizedBox(height: 12), FilledButton(onPressed: () async { await Supabase.instance.client.auth.signOut(); _check(); }, child: const Text('خروج'))]))));
    return const DashboardScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});
  final Future<void> Function() onLogin;
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(); final password = TextEditingController();
  bool busy = false; String? error;
  Future<void> login() async {
    setState(() { busy = true; error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      await widget.onLogin();
    } on AuthException catch (e) { setState(() => error = e.message); }
    catch (e) { setState(() => error = e.toString()); }
    if (mounted) setState(() => busy = false);
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(children: [
    const BrandMark(), const SizedBox(height: 18), const Text('QR Studio', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('مدیریت هوشمند محصولات و QR Code'),
    const SizedBox(height: 30), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ایمیل مدیر', prefixIcon: Icon(Icons.email_outlined))),
    const SizedBox(height: 12), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'رمز عبور', prefixIcon: Icon(Icons.lock_outline))),
    if (error != null) Padding(padding: const EdgeInsets.all(10), child: Text(error!, style: const TextStyle(color: Colors.red))),
    const SizedBox(height: 16), SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : login, child: Text(busy ? 'در حال ورود...' : 'ورود به پنل مدیریت'))),
  ])))));
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  final search = TextEditingController(); bool busy = false;
  Future<List<Map<String,dynamic>>> load() async {
    var q = Supabase.instance.client.from('products').select().order('created_at', ascending: false);
    final text = search.text.trim();
    if (text.isNotEmpty) q = q.ilike('name', '%$text%');
    final rows = await q;
    return List<Map<String,dynamic>>.from(rows);
  }
  Future<void> refresh() async { setState(() => busy = true); await Future<void>.delayed(const Duration(milliseconds: 200)); if (mounted) setState(() => busy = false); }
  Future<void> editor([Map<String,dynamic>? product]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductEditor(product: product)));
    if (mounted) setState(() {});
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QR Studio', style: TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(onPressed: () async { await Supabase.instance.client.auth.signOut(); if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthGate()), (_) => false); }, icon: const Icon(Icons.logout))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => editor(), icon: const Icon(Icons.add), label: const Text('محصول جدید')),
    body: RefreshIndicator(onRefresh: refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Color(0xFF15142E), Color(0xFF54268A)])), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('پنل مدیریت محصولات', style: TextStyle(color: Colors.white70)), SizedBox(height: 8), Text('محصولات خود را مدیریت کنید', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 21)), SizedBox(height: 4), Text('برای هر محصول یک QR اختصاصی بسازید.', style: TextStyle(color: Colors.white70))])),
      const SizedBox(height: 16), TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'جست‌وجوی نام محصول', prefixIcon: Icon(Icons.search))),
      const SizedBox(height: 12), FutureBuilder<List<Map<String,dynamic>>>(future: load(), builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
        if (snap.hasError) return Text('خطا در دریافت محصولات: ${snap.error}');
        final rows = snap.data ?? [];
        if (rows.isEmpty) return const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('هنوز محصولی ثبت نشده است.')));
        return Column(children: rows.map((p) => Card(child: ListTile(
          title: Text(p['name']?.toString() ?? 'بدون نام', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('کد: ${p['code'] ?? '-'} • اسکن: ${p['scan_count'] ?? 0}'),
          leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QRScreen(product: p))),
          onLongPress: () => editor(p),
        ))).toList());
      }),
      const Padding(padding: EdgeInsets.only(top: 12), child: Text('برای نمایش QR روی محصول ضربه بزنید؛ برای ویرایش، لمس طولانی کنید.', style: TextStyle(color: Colors.black54, fontSize: 12))),
    ])),
  );
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, this.product});
  final Map<String,dynamic>? product;
  @override State<ProductEditor> createState() => _ProductEditorState();
}
class _ProductEditorState extends State<ProductEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.product?['name']?.toString() ?? '');
  late final code = TextEditingController(text: widget.product?['code']?.toString() ?? '');
  late final brand = TextEditingController(text: widget.product?['brand']?.toString() ?? '');
  late final category = TextEditingController(text: widget.product?['category']?.toString() ?? '');
  late final description = TextEditingController(text: widget.product?['description']?.toString() ?? '');
  bool published = false, busy = false;
  @override void initState() { super.initState(); published = widget.product?['is_published'] == true; }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final data = {'name': name.text.trim(), 'code': code.text.trim().isEmpty ? null : code.text.trim(), 'brand': brand.text.trim(), 'category': category.text.trim(), 'description': description.text.trim(), 'is_published': published, 'is_active': true};
    try {
      final q = Supabase.instance.client.from('products');
      if (widget.product == null) { await q.insert(data); } else { await q.update(data).eq('id', widget.product!['id']); }
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ذخیره نشد: $e'))); }
    if (mounted) setState(() => busy = false);
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.product == null ? 'ثبت محصول' : 'ویرایش محصول')), body: Form(key: form, child: ListView(padding: const EdgeInsets.all(16), children: [
    TextFormField(controller: name, decoration: const InputDecoration(labelText: 'نام محصول *'), validator: (v) => (v == null || v.trim().isEmpty) ? 'نام محصول الزامی است' : null),
    const SizedBox(height: 12), TextField(controller: code, decoration: const InputDecoration(labelText: 'کد محصول')),
    const SizedBox(height: 12), TextField(controller: brand, decoration: const InputDecoration(labelText: 'برند / تولیدکننده')),
    const SizedBox(height: 12), TextField(controller: category, decoration: const InputDecoration(labelText: 'دسته‌بندی')),
    const SizedBox(height: 12), TextField(controller: description, maxLines: 5, decoration: const InputDecoration(labelText: 'توضیحات')),
    SwitchListTile(value: published, onChanged: (v) => setState(() => published = v), title: const Text('انتشار عمومی محصول')),
    const SizedBox(height: 16), FilledButton.icon(onPressed: busy ? null : save, icon: const Icon(Icons.save), label: Text(busy ? 'در حال ذخیره...' : 'ذخیره محصول')),
  ])));
}

class QRScreen extends StatelessWidget {
  const QRScreen({super.key, required this.product});
  final Map<String,dynamic> product;
  @override Widget build(BuildContext context) {
    final url = '${publicSiteUrl.replaceAll(RegExp(r'/\$'), '')}/product.html?id=${product['id']}';
    return Scaffold(appBar: AppBar(title: const Text('QR اختصاصی محصول')), body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(product['name']?.toString() ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Text('کد: ${product['code'] ?? '-'}'),
      const SizedBox(height: 24), Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: QrImageView(data: url, size: 240, backgroundColor: Colors.white)),
      const SizedBox(height: 16), SelectableText(url, textAlign: TextAlign.center),
      const SizedBox(height: 8), const Text('شناسه QR با ویرایش اطلاعات محصول تغییر نمی‌کند.', style: TextStyle(color: Colors.black54)),
    ]))));
  }
}
