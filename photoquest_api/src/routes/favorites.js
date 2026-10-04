// Route spot favorit milik user yang login.
const express = require('express');

const db = require('../db');
const { ok, fail } = require('../utils/response');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.use(requireAuth);

// GET /favorites -> daftar spot favorit (terbaru dulu)
router.get('/', async (req, res) => {
  const { rows } = await db.query(
    `SELECT s.id, s.name, s.category, s.description, s.latitude, s.longitude, s.best_time,
            s.photo_types, s.tips, s.image_url, s.entry_fee_idr, f.created_at AS favorited_at
     FROM favorites f
     JOIN spots s ON s.id = f.spot_id
     WHERE f.user_id = $1
     ORDER BY f.created_at DESC`,
    [req.user.id]
  );
  return ok(res, rows);
});

// POST /favorites  { spot_id }
router.post('/', async (req, res) => {
  const spotId = Number(req.body?.spot_id);
  if (!Number.isInteger(spotId)) return fail(res, 400, 'spot_id wajib berupa angka');

  try {
    // ON CONFLICT DO NOTHING: menambah favorit yang sudah ada tidak dianggap error.
    await db.query(
      `INSERT INTO favorites (user_id, spot_id) VALUES ($1, $2)
       ON CONFLICT (user_id, spot_id) DO NOTHING`,
      [req.user.id, spotId]
    );
  } catch (err) {
    // 23503 = foreign_key_violation -> spot_id tidak ada di tabel spots
    if (err.code === '23503') return fail(res, 404, 'Spot tidak ditemukan');
    throw err;
  }
  return ok(res, { spot_id: spotId }, 'Ditambahkan ke favorit', 201);
});

// DELETE /favorites/:spotId
router.delete('/:spotId', async (req, res) => {
  const spotId = Number(req.params.spotId);
  if (!Number.isInteger(spotId)) return fail(res, 400, 'spotId tidak valid');

  const result = await db.query(
    'DELETE FROM favorites WHERE user_id = $1 AND spot_id = $2',
    [req.user.id, spotId]
  );
  // Idempoten: menghapus yang memang tidak ada tetap dibalas sukses.
  return ok(res, { spot_id: spotId, removed: result.rowCount > 0 }, 'Dihapus dari favorit');
});

module.exports = router;
