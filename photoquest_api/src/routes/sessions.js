// Route sesi foto: menyimpan hasil Plan (spot, jenis foto, waktu, skor, rekomendasi).
const express = require('express');

const db = require('../db');
const { ok, fail } = require('../utils/response');
const { requireAuth } = require('../middleware/auth');
const { PHOTO_TYPES } = require('../services/scoreService');

const router = express.Router();
router.use(requireAuth);

// POST /sessions { spot_id, photo_type, planned_at, score, recommendation }
router.post('/', async (req, res) => {
  const { spot_id: spotId, photo_type: photoType, planned_at: plannedAtRaw, score, recommendation } =
    req.body || {};

  if (!Number.isInteger(spotId)) return fail(res, 400, 'spot_id wajib berupa angka');
  if (!PHOTO_TYPES.includes(photoType)) return fail(res, 400, 'photo_type tidak valid');
  const plannedAt = new Date(plannedAtRaw);
  if (typeof plannedAtRaw !== 'string' || Number.isNaN(plannedAt.getTime())) {
    return fail(res, 400, 'planned_at wajib berupa tanggal ISO 8601');
  }
  if (!Number.isInteger(score) || score < 0 || score > 100) {
    return fail(res, 400, 'score harus bilangan bulat 0–100');
  }
  if (recommendation !== undefined && (typeof recommendation !== 'object' || Array.isArray(recommendation))) {
    return fail(res, 400, 'recommendation harus objek');
  }

  try {
    const { rows } = await db.query(
      `INSERT INTO photo_sessions (user_id, spot_id, photo_type, planned_at, score, recommendation)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, spot_id, photo_type, planned_at, score, recommendation, created_at`,
      [req.user.id, spotId, photoType, plannedAt.toISOString(), score, recommendation ?? null]
    );
    return ok(res, rows[0], 'Sesi foto disimpan', 201);
  } catch (err) {
    if (err.code === '23503') return fail(res, 404, 'Spot tidak ditemukan');
    throw err;
  }
});

// GET /sessions -> sesi milik user, rencana terdekat dulu
router.get('/', async (req, res) => {
  const { rows } = await db.query(
    `SELECT ps.id, ps.spot_id, s.name AS spot_name, ps.photo_type, ps.planned_at,
            ps.score, ps.recommendation, ps.created_at
     FROM photo_sessions ps
     JOIN spots s ON s.id = ps.spot_id
     WHERE ps.user_id = $1
     ORDER BY ps.planned_at DESC
     LIMIT 50`,
    [req.user.id]
  );
  return ok(res, rows);
});

module.exports = router;
