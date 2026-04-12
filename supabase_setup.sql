-- ============================================================
-- SISTEM LAYANAN KUNJUNGAN & PENITIPAN BARANG LAPAS
-- Supabase SQL Setup Script
-- ============================================================

-- 1. TABEL WBP (Warga Binaan Pemasyarakatan)
CREATE TABLE IF NOT EXISTS wbp (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nama_wbp TEXT NOT NULL,
  nik_wbp TEXT UNIQUE NOT NULL,
  kamar TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. TABEL KELUARGA WBP
CREATE TABLE IF NOT EXISTS keluarga_wbp (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  wbp_id UUID NOT NULL REFERENCES wbp(id) ON DELETE CASCADE,
  nama_keluarga TEXT NOT NULL,
  nik_keluarga TEXT UNIQUE NOT NULL,
  hubungan TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. TABEL KUNJUNGAN
CREATE TABLE IF NOT EXISTS kunjungan (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  wbp_id UUID NOT NULL REFERENCES wbp(id) ON DELETE CASCADE,
  nama_pengunjung TEXT NOT NULL,
  nik_pengunjung TEXT NOT NULL,
  tgl_kunjungan DATE NOT NULL DEFAULT CURRENT_DATE,
  status TEXT NOT NULL DEFAULT 'menunggu' CHECK (status IN ('menunggu', 'hadir', 'selesai')),
  daftar_barang JSONB DEFAULT '[]',
  metode_daftar TEXT NOT NULL DEFAULT 'online' CHECK (metode_daftar IN ('online', 'onsite')),
  no_antrean INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. AUTO-INCREMENT NOMOR ANTREAN PER HARI
CREATE SEQUENCE IF NOT EXISTS antrean_harian_seq START 1;

CREATE OR REPLACE FUNCTION set_no_antrean()
RETURNS TRIGGER AS $$
DECLARE
  max_antrean INTEGER;
BEGIN
  SELECT COALESCE(MAX(no_antrean), 0) + 1
  INTO max_antrean
  FROM kunjungan
  WHERE tgl_kunjungan = NEW.tgl_kunjungan;
  
  NEW.no_antrean := max_antrean;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_antrean
  BEFORE INSERT ON kunjungan
  FOR EACH ROW EXECUTE FUNCTION set_no_antrean();

-- 5. AUTO-UPDATE updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_updated_at
  BEFORE UPDATE ON kunjungan
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE wbp ENABLE ROW LEVEL SECURITY;
ALTER TABLE keluarga_wbp ENABLE ROW LEVEL SECURITY;
ALTER TABLE kunjungan ENABLE ROW LEVEL SECURITY;

-- WBP: Siapapun bisa baca (untuk validasi form pengunjung)
CREATE POLICY "wbp_public_read" ON wbp
  FOR SELECT USING (true);

-- WBP: Hanya admin (authenticated) yang bisa insert/update/delete
CREATE POLICY "wbp_admin_write" ON wbp
  FOR ALL USING (auth.role() = 'authenticated');

-- KELUARGA_WBP: Siapapun bisa baca (untuk validasi NIK)
CREATE POLICY "keluarga_public_read" ON keluarga_wbp
  FOR SELECT USING (true);

-- KELUARGA_WBP: Hanya admin yang bisa write
CREATE POLICY "keluarga_admin_write" ON keluarga_wbp
  FOR ALL USING (auth.role() = 'authenticated');

-- KUNJUNGAN: Siapapun bisa insert (pengunjung mendaftar)
CREATE POLICY "kunjungan_public_insert" ON kunjungan
  FOR INSERT WITH CHECK (true);

-- KUNJUNGAN: Siapapun bisa baca kunjungan sendiri (by NIK)
CREATE POLICY "kunjungan_public_select" ON kunjungan
  FOR SELECT USING (true);

-- KUNJUNGAN: Hanya admin yang bisa update status
CREATE POLICY "kunjungan_admin_update" ON kunjungan
  FOR UPDATE USING (auth.role() = 'authenticated');

-- ============================================================
-- DATA SAMPLE (Opsional - Hapus jika tidak diperlukan)
-- ============================================================

-- Sample WBP
INSERT INTO wbp (nama_wbp, nik_wbp, kamar) VALUES
  ('Budi Santoso', '1234567890123456', 'Blok A-1'),
  ('Ahmad Fauzi', '2345678901234567', 'Blok B-3'),
  ('Sujatmiko', '3456789012345678', 'Blok A-4')
ON CONFLICT (nik_wbp) DO NOTHING;

-- Sample Keluarga WBP (NIK ini yang digunakan pengunjung saat daftar)
INSERT INTO keluarga_wbp (wbp_id, nama_keluarga, nik_keluarga, hubungan)
SELECT 
  w.id,
  'Siti Rahayu',
  '9876543210987654',
  'Istri'
FROM wbp w WHERE w.nik_wbp = '1234567890123456'
ON CONFLICT (nik_keluarga) DO NOTHING;

INSERT INTO keluarga_wbp (wbp_id, nama_keluarga, nik_keluarga, hubungan)
SELECT 
  w.id,
  'Dewi Susanti',
  '8765432109876543',
  'Adik'
FROM wbp w WHERE w.nik_wbp = '2345678901234567'
ON CONFLICT (nik_keluarga) DO NOTHING;

-- ============================================================
-- INDEX untuk performa query
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_kunjungan_tgl ON kunjungan(tgl_kunjungan);
CREATE INDEX IF NOT EXISTS idx_kunjungan_status ON kunjungan(status);
CREATE INDEX IF NOT EXISTS idx_kunjungan_nik ON kunjungan(nik_pengunjung);
CREATE INDEX IF NOT EXISTS idx_keluarga_nik ON keluarga_wbp(nik_keluarga);
