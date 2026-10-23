// Pencatatan hasil Steady Challenge ke blockchain PUBLIK (Ethereum Sepolia testnet).
//
// Arsitektur:
//   - Smart contract ChallengeRegistry (contracts/ChallengeRegistry.sol) menyimpan catatan
//     {attemptId, userId, hold x100, tilt x1000, shake x1000, dataHash}. Hanya wallet
//     pemilik (relayer = backend ini) yang boleh menulis; siapa pun boleh membaca.
//   - Transaksi butuh 12-30 detik (> timeout aplikasi 8 detik), jadi POST /challenge
//     menyimpan ke database dan membalas cepat; transaksi dikirim di latar belakang.
//   - Status (pending/confirmed/failed) disimpan di kolom tx_* tabel challenge_attempts dan
//     diperbarui saat GET /chain dipanggil (refreshPending), tanpa worker terpisah.
//   - Bila RPC/kontrak/saldo bermasalah, hasil challenge TETAP tersimpan; status = failed
//     dan dapat dikirim ulang (retry).
//
// Layanan dibuat lewat createChainService({ client }) agar tes dapat memakai klien palsu
// (tanpa jaringan). Klien nyata (ethers.js) dibuat oleh createEthersClient.
const { keccak256, toUtf8Bytes } = require('ethers');

const db = require('../db');
const config = require('../config');

const EXPLORER = 'https://sepolia.etherscan.io';
const CHAIN_ID = 11155111;
const RPC_TIMEOUT_MS = 8000;
const PENDING_EXPIRE_MS = 30 * 60 * 1000; // tx tanpa receipt > 30 menit dianggap gagal
const STUCK_MS = 2 * 60 * 1000; // pending tanpa tx_hash > 2 menit (server mati saat kirim)
const LIST_LIMIT = 100;

class ChainUnavailableError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ChainUnavailableError';
  }
}

// ------------------------------------------------------------- data & hash
/**
 * JSON kanonik: key objek diurutkan rekursif, sehingga hash selalu sama untuk data yang
 * sama walau urutan key berbeda.
 */
