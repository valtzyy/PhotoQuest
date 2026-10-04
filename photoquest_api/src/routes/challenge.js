// Route Steady Shot Challenge.
// Fase 3: hanya GET (riwayat untuk halaman Profil).
// Fase 10: ditambah POST /challenge + pencatatan ke blockchain.
const express = require('express');

const db = require('../db');
const { ok } = require('../utils/response');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

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

module.exports = router;
