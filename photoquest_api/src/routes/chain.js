// Route Chain Explorer: catatan di blockchain Sepolia, verifikasi, retry, dan demo manipulasi.
const express = require('express');

const config = require('../config');
const chainService = require('../services/chainService');
const { ok, fail } = require('../utils/response');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

// GET /chain -> catatan (tx_hash, status, URL Etherscan) + info jaringan/kontrak.
// Status transaksi pending diperbarui dulu dari Sepolia (tanpa worker terpisah).
router.get('/', async (req, res) => {
  const records = await chainService.getRecords();
  return ok(res, { demo_mode: config.demoMode, ...chainService.info(), records });
});

// GET /chain/verify -> bandingkan database dengan catatan on-chain
router.get('/verify', async (req, res) => {
  try {
    const result = await chainService.verify();
    const message = result.valid
      ? 'Data database cocok dengan catatan on-chain'
      : `${result.mismatches.length} catatan tidak cocok dengan on-chain`;
    return ok(res, result, message);
  } catch (err) {
    if (err instanceof chainService.ChainUnavailableError) {
      return fail(res, 503, 'Sepolia tidak dapat dihubungi, coba lagi');
    }
    throw err;
  }
});

// POST /chain/retry -> kirim ulang catatan yang failed (dan pending macet)
router.post('/retry', async (req, res) => {
  const queued = await chainService.retry();
  return ok(res, { queued }, queued ? `${queued} catatan dikirim ulang` : 'Tidak ada catatan yang perlu dikirim ulang');
});

// Endpoint demo hanya aktif jika DEMO_MODE=true di .env
function demoOnly(req, res, next) {
  if (!config.demoMode) return fail(res, 403, 'Fitur demo nonaktif (DEMO_MODE=false)');
  return next();
}

// POST /chain/tamper-demo -> ubah data catatan confirmed terbaru DI DATABASE
// (on-chain tidak bisa diubah, jadi /chain/verify akan menunjukkan ketidakcocokan)
router.post('/tamper-demo', demoOnly, async (req, res) => {
  const id = await chainService.tamperDemo();
  if (id === null) return fail(res, 409, 'Tidak ada catatan confirmed yang bisa dimanipulasi (atau semuanya sudah dimanipulasi)');
  return ok(res, { tampered_attempt: id }, `Data percobaan #${id} diubah di database (on-chain tetap asli)`);
});

// POST /chain/repair-demo -> kembalikan data asli di database
router.post('/repair-demo', demoOnly, async (req, res) => {
  const repaired = await chainService.repairDemo();
  return ok(res, { repaired_attempts: repaired }, repaired.length ? 'Data asli dipulihkan' : 'Tidak ada data yang perlu dipulihkan');
});

module.exports = router;