function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (value && typeof value === 'object') {
    const keys = Object.keys(value).sort();
    return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalJson(value[k])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

/** Baris challenge_attempts -> nilai integer yang dicatat di kontrak. */
function toChainValues(row) {
  return {
    attemptId: Number(row.id),
    userId: Number(row.user_id),
    hold: Math.round(Number(row.hold_seconds) * 100),
    tilt: Math.round(Number(row.avg_tilt) * 1000),
    shake: Math.round(Number(row.avg_shake) * 1000),
  };
}

/** keccak256 dari data kanonik (hash bawaan Ethereum). */
function computeDataHash(values) {
  const data = {
    attempt_id: values.attemptId,
    user_id: values.userId,
    hold_x100: values.hold,
    tilt_x1000: values.tilt,
    shake_x1000: values.shake,
  };
  return keccak256(toUtf8Bytes(canonicalJson(data)));
}

/** Pesan error singkat TANPA rahasia (URL RPC dan private key dibuang). */
function sanitizeError(err) {
  let msg = String(err?.shortMessage || err?.message || err || 'Kesalahan tidak diketahui');
  for (const secret of [config.sepoliaRpcUrl, config.ethPrivateKey]) {
    if (secret) msg = msg.split(secret).join('[disembunyikan]');
  }
  msg = msg.replace(/https?:\/\/\S+/g, '[url]').replace(/\s+/g, ' ').trim();
  return msg.slice(0, 200);
}

const txUrl = (hash) => `${EXPLORER}/tx/${hash}`;
const addressUrl = (addr) => `${EXPLORER}/address/${addr}`;

function withTimeout(promise, ms, label = 'RPC') {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new ChainUnavailableError(`${label} tidak merespons (${ms} ms)`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

// ------------------------------------------------------------- klien ethers
/**
 * Klien nyata ke Sepolia lewat ethers.js. Antarmuka (dipakai layanan dan ditiru oleh tes):
 *   configured, info{chainId, contractAddress}
 *   send({attemptId,userId,hold,tilt,shake,dataHash}) -> { hash }
 *   getReceipt(hash) -> null | { status, blockNumber, index }
 *   getRecord(index) -> { attemptId,userId,hold,tilt,shake,dataHash }
 */
function createEthersClient({
  rpcUrl = config.sepoliaRpcUrl,
  privateKey = config.ethPrivateKey,
  contractAddress = config.chainContractAddress,
  chainId = CHAIN_ID,
  timeoutMs = RPC_TIMEOUT_MS,
} = {}) {
  const info = { chainId, contractAddress };
  if (!rpcUrl || !privateKey || !contractAddress) {
    const missing = [
      !rpcUrl && 'SEPOLIA_RPC_URL',
      !privateKey && 'ETH_PRIVATE_KEY',
      !contractAddress && 'CHAIN_CONTRACT_ADDRESS',
    ].filter(Boolean);
    const unavailable = async () => {
      throw new ChainUnavailableError(`Blockchain belum dikonfigurasi (${missing.join(', ')} kosong)`);
    };
    return { configured: false, info, send: unavailable, getReceipt: unavailable, getRecord: unavailable };
  }

  const { JsonRpcProvider, Wallet, Contract, FetchRequest } = require('ethers');
  const abi = require('../../contracts/ChallengeRegistry.abi.json');
  let cached;
  const get = () => {
    if (cached) return cached;
    try {
      const req = new FetchRequest(rpcUrl);
      req.timeout = timeoutMs;
      // staticNetwork: tidak perlu memanggil RPC hanya untuk mendeteksi jaringan.
      const provider = new JsonRpcProvider(req, chainId, { staticNetwork: true });
      const wallet = new Wallet(privateKey, provider);
      cached = { provider, contract: new Contract(contractAddress, abi, wallet) };
    } catch (err) {
      // Pesan asli tidak diteruskan: bisa memuat potongan kunci.
      throw new ChainUnavailableError('Konfigurasi blockchain tidak valid (periksa ETH_PRIVATE_KEY dan CHAIN_CONTRACT_ADDRESS)');
    }
    return cached;
  };

  return {
    configured: true,
    info,
    async send(v) {
      const { contract } = get();
      const tx = await contract.record(v.attemptId, v.userId, v.hold, v.tilt, v.shake, v.dataHash);
      return { hash: tx.hash }; // tidak menunggu konfirmasi
    },
    async getReceipt(hash) {
      const { provider, contract } = get();
      const receipt = await provider.getTransactionReceipt(hash);
      if (!receipt) return null;
      let index = null;
      for (const log of receipt.logs) {
        if (log.address.toLowerCase() !== String(contractAddress).toLowerCase()) continue;
        try {
          const parsed = contract.interface.parseLog(log);
          if (parsed && parsed.name === 'ChallengeRecorded') index = Number(parsed.args.index);
        } catch (_) {
          // log lain, abaikan
        }
      }
      return { status: receipt.status, blockNumber: Number(receipt.blockNumber), index };
    },
    async getRecord(index) {
      const { contract } = get();
      const r = await contract.getRecord(index);
      return {
        attemptId: Number(r.attemptId),
        userId: Number(r.userId),
        hold: Number(r.holdSeconds),
        tilt: Number(r.avgTilt),
        shake: Number(r.avgShake),
        dataHash: String(r.dataHash).toLowerCase(),
      };
    },
  };
}

// ------------------------------------------------------------- layanan
function createChainService({ client, refreshIntervalMs = 5000, now = Date.now } = {}) {
  let chainClient = client || createEthersClient();
  let refreshMs = refreshIntervalMs;
  let queue = Promise.resolve(); // pengiriman diserialkan agar nonce wallet tidak bentrok
  const inFlight = new Set();
  let lastRefresh = 0;
  let refreshing = null;

  /** Kirim satu percobaan ke kontrak. Tidak pernah melempar; hasilnya tersimpan di database. */
  function submit(attemptId) {
    if (inFlight.has(attemptId)) return queue;
    inFlight.add(attemptId);
    queue = queue
      .then(() => sendOne(attemptId))
      .catch(() => {})
      .finally(() => inFlight.delete(attemptId));
    return queue;
  }

  async function sendOne(attemptId) {
    const { rows } = await db.query(
      `SELECT id, user_id, success, hold_seconds, avg_tilt, avg_shake, tx_status, tx_hash
       FROM challenge_attempts WHERE id = $1`,
      [attemptId]
    );
    const row = rows[0];
    if (!row || !row.success) return;
    if (row.tx_status === 'confirmed' || (row.tx_status === 'pending' && row.tx_hash)) return;
    const values = toChainValues(row);
    const dataHash = computeDataHash(values);
    try {
      const { hash } = await chainClient.send({ ...values, dataHash });
      await db.query(
        `UPDATE challenge_attempts
         SET data_hash = $2, tx_hash = $3, tx_status = 'pending', tx_error = NULL, tx_sent_at = NOW()
         WHERE id = $1`,
        [attemptId, dataHash, hash]
      );
    } catch (err) {
      await db.query(
        `UPDATE challenge_attempts SET data_hash = $2, tx_status = 'failed', tx_error = $3 WHERE id = $1`,
        [attemptId, dataHash, sanitizeError(err)]
      );
    }
  }

  /**
   * Dipanggil POST /challenge untuk percobaan yang berhasil: tandai pending (cepat), lalu
   * kirim transaksi di latar belakang tanpa ditunggu.
   */
  async function enqueueAttempt(attemptRow) {
    const dataHash = computeDataHash(toChainValues(attemptRow));
    await db.query(
      `UPDATE challenge_attempts
       SET data_hash = $2, tx_status = 'pending', tx_hash = NULL, tx_error = NULL
       WHERE id = $1`,
      [attemptRow.id, dataHash]
    );
    submit(attemptRow.id);
    return { status: 'pending', data_hash: dataHash };
  }

  const failRow = (id, reason) =>
    db.query(`UPDATE challenge_attempts SET tx_status = 'failed', tx_error = $2 WHERE id = $1`, [id, reason]);

  /** Perbarui status transaksi pending dengan membaca receipt dari Sepolia. */
  function refreshPending({ force = false } = {}) {
    if (refreshing) return refreshing;
    if (!force && now() - lastRefresh < refreshMs) return Promise.resolve();
    lastRefresh = now();
    refreshing = (async () => {
      try {
        const { rows } = await db.query(
          `SELECT id, tx_hash, tx_sent_at FROM challenge_attempts
           WHERE tx_status = 'pending' AND tx_hash IS NOT NULL ORDER BY id LIMIT 30`
        );
        await Promise.allSettled(
          rows.map(async (r) => {
            const receipt = await withTimeout(chainClient.getReceipt(r.tx_hash), RPC_TIMEOUT_MS);
            if (receipt) {
              if (receipt.status === 1) {
                await db.query(
                  `UPDATE challenge_attempts
                   SET tx_status = 'confirmed', block_number = $2, chain_index = $3, confirmed_at = NOW(), tx_error = NULL
                   WHERE id = $1 AND tx_status = 'pending'`,
                  [r.id, receipt.blockNumber, receipt.index]
                );
              } else {
                await failRow(r.id, 'Transaksi ditolak kontrak (reverted)');
              }
            } else if (r.tx_sent_at && now() - new Date(r.tx_sent_at).getTime() > PENDING_EXPIRE_MS) {
              await failRow(r.id, 'Tidak terkonfirmasi dalam 30 menit');
            }
          })
        );
        // Pending tanpa tx_hash yang macet (server mati saat mengirim) dikirim ulang otomatis.
        const stuck = await db.query(
          `SELECT id FROM challenge_attempts
           WHERE tx_status = 'pending' AND tx_hash IS NULL
             AND created_at < NOW() - ($1::int * INTERVAL '1 millisecond')
           ORDER BY id LIMIT 10`,
          [STUCK_MS]
        );
        for (const r of stuck.rows) submit(r.id);
      } catch (_) {
        // RPC/DB sementara bermasalah: status dibiarkan, dicoba lagi pada panggilan berikutnya.
      } finally {
        refreshing = null;
      }
    })();
    return refreshing;
  }

  /** Kirim ulang percobaan yang failed (dan pending macet). Mengembalikan jumlah yang diantrikan. */
  async function retry() {
    const { rows } = await db.query(
      `SELECT id FROM challenge_attempts
       WHERE success = TRUE AND (tx_status = 'failed'
         OR (tx_status = 'pending' AND tx_hash IS NULL
             AND created_at < NOW() - ($1::int * INTERVAL '1 millisecond')))
       ORDER BY id LIMIT 20`,
      [STUCK_MS]
    );
    for (const r of rows) {
      await db.query(
        `UPDATE challenge_attempts SET tx_status = 'pending', tx_hash = NULL, tx_error = NULL WHERE id = $1`,
        [r.id]
      );
      submit(r.id);
    }
    return rows.length;
  }

  function shape(r) {
    return {
      attempt_id: r.attempt_id,
      user_id: r.user_id,
      hold_seconds: Number(r.hold_seconds),
      avg_tilt: Number(r.avg_tilt),
      avg_shake: Number(r.avg_shake),
      data_hash: r.data_hash,
      tx_hash: r.tx_hash,
      status: r.tx_status,
      error: r.tx_status === 'failed' ? r.tx_error : null,
      chain_index: r.chain_index,
      block_number: r.block_number === null ? null : Number(r.block_number),
      confirmed_at: r.confirmed_at ? r.confirmed_at.toISOString() : null,
      created_at: r.created_at.toISOString(),
      tampered: Boolean(r.tampered),
      explorer_url: r.tx_hash ? txUrl(r.tx_hash) : null,
    };
  }

  /** Daftar catatan (terbaru dulu) setelah memperbarui status pending. */
  async function getRecords() {
    await refreshPending();
    const { rows } = await db.query(
      `SELECT id AS attempt_id, user_id, hold_seconds, avg_tilt, avg_shake, data_hash, tx_hash, tx_status,
              tx_error, chain_index, block_number, confirmed_at, created_at, (demo_original IS NOT NULL) AS tampered
       FROM challenge_attempts WHERE tx_status IS NOT NULL
       ORDER BY id DESC LIMIT $1`,
      [LIST_LIMIT]
    );
    return rows.map(shape);
  }

  function info() {
    const c = chainClient.info || {};
    return {
      network: 'sepolia',
      chain_id: c.chainId || CHAIN_ID,
      configured: Boolean(chainClient.configured),
      contract_address: c.contractAddress || null,
      contract_url: c.contractAddress ? addressUrl(c.contractAddress) : null,
    };
  }

  /**
   * Bandingkan data di database dengan catatan on-chain untuk semua transaksi confirmed.
   * On-chain tidak bisa diubah, jadi ketidakcocokan berarti data database dimanipulasi.
   * Melempar ChainUnavailableError bila Sepolia tidak dapat dihubungi.
   */
  async function verify() {
    await refreshPending({ force: true });
    const { rows } = await db.query(
      `SELECT id, user_id, hold_seconds, avg_tilt, avg_shake, chain_index
       FROM challenge_attempts WHERE tx_status = 'confirmed' AND chain_index IS NOT NULL
       ORDER BY chain_index LIMIT $1`,
      [LIST_LIMIT]
    );
    const counts = await db.query(
      `SELECT COUNT(*) FILTER (WHERE tx_status = 'pending') AS pending,
              COUNT(*) FILTER (WHERE tx_status = 'failed') AS failed
       FROM challenge_attempts`
    );
    const mismatches = [];
    let unreachable = 0;
    await Promise.all(
      rows.map(async (r) => {
        let onchain;
        try {
          onchain = await withTimeout(chainClient.getRecord(r.chain_index), RPC_TIMEOUT_MS);
        } catch (err) {
          unreachable++;
          return;
        }
        const values = toChainValues(r);
        const reasons = [];
        if (onchain.attemptId !== values.attemptId) reasons.push('attempt_id berbeda');
        if (onchain.userId !== values.userId) reasons.push('user_id berbeda');
        if (onchain.hold !== values.hold) {
          reasons.push(`hold_seconds berbeda (database ${values.hold / 100}, on-chain ${onchain.hold / 100})`);
        }
        if (onchain.tilt !== values.tilt) {
          reasons.push(`avg_tilt berbeda (database ${values.tilt / 1000}, on-chain ${onchain.tilt / 1000})`);
        }
        if (onchain.shake !== values.shake) {
          reasons.push(`avg_shake berbeda (database ${values.shake / 1000}, on-chain ${onchain.shake / 1000})`);
        }
        if (onchain.dataHash !== computeDataHash(values)) reasons.push('data_hash tidak cocok');
        if (reasons.length) {
          mismatches.push({ attempt_id: r.id, chain_index: r.chain_index, reason: reasons.join('; ') });
        }
      })
    );
    if (rows.length > 0 && unreachable === rows.length) {
      throw new ChainUnavailableError('Catatan on-chain tidak dapat dibaca dari Sepolia');
    }
    mismatches.sort((a, b) => a.chain_index - b.chain_index);
    return {
      valid: mismatches.length === 0,
      checked: rows.length - unreachable,
      pending: Number(counts.rows[0].pending),
      failed: Number(counts.rows[0].failed),
      mismatches,
    };
  }

  // ---------------------------------------------------------------- demo
  /** Ubah data catatan confirmed terbaru di DATABASE (on-chain tidak bisa diubah). */
  async function tamperDemo() {
    const { rows } = await db.query(
      `SELECT id, hold_seconds, avg_tilt, avg_shake FROM challenge_attempts
       WHERE tx_status = 'confirmed' AND demo_original IS NULL ORDER BY id DESC LIMIT 1`
    );
    const target = rows[0];
    if (!target) return null;
    await db.query(
      `UPDATE challenge_attempts SET demo_original = $2::jsonb, hold_seconds = 19.99 WHERE id = $1`,
      [
        target.id,
        JSON.stringify({ hold_seconds: target.hold_seconds, avg_tilt: target.avg_tilt, avg_shake: target.avg_shake }),
      ]
    );
    return target.id;
  }

  async function repairDemo() {
    const result = await db.query(
      `UPDATE challenge_attempts
       SET hold_seconds = (demo_original->>'hold_seconds')::numeric,
           avg_tilt = (demo_original->>'avg_tilt')::numeric,
           avg_shake = (demo_original->>'avg_shake')::numeric,
           demo_original = NULL
       WHERE demo_original IS NOT NULL RETURNING id`
    );
    return result.rows.map((r) => r.id);
  }

  return {
    submit,
    enqueueAttempt,
    refreshPending,
    retry,
    getRecords,
    info,
    verify,
    tamperDemo,
    repairDemo,
    idle: () => queue,
    // Hanya untuk tes:
    setClient: (c) => {
      chainClient = c;
    },
    setRefreshInterval: (ms) => {
      refreshMs = ms;
      lastRefresh = 0;
    },
  };
}

const defaultService = createChainService();

module.exports = {
  ChainUnavailableError,
  canonicalJson,
  toChainValues,
  computeDataHash,
  sanitizeError,
  createEthersClient,
  createChainService,
  txUrl,
  addressUrl,
  ...defaultService,
};
