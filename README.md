# UMKM Manager

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
