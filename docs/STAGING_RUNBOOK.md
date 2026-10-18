# Runbook staging (bukan production)

Jalankan hanya terhadap project staging yang project ref dan URL-nya telah diverifikasi dua orang. Pekerjaan ini tidak menjalankan perintah remote berikut.

## Backup dan migration

1. Catat commit, project ref, operator, waktu, dan jumlah row kritis.
2. Ambil backup terenkripsi dan uji dapat dibaca: `supabase db dump --linked -f staging-before-upgrade.sql`, lalu `pg_restore --list staging-before-upgrade.sql`.
3. Tinjau `supabase db push --dry-run`; terapkan migration 0001–0032 dengan `supabase db push` hanya setelah maintenance window.
4. Jalankan lint schema dan bandingkan jumlah auth user, usaha, transaksi, ledger stok, invoice, period, reservation, dan audit sebelum/sesudah. Gunakan forward-fix migration, bukan rollback destruktif data keuangan.

## Secrets dan Edge Function

Simpan `GEMINI_API_KEY` atau `OPENAI_API_KEY`, `SUPABASE_URL`, dan `SUPABASE_SERVICE_ROLE_KEY` hanya di secret staging. Jangan masukkan ke APK/JSON aplikasi. Atur provider/model/limit di `ai_system_config`, lalu deploy khusus staging:

```bash
supabase functions deploy recommend-business-config --project-ref <STAGING_REF>
```

Uji request ber-idempotency key; retry key sama harus replay dengan satu usage sukses, satu reservation completed, dan satu draft.

## Provisioning admin dan demo

1. Buat akun biasa dan verifikasi email; cocokkan UUID/email di Auth.
2. Dari SQL operator staging, set `profiles.role='admin'` untuk UUID tersebut satu kali. Tidak ada password default.
3. Buat data palsu: owner toko, barbershop, fotografi, admin usaha, dan kasir.
4. Buat promosi ber-expiry/kuota kecil. Token undangan dibuat lewat UI, disalin sekali ke kanal privat, lalu dihapus setelah redeem/revoke.

## Smoke test

- Login/verifikasi, redeem/revoke undangan, create/switch usaha, role boundary.
- Produk barang/jasa, customer, checkout, stock ledger, expense, dashboard/report.
- Invoice → submission → approve/reject; approval ganda harus idempoten.
- Admin metrics dan filter/pagination audit/undangan.
- AI valid, retry, payload conflict, timeout, quota exhausted, draft reopen/apply.
- Jalankan `DEVICE_TEST_SCENARIOS.md` pada APK release.

## Pemulihan

Jika bermasalah, hentikan distribusi APK dan nonaktifkan entry point terkait. Kembalikan kode/Edge Function stabil tanpa menghapus histori, lalu buat migration perbaikan maju. Restore penuh hanya untuk insiden berat setelah menyimpan salinan kondisi bermasalah dan merekonsiliasi transaksi memakai `business_id + request_id`; auth, storage, dan database harus dipulihkan konsisten.
