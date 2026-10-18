# Implementasi dan aturan bisnis

## Alur inti

Pengguna login melalui Supabase, memilih atau membuat usaha, mengelola produk/layanan dan pelanggan, melakukan checkout, mencatat pengeluaran, lalu membaca laporan periode. APK tetap memerlukan internet untuk backend dan AI; tidak ada klaim transaksi offline atau sinkronisasi lokal.

Checkout hanya melalui RPC `process_checkout` dengan `request_id`. Harga/HPP/nama diambil dan disnapshot oleh database, baris produk ganda digabung, produk dikunci berurutan, stok serta ledger ditulis atomik. Transfer/QRIS hanya catatan metode bayar, bukan konfirmasi bank. Penjualan berstatus batal tidak masuk laporan. Pengeluaran operasional dipisahkan dari HPP agar persediaan tidak dihitung dua kali.

## Capability AI

AI hanya boleh memilih dan mengonfigurasi capability yang ada di `FeatureCapabilityTemplates`. Output melewati schema/allowlist, batas panjang/jumlah, dependency, custom-field module, action, dan dashboard widget. Output tidak pernah dieksekusi sebagai Dart, JavaScript, SQL, route, role, harga, atau pembayaran. Capability dengan `isImplemented: false` tidak ditawarkan sebagai fitur operasional. Booking, project, order, appointment, DP, diskon, employee, debt-payment workflow tetap non-operasional sampai backend dan UI lengkap.

Permintaan AI hanya terjadi dari tombol pengguna. Provider/model/key berada di Edge Function (`GEMINI_API_KEY` atau `OPENAI_API_KEY`, konfigurasi di `ai_system_config`). Reservation memakai request ID terikat hash payload, advisory lock per request/periode, lease dua menit, dan finalisasi atomik bersama penyimpanan draft. Hanya state `granted` yang boleh memanggil provider; retry yang berjalan, replay hasil selesai, konflik payload, dan key yang telah ditutup berhenti sebelum provider. Respons timeout, error, terlambat, tidak valid, atau gagal disimpan dicatat tetapi tidak memotong kuota. Harga provider yang tidak dikonfigurasi tetap `null`.

## Paket dan pembayaran

Paket backend: Dasar Rp35.000/3, Plus Rp45.000/5, Pro Rp60.000/8 konfigurasi AI per periode. Kuota milik akun dan dibagi ke seluruh usaha. Paket AI yang berakhir tidak memblokir data usaha.

Invoice menyimpan snapshot nama paket, harga, dan kuota. Klaim pembayaran berstatus `PENDING` sampai platform admin menyetujui. Approval idempoten karena satu invoice hanya dapat membuat satu period. Renewal awal dimulai pada akhir period aktif terakhir; period baru setelah expiry dimulai saat approval. Akhir periode memakai `timestamptz + interval '1 month'` PostgreSQL (tanggal akhir bulan di-clamp). Tidak ada prorata, gateway, auto-debit, atau konfirmasi bank otomatis.

Promosi memiliki expiry, quota, alasan, actor, dan period sendiri. Voucher lama dipertahankan untuk kompatibilitas; undangan baru memakai token acak yang hanya tampil sekali, hash SHA-256, tujuan, expiry/revoke, penggunaan sekali, optional email/usaha/role, serta rate limit.

## Audit dan keamanan

Platform admin berasal dari `profiles.role` yang tidak dapat diubah client. Role usaha tersimpan terpisah di `business_members`. RLS membatasi data per usaha; RPC sensitif memeriksa `auth.uid()`/role, memakai `SECURITY DEFINER SET search_path`, dan grant minimal. Audit backend menyimpan actor, waktu server, target, hasil, correlation ID, dan metadata non-rahasia. Token mentah, password, biometrik, prompt, dan credential tidak dicatat.

Biometrik hanya membuka sesi lokal yang masih sah. Logout/pergantian akun membersihkan enrollment/cache lokal terkait dan tidak menyimpan password atau data biometrik mentah.
