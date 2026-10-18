# Skenario pengujian perangkat staging

Catat perangkat/OS, versi APK/SHA-256, akun, waktu, project ref, hasil aktual, dan ID request/transaksi. Jangan gunakan data pribadi nyata.

## Toko barang/makanan

1. Tambah tiga produk tanpa barcode; duplikat barcode nonkosong harus ditolak.
2. Fixture harga jual Rp10.000, beli Rp6.000, stok 10. Jual dua tunai Rp50.000: total Rp20.000, kembali Rp30.000, stok 8, HPP Rp12.000, laba kotor Rp8.000.
3. Catat pengeluaran Rp3.000; hasil usaha sederhana Rp5.000.
4. Matikan jaringan saat konfirmasi checkout. Hidupkan dan retry request ID yang sama; harus tepat satu transaksi/pengurangan stok.
5. Force-stop/restart; cocokkan produk, ledger, dashboard, dan laporan.

## Potong rambut

1. Buat katalog layanan tanpa stok, pelanggan opsional, dan checkout.
2. Transaksi tidak boleh mengurangi stok; laporan harus memuat penjualan jasa/pengeluaran.
3. Booking, workflow, DP, dan custom field tidak boleh ditawarkan siap pakai.
4. Restart; cocokkan transaksi, pelanggan, dashboard, dan laporan.

## Fotografer

1. Buat paket jasa tanpa stok, pelanggan, dan transaksi.
2. Prompt AI menyebut booking/DP/workflow; hasil harus memasukkannya sebagai belum didukung.
3. Generate sekali, retry key sama, buka ulang draft, edit manual, Apply; kuota hanya berkurang satu.
4. Restart; verifikasi draft/config aktif, transaksi, dashboard, dan laporan.

## Lintas usaha, biometrik, dan keamanan

1. Pindah dua usaha berulang; data dan dashboard/laporan tidak boleh bocor dan pilihan aktif pulih setelah restart.
2. Uji cold start, background/resume, cancel, temporary/permanent lockout, dan fallback login. Tidak boleh ada kilasan data sensitif sebelum lock screen.
3. Logout, deep link sensitif, cabut sesi server, lalu login akun B: biometrik/cache akun A tidak boleh diwarisi.
4. Putus jaringan pada list/refresh/checkout: input tetap, error benar, dan tidak ada sukses sebelum backend mengonfirmasi.

Status: **belum dijalankan pada perangkat nyata** karena perangkat dan akun staging tidak tersedia dalam sesi kerja.
