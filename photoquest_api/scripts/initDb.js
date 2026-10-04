// Menjalankan sql/schema.sql lalu sql/seed.sql ke database di DATABASE_URL.
// Dipakai untuk DB lokal maupun Neon (tidak butuh psql terpasang).
// PERINGATAN: schema.sql menghapus (DROP) semua tabel lalu membuat ulang.
const fs = require('fs');
const path = require('path');
const { pool } = require('../src/db');

async function run() {
  const sqlDir = path.join(__dirname, '..', 'sql');
  for (const file of ['schema.sql', 'seed.sql']) {
    const sql = fs.readFileSync(path.join(sqlDir, file), 'utf8');
    process.stdout.write(`Menjalankan ${file} ... `);
    await pool.query(sql);
    console.log('selesai');
  }
  const { rows } = await pool.query(
    `SELECT (SELECT COUNT(*) FROM users)      AS users,
            (SELECT COUNT(*) FROM spots)      AS spots,
            (SELECT COUNT(*) FROM gear_items) AS gear_items`
  );
  console.log('Jumlah data:', rows[0]);
}

run()
  .catch((err) => {
    console.error('\nGagal inisialisasi database:', err.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
