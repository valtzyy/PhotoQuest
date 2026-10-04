// Route Saran & Kesan mata kuliah Pemrograman Aplikasi Mobile.
const express = require('express');

const db = require('../db');
const { ok, fail } = require('../utils/response');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
const MAX_LENGTH = 1000;

router.use(requireAuth);

// POST /feedback  { saran, kesan }
router.post('/', async (req, res) => {
  const saran = typeof req.body?.saran === 'string' ? req.body.saran.trim() : '';
  const kesan = typeof req.body?.kesan === 'string' ? req.body.kesan.trim() : '';

  if (!saran || !kesan) return fail(res, 400, 'Saran dan kesan wajib diisi');
  if (saran.length > MAX_LENGTH || kesan.length > MAX_LENGTH) {
    return fail(res, 400, `Saran/kesan maksimal ${MAX_LENGTH} karakter`);
  }

  const { rows } = await db.query(
    `INSERT INTO feedback (user_id, saran, kesan) VALUES ($1, $2, $3)
     RETURNING id, saran, kesan, created_at`,
    [req.user.id, saran, kesan]
  );
  return ok(res, rows[0], 'Terima kasih atas saran dan kesannya', 201);
});

// GET /feedback/me -> feedback yang pernah dikirim user ini (terbaru dulu)
router.get('/me', async (req, res) => {
  const { rows } = await db.query(
    `SELECT id, saran, kesan, created_at FROM feedback
     WHERE user_id = $1 ORDER BY created_at DESC`,
    [req.user.id]
  );
  return ok(res, rows);
});

module.exports = router;
