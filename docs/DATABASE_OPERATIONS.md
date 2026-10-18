# Migration, backfill, dan pemulihan

Jalankan migration hanya setelah backup terverifikasi:

```bash
supabase db dump --linked --data-only -f backup-before-upgrade.sql
supabase db push --dry-run
supabase db push
```

Migration `0026` memperbaiki indeks barcode, menambah request ID/snapshot nama, membuat ledger stok dan audit, lalu membuat saldo pembuka yang idempoten untuk produk lama. `0027` menambah paket bulanan, invoice, payment submission, period, dan promosi; langganan lama dibackfill sebagai period histori. `0028` menambah undangan aman. `0029` memberi grant minimum ke role aplikasi; RLS tetap menjadi pembatas baris. Semua waktu disimpan `timestamptz`; UI menampilkan konteks Asia/Makassar.

Jangan rollback destruktif transaksi, item, stock movement, expense, invoice, period, payment, atau audit. Jika release bermasalah, nonaktifkan entry point UI/Edge Function, pulihkan kode aplikasi, lalu buat migration perbaikan maju. Restore penuh hanya untuk insiden dan harus memakai backup sebelum upgrade; rekonsiliasi transaksi berdasarkan `business_id + request_id` sebelum mengulang checkout.

## Platform admin pertama

Tidak ada password default. Buat akun normal dengan email terverifikasi, lalu dari SQL Editor yang dilindungi/CLI dengan kredensial operator jalankan sekali:

```sql
update public.profiles set role = 'admin'
where id = '<UUID auth user yang sudah diverifikasi>';
```

Periksa UUID dan email langsung di Auth sebelum eksekusi. Setelah admin pertama tersedia, perubahan berikutnya harus melalui RPC admin dan audit. Jangan menaruh UUID/email produksi dalam repository.

## Undangan

Admin memanggil `admin_create_invitation`; salin token hasil hanya saat itu dan kirim melalui kanal privat. Token mentah tidak dapat dipulihkan dari database. Gunakan `APP_ACCESS`, `BUSINESS_MEMBERSHIP`, atau `PROMOTION`; membership hanya `ADMIN`/`CASHIER`, tidak pernah owner/platform admin. Cabut dengan `admin_revoke_invitation`.

## Environment

- Flutter: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` melalui `--dart-define-from-file` lokal.
- Edge Function: `GEMINI_API_KEY` atau `OPENAI_API_KEY` di Supabase Secrets.
- Provider/model/limit: tabel server-only `ai_system_config`.
- Android signing: `android/key.properties` lokal dan keystore di luar Git.

Tidak pernah gunakan `service_role` di APK.
