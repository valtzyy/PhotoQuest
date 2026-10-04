// Route spot foto: daftar + pencarian + filter kategori, dan detail.
const express = require('express');

const db = require('../db');
const { ok, fail } = require('../utils/response');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

const CATEGORIES = ['landscape', 'architecture', 'street', 'nature', 'culture'];
const SPOT_COLUMNS = `id, name, category, description, latitude, longitude, best_time,
  photo_types, tips, image_url, entry_fee_idr`;

router.use(requireAuth);

// Karakter % dan _ adalah wildcard di LIKE; di-escape agar dicari sebagai teks biasa.
function escapeLike(text) {
  return text.replace(/[\\%_]/g, (ch) => `\\${ch}`);
}

// GET /spots?search=pantai&category=landscape
router.get('/', async (req, res) => {
  const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
  const category = typeof req.query.category === 'string' ? req.query.category.trim() : '';

  if (category && !CATEGORIES.includes(category)) {
    return fail(res, 400, `Kategori tidak valid. Pilihan: ${CATEGORIES.join(', ')}`);
  }

  // Parameter NULL berarti filter tersebut tidak dipakai.
  // ILIKE = pencarian tidak peka huruf besar/kecil pada nama ATAU deskripsi.
  const { rows } = await db.query(
    `SELECT ${SPOT_COLUMNS} FROM spots
     WHERE ($1::text IS NULL OR name ILIKE $1 OR description ILIKE $1)
       AND ($2::text IS NULL OR category = $2)
     ORDER BY name`,
    [search ? `%${escapeLike(search)}%` : null, category || null]
  );
  return ok(res, rows);
});

// GET /spots/:id
router.get('/:id', async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return fail(res, 400, 'ID spot tidak valid');

  const { rows } = await db.query(`SELECT ${SPOT_COLUMNS} FROM spots WHERE id = $1`, [id]);
  if (!rows[0]) return fail(res, 404, 'Spot tidak ditemukan');
  return ok(res, rows[0]);
});

module.exports = router;
