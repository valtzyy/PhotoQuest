// Uji blockchain Sepolia: hash data, alur pencatatan (pending -> confirmed/failed), verifikasi
// terhadap data on-chain, retry, dan demo manipulasi. Memakai KLIEN PALSU: tidak memanggil
// jaringan sungguhan.
process.env.DEMO_MODE = 'true'; // aktifkan endpoint demo untuk tes (sebelum config dimuat)

const { test, describe, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');

const config = require('../src/config');
const chain = require('../src/services/chainService');
const { startServer, createTestUser, deleteTestUser, db } = require('./helpers');

const CONTRACT = '0x1234567890abcdef1234567890abcdef12345678';

/** Klien palsu: meniru kontrak ChallengeRegistry di memori, transaksi baru "dimining" lewat mineAll(). */
function createFakeClient() {
  const f = {
    configured: true,
    info: { chainId: 11155111, contractAddress: CONTRACT },
    records: [],
    txs: new Map(),
    failSend: null,
    down: false,
    sent: 0,
    async send(v) {
      if (f.failSend) throw new Error(f.failSend);
      f.sent += 1;
      const hash = `0x${f.sent.toString(16).padStart(64, '0')}`;
      f.txs.set(hash, { v, mined: false, status: 1 });
      return { hash };
    },
    async getReceipt(hash) {
      if (f.down) throw new chain.ChainUnavailableError('RPC mati');
      const t = f.txs.get(hash);
      if (!t || !t.mined) return null;
      return { status: t.status, blockNumber: t.block, index: t.index };
    },
    async getRecord(index) {
      if (f.down) throw new chain.ChainUnavailableError('RPC mati');
      const r = f.records[index];
      if (!r) throw new Error('IndexOutOfRange');
      return r;
    },
    mineAll({ status = 1 } = {}) {
      for (const t of f.txs.values()) {
        if (t.mined) continue;
        t.mined = true;
        t.status = status;
        t.index = f.records.length;
        t.block = 5000000 + f.records.length;
        if (status === 1) f.records.push({ ...t.v, dataHash: t.v.dataHash.toLowerCase() });
      }
    },
  };
  return f;
}

describe('Unit: data kanonik & hash (tanpa database/jaringan)', () => {
  test('JSON kanonik: urutan key tidak memengaruhi hasil', () => {
    assert.strictEqual(chain.canonicalJson({ b: 1, a: { d: 2, c: 3 } }), '{"a":{"c":3,"d":2},"b":1}');
    assert.strictEqual(chain.canonicalJson({ x: 1, y: 2 }), chain.canonicalJson({ y: 2, x: 1 }));
  });

  test('toChainValues: desimal menjadi integer (x100 / x1000)', () => {
    const v = chain.toChainValues({ id: 7, user_id: 3, hold_seconds: '5.20', avg_tilt: '1.250', avg_shake: '0.080' });
    assert.deepStrictEqual(v, { attemptId: 7, userId: 3, hold: 520, tilt: 1250, shake: 80 });
  });

  test('keccak256: 0x + 64 hex, deterministik, berubah bila satu angka berubah', () => {
    const v = { attemptId: 1, userId: 2, hold: 520, tilt: 1250, shake: 80 };
    const h = chain.computeDataHash(v);
    assert.match(h, /^0x[0-9a-f]{64}$/);
    assert.strictEqual(chain.computeDataHash({ ...v }), h);
    assert.notStrictEqual(chain.computeDataHash({ ...v, hold: 521 }), h);
  });

  test('sanitizeError membuang URL RPC dan private key', () => {
    const oldUrl = config.sepoliaRpcUrl;
    const oldKey = config.ethPrivateKey;
    config.sepoliaRpcUrl = 'https://eth-sepolia.example/v2/KUNCI-RAHASIA';
    config.ethPrivateKey = '0xabc123rahasia';
    try {
      const msg = chain.sanitizeError(new Error(`gagal ke ${config.sepoliaRpcUrl} memakai ${config.ethPrivateKey}`));
      assert.ok(!msg.includes('KUNCI-RAHASIA'));
      assert.ok(!msg.includes('abc123rahasia'));
      assert.ok(msg.length <= 200);
    } finally {
      config.sepoliaRpcUrl = oldUrl;
      config.ethPrivateKey = oldKey;
    }
  });

  test('Klien tanpa konfigurasi: configured=false dan send ditolak dengan pesan jelas', async () => {
    const c = chain.createEthersClient({ rpcUrl: '', privateKey: '', contractAddress: '' });
    assert.strictEqual(c.configured, false);
    await assert.rejects(() => c.send({}), (e) => e instanceof chain.ChainUnavailableError && /SEPOLIA_RPC_URL/.test(e.message));
  });
});

describe('Integrasi: /challenge dan /chain (klien palsu)', () => {
  let server;
  let baseUrl;
  let me;
  let auth;
  let fake;

  before(async () => {
    ({ server, baseUrl } = await startServer());
    me = await createTestUser(baseUrl, 'chain');
    auth = { Authorization: `Bearer ${me.token}`, 'Content-Type': 'application/json' };
    chain.setRefreshInterval(0);
  });

  beforeEach(async () => {
    fake = createFakeClient();
    chain.setClient(fake);
    await chain.repairDemo();
    // Mulai bersih: hapus percobaan milik user uji (agar tes saling independen).
    await db.query('DELETE FROM challenge_attempts WHERE user_id = $1', [me.user.id]);
  });

  after(async () => {
    await chain.repairDemo();
    await deleteTestUser(me.email);
    server.close();
    await db.pool.end();
  });

  const post = async (path, body) => {
    const res = await fetch(`${baseUrl}${path}`, { method: 'POST', headers: auth, body: JSON.stringify(body ?? {}) });
    return { status: res.status, body: await res.json() };
  };
  const get = async (path) => {
    const res = await fetch(`${baseUrl}${path}`, { headers: auth });
    return { status: res.status, body: await res.json() };
  };
  const win = (extra = {}) => ({ success: true, hold_seconds: 5.04, avg_tilt: 1.2345, avg_shake: 0.0789, ...extra });
  const mine = (id) => get('/chain').then((r) => r.body.data.records.find((x) => x.attempt_id === id));

  test('Challenge gagal -> tersimpan, tidak masuk blockchain', async () => {
    const r = await post('/challenge', { success: false, hold_seconds: 2.4, avg_tilt: 3.1, avg_shake: 0.4 });
    assert.strictEqual(r.status, 201);
    assert.strictEqual(r.body.data.chain, null);
    await chain.idle();
    assert.strictEqual(fake.sent, 0);
    assert.strictEqual(await mine(r.body.data.attempt.id), undefined);
  });

  test('Challenge berhasil: balasan cepat berstatus pending, transaksi dikirim di latar belakang', async () => {
    fake.send = async () => {
      await new Promise((resolve) => setTimeout(resolve, 400)); // meniru latensi jaringan
      return { hash: `0x${'a'.repeat(64)}` };
    };
    const t0 = Date.now();
    const r = await post('/challenge', win());
    assert.ok(Date.now() - t0 < 350, 'balasan tidak boleh menunggu transaksi');
    assert.strictEqual(r.status, 201);
    assert.strictEqual(r.body.data.chain.status, 'pending');
    const id = r.body.data.attempt.id;
    const { rows: before } = await db.query('SELECT tx_status, tx_hash FROM challenge_attempts WHERE id = $1', [id]);
    assert.strictEqual(before[0].tx_status, 'pending');
    assert.strictEqual(before[0].tx_hash, null);
    await chain.idle();
    const { rows: after } = await db.query('SELECT tx_status, tx_hash FROM challenge_attempts WHERE id = $1', [id]);
    assert.strictEqual(after[0].tx_status, 'pending');
    assert.strictEqual(after[0].tx_hash, `0x${'a'.repeat(64)}`);
  });

  test('Alur penuh: pending -> confirmed (GET /chain) -> verify VALID', async () => {
    const r = await post('/challenge', win());
    const id = r.body.data.attempt.id;
    await chain.idle();

    let rec = await mine(id);
    assert.strictEqual(rec.status, 'pending');
    assert.match(rec.tx_hash, /^0x[0-9a-f]{64}$/);
    assert.strictEqual(rec.explorer_url, `https://sepolia.etherscan.io/tx/${rec.tx_hash}`);
    assert.strictEqual(rec.chain_index, null);

    fake.mineAll();
    rec = await mine(id); // GET /chain memperbarui status dari "Sepolia"
    assert.strictEqual(rec.status, 'confirmed');
    assert.strictEqual(rec.chain_index, 0);
    assert.strictEqual(rec.block_number, 5000000);
    assert.ok(rec.confirmed_at);
    assert.strictEqual(rec.hold_seconds, 5.04);

    const v = (await get('/chain/verify')).body.data;
    assert.strictEqual(v.valid, true);
    assert.strictEqual(v.checked, 1);
    assert.deepStrictEqual(v.mismatches, []);
  });

  test('GET /chain menyertakan info jaringan, kontrak, dan demo_mode', async () => {
    const d = (await get('/chain')).body.data;
    assert.strictEqual(d.network, 'sepolia');
    assert.strictEqual(d.chain_id, 11155111);
    assert.strictEqual(d.configured, true);
    assert.strictEqual(d.contract_address, CONTRACT);
    assert.strictEqual(d.contract_url, `https://sepolia.etherscan.io/address/${CONTRACT}`);
    assert.strictEqual(d.demo_mode, true);
    assert.ok(Array.isArray(d.records));
  });

  test('Kirim gagal (saldo/RPC) -> hasil TETAP tersimpan, status failed; retry berhasil', async () => {
    fake.failSend = 'insufficient funds for gas';
    const r = await post('/challenge', win());
    assert.strictEqual(r.status, 201);
    const id = r.body.data.attempt.id;
    await chain.idle();

    let rec = await mine(id);
    assert.strictEqual(rec.status, 'failed');
    assert.match(rec.error, /insufficient funds/);
    const hist = (await get('/challenge')).body.data;
    assert.ok(hist.some((h) => h.id === id), 'riwayat Profil tetap memuat percobaan');

    fake.failSend = null;
    const retried = await post('/chain/retry');
    assert.strictEqual(retried.body.data.queued, 1);
    await chain.idle();
    rec = await mine(id);
    assert.strictEqual(rec.status, 'pending');
    fake.mineAll();
    assert.strictEqual((await mine(id)).status, 'confirmed');
  });

  test('Blockchain belum dikonfigurasi -> status failed dengan alasan, tidak error', async () => {
    chain.setClient(chain.createEthersClient({ rpcUrl: '', privateKey: '', contractAddress: '' }));
    const r = await post('/challenge', win());
    assert.strictEqual(r.status, 201);
    await chain.idle();
    const rec = await mine(r.body.data.attempt.id);
    assert.strictEqual(rec.status, 'failed');
    assert.match(rec.error, /belum dikonfigurasi/);
    assert.strictEqual((await get('/chain')).body.data.configured, false);
  });

  test('Transaksi ditolak kontrak (reverted) -> failed', async () => {
    const r = await post('/challenge', win());
    await chain.idle();
    fake.mineAll({ status: 0 });
    const rec = await mine(r.body.data.attempt.id);
    assert.strictEqual(rec.status, 'failed');
    assert.match(rec.error, /reverted/);
  });

  test('Pending tanpa receipt > 30 menit -> failed (bisa di-retry)', async () => {
    const r = await post('/challenge', win());
    const id = r.body.data.attempt.id;
    await chain.idle();
    await db.query("UPDATE challenge_attempts SET tx_sent_at = NOW() - INTERVAL '31 minutes' WHERE id = $1", [id]);
    const rec = await mine(id);
    assert.strictEqual(rec.status, 'failed');
    assert.match(rec.error, /30 menit/);
  });

  test('Pending macet tanpa tx_hash (server mati saat kirim) dikirim ulang otomatis', async () => {
    const r = await post('/challenge', win());
    const id = r.body.data.attempt.id;
    await chain.idle();
    await db.query(
      "UPDATE challenge_attempts SET tx_hash = NULL, tx_sent_at = NULL, created_at = NOW() - INTERVAL '5 minutes' WHERE id = $1",
      [id]
    );
    const sentBefore = fake.sent;
    await chain.refreshPending({ force: true });
    await chain.idle();
    assert.strictEqual(fake.sent, sentBefore + 1);
    assert.match((await mine(id)).tx_hash, /^0x[0-9a-f]{64}$/);
  });

  test('RPC mati saat GET /chain -> tetap 200, status pending dipertahankan', async () => {
    const r = await post('/challenge', win());
    await chain.idle();
    fake.mineAll();
    fake.down = true;
    const res = await get('/chain');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.records.find((x) => x.attempt_id === r.body.data.attempt.id).status, 'pending');
  });

  test('Demo manipulasi: ubah data di DATABASE -> verify INVALID; pulihkan -> VALID', async () => {
    const r = await post('/challenge', win());
    const id = r.body.data.attempt.id;
    await chain.idle();
    fake.mineAll();
    await get('/chain');

    const t = await post('/chain/tamper-demo');
    assert.strictEqual(t.status, 200);
    assert.strictEqual(t.body.data.tampered_attempt, id);
    assert.strictEqual((await mine(id)).tampered, true);

    const broken = (await get('/chain/verify')).body.data;
    assert.strictEqual(broken.valid, false);
    assert.strictEqual(broken.mismatches.length, 1);
    assert.strictEqual(broken.mismatches[0].attempt_id, id);
    assert.match(broken.mismatches[0].reason, /hold_seconds berbeda \(database 19\.99, on-chain 5\.04\)/);
    assert.match(broken.mismatches[0].reason, /data_hash tidak cocok/);
    assert.strictEqual(fake.records[0].hold, 504, 'catatan on-chain tidak berubah');

    assert.strictEqual((await post('/chain/tamper-demo')).status, 409); // sudah dimanipulasi

    const fixed = await post('/chain/repair-demo');
    assert.deepStrictEqual(fixed.body.data.repaired_attempts, [id]);
    assert.strictEqual((await get('/chain/verify')).body.data.valid, true);
  });

  test('Verify: Sepolia tidak dapat dihubungi -> 503', async () => {
    await post('/challenge', win());
    await chain.idle();
    fake.mineAll();
    await get('/chain');
    fake.down = true;
    assert.strictEqual((await get('/chain/verify')).status, 503);
  });

  test('Endpoint demo -> 403 bila DEMO_MODE=false', async () => {
    config.demoMode = false;
    try {
      assert.strictEqual((await post('/chain/tamper-demo')).status, 403);
      assert.strictEqual((await post('/chain/repair-demo')).status, 403);
    } finally {
      config.demoMode = true;
    }
  });

  test('Validasi: menang tapi hold < 5 detik / angka tidak valid -> 400', async () => {
    assert.strictEqual((await post('/challenge', { success: true, hold_seconds: 3, avg_tilt: 1, avg_shake: 0.1 })).status, 400);
    assert.strictEqual((await post('/challenge', { success: 'ya', hold_seconds: 3, avg_tilt: 1, avg_shake: 0.1 })).status, 400);
    assert.strictEqual((await post('/challenge', { success: false, hold_seconds: 25, avg_tilt: 1, avg_shake: 0.1 })).status, 400);
  });

  test('Endpoint chain tanpa token -> 401', async () => {
    for (const path of ['/chain', '/chain/verify']) {
      assert.strictEqual((await fetch(`${baseUrl}${path}`)).status, 401);
    }
    assert.strictEqual((await fetch(`${baseUrl}/chain/retry`, { method: 'POST' })).status, 401);
  });
});
