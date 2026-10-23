// Menjalankan semua file di sql/migrations (urut nama). Idempoten dan tidak menghapus data.
//   npm run db:migrate                     -> database di .env (lokal)
//   DATABASE_URL=... npm run db:migrate    -> database lain (mis. Neon)
const fs = require('fs');
const path = require('path');
const { pool } = require('../src/db');

async function run() {
  const target = new URL(process.env.DATABASE_URL || require('../src/config').databaseUrl);
  console.log(`Target database: ${target.hostname}${target.pathname}`);
  const dir = path.join(__dirname, '..', 'sql', 'migrations');
  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()) {
    process.stdout.write(`Menjalankan ${file} ... `);
    await pool.query(fs.readFileSync(path.join(dir, file), 'utf8'));
    console.log('selesai');
  }
}

run()
  .catch((err) => {
    console.error('\nMigrasi gagal:', err.message);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
