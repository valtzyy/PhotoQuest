// Uji daftar/pencarian/filter spot dan favorit.
// Mengandalkan data seed (18 spot Yogyakarta).
const { test, before, after } = require('node:test');
const assert = require('node:assert');

const { startServer, createTestUser, deleteTestUser, db } = require('./helpers');

let server;
let baseUrl;
let me;
let auth;

async function getJson(path) {
  const res = await fetch(`${baseUrl}${path}`, { headers: auth });
  return { status: res.status, body: await res.json() };
}

before(async () => {
  ({ server, baseUrl } = await startServer());
  me = await createTestUser(baseUrl, 'spots');
  auth = { Authorization: `Bearer ${me.token}` };
});

after(async () => {
  await deleteTestUser(me.email);
  server.close();
  await db.pool.end();
});

test('GET /spots tanpa filter -> semua spot seed, photo_types berupa array', async () => {
  const { status, body } = await getJson('/spots');
  assert.strictEqual(status, 200);
  assert.ok(body.data.length >= 15);
  assert.ok(Array.isArray(body.data[0].photo_types));
  assert.strictEqual(typeof body.data[0].latitude, 'number');
});

test('Search tidak peka huruf besar/kecil, mencari di nama & deskripsi', async () => {
  const byName = await getJson('/spots?search=PRAMBANAN');
  assert.ok(byName.body.data.some((s) => s.name === 'Candi Prambanan'));

  // "UNESCO" hanya ada di deskripsi Prambanan
  const byDesc = await getJson('/spots?search=unesco');
  assert.deepStrictEqual(byDesc.body.data.map((s) => s.name), ['Candi Prambanan']);
});

test('Wildcard % di pencarian dianggap teks biasa (tidak mengembalikan semua)', async () => {
  const { body } = await getJson('/spots?search=%25');
  assert.strictEqual(body.data.length, 0);
});

test('Filter kategori + kombinasi dengan search', async () => {
  const street = await getJson('/spots?category=street');
  assert.ok(street.body.data.length > 0);
  assert.ok(street.body.data.every((s) => s.category === 'street'));

  const combo = await getJson('/spots?category=landscape&search=pantai');
  assert.ok(combo.body.data.every((s) => s.category === 'landscape'));
  assert.ok(combo.body.data.some((s) => s.name === 'Pantai Parangtritis'));
});

test('Kategori tidak valid -> 400', async () => {
  assert.strictEqual((await getJson('/spots?category=selfie')).status, 400);
});

test('GET /spots/:id -> detail, id tidak ada -> 404', async () => {
  const list = await getJson('/spots');
  const first = list.body.data[0];
  const detail = await getJson(`/spots/${first.id}`);
  assert.strictEqual(detail.body.data.name, first.name);
  assert.strictEqual((await getJson('/spots/999999')).status, 404);
});

test('Favorit: tambah (idempoten), daftar, hapus', async () => {
  const { body } = await getJson('/spots?search=tugu');
  const spotId = body.data[0].id;
  const post = () => fetch(`${baseUrl}/favorites`, {
    method: 'POST',
    headers: { ...auth, 'Content-Type': 'application/json' },
    body: JSON.stringify({ spot_id: spotId }),
  });

  assert.strictEqual((await post()).status, 201);
  assert.strictEqual((await post()).status, 201); // kedua kali tidak error

  const favs = await getJson('/favorites');
  assert.deepStrictEqual(favs.body.data.map((s) => s.id), [spotId]);

  const del = await fetch(`${baseUrl}/favorites/${spotId}`, { method: 'DELETE', headers: auth });
  assert.strictEqual((await del.json()).data.removed, true);
  assert.strictEqual((await getJson('/favorites')).body.data.length, 0);
});

test('Favorit spot yang tidak ada -> 404', async () => {
  const res = await fetch(`${baseUrl}/favorites`, {
    method: 'POST',
    headers: { ...auth, 'Content-Type': 'application/json' },
    body: JSON.stringify({ spot_id: 999999 }),
  });
  assert.strictEqual(res.status, 404);
});

test('Spot & favorit tanpa token -> 401', async () => {
  assert.strictEqual((await fetch(`${baseUrl}/spots`)).status, 401);
  assert.strictEqual((await fetch(`${baseUrl}/favorites`)).status, 401);
});
