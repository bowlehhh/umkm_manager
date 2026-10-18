# Matriks requirement dan bukti — 17 Oktober 2026

`SELESAI` berarti implementasi dan bukti lokal tersedia. `PARSIAL` berarti ada pekerjaan eksternal/perangkat/staging atau subkasus yang belum dibuktikan. Tes mock tidak menggantikan RPC, RLS, Edge Function deployed, atau perangkat nyata.

| Requirement | Status | Implementasi utama | Bukti yang dijalankan | Batasan/kebutuhan eksternal |
|---|---|---|---|---|
| Produk barang/jasa, barcode nullable, harga dan stok | SELESAI | `0026_core_commerce_integrity.sql`, product repository/UI | `core_integrity.sql`, Flutter tests | Uji perangkat ada di `DEVICE_TEST_SCENARIOS.md` |
| Checkout atomik, harga server, duplicate line, snapshot, customer, retry | SELESAI | RPC `process_checkout`, checkout repository | `core_integrity.sql`, pagination test | Gangguan jaringan nyata perlu perangkat/staging |
| Ledger stok dan backfill saldo lama | SELESAI | migration 0026, stock repository/UI | fixture SQL; replay migration kosong | Pembalikan transaksi belum ditawarkan sebagai flow UI |
| Dashboard usaha, laporan, dan pengeluaran | SELESAI | summary/report RPC, repositories/UI | fixture Rp20k/Rp12k/Rp8k/Rp3k/Rp5k | Bukan laporan arus kas lengkap; visual belum diuji perangkat |
| Capability AI hanya yang operasional | SELESAI | capability registry, Edge schema/validator | `ai_business_builder_test.dart` | Provider nyata tidak dipanggil karena credential tidak tersedia |
| Custom field, workflow, DP | SELESAI dengan cara disembunyikan | Edge memaksa kosong/false; review UI dan config lama disanitasi | Flutter fixture tests | Belum operasional; data konfigurasi lama tidak dihapus |
| Preview, Apply, versi konfigurasi | SELESAI | setup controller, `business_configurations` | Flutter tests | Restore versi melalui UI khusus belum tersedia; histori tetap di DB |
| Paket, invoice, pembayaran manual, promosi | SELESAI | migrations 0027, 0030; admin/user UI | replay migrations; SQL contracts | Gateway/upload bukti privat sengaja tidak dibuat |
| Undangan create/list/filter/revoke | SELESAI | admin repository/UI; migrations 0028, 0031 | `admin_dashboard_invitations.sql` | Pengiriman token tetap proses operator |
| Token mentah hanya sekali dan hash-only | SELESAI | RPC create; dialog satu kali | SQL memastikan raw token tidak tersimpan | Screenshot/manual UI admin belum dilakukan |
| Dashboard platform admin | SELESAI | metrics RPC, admin UI | SQL memeriksa seluruh key metrik | Angka staging bergantung data staging |
| Audit platform + bisnis, filter/pagination | SELESAI | activity-audit RPC/UI | SQL filter source/action | Event historis sebelum migration tidak lengkap |
| Otorisasi backend admin/RLS | SELESAI untuk fungsi baru | `require_admin`, grants, RLS | non-admin ditolak; `rls_isolation.sql` | Seluruh endpoint lama belum diuji exhaustif |
| Kuota AI atomik/idempoten | SELESAI lokal | migration 0032 dan Edge Function | SQL idempotency + 16 proses paralel | Belum diuji Edge deployed/provider nyata |
| Retry/payload beda/timeout/stale/late/save failure | SELESAI lokal | reserve/finalize v2 + lease + draft atomik | `ai_quota_idempotency.sql` | Timeout provider end-to-end butuh credential |
| Tanpa provider call/kuota ganda | SELESAI secara kontrak lokal | provider hanya setelah state `granted` | 1 grant, 15 in-progress, 1 reservation; 1 completed/draft | Counter provider nyata belum diobservasi staging |
| Biometrik cold start/logout/account switch/deep link | PARSIAL | notifier, router guard, account binding | unit service + review kode | Perangkat nyata dan revoke sesi end-to-end belum |
| Biometrik cancel/lockout/background-resume | PARSIAL | hasil terpisah, lifecycle observer | unit cancel/lockout; analyzer | Prompt native/OEM wajib perangkat nyata |
| APK target backend dan INTERNET | SELESAI untuk artefak lokal | AppConfig + manifest | URL backend ditemukan di `libapp.so`; manifest | Pemilik harus mengonfirmasi project ref staging tujuan |
| Release signing bukan debug | SELESAI untuk artefak lokal | Gradle tanpa fallback | apksigner v2, DN/digest non-debug | Custody/expiry keystore tanggung jawab pemilik |
| Staging/deploy/recovery | PARSIAL | `STAGING_RUNBOOK.md` | database lokal reset/replay | Tidak ada deploy remote/production |
| Tiga skenario usaha/restart/offline/switch | PARSIAL | `DEVICE_TEST_SCENARIOS.md` | skenario terdokumentasi | Belum ada perangkat dan akun staging |

## Hasil eksekusi lokal terakhir

- `flutter analyze`: lulus, 0 issue.
- `flutter test`: lulus 64 tes.
- Migration 0001–0032: replay dari database kosong berhasil.
- Empat SQL test dijalankan dengan `ON_ERROR_STOP=1`: lulus.
- `tool/test_ai_quota_parallel.sh`: lulus; 16 proses menghasilkan tepat 1 grant, 15 in-progress, dan 1 reservation.
- Deno/Edge type test: belum; executable Deno tidak tersedia dan CLI Supabase ini tidak memiliki subcommand bundle.
- Provider AI nyata, deploy staging, dan seluruh uji perangkat: belum dijalankan.

APK terbaru: `build/app/outputs/flutter-apk/app-release.apk`, SHA-256 `e9cf6d95d837e4e071b219e3e119ed914a962252cb624f7334cbfe88bb87ec19`. URL yang tertanam adalah `https://riyrokoamdrntfozukzs.supabase.co`; project ini harus dikonfirmasi pemilik sebagai staging tujuan sebelum distribusi. Sertifikat signer SHA-256 `8c432629ecf74707068ab18ffa885ebfc4dff17349351a147b6272f5b4c04963`, DN bukan `Android Debug`, dan digest berbeda dari default debug certificate lokal.
