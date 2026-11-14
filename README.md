# QR Studio — Android App

QR Studio is a Persian-first Flutter app for managing product information and creating a dedicated QR code for each product.

## Download and install the Android APK

1. Open [GitHub Actions](https://github.com/alimokhtari3900-source/qr-studio/actions/workflows/android-apk.yml).
2. Open the latest successful **Build Android APK** run.
3. Download the `QR-Studio-Android-APK` artifact, extract it, and install `QR-Studio.apk` on Android.

## Connect the backend

Add these repository Variables under **Settings → Secrets and variables → Actions → Variables**:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY` (publishable key only; never use a secret or service-role key in the app)
- `PUBLIC_SITE_URL` (optional; default is `https://alimokhtari3900-source.github.io/qr-studio`)

The initial database setup is in `supabase/migrations/202611100001_initial_schema.sql`. The product photo bucket and its admin-only upload policies are in `supabase/migrations/202611140001_product_images.sql`.

## Publish the public product pages

In the repository, open **Settings → Pages → Build and deployment** and set **Source** to **GitHub Actions** once. The `Publish QR Studio product pages` workflow will then deploy `web/product.html` whenever it changes on `main`.

When the page is deployed, each QR opens a mobile-friendly public page showing the product name, brand, category, description, and photos. Anyone can view a product only after the admin turns on **انتشار عمومی محصول** and keeps the product active.

## Product photos

The product editor supports up to six JPEG, PNG, or WEBP images per product. Each image can be up to 8 MB. Public downloads are enabled for the dedicated `product-images` bucket; uploads and deletes are restricted to authenticated admins.

## Safety

The app uses the Supabase publishable key with Row Level Security. Never add a Supabase secret key or `service_role` key to source code, GitHub Variables, or an Android build.
