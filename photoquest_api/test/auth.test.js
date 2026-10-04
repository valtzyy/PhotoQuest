// Uji alur autentikasi: register, login, dan /auth/me.
// Membutuhkan database di DATABASE_URL. User uji dihapus lagi setelah tes selesai.
const { test, before, after } = require('node:test');
const assert = require('node:assert');
const jwt = require('jsonwebtoken');

const app = require('../src/app');
const db = require('../src/db');
const config = require('../src/config');

let server;
let baseUrl;
const email = `test_${Date.now()}@photoquest.test`;
const password = 'rahasia123';
let token;

async function post(path, body, headers = {}) {
  const res = await fetch(`${baseUrl}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

async function get(path, headers = {}) {
  const res = await fetch(`${baseUrl}${path}`, { headers });
  return { status: res.status, body: await res.json() };
}

before(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await db.query('DELETE FROM users WHERE email = $1', [email]);
  server.close();
  await db.pool.end();
});

test('Register berhasil -> 201, token, password_hash tidak dikirim', async () => {
  const r = await post('/auth/register', { name: 'Tester', email, password });
  assert.strictEqual(r.status, 201);
  assert.ok(r.body.data.token);
  assert.strictEqual(r.body.data.user.email, email);
  assert.strictEqual(r.body.data.user.password_hash, undefined);
});

test('Password tersimpan sebagai hash bcrypt, bukan teks polos', async () => {
  const { rows } = await db.query('SELECT password_hash FROM users WHERE email = $1', [email]);
  assert.notStrictEqual(rows[0].password_hash, password);
  assert.match(rows[0].password_hash, /^\$2[aby]\$10\$/);
});

test('Register email yang sama -> 409', async () => {
  const r = await post('/auth/register', { name: 'Tester', email, password });
  assert.strictEqual(r.status, 409);
});

test('Validasi: email tidak valid / password < 6 -> 400', async () => {
  assert.strictEqual((await post('/auth/login', { email: 'bukan-email', password })).status, 400);
  assert.strictEqual((await post('/auth/login', { email, password: '123' })).status, 400);
});

test('Login password salah -> 401', async () => {
  const r = await post('/auth/login', { email, password: 'salahsekali' });
  assert.strictEqual(r.status, 401);
  assert.strictEqual(r.body.success, false);
});

test('Login benar -> token JWT berlaku 7 hari', async () => {
  const r = await post('/auth/login', { email: email.toUpperCase(), password });
  assert.strictEqual(r.status, 200);
  token = r.body.data.token;
  const payload = jwt.decode(token);
  assert.strictEqual(payload.exp - payload.iat, 7 * 24 * 60 * 60);
});

test('GET /auth/me dengan token -> data user', async () => {
  const r = await get('/auth/me', { Authorization: `Bearer ${token}` });
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.body.data.email, email);
});

test('GET /auth/me tanpa token / token palsu / kedaluwarsa -> 401', async () => {
  assert.strictEqual((await get('/auth/me')).status, 401);
  assert.strictEqual((await get('/auth/me', { Authorization: 'Bearer abc.def.ghi' })).status, 401);

  const expired = jwt.sign({ sub: '1', email }, config.jwtSecret, { expiresIn: -10 });
  const r = await get('/auth/me', { Authorization: `Bearer ${expired}` });
  assert.strictEqual(r.status, 401);
  assert.match(r.body.message, /berakhir/);
});
