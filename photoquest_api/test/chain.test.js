// Uji blockchain sederhana: hash, proof-of-work, verifikasi, challenge -> blok, demo tamper.
process.env.DEMO_MODE = 'true'; // aktifkan endpoint demo untuk tes (sebelum config dimuat)

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');

const chain = require('../src/services/chainService');
const { startServer, createTestUser, deleteTestUser, db } = require('./helpers');

describe('Unit: hash & verifikasi (tanpa database)', () => {
  const genesis = chain.mine({ block_index: 0, timestamp: '2026-10-06T00:00:00.000Z', data: { m: 'g' }, prev_hash: '0' });
  const b1 = chain.mine({ block_index: 1, timestamp: '2026-10-06T00:01:00.000Z', data: { a: 1, b: [2, { y: 1, x: 0 }] }, prev_hash: genesis.hash });
  const b2 = chain.mine({ block_index: 2, timestamp: '2026-10-06T00:02:00.000Z', data: { a: 2 }, prev_hash: b1.hash });

  test('JSON kanonik: urutan key tidak memengaruhi hasil', () => {
    assert.strictEqual(chain.canonicalJson({ b: 1, a: { d: 2, c: 3 } }), '{"a":{"c":3,"d":2},"b":1}');
    assert.strictEqual(chain.canonicalJson({ x: 1, y: 2 }), chain.canonicalJson({ y: 2, x: 1 }));
  });

  test('Hash SHA-256 64 karakter hex, deterministik, & memenuhi proof-of-work "00"', () => {
    assert.match(b1.hash, /^00[0-9a-f]{62}$/);
    assert.strictEqual(chain.computeHash(b1), b1.hash);
  });

  test('Chain utuh -> valid', () => {
    assert.deepStrictEqual(chain.verifyBlocks([genesis, b1, b2]), { valid: true, broken_at: null, reason: null });
  });

  test('Key data disusun ulang (seperti JSONB) -> tetap valid', () => {
    const reordered = { ...b1, data: { b: [2, { x: 0, y: 1 }], a: 1 } };
    assert.strictEqual(chain.verifyBlocks([genesis, reordered, b2]).valid, true);
  });

  test('Data diubah tanpa hitung ulang hash -> invalid di blok tersebut', () => {
    const forged = { ...b1, data: { ...b1.data, a: 999 } };
    const r = chain.verifyBlocks([genesis, forged, b2]);
    assert.strictEqual(r.valid, false);
    assert.strictEqual(r.broken_at, 1);
  });

  test('Hash dihitung ulang setelah data diubah -> blok berikutnya putus (prev_hash)', () => {
    const remined = chain.mine({ ...b1, data: { a: 999 } });
    const r = chain.verifyBlocks([genesis, remined, b2]);
    assert.strictEqual(r.valid, false);
    assert.strictEqual(r.broken_at, 2);
  });
});

describe('Integrasi: /challenge & /chain', () => {
  let server;
  let baseUrl;
  let me;
  let auth;

  before(async () => {
    ({ server, baseUrl } = await startServer());
    me = await createTestUser(baseUrl, 'chain');
    auth = { Authorization: `Bearer ${me.token}`, 'Content-Type': 'application/json' };
    await chain.repairDemo(); // mulai dari kondisi bersih
  });

  after(async () => {
    await chain.repairDemo();
    // Hapus blok milik user uji (selalu di ujung chain) agar chain dev tetap bersih.
    await db.query("DELETE FROM chain_blocks WHERE (data->>'user_id')::int = $1", [me.user.id]);
    await deleteTestUser(me.email);
    server.close();
    await db.pool.end();
  });

  const post = async (path, body) => {
    const res = await fetch(`${baseUrl}${path}`, { method: 'POST', headers: auth, body: JSON.stringify(body ?? {}) });
    return { status: res.status, body: await res.json() };
  };
  const get = async (path) => (await fetch(`${baseUrl}${path}`, { headers: auth })).json();

  test('Challenge gagal -> disimpan, tanpa blok', async () => {
    const r = await post('/challenge', { success: false, hold_seconds: 2.4, avg_tilt: 3.1, avg_shake: 0.4 });
    assert.strictEqual(r.status, 201);
    assert.strictEqual(r.body.data.block, null);
  });

  test('Challenge berhasil -> blok baru di ujung chain, chain tetap valid', async () => {
    const before = (await get('/chain')).data.blocks.length;
    const r = await post('/challenge', { success: true, hold_seconds: 5.04, avg_tilt: 1.2345, avg_shake: 0.0789 });
    assert.strictEqual(r.status, 201);
    const { blocks } = (await get('/chain')).data;
    assert.strictEqual(blocks.length, before + 1);
    const last = blocks.at(-1);
    assert.strictEqual(last.block_index, r.body.data.block.block_index);
    assert.strictEqual(last.data.user_id, me.user.id);
    assert.strictEqual(last.prev_hash, blocks.at(-2).hash);
    assert.strictEqual((await get('/chain/verify')).data.valid, true);
  });

  test('Validasi: menang tapi hold < 5 detik / angka tidak valid -> 400', async () => {
    assert.strictEqual((await post('/challenge', { success: true, hold_seconds: 3, avg_tilt: 1, avg_shake: 0.1 })).status, 400);
    assert.strictEqual((await post('/challenge', { success: 'ya', hold_seconds: 3, avg_tilt: 1, avg_shake: 0.1 })).status, 400);
    assert.strictEqual((await post('/challenge', { success: false, hold_seconds: 25, avg_tilt: 1, avg_shake: 0.1 })).status, 400);
  });

  test('Demo manipulasi -> INVALID di blok terakhir, pulihkan -> VALID', async () => {
    const lastIndex = (await get('/chain')).data.blocks.at(-1).block_index;
    const t = await post('/chain/tamper-demo');
    assert.strictEqual(t.body.data.tampered_block, lastIndex);

    const broken = (await get('/chain/verify')).data;
    assert.strictEqual(broken.valid, false);
    assert.strictEqual(broken.broken_at, lastIndex);

    await post('/chain/repair-demo');
    assert.strictEqual((await get('/chain/verify')).data.valid, true);
  });

  test('GET /chain menyertakan demo_mode & difficulty', async () => {
    const data = (await get('/chain')).data;
    assert.strictEqual(data.demo_mode, true);
    assert.strictEqual(data.difficulty, 2);
    assert.strictEqual(data.blocks[0].block_index, 0);
    assert.strictEqual(data.blocks[0].prev_hash, '0');
  });
});
