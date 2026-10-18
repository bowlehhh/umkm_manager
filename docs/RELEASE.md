# Rilis UMKM Manager

Dokumen ini adalah urutan pemeriksaan sebelum membuat APK/AAB untuk pengujian
atau publikasi. Jalankan dari root proyek.

## Status aplikasi yang perlu diketahui

- Login, produk, foto produk, kasir/keranjang, transaksi, pelanggan, stok,
  konfigurasi fitur, catatan usaha, dan login biometrik adalah fitur yang
  tersedia di aplikasi.
- Login biometrik memakai token sesi terenkripsi yang tersimpan lokal di
  perangkat. Password pengguna tidak disimpan aplikasi.
- AI dijalankan melalui Edge Function Supabase; kunci Gemini/OpenAI tidak
  boleh dimasukkan ke APK.
- Paket berbayar dan pembayaran otomatis belum terhubung ke payment gateway.
  Layanan entitlement saat ini memberi akses untuk pengguna yang sudah masuk.
  Karena itu, jangan menjual paket AI sebelum backend pembayaran, webhook,
  verifikasi status langganan, dan pembatasan kuota benar-benar diterapkan.

## 1. Konfigurasi produksi

1. Buat file konfigurasi lokal dari contoh:

   ```bash
   cp supabase.example.json supabase.local.json
   ```

2. Isi hanya `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY`. Jangan memasukkan
   `service_role` key, Gemini key, atau OpenAI key ke file aplikasi.
3. Di Supabase, aktifkan verifikasi email dan gunakan SMTP produksi.
4. Terapkan skema serta deploy Edge Function:

   ```bash
   supabase db push
   supabase functions deploy recommend-business-config
   ```

5. Simpan secret AI hanya pada Supabase. Untuk provider yang digunakan, set
   secret yang sesuai (`GEMINI_API_KEY` atau `OPENAI_API_KEY`) lalu atur model
   lewat tabel konfigurasi server-side.

## 2. Signing Android

Keystore adalah identitas permanen aplikasi di Play Store. Buat sekali,
simpan cadangannya di lokasi aman di luar repository, dan jangan hilangkan
password-nya.

```bash
keytool -genkeypair -v -keystore /lokasi-aman/umkm-manager-release.jks \
  -alias umkm-manager -keyalg RSA -keysize 2048 -validity 10000
cp android/key.properties.example android/key.properties
```

Ubah empat nilai dalam `android/key.properties` agar cocok dengan keystore.
File ini dan keystore telah diabaikan Git. Build release memang akan berhenti
jika signing belum tersedia; ini mencegah APK produksi ditandatangani debug
key secara tidak sengaja.

## 3. Pemeriksaan sebelum build

```bash
flutter pub get
flutter analyze
flutter test
deno test supabase/functions/recommend-business-config/ai_service_test.ts
```

Uji manual pada perangkat fisik dengan akun baru dan akun lama:

1. Daftar, verifikasi email, masuk, buat usaha, lalu keluar dan masuk lagi.
2. Aktifkan biometrik, keluar, buka ulang aplikasi, dan pastikan login
   biometrik berhasil. Uji juga ketika biometrik perangkat dibatalkan.
3. Buat produk dengan dan tanpa foto; buka Produk dan Kasir; tambahkan ke
   keranjang; ubah jumlah; selesaikan pembayaran; cek Transaksi dan Stok.
4. Buat pelanggan, cari data, lalu pastikan data tidak muncul pada usaha lain.
5. Tambahkan fitur lewat prompt AI dan pastikan fitur tersimpan, muncul di
   navigasi, serta data catatan dapat dibuat dan diubah.
6. Matikan jaringan pada layar daftar/refresh dan pastikan pesan gagal tampil
   tanpa crash; hidupkan lagi lalu coba ulang.

## 4. Membuat artefak rilis

Untuk Play Store gunakan Android App Bundle (AAB):

```bash
flutter build appbundle --release \
  --dart-define-from-file=supabase.local.json
```

Artefak berada di `build/app/outputs/bundle/release/app-release.aab`.
Untuk distribusi pengujian langsung, gunakan APK release:

```bash
flutter build apk --release \
  --dart-define-from-file=supabase.local.json
```

Pasang artefak pada perangkat uji dan ulangi daftar pengujian manual di atas.

## 5. Yang disiapkan sebelum unggah ke Play Console

- Akses akun Play Console pemilik aplikasi.
- Nama aplikasi, deskripsi singkat/panjang, kategori, email dukungan, dan
  alamat kebijakan privasi publik yang sesuai dengan cara aplikasi memakai
  akun, foto produk, data transaksi, dan biometrik.
- Ikon aplikasi produksi (bukan ikon Flutter bawaan), tangkapan layar nyata,
  dan aset grafis store yang diperlukan oleh formulir Play Console.
- Jawaban Data safety yang sesuai implementasi sebenarnya; jangan menyatakan
  aplikasi tidak mengirim data bila Supabase dipakai.
- Pengujian internal terlebih dahulu, kemudian closed/open testing sesuai
  kebutuhan sebelum produksi.

Setiap kenaikan versi di store harus menaikkan build number di `pubspec.yaml`,
misalnya `1.0.1+2`.
