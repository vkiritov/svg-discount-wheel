# Lucky Discount Wheel

Aplikasi wheel diskon berbasis React + Vite + Supabase, disiapkan untuk deploy gratis ke Netlify.

## Fitur
- Buyer wheel dengan voucher satu kali pakai yang ditegakkan oleh PostgreSQL (row lock + unique constraint).
- Dua mode peluang: persentase manual (total harus 100%) atau jumlah bagian (peluang dihitung otomatis).
- Admin login melalui Supabase Auth; akses admin menggunakan `app_metadata.role = admin`.
- Pengaturan nama toko, judul wheel, dan nomor WhatsApp seller dari dashboard.
- Pembuatan voucher massal, daftar voucher, riwayat spin.
- Bukti hadiah PNG dan tombol WhatsApp.

## 1. Buat project Supabase
1. Buat project di https://supabase.com/dashboard.
2. Buka SQL Editor, jalankan seluruh isi `supabase/migrations/0001_initial.sql`.
3. Jalankan juga seluruh isi `supabase/migrations/0002_check_voucher_available.sql`. Migration kedua menambahkan pemeriksaan ketersediaan voucher yang aman tanpa membuka akses baca tabel voucher ke buyer.
4. Buka Authentication > Users, buat user admin.
5. Buka user tersebut dan set **App Metadata** menjadi JSON:
   ```json
   {"role":"admin"}
   ```
   Jangan gunakan User Metadata untuk role admin. App Metadata tidak dapat diubah oleh user biasa.
6. Catat Project URL dan publishable key (atau anon key lama) dari Project Settings > API.

## 2. Jalankan lokal
1. Install Node.js LTS.
2. Salin `.env.example` menjadi `.env`.
3. Isi `VITE_SUPABASE_URL` dan `VITE_SUPABASE_ANON_KEY`.
4. Jalankan:
   ```bash
   npm install
   npm run dev
   ```
5. Buka URL lokal yang ditampilkan Vite. Buyer: `/`, admin: `/admin`.

## 3. Deploy ke Netlify
1. Push repository ini ke GitHub.
2. Di Netlify pilih Add new site > Import an existing project > GitHub.
3. Pilih repository `vkiritov/svg-discount-wheel`.
4. Build command `npm run build`, publish directory `dist`.
5. Tambahkan environment variables `VITE_SUPABASE_URL` dan `VITE_SUPABASE_ANON_KEY`.
6. Deploy.

## 4. Keamanan penting
- Hanya publishable/anon key boleh berada di frontend. Jangan pernah masukkan service_role/secret key ke `.env` frontend atau GitHub.
- Admin harus diberi `app_metadata.role=admin` melalui Supabase Dashboard.
- Tabel voucher tidak dapat dibaca buyer. Pemeriksaan awal menggunakan fungsi terbatas `check_voucher_available`; spin final tetap diproses secara atomik oleh `redeem_and_spin`.
- Fungsi mengunci baris voucher (`FOR UPDATE`) dan mencatat spin dengan unique `voucher_id`, sehingga dua request bersamaan tidak dapat memakai voucher yang sama dua kali.
- Backup data secara berkala. Free plan dapat memiliki batas penggunaan dan project pause; cek harga/kuota penyedia.

## Catatan rilis awal
Ini adalah starter MVP yang perlu diuji di project Supabase milikmu sebelum dipakai untuk promo sungguhan. Khususnya uji login admin, RLS, format nomor WhatsApp, dan redemption voucher dari dua browser/perangkat secara bersamaan. Tampilan wheel adalah animasi presentasi; hasil hadiah final selalu berasal dari database.
