// Membangun aplikasi Express (dipisah dari index.js agar bisa diuji tanpa listen ke port).
const express = require('express');
const cors = require('cors');

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

// 404 untuk endpoint yang tidak ada.
app.use((req, res) => fail(res, 404, `Endpoint ${req.method} ${req.path} tidak ditemukan`));

// Penanganan error terpusat: error tak terduga tetap dibalas dengan format seragam.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  // JSON body yang rusak dari client
  if (err.type === 'entity.parse.failed') {
    return fail(res, 400, 'Body JSON tidak valid');
  }
  console.error('[error]', err);
  return fail(res, err.status || 500, err.expose ? err.message : 'Terjadi kesalahan pada server');
});

module.exports = app;
