// Route autentikasi: register, login, dan validasi session (/auth/me).
const express = require('express');
const bcrypt = require('bcrypt');

const db = require('../db');
const { ok, fail } = require('../utils/response');
const { requireAuth, signToken } = require('../middleware/auth');

const router = express.Router();

const BCRYPT_COST = 10;
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Kolom user yang aman dikirim ke client (password_hash TIDAK pernah dikirim).
const USER_COLUMNS = 'id, name, email, photo_url, created_at';

// Validasi input bersama untuk register & login.
function validateCredentials({ email, password }) {
  if (typeof email !== 'string' || !EMAIL_REGEX.test(email.trim())) {
    return 'Format email tidak valid';
  }
  if (typeof password !== 'string' || password.length < 6) {
    return 'Password minimal 6 karakter';
  }
  return null;
}

// POST /auth/register  { name, email, password }
router.post('/register', async (req, res) => {
  const { name, email, password } = req.body || {};

  if (typeof name !== 'string' || name.trim().length < 2) {
    return fail(res, 400, 'Nama minimal 2 karakter');
  }
  const error = validateCredentials({ email, password });
  if (error) return fail(res, 400, error);

  const normalizedEmail = email.trim().toLowerCase();

  // Hash password dengan bcrypt (cost 10). Salt acak sudah termasuk di dalam hash.
  const passwordHash = await bcrypt.hash(password, BCRYPT_COST);

  try {
    const { rows } = await db.query(
      `INSERT INTO users (name, email, password_hash)
       VALUES ($1, $2, $3)
       RETURNING ${USER_COLUMNS}`,
      [name.trim(), normalizedEmail, passwordHash]
    );
    const user = rows[0];
    // Langsung login setelah register: kembalikan token juga.
    return ok(res, { token: signToken(user), user }, 'Registrasi berhasil', 201);
  } catch (err) {
    // 23505 = unique_violation (email sudah dipakai)
    if (err.code === '23505') {
      return fail(res, 409, 'Email sudah terdaftar');
    }
    throw err;
  }
});

// POST /auth/login  { email, password }
router.post('/login', async (req, res) => {
  const { email, password } = req.body || {};
  const error = validateCredentials({ email, password });
  if (error) return fail(res, 400, error);

  const { rows } = await db.query(
    `SELECT ${USER_COLUMNS}, password_hash FROM users WHERE email = $1`,
    [email.trim().toLowerCase()]
  );
  const row = rows[0];

  // bcrypt.compare meng-hash ulang password input dengan salt yang sama lalu membandingkan.
  // Pesan error sengaja dibuat sama untuk email/password salah agar tidak membocorkan
  // email mana yang terdaftar.
  const valid = row ? await bcrypt.compare(password, row.password_hash) : false;
  if (!valid) {
    return fail(res, 401, 'Email atau password salah');
  }

  const { password_hash: _ignored, ...user } = row;
  return ok(res, { token: signToken(user), user }, 'Login berhasil');
});

// GET /auth/me  -> dipakai app saat dibuka untuk memulihkan session
router.get('/me', requireAuth, async (req, res) => {
  const { rows } = await db.query(
    `SELECT ${USER_COLUMNS} FROM users WHERE id = $1`,
    [req.user.id]
  );
  // Token valid tapi user sudah dihapus -> anggap session tidak berlaku.
  if (!rows[0]) return fail(res, 401, 'User tidak ditemukan. Silakan login kembali.');
  return ok(res, rows[0]);
});

module.exports = router;
