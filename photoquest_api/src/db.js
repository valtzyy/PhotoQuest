// Koneksi PostgreSQL memakai connection pool (koneksi dipakai ulang antar request).
const { Pool } = require('pg');
const config = require('./config');

// Untuk Neon/Supabase cukup tambahkan `?sslmode=require` di DATABASE_URL.
const pool = new Pool({ connectionString: config.databaseUrl });

pool.on('error', (err) => {
  console.error('[db] Error pada koneksi idle:', err.message);
});

module.exports = {
  pool,
  // Helper agar route cukup memanggil db.query(sql, params).
  // Selalu pakai parameter ($1, $2, ...) untuk mencegah SQL injection.
  query: (text, params) => pool.query(text, params),
};
