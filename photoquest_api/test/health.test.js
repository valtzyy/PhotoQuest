// Uji endpoint dasar memakai test runner bawaan Node (node --test).
// Membutuhkan database di DATABASE_URL sudah berjalan.
const { test, before, after } = require('node:test');
const assert = require('node:assert');

const app = require('../src/app');
const { pool } = require('../src/db');

let server;
let baseUrl;

before(async () => {
  // Port 0 = sistem memilih port kosong secara acak
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  server.close();
  await pool.end();
});

test('GET /health -> server dan database terhubung', async () => {
  const res = await fetch(`${baseUrl}/health`);
  const body = await res.json();
  assert.strictEqual(res.status, 200);
  assert.strictEqual(body.success, true);
  assert.strictEqual(body.data.database, 'connected');
});

test('Endpoint tidak dikenal -> 404 dengan format { success, data, message }', async () => {
  const res = await fetch(`${baseUrl}/tidak-ada`);
  const body = await res.json();
  assert.strictEqual(res.status, 404);
  assert.deepStrictEqual(Object.keys(body).sort(), ['data', 'message', 'success']);
  assert.strictEqual(body.success, false);
});

test('Body JSON rusak -> 400', async () => {
  const res = await fetch(`${baseUrl}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{rusak',
  });
  assert.strictEqual(res.status, 400);
});
