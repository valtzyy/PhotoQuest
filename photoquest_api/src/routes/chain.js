// Route Chain Explorer: lihat blok, verifikasi, dan demo manipulasi data.
const express = require('express');

const config = require('../config');
const chainService = require('../services/chainService');
const { ok, fail } = require('../utils/response');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

// GET /chain -> semua blok + info apakah tombol demo boleh ditampilkan
router.get('/', async (req, res) => {
  const blocks = await chainService.getChain();
  return ok(res, { demo_mode: config.demoMode, difficulty: chainService.DIFFICULTY, blocks });
});

// GET /chain/verify -> { valid, broken_at, reason }
router.get('/verify', async (req, res) => {
  const result = await chainService.verifyChain();
  return ok(res, result, result.valid ? 'Chain VALID' : `Chain INVALID di blok #${result.broken_at}`);
});

// Endpoint demo hanya aktif jika DEMO_MODE=true di .env
function demoOnly(req, res, next) {
  if (!config.demoMode) return fail(res, 403, 'Fitur demo nonaktif (DEMO_MODE=false)');
  return next();
}

// POST /chain/tamper-demo -> ubah data blok terakhir TANPA menghitung ulang hash
router.post('/tamper-demo', demoOnly, async (req, res) => {
  const index = await chainService.tamperDemo();
  if (index === null) return fail(res, 409, 'Semua blok sudah dimanipulasi, pulihkan dulu');
  return ok(res, { tampered_block: index }, `Data blok #${index} diubah (hash tidak dihitung ulang)`);
});

// POST /chain/repair-demo -> kembalikan data asli blok yang dimanipulasi
router.post('/repair-demo', demoOnly, async (req, res) => {
  const repaired = await chainService.repairDemo();
  return ok(res, { repaired_blocks: repaired }, repaired.length ? 'Data asli dipulihkan' : 'Tidak ada blok yang perlu dipulihkan');
});

module.exports = router;
