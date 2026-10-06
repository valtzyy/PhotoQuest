// Route Steady Shot Challenge: riwayat dan pengiriman hasil.
// Hasil yang BERHASIL dicatat sebagai blok baru di blockchain (chainService).
const express = require('express');

const db = require('../db');
const { ok, fail } = require('../utils/response');
const { requireAuth } = require('../middleware/auth');
const chainService = require('../services/chainService');

const router = express.Router();

const HOLD_TARGET = 5; // detik stabil yang dibutuhkan untuk menang
const TIME_LIMIT = 20; // batas waktu challenge (detik)

const round = (v, digits) => Math.round(v * 10 ** digits) / 10 ** digits;
const isNum = (v) => typeof v === 'number' && Number.isFinite(v) && v >= 0;

router.use(requireAuth);

// GET /challenge -> 20 percobaan terakhir milik user
router.get('/', async (req, res) => {
  const { rows } = await db.query(
    `SELECT id, success, hold_seconds, avg_tilt, avg_shake, created_at
     FROM challenge_attempts
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT 20`,
    [req.user.id]
  );
  // NUMERIC dari pg dikembalikan sebagai string -> ubah ke number untuk client.
  const data = rows.map((r) => ({
    ...r,
    hold_seconds: Number(r.hold_seconds),
    avg_tilt: Number(r.avg_tilt),
    avg_shake: Number(r.avg_shake),
  }));
  return ok(res, data);
});

// POST /challenge { success, hold_seconds, avg_tilt, avg_shake }
router.post('/', async (req, res) => {
  const { success, hold_seconds: hold, avg_tilt: tilt, avg_shake: shake } = req.body || {};

  if (typeof success !== 'boolean') return fail(res, 400, 'success wajib boolean');
  if (!isNum(hold) || hold > TIME_LIMIT) return fail(res, 400, `hold_seconds harus 0–${TIME_LIMIT}`);
  if (!isNum(tilt) || tilt > 90) return fail(res, 400, 'avg_tilt harus 0–90 derajat');
  if (!isNum(shake) || shake > 50) return fail(res, 400, 'avg_shake tidak valid');
  // Pemeriksaan konsistensi sederhana: menang berarti stabil minimal 5 detik.
  if (success && hold < HOLD_TARGET) {
    return fail(res, 400, `Hasil tidak konsisten: menang butuh hold ≥ ${HOLD_TARGET} detik`);
  }

  const values = { hold: round(hold, 2), tilt: round(tilt, 3), shake: round(shake, 3) };
  const { rows } = await db.query(
    `INSERT INTO challenge_attempts (user_id, success, hold_seconds, avg_tilt, avg_shake)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, success, hold_seconds, avg_tilt, avg_shake, created_at`,
    [req.user.id, success, values.hold, values.tilt, values.shake]
  );
  const attempt = {
    ...rows[0],
    hold_seconds: Number(rows[0].hold_seconds),
    avg_tilt: Number(rows[0].avg_tilt),
    avg_shake: Number(rows[0].avg_shake),
  };

  // Hanya percobaan yang berhasil yang masuk blockchain.
  let block = null;
  if (success) {
    const added = await chainService.addBlock({
      type: 'steady_shot',
      attempt_id: attempt.id,
      user_id: req.user.id,
      hold_seconds: values.hold,
      avg_tilt: values.tilt,
      avg_shake: values.shake,
    });
    block = { block_index: added.block_index, hash: added.hash };
  }

  return ok(res, { attempt, block }, success ? 'Berhasil! Tercatat di blockchain' : 'Hasil disimpan', 201);
});

module.exports = router;
