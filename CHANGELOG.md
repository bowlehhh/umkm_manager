# Changelog

## Unreleased

- Memperketat checkout dengan request ID, kalkulasi database, snapshot nama/harga/HPP, agregasi baris ganda, customer validation, lock konsisten, dan ledger stok.
- Memperbaiki barcode opsional agar banyak produk tanpa barcode diperbolehkan, sementara barcode terisi tetap unik per usaha.
- Menambahkan CRUD pengeluaran dan laporan periode server-side (penjualan, diskon, HPP, laba kotor, biaya, hasil sederhana, item terjual).
- Menambahkan paket AI Dasar/Plus/Pro, invoice manual, pengajuan dan review pembayaran, period kalender, kuota akun, renewal terjadwal, dan promosi eksplisit.
- Memisahkan expiry paket AI dari akses data usaha.
- Menambahkan undangan aman bertujuan dengan token acak ber-hash, expiry, revoke, binding email/usaha/role, sekali pakai, dan rate limit.
- Menolak respons AI invalid tanpa memotong kuota serta mempertahankan konfigurasi manual.
- Menambahkan audit bisnis backend serta dokumentasi deployment, pemulihan, dan test matrix.
- Menambahkan UI platform admin untuk membuat, memfilter, melihat status, dan mencabut undangan; token mentah hanya muncul pada dialog hasil pembuatan.
- Menambahkan metrik admin untuk pengguna/usaha, subscription period, promosi, invoice, pembayaran, kuota, serta audit platform+usaha dengan filter dan pagination.
- Memperkuat kuota AI dengan idempotency key terikat payload, advisory lock, lease/expiry, replay hasil, penyimpanan draft atomik, dan penolakan respons terlambat.
- Menyembunyikan custom field, workflow, booking, dan DP sampai alur operasional lengkap tersedia.
- Menambahkan penanganan lockout serta penguncian biometrik pada background, dan runbook staging/skenario uji perangkat.
