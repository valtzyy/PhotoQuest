// Route profil user: ubah nama, upload & ambil foto profil.
const express = require('express');
const multer = require('multer');

const db = require('../db');
const { ok, fail } = require('../utils/response');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

const USER_COLUMNS = 'id, name, email, photo_url, created_at';
const ALLOWED_MIME = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_PHOTO_BYTES = 2 * 1024 * 1024; // 2 MB

// multer memoryStorage: file disimpan di RAM (req.file.buffer), lalu kita simpan
// ke Postgres. Tidak memakai disk karena disk Render free hilang saat restart.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_PHOTO_BYTES },
  fileFilter: (req, file, cb) => cb(null, ALLOWED_MIME.includes(file.mimetype)),
});

router.use(requireAuth);

// PUT /users/me  { name }
router.put('/me', async (req, res) => {
  const name = typeof req.body?.name === 'string' ? req.body.name.trim() : '';
  if (name.length < 2 || name.length > 100) {
    return fail(res, 400, 'Nama harus 2-100 karakter');
  }
  const { rows } = await db.query(
    `UPDATE users SET name = $1 WHERE id = $2 RETURNING ${USER_COLUMNS}`,
    [name, req.user.id]
  );
  if (!rows[0]) return fail(res, 404, 'User tidak ditemukan');
  return ok(res, rows[0], 'Nama berhasil diperbarui');
});

// POST /users/me/photo  (multipart/form-data, field "photo")
router.post('/me/photo', upload.single('photo'), async (req, res) => {
  if (!req.file) {
    return fail(res, 400, 'File foto wajib diisi (JPG/PNG/WEBP, maks. 2 MB)');
  }

  // Simpan/timpa foto (UPSERT): satu user hanya punya satu foto.
  await db.query(
    `INSERT INTO user_photos (user_id, mime_type, data, updated_at)
     VALUES ($1, $2, $3, NOW())
     ON CONFLICT (user_id)
     DO UPDATE SET mime_type = EXCLUDED.mime_type, data = EXCLUDED.data, updated_at = NOW()`,
    [req.user.id, req.file.mimetype, req.file.buffer]
  );

  // Query string ?v=<waktu> membuat URL berubah setiap upload, sehingga
  // aplikasi tidak menampilkan foto lama dari cache.
  const photoUrl = `/users/${req.user.id}/photo?v=${Date.now()}`;
  const { rows } = await db.query(
    `UPDATE users SET photo_url = $1 WHERE id = $2 RETURNING ${USER_COLUMNS}`,
    [photoUrl, req.user.id]
  );
  return ok(res, rows[0], 'Foto profil berhasil diperbarui');
});

// GET /users/:id/photo  -> mengirim biner gambar (bukan JSON)
router.get('/:id/photo', async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return fail(res, 400, 'ID tidak valid');

  const { rows } = await db.query(
    'SELECT mime_type, data FROM user_photos WHERE user_id = $1',
    [id]
  );
  if (!rows[0]) return fail(res, 404, 'Foto tidak ditemukan');

  res.set('Cache-Control', 'private, max-age=86400');
  return res.type(rows[0].mime_type).send(rows[0].data);
});

module.exports = router;
