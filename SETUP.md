# 📋 PANDUAN SETUP — Sistem Layanan Kunjungan & Penitipan Barang Lapas

## 🗂️ File yang Dihasilkan

| File | Keterangan |
|------|------------|
| `supabase_setup.sql` | Script SQL untuk tabel, RLS, trigger, dan data sample |
| `index.html` | Halaman pengunjung (pendaftaran, validasi NIK, QR Code) |
| `admin.html` | Panel admin (login, QR scanner, manajemen antrean, onsite) |
| `SETUP.md` | Panduan ini |

---

## 🚀 LANGKAH SETUP

### 1. Buat Project Supabase
1. Buka [supabase.com](https://supabase.com) → **New Project**
2. Pilih nama project, password database, dan region terdekat (Singapore)
3. Tunggu project selesai dibuat (~1 menit)

### 2. Jalankan SQL Setup
1. Di dashboard Supabase → klik **SQL Editor** → **New Query**
2. Copy-paste isi file `supabase_setup.sql`
3. Klik **Run** (atau Ctrl+Enter)
4. Pastikan tidak ada error

### 3. Dapatkan API Keys
1. Di dashboard Supabase → **Settings** → **API**
2. Copy:
   - **Project URL** → contoh: `https://abcdefgh.supabase.co`
   - **anon/public key** → string panjang mulai dari `eyJh...`

### 4. Isi Config di HTML
Buka `index.html` dan `admin.html`, ganti 2 baris ini:

```javascript
const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
```

Dengan nilai asli dari step 3.

### 5. Buat Akun Admin
1. Di dashboard Supabase → **Authentication** → **Users** → **Add User**
2. Masukkan email dan password untuk petugas admin
3. Atau gunakan: **Authentication** → **Providers** → pastikan **Email** enabled

### 6. Deploy ke Cloudflare Pages
1. Upload 2 file HTML ke repository GitHub
2. Buka [pages.cloudflare.com](https://pages.cloudflare.com)
3. **Create Project** → Connect to Git → pilih repo
4. Build settings:
   - Build command: *(kosongkan)*
   - Output directory: `/` atau `.`
5. **Save and Deploy**

---

## 🔧 KONFIGURASI TAMBAHAN SUPABASE

### Aktifkan Email Auth
**Authentication** → **Settings** → Pastikan:
- ☑ Enable Email Signup
- Atur Site URL ke domain Cloudflare Pages Anda

### Storage (Opsional)
Tidak diperlukan untuk versi ini karena tidak ada upload file.

---

## 📱 CARA PENGGUNAAN

### Untuk Pengunjung (index.html)
1. Buka halaman di HP
2. Isi NIK Pengunjung (harus sudah terdaftar sebagai keluarga WBP)
3. Isi nama lengkap dan nama WBP yang dikunjungi
4. Tambahkan daftar barang bawaan (opsional)
5. Klik **Daftar Sekarang** → QR Code muncul
6. Screenshot QR Code untuk ditunjukkan ke petugas

### Untuk Admin Petugas (admin.html)
1. Login dengan akun admin
2. **Tab Scan QR**: Scan QR pengunjung → status otomatis jadi "Hadir"
3. **Tab Antrean**: Lihat semua kunjungan hari ini, filter status
4. **Tab Cari**: Cari berdasarkan NIK/nama
5. **Tab Onsite**: Daftar manual untuk pengunjung tanpa HP

---

## 📊 STRUKTUR DATABASE

```
wbp
├── id (UUID, PK)
├── nama_wbp
├── nik_wbp (UNIQUE)
├── kamar
└── created_at

keluarga_wbp
├── id (UUID, PK)
├── wbp_id → wbp.id
├── nama_keluarga
├── nik_keluarga (UNIQUE)  ← NIK yang dipakai saat pendaftaran
├── hubungan
└── created_at

kunjungan
├── id (UUID, PK)
├── wbp_id → wbp.id
├── nama_pengunjung
├── nik_pengunjung
├── tgl_kunjungan (DATE)
├── status (menunggu/hadir/selesai)
├── daftar_barang (JSONB array)
├── metode_daftar (online/onsite)
├── no_antrean (auto-increment per hari)
├── created_at
└── updated_at
```

---

## 🔒 KEAMANAN (RLS Policies)

| Tabel | Operasi | Siapa |
|-------|---------|-------|
| `wbp` | SELECT | Semua (public) |
| `wbp` | INSERT/UPDATE/DELETE | Admin (authenticated) |
| `keluarga_wbp` | SELECT | Semua (public) |
| `keluarga_wbp` | INSERT/UPDATE/DELETE | Admin (authenticated) |
| `kunjungan` | INSERT | Semua (public) — pengunjung mendaftar |
| `kunjungan` | SELECT | Semua (public) |
| `kunjungan` | UPDATE | Admin (authenticated) — update status |

---

## 💾 OFFLINE SUPPORT

QR Code terakhir tersimpan di `localStorage` browser pengunjung.
Jika koneksi terputus setelah mendaftar, pengunjung masih bisa melihat QR-nya
dengan membuka kembali halaman (muncul banner "Pendaftaran Sebelumnya").
Data offline otomatis hilang setelah 8 jam.

---

## 🛠️ TROUBLESHOOTING

| Masalah | Solusi |
|---------|--------|
| NIK tidak valid | Tambahkan data keluarga di tabel `keluarga_wbp` via Supabase Table Editor |
| Kamera tidak bisa dibuka | Pastikan browser mengizinkan akses kamera; gunakan HTTPS |
| Login admin gagal | Cek email/password di Supabase → Authentication → Users |
| QR tidak terbaca | Pastikan pencahayaan cukup; jauhkan/dekatkan kamera |
| Data tidak muncul | Cek API key dan URL di config; buka Console browser untuk error |

---

## 📞 MENAMBAH DATA WBP & KELUARGA

Masuk ke Supabase → **Table Editor**:
1. Pilih tabel `wbp` → **Insert Row** → isi nama, NIK, kamar
2. Pilih tabel `keluarga_wbp` → **Insert Row** → isi wbp_id, nama, NIK keluarga, hubungan

Atau jalankan SQL:
```sql
-- Tambah WBP
INSERT INTO wbp (nama_wbp, nik_wbp, kamar) VALUES ('Nama WBP', '1234567890123456', 'Blok A-1');

-- Tambah keluarga (copy UUID dari tabel wbp)
INSERT INTO keluarga_wbp (wbp_id, nama_keluarga, nik_keluarga, hubungan)
VALUES ('uuid-dari-wbp', 'Nama Keluarga', '9876543210987654', 'Istri');
```
