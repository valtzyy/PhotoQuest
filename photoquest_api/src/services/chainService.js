// Blockchain sederhana (hash chain + proof-of-work ringan) untuk hasil Steady Challenge.
//
// Setiap blok: block_index, timestamp, data, prev_hash, nonce, hash
//   hash = SHA-256(block_index + timestamp ISO + JSON(data) + prev_hash + nonce)
// Blok saling terkait karena prev_hash = hash blok sebelumnya. Mengubah data satu
// blok membuat hash-nya tidak cocok lagi, sehingga chain terdeteksi INVALID.
const crypto = require('crypto');
const db = require('../db');

const DIFFICULTY = 2; // hash harus diawali "00"
const PREFIX = '0'.repeat(DIFFICULTY);
const GENESIS_DATA = { message: 'Genesis block PhotoQuest' };
const LOCK_KEY = 20261006; // advisory lock agar dua request tidak membuat block_index sama

/**
 * JSON kanonik: key objek diurutkan secara rekursif.
 * Wajib karena PostgreSQL JSONB menyusun ulang urutan key; tanpa ini hash data
 * yang dibaca kembali dari database akan berbeda dari hash saat blok dibuat.
 */
function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (value && typeof value === 'object') {
    const keys = Object.keys(value).sort();
    return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalJson(value[k])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function computeHash({ block_index: index, timestamp, data, prev_hash: prevHash, nonce }) {
  const ts = timestamp instanceof Date ? timestamp.toISOString() : timestamp;
  return crypto
    .createHash('sha256')
    .update(`${index}${ts}${canonicalJson(data)}${prevHash}${nonce}`)
    .digest('hex');
}

/** Proof-of-work: naikkan nonce sampai hash diawali "00" (rata-rata ±256 percobaan). */
function mine({ block_index: index, timestamp, data, prev_hash: prevHash }) {
  let nonce = 0;
  let hash = computeHash({ block_index: index, timestamp, data, prev_hash: prevHash, nonce });
  while (!hash.startsWith(PREFIX)) {
    nonce++;
    hash = computeHash({ block_index: index, timestamp, data, prev_hash: prevHash, nonce });
  }
  return { block_index: index, timestamp, data, prev_hash: prevHash, nonce, hash };
}

/**
 * Verifikasi seluruh chain (urut block_index):
 *   1. hash yang disimpan == hash yang dihitung ulang (data tidak diubah)
 *   2. hash memenuhi difficulty (proof-of-work)
 *   3. prev_hash == hash blok sebelumnya (genesis: "0")
 */
function verifyBlocks(blocks) {
  for (let i = 0; i < blocks.length; i++) {
    const b = blocks[i];
    const expectedPrev = i === 0 ? '0' : blocks[i - 1].hash;
    if (b.prev_hash !== expectedPrev) {
      return { valid: false, broken_at: b.block_index, reason: 'prev_hash tidak cocok dengan hash blok sebelumnya' };
    }
    if (computeHash(b) !== b.hash) {
      return { valid: false, broken_at: b.block_index, reason: 'data blok diubah (hash tidak cocok)' };
    }
    if (!b.hash.startsWith(PREFIX)) {
      return { valid: false, broken_at: b.block_index, reason: 'hash tidak memenuhi proof-of-work' };
    }
  }
  return { valid: true, broken_at: null, reason: null };
}

const SELECT_BLOCKS = 'SELECT block_index, timestamp, data, prev_hash, hash, nonce FROM chain_blocks';

/** Buat genesis block jika tabel masih kosong. */
async function ensureGenesis(client = db) {
  const { rows } = await client.query('SELECT 1 FROM chain_blocks LIMIT 1');
  if (rows.length) return;
  const genesis = mine({ block_index: 0, timestamp: new Date().toISOString(), data: GENESIS_DATA, prev_hash: '0' });
  await client.query(
    `INSERT INTO chain_blocks (block_index, timestamp, data, prev_hash, hash, nonce)
     VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (block_index) DO NOTHING`,
    [0, genesis.timestamp, genesis.data, genesis.prev_hash, genesis.hash, genesis.nonce]
  );
}

/** Tambah blok baru berisi `data` di ujung chain. */
async function addBlock(data) {
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');
    // Kunci transaksi: penambahan blok dilayani satu per satu.
    await client.query('SELECT pg_advisory_xact_lock($1)', [LOCK_KEY]);
    await ensureGenesis(client);
    const { rows } = await client.query(`${SELECT_BLOCKS} ORDER BY block_index DESC LIMIT 1`);
    const last = rows[0];
    const block = mine({
      block_index: last.block_index + 1,
      timestamp: new Date().toISOString(),
      data,
      prev_hash: last.hash,
    });
    await client.query(
      `INSERT INTO chain_blocks (block_index, timestamp, data, prev_hash, hash, nonce)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [block.block_index, block.timestamp, block.data, block.prev_hash, block.hash, block.nonce]
    );
    await client.query('COMMIT');
    return block;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function getChain() {
  await ensureGenesis();
  const { rows } = await db.query(`${SELECT_BLOCKS} ORDER BY block_index`);
  return rows.map((r) => ({ ...r, timestamp: r.timestamp.toISOString() }));
}

async function verifyChain() {
  return verifyBlocks(await getChain());
}

// ---------------------------------------------------------------- demo
// Tamper: ubah data blok terakhir TANPA menghitung ulang hash. Data asli disimpan
// di dalam field `_tampered_original` agar bisa dipulihkan (repair).
async function tamperDemo() {
  await ensureGenesis();
  const { rows } = await db.query(
    `${SELECT_BLOCKS} WHERE NOT (data ? '_tampered_original') ORDER BY block_index DESC LIMIT 1`
  );
  const target = rows[0];
  if (!target) return null;
  const forged = { ...target.data, hold_seconds: 99.9, _tampered_original: target.data };
  await db.query('UPDATE chain_blocks SET data = $1 WHERE block_index = $2', [forged, target.block_index]);
  return target.block_index;
}

async function repairDemo() {
  const result = await db.query(
    `UPDATE chain_blocks SET data = data -> '_tampered_original'
     WHERE data ? '_tampered_original' RETURNING block_index`
  );
  return result.rows.map((r) => r.block_index);
}

module.exports = {
  DIFFICULTY,
  canonicalJson,
  computeHash,
  mine,
  verifyBlocks,
  ensureGenesis,
  addBlock,
  getChain,
  verifyChain,
  tamperDemo,
  repairDemo,
};
