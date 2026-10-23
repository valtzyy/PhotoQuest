-- =====================================================================
-- PhotoQuest - Skema database online (PostgreSQL)
-- PERINGATAN: file ini MENGHAPUS semua tabel lalu membuat ulang.
-- Jalankan lewat: npm run db:init
-- =====================================================================

DROP TABLE IF EXISTS feedback, chain_blocks, challenge_attempts, photo_sessions,
  favorites, user_photos, gear_items, spots, users CASCADE;

-- ---------------------------------------------------------------------
-- Pengguna. Password TIDAK pernah disimpan polos, hanya hash bcrypt.
-- ---------------------------------------------------------------------
CREATE TABLE users (
  id            SERIAL PRIMARY KEY,
  name          VARCHAR(100) NOT NULL,
  email         VARCHAR(255) NOT NULL UNIQUE,
  password_hash TEXT         NOT NULL,
  photo_url     TEXT,                       -- mis. /users/5/photo (lihat tabel user_photos)
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Foto profil disimpan sebagai biner di Postgres (bukan di disk server),
-- karena disk Render free bersifat sementara dan hilang saat restart.
CREATE TABLE user_photos (
  user_id    INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  mime_type  VARCHAR(50) NOT NULL,
  data       BYTEA       NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- Spot foto
-- ---------------------------------------------------------------------
CREATE TABLE spots (
  id            SERIAL PRIMARY KEY,
  name          VARCHAR(150) NOT NULL,
  category      VARCHAR(20)  NOT NULL
                CHECK (category IN ('landscape','architecture','street','nature','culture')),
  description   TEXT         NOT NULL,
  latitude      DOUBLE PRECISION NOT NULL,
  longitude     DOUBLE PRECISION NOT NULL,
  best_time     VARCHAR(10)  NOT NULL CHECK (best_time IN ('sunrise','sunset','any')),
  -- jenis foto yang cocok: landscape | sunset | street | architecture | portrait
  photo_types   TEXT[]       NOT NULL DEFAULT '{}',
  tips          TEXT,
  image_url     TEXT,                       -- foto asli (Wikimedia Commons)
  image_credit  TEXT,                       -- atribusi: pembuat foto + lisensi
  entry_fee_idr INT
);

CREATE INDEX idx_spots_category ON spots(category);

CREATE TABLE favorites (
  id         SERIAL PRIMARY KEY,
  user_id    INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  spot_id    INT NOT NULL REFERENCES spots(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, spot_id)
);

-- Rencana pemotretan hasil fitur Plan (AI score)
CREATE TABLE photo_sessions (
  id             SERIAL PRIMARY KEY,
  user_id        INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  spot_id        INT NOT NULL REFERENCES spots(id) ON DELETE CASCADE,
  photo_type     VARCHAR(20) NOT NULL,
  planned_at     TIMESTAMPTZ NOT NULL,
  score          INT NOT NULL CHECK (score BETWEEN 0 AND 100),
  recommendation JSONB,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Hasil mini-game Steady Shot Challenge.
-- Percobaan yang BERHASIL juga dicatat ke blockchain publik (Ethereum Sepolia) lewat
-- smart contract ChallengeRegistry. Kolom tx_* melacak transaksi tersebut:
--   tx_status: NULL (tidak dicatat, mis. percobaan gagal) | pending | confirmed | failed
CREATE TABLE challenge_attempts (
  id            SERIAL PRIMARY KEY,
  user_id       INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  success       BOOLEAN NOT NULL,
  hold_seconds  NUMERIC(5,2) NOT NULL,
  avg_tilt      NUMERIC(6,3) NOT NULL,
  avg_shake     NUMERIC(6,3) NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  data_hash     VARCHAR(66),                -- keccak256 data kanonik (sama dengan yang di on-chain)
  tx_hash       VARCHAR(66),                -- hash transaksi Sepolia
  tx_status     VARCHAR(10) CHECK (tx_status IN ('pending','confirmed','failed')),
  tx_error      TEXT,                       -- alasan singkat bila failed (tanpa rahasia)
  tx_sent_at    TIMESTAMPTZ,                -- kapan transaksi dikirim ke jaringan
  chain_index   INT,                        -- indeks catatan di kontrak (recordCount saat dicatat)
  block_number  BIGINT,                     -- nomor blok Sepolia
  confirmed_at  TIMESTAMPTZ,
  demo_original JSONB                       -- data asli saat demo manipulasi (DEMO_MODE) aktif
);
CREATE INDEX challenge_attempts_tx_status_idx ON challenge_attempts (tx_status);

-- Saran & Kesan mata kuliah Pemrograman Aplikasi Mobile
CREATE TABLE feedback (
  id         SERIAL PRIMARY KEY,
  user_id    INT  NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  saran      TEXT NOT NULL,
  kesan      TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Daftar gear fotografi untuk fitur Konverter Mata Uang
CREATE TABLE gear_items (
  id        SERIAL PRIMARY KEY,
  name      VARCHAR(150) NOT NULL,
  price_idr INT NOT NULL CHECK (price_idr >= 0)
);
