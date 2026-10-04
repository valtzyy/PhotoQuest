// Uji profil (nama & foto), Saran & Kesan, dan riwayat challenge.
const { test, before, after } = require('node:test');
const assert = require('node:assert');

const { startServer, createTestUser, deleteTestUser, db } = require('./helpers');

let server;
let baseUrl;
let me;
let auth;

// PNG 1x1 piksel yang valid (untuk uji upload foto)
const TINY_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64'
);

function uploadPhoto(buffer, type, filename) {
  const form = new FormData();
  form.append('photo', new Blob([buffer], { type }), filename);
  return fetch(`${baseUrl}/users/me/photo`, { method: 'POST', headers: auth, body: form });
}

before(async () => {
  ({ server, baseUrl } = await startServer());
  me = await createTestUser(baseUrl, 'profile');
  auth = { Authorization: `Bearer ${me.token}` };
});

after(async () => {
  await deleteTestUser(me.email);
  server.close();
  await db.pool.end();
});

test('PUT /users/me mengubah nama', async () => {
  const res = await fetch(`${baseUrl}/users/me`, {
    method: 'PUT',
    headers: { ...auth, 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: '  Nama Baru  ' }),
  });
  const body = await res.json();
  assert.strictEqual(res.status, 200);
  assert.strictEqual(body.data.name, 'Nama Baru');
});

test('PUT /users/me menolak nama terlalu pendek', async () => {
  const res = await fetch(`${baseUrl}/users/me`, {
    method: 'PUT',
    headers: { ...auth, 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: 'A' }),
  });
  assert.strictEqual(res.status, 400);
});

test('Upload foto PNG -> photo_url terisi dan foto bisa diambil kembali', async () => {
  const res = await uploadPhoto(TINY_PNG, 'image/png', 'a.png');
  const body = await res.json();
  assert.strictEqual(res.status, 200);
  assert.match(body.data.photo_url, new RegExp(`^/users/${me.user.id}/photo\\?v=\\d+$`));

  const photo = await fetch(`${baseUrl}${body.data.photo_url}`, { headers: auth });
  assert.strictEqual(photo.status, 200);
  assert.strictEqual(photo.headers.get('content-type'), 'image/png');
  assert.deepStrictEqual(Buffer.from(await photo.arrayBuffer()), TINY_PNG);
});

test('Upload file bukan gambar -> 400', async () => {
  const res = await uploadPhoto(Buffer.from('halo'), 'text/plain', 'a.txt');
  assert.strictEqual(res.status, 400);
});

test('Upload foto > 2 MB -> 400 dengan pesan ukuran', async () => {
  const res = await uploadPhoto(Buffer.alloc(2 * 1024 * 1024 + 1), 'image/jpeg', 'big.jpg');
  const body = await res.json();
  assert.strictEqual(res.status, 400);
  assert.match(body.message, /2 MB/);
});

test('Endpoint profil tanpa token -> 401', async () => {
  const res = await fetch(`${baseUrl}/users/me`, { method: 'PUT' });
  assert.strictEqual(res.status, 401);
});

test('Kirim & ambil Saran dan Kesan', async () => {
  const post = await fetch(`${baseUrl}/feedback`, {
    method: 'POST',
    headers: { ...auth, 'Content-Type': 'application/json' },
    body: JSON.stringify({ saran: 'Tambah praktikum', kesan: 'Seru' }),
  });
  assert.strictEqual(post.status, 201);

  const list = await (await fetch(`${baseUrl}/feedback/me`, { headers: auth })).json();
  assert.strictEqual(list.data.length, 1);
  assert.strictEqual(list.data[0].kesan, 'Seru');
});

test('Feedback kosong ditolak -> 400', async () => {
  const res = await fetch(`${baseUrl}/feedback`, {
    method: 'POST',
    headers: { ...auth, 'Content-Type': 'application/json' },
    body: JSON.stringify({ saran: '  ', kesan: 'ok' }),
  });
  assert.strictEqual(res.status, 400);
});

test('GET /challenge -> riwayat (angka sudah berupa number)', async () => {
  await db.query(
    `INSERT INTO challenge_attempts (user_id, success, hold_seconds, avg_tilt, avg_shake)
     VALUES ($1, true, 5.2, 1.25, 0.08)`,
    [me.user.id]
  );
  const body = await (await fetch(`${baseUrl}/challenge`, { headers: auth })).json();
  assert.strictEqual(body.data.length, 1);
  assert.strictEqual(body.data[0].hold_seconds, 5.2);
});
