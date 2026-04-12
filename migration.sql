-- ============================================================
-- MIGRATION — jalankan di Supabase SQL Editor
-- ============================================================

-- Tambah kolom status WBP (jika belum ada)
ALTER TABLE wbp ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'aktif' 
  CHECK (status IN ('aktif', 'bebas'));

-- Tambah kolom jam kunjungan (jika belum ada)
ALTER TABLE kunjungan ADD COLUMN IF NOT EXISTS jam_kunjungan TEXT;

-- Index
CREATE INDEX IF NOT EXISTS idx_wbp_status ON wbp(status);
CREATE INDEX IF NOT EXISTS idx_kunjungan_tgl ON kunjungan(tgl_kunjungan);

-- ============================================================
-- SETUP LENGKAP (untuk project baru — skip jika sudah ada tabel)
-- ============================================================

CREATE TABLE IF NOT EXISTS wbp (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nama_wbp TEXT NOT NULL,
  nik_wbp TEXT UNIQUE NOT NULL,
  kamar TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'aktif' CHECK (status IN ('aktif', 'bebas')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS keluarga_wbp (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  wbp_id UUID NOT NULL REFERENCES wbp(id) ON DELETE CASCADE,
  nama_keluarga TEXT NOT NULL,
  nik_keluarga TEXT UNIQUE NOT NULL,
  hubungan TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS kunjungan (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  wbp_id UUID NOT NULL REFERENCES wbp(id) ON DELETE CASCADE,
  nama_pengunjung TEXT NOT NULL,
  nik_pengunjung TEXT NOT NULL,
  tgl_kunjungan DATE NOT NULL DEFAULT CURRENT_DATE,
  jam_kunjungan TEXT,
  status TEXT NOT NULL DEFAULT 'menunggu' CHECK (status IN ('menunggu', 'hadir', 'selesai')),
  daftar_barang JSONB NOT NULL DEFAULT '[]'::jsonb,
  metode_daftar TEXT NOT NULL DEFAULT 'online' CHECK (metode_daftar IN ('online', 'onsite')),
  no_antrean INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-increment nomor antrean RESET per hari
CREATE OR REPLACE FUNCTION set_no_antrean()
RETURNS TRIGGER AS $$
DECLARE max_antrean INTEGER;
BEGIN
  SELECT COALESCE(MAX(no_antrean), 0) + 1
  INTO max_antrean
  FROM kunjungan WHERE tgl_kunjungan = NEW.tgl_kunjungan;
  NEW.no_antrean := max_antrean;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_antrean ON kunjungan;
CREATE TRIGGER trigger_set_antrean
  BEFORE INSERT ON kunjungan
  FOR EACH ROW EXECUTE FUNCTION set_no_antrean();

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_updated_at ON kunjungan;
CREATE TRIGGER trigger_updated_at
  BEFORE UPDATE ON kunjungan
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- RLS
ALTER TABLE wbp ENABLE ROW LEVEL SECURITY;
ALTER TABLE keluarga_wbp ENABLE ROW LEVEL SECURITY;
ALTER TABLE kunjungan ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wbp_public_read" ON wbp;
CREATE POLICY "wbp_public_read" ON wbp FOR SELECT USING (true);
DROP POLICY IF EXISTS "wbp_admin_write" ON wbp;
CREATE POLICY "wbp_admin_write" ON wbp FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "keluarga_public_read" ON keluarga_wbp;
CREATE POLICY "keluarga_public_read" ON keluarga_wbp FOR SELECT USING (true);
DROP POLICY IF EXISTS "keluarga_admin_write" ON keluarga_wbp;
CREATE POLICY "keluarga_admin_write" ON keluarga_wbp FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "kunjungan_public_insert" ON kunjungan;
CREATE POLICY "kunjungan_public_insert" ON kunjungan FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "kunjungan_public_select" ON kunjungan;
CREATE POLICY "kunjungan_public_select" ON kunjungan FOR SELECT USING (true);
DROP POLICY IF EXISTS "kunjungan_admin_update" ON kunjungan;
CREATE POLICY "kunjungan_admin_update" ON kunjungan FOR UPDATE USING (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "kunjungan_admin_delete" ON kunjungan;
CREATE POLICY "kunjungan_admin_delete" ON kunjungan FOR DELETE USING (auth.role() = 'authenticated');

-- Indexes
CREATE INDEX IF NOT EXISTS idx_kunjungan_tgl ON kunjungan(tgl_kunjungan);
CREATE INDEX IF NOT EXISTS idx_kunjungan_status ON kunjungan(status);
CREATE INDEX IF NOT EXISTS idx_kunjungan_nik ON kunjungan(nik_pengunjung);
CREATE INDEX IF NOT EXISTS idx_keluarga_nik ON keluarga_wbp(nik_keluarga);
CREATE INDEX IF NOT EXISTS idx_wbp_status ON wbp(status);
