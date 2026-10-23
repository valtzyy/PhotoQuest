-- Migrasi 001: blockchain Sepolia. AMAN untuk database yang sudah berisi data
-- (hanya menambah kolom/indeks, idempoten, tidak menghapus apa pun).
-- Jalankan: npm run db:migrate   (lihat DEPLOY.md untuk Neon)
--
-- Tabel lama `chain_blocks` (hash chain di PostgreSQL) TIDAK dihapus oleh migrasi ini
-- agar datanya tetap ada. Setelah yakin tidak diperlukan, hapus manual:
--   DROP TABLE chain_blocks;
-- Percobaan challenge lama yang sudah ada tidak dikirim ke Sepolia (tx_status tetap NULL).

ALTER TABLE challenge_attempts ADD COLUMN IF NOT EXISTS data_hash     VARCHAR(66);
ALTER TABLE challenge_attempts ADD COLUMN IF NOT EXISTS tx_hash       VARCHAR(66);
ALTER TABLE challenge_attempts ADD COLUMN IF NOT EXISTS tx_status     VARCHAR(10);
ALTER TABLE challenge_attempts ADD COLUMN IF NOT EXISTS tx_error      TEXT;
ALTER TABLE challenge_attempts ADD COLUMN IF NOT EXISTS tx_sent_at    TIMESTAMPTZ;
ALTER TABLE challenge_attempts ADD COLUMN IF NOT EXISTS chain_index   INT;
ALTER TABLE challenge_attempts ADD COLUMN IF NOT EXISTS block_number  BIGINT;
ALTER TABLE challenge_attempts ADD COLUMN IF NOT EXISTS confirmed_at  TIMESTAMPTZ;
ALTER TABLE challenge_attempts ADD COLUMN IF NOT EXISTS demo_original JSONB;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'challenge_attempts_tx_status_check') THEN
    ALTER TABLE challenge_attempts
      ADD CONSTRAINT challenge_attempts_tx_status_check
      CHECK (tx_status IN ('pending','confirmed','failed'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS challenge_attempts_tx_status_idx ON challenge_attempts (tx_status);
