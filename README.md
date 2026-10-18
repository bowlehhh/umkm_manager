# ikam

Aplikasi Flutter untuk manajemen bisnis UMKM. Proyek memakai Supabase Auth dan
disusun dengan arsitektur berbasis fitur.

## Menjalankan aplikasi

1. Salin `supabase.example.json` menjadi file lokal, misalnya
   `supabase.local.json`, lalu isi URL dan publishable key proyek Supabase.
2. Jalankan:

   ```bash
   flutter run --dart-define-from-file=supabase.local.json
   ```

Jangan pernah memasukkan `service_role` key Supabase ke aplikasi Flutter atau
menyimpan key tersebut dalam repository.

Jika `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` belum diisi, aplikasi tidak
memberikan akses ke fitur bisnis. Konfigurasikan Supabase terlebih dahulu agar
setiap pengguna wajib masuk memakai akun email.

## Login dan verifikasi email

Setiap pengguna wajib masuk sebelum dapat membuka usaha atau data bisnis. Di
Supabase Dashboard, buka **Authentication → Providers → Email** lalu aktifkan
**Confirm email**. Pastikan juga pengiriman email dikonfigurasi; SMTP kustom
direkomendasikan untuk produksi. Setelah daftar, pengguna harus membuka tautan
verifikasi dari email sebelum bisa masuk.

Satu email mewakili satu akun Supabase dan dapat memiliki banyak usaha melalui
halaman **Pilih usaha**. Email lain memakai `auth.uid()` yang berbeda; RLS pada
`business_members` membatasi data agar hanya terlihat oleh anggota usaha itu.

## AI Business Builder

Fitur **AI Business Builder** memanggil Edge Function Supabase, bukan Gemini
langsung dari Flutter. Kunci Gemini hanya disimpan sebagai Supabase secret dan
tidak boleh dimasukkan ke file konfigurasi Flutter.

Setelah membuat atau memilih proyek Supabase, jalankan dari root proyek:

```bash
supabase login
supabase link --project-ref <project-ref-Anda>
supabase db push
supabase secrets set GEMINI_API_KEY="<isi-lokal-di-terminal>"
supabase functions deploy recommend-business-config
```

Ganti placeholder hanya di terminal lokal. Jangan menyimpan perintah yang sudah
berisi nilai kunci pada shell history, file, atau repository. Setelah deploy,
jalankan aplikasi dengan konfigurasi Supabase biasa; Flutter akan memanggil
`recommend-business-config` melalui SDK Supabase. Tanpa konfigurasi Supabase,
aplikasi berhenti di layar konfigurasi dan tidak memberi akses ke data atau
fitur bisnis.

Konfigurasi AI server-side tersimpan pada `ai_system_config`: provider, model, cache prompt,
TTL, model default, batas output, limit harian, dan rate limit per menit. Tabel ini tidak memiliki
akses client. Untuk berpindah ke OpenAI nanti, simpan `OPENAI_API_KEY` sebagai
Supabase secret lalu ubah `provider` menjadi `openai` dan `default_model`
menjadi model mini yang dipilih, misalnya `gpt-5-mini`; aplikasi Flutter tidak
perlu diubah. Harga model yang opsional tersimpan di `ai_model_pricing`; bila
belum diisi, biaya pada log tetap `null` agar aplikasi tidak mengarang biaya.
`ai_usage_logs` menyimpan metrik penggunaan tanpa prompt atau secret.

Context cache memakai kunci `feature + prompt version + schema version +
model`. Ketika cache tidak tersedia atau provider menolaknya, request tetap
berjalan melalui jalur non-cache. AI Business Builder bersifat interaktif,
sehingga Batch API tidak digunakan.

## Operasional Supabase dan biaya

Query aplikasi selalu dibatasi pada `business_id` dan RLS, mengambil kolom yang
dibutuhkan, serta menggunakan batas data pada daftar yang dapat berkembang.
Untuk fitur baru, agregasi dashboard harus dibuat sebagai RPC/view PostgreSQL,
bukan menghitung seluruh transaksi di Flutter. Realtime hanya digunakan bila
memang perlu dan harus difilter ke bisnis atau pengguna terkait.

Aktifkan dan tinjau Usage serta Billing di Supabase Dashboard untuk database
size, bandwidth/egress, Storage, Function invocation, dan Realtime. Alert
biaya adalah konfigurasi Dashboard/proyek Supabase; tidak disimpan di Flutter.

## Android release signing

Release tidak pernah memakai debug key. Buat keystore produksi di lokasi aman
di luar Git lalu buat `android/key.properties` lokal dengan `storeFile`,
`storePassword`, `keyAlias`, dan `keyPassword`. File tersebut serta `.jks` dan
`.keystore` sudah diabaikan Git. Packaging release gagal bila konfigurasi ini
belum lengkap; jangan menggantinya dengan credential dummy.

Panduan validasi, build AAB, dan daftar kebutuhan publikasi tersedia di
[`docs/RELEASE.md`](docs/RELEASE.md).

## Dokumentasi operasional

- [Aturan bisnis dan implementasi](docs/IMPLEMENTATION.md)
- [Migration, pemulihan, admin, dan undangan](docs/DATABASE_OPERATIONS.md)
- [Matriks pengujian nyata](docs/TEST_MATRIX.md)
- [Perubahan perilaku](CHANGELOG.md)

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# umkm_manager
