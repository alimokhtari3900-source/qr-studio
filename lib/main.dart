import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const publicSiteUrl = String.fromEnvironment(
  'PUBLIC_SITE_URL',
  defaultValue: 'https://alimokhtari3900-source.github.io/qr-studio',
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
        title: 'QR Studio',
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
                  'QR Studio',
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
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(29),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF17152D),
              Color(0xFF542A83),
              Color(0xFF111B44),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x443A1B75),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 72),
            Positioned(
              right: 13,
              top: 11,
              child: Icon(
                Icons.auto_awesome,
                color: Colors.amber.shade300,
                size: 19,
              ),
            ),
            Positioned(
              bottom: 11,
              left: 15,
              child: Container(
                width: 27,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.amber.shade400,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ],
        ),
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

  Future<List<Map<String, dynamic>>> load() async {
    final query = Supabase.instance.client.from('products').select();
    final text = search.text.trim();
    final rows = text.isEmpty
        ? await query.order('created_at', ascending: false)
        : await query
            .filter('name', 'ilike', '%$text%')
            .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> editor([Map<String, dynamic>? product]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductEditor(product: product)),
    );
    if (mounted) setState(() {});
  }

  Widget productThumbnail(Map<String, dynamic> product) {
    final raw = product['images'];
    final url = raw is List && raw.isNotEmpty && raw.first is String
        ? raw.first as String
        : null;
    if (url == null || url.isEmpty) {
      return const CircleAvatar(
        backgroundColor: Color(0xFFEDE8F4),
        child: Icon(Icons.inventory_2_outlined, color: Color(0xFF542A83)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const CircleAvatar(
          child: Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'QR Studio',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'خروج از حساب',
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => editor(),
          icon: const Icon(Icons.add),
          label: const Text('محصول جدید'),
        ),
        body: RefreshIndicator(
          onRefresh: () async { if (mounted) setState(() {}); },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF17152D), Color(0xFF54268A)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'پنل مدیریت محصولات',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'محصولاتت را حرفه‌ای معرفی کن',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 21,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'عکس، مشخصات و توضیحات را ثبت کن و QR اختصاصی بساز.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'جست‌وجوی نام محصول',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: load(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return const Text(
                      'دریافت محصولات انجام نشد. اتصال اینترنت را بررسی کنید.',
                    );
                  }
                  final rows = snap.data ?? [];
                  if (rows.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: Text('هنوز محصولی ثبت نشده است.')),
                    );
                  }
                  return Column(
                    children: rows
                        .map(
                          (product) => Card(
                            elevation: 0,
                            color: Colors.white,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              title: Text(
                                product['name']?.toString() ?? 'بدون نام',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'کد: ${product['code'] ?? '-'}  •  اسکن: ${product['scan_count'] ?? 0}',
                              ),
                              leading: productThumbnail(product),
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QRScreen(product: product),
                                ),
                              ),
                              onLongPress: () => editor(product),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'برای نمایش QR روی محصول بزنید؛ برای ویرایش، لمس طولانی کنید.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
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
  final List<XFile> selectedImages = [];
  List<String> existingImages = [];
  bool published = false;
  bool busy = false;
  bool picking = false;

  @override
  void initState() {
    super.initState();
    published = widget.product?['is_published'] == true;
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
        'is_published': published,
        'is_active': true,
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
              Card(
                elevation: 0,
                child: SwitchListTile(
                  value: published,
                  onChanged: busy ? null : (value) => setState(() => published = value),
                  title: const Text('انتشار عمومی محصول'),
                  subtitle: const Text(
                    'برای اینکه همه بتوانند با اسکن QR صفحه محصول را ببینند، این گزینه باید روشن باشد.',
                  ),
                ),
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
    final url = '$baseUrl/product.html?id=$id';
    final isPublished =
        product['is_published'] == true && product['is_active'] == true;
    final rawImages = product['images'];
    final imageCount = rawImages is List ? rawImages.length : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('QR اختصاصی محصول')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product['name']?.toString() ?? '',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text('کد: ${product['code'] ?? '-'}  •  $imageCount عکس'),
                const SizedBox(height: 20),
                if (!isPublished)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3D8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'این محصول هنوز عمومی نشده است. برای نمایش آن پس از اسکن، از بخش ویرایش گزینه «انتشار عمومی محصول» را روشن کنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF795312)),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 22,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: url,
                    size: 240,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'این کد را اسکن کنید تا صفحه معرفی محصول باز شود.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                SelectableText(
                  url,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF542A83), fontSize: 12),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('نشانی صفحه را می‌توانید لمس طولانی و کپی کنید.'),
                    ),
                  ),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('راهنمای اشتراک‌گذاری QR'),
                ),
                const SizedBox(height: 4),
                const Text(
                  'شناسه QR با ویرایش اطلاعات محصول تغییر نمی‌کند.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
