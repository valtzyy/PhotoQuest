// Helper bersama untuk tes: menyalakan server di port acak dan membuat user uji.
const app = require('../src/app');
const db = require('../src/db');

async function startServer() {
  const server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  return { server, baseUrl: `http://127.0.0.1:${server.address().port}` };
}

// Mendaftarkan user baru lewat API dan mengembalikan { email, token, user }.
async function createTestUser(baseUrl, prefix = 'test') {
  const email = `${prefix}_${Date.now()}_${Math.floor(Math.random() * 1e6)}@photoquest.test`;
  const res = await fetch(`${baseUrl}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: 'Tester', email, password: 'rahasia123' }),
  });
  const body = await res.json();
  return { email, token: body.data.token, user: body.data.user };
}

async function deleteTestUser(email) {
  await db.query('DELETE FROM users WHERE email = $1', [email]);
}

module.exports = { startServer, createTestUser, deleteTestUser, db };
