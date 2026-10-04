// Membangun aplikasi Express (dipisah dari index.js agar bisa diuji tanpa listen ke port).
const express = require('express');
const cors = require('cors');
const multer = require('multer');

const db = require('./db');
const { ok, fail } = require('./utils/response');

const app = express();

app.use(cors());
app.use(express.json({ limit: '1mb' }));

// GET /health -> memastikan server hidup DAN database bisa diakses.
app.get('/health', async (req, res) => {
  try {
    const result = await db.query('SELECT NOW() AS now');
    return ok(res, {
      status: 'ok',
      database: 'connected',
      time: result.rows[0].now,
    }, 'PhotoQuest API berjalan');
  } catch (err) {
    console.error('[health] DB error:', err.message);
    return fail(res, 503, 'Database tidak dapat diakses', {
      status: 'degraded',
      database: 'disconnected',
      time: new Date().toISOString(),
    });
  }
});

// Route fitur. Route lain (spots, favorites, dll) ditambahkan pada fase berikutnya.
app.use('/auth', require('./routes/auth'));
app.use('/users', require('./routes/users'));
app.use('/feedback', require('./routes/feedback'));
app.use('/challenge', require('./routes/challenge'));
app.use('/spots', require('./routes/spots'));
app.use('/favorites', require('./routes/favorites'));

// 404 untuk endpoint yang tidak ada.
app.use((req, res) => fail(res, 404, `Endpoint ${req.method} ${req.path} tidak ditemukan`));

// Penanganan error terpusat: error tak terduga tetap dibalas dengan format seragam.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  // JSON body yang rusak dari client
  if (err.type === 'entity.parse.failed') {
    return fail(res, 400, 'Body JSON tidak valid');
  }
  // Error upload dari multer, mis. file lebih dari 2 MB
  if (err instanceof multer.MulterError) {
    const message = err.code === 'LIMIT_FILE_SIZE' ? 'Ukuran foto maksimal 2 MB' : `Upload gagal: ${err.message}`;
    return fail(res, 400, message);
  }
  console.error('[error]', err);
  return fail(res, err.status || 500, err.expose ? err.message : 'Terjadi kesalahan pada server');
});

module.exports = app;
