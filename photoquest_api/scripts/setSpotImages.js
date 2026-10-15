// Mengisi foto asli spot (image_url + image_credit). Aman dijalankan berulang (idempoten),
// tidak menghapus data apa pun, dan menambah kolom image_credit bila belum ada.
//   npm run db:images                     -> database di .env (lokal)
//   DATABASE_URL=... npm run db:images    -> database lain (mis. Neon)
const { SPOT_IMAGES, imageUrl, creditText } = require('../sql/spotImages');

async function applySpotImages(pool) {
  await pool.query('ALTER TABLE spots ADD COLUMN IF NOT EXISTS image_credit TEXT');
  let updated = 0;
  for (const [name, file, artist, license] of SPOT_IMAGES) {
    const res = await pool.query(
      'UPDATE spots SET image_url = $2, image_credit = $3 WHERE name = $1',
      [name, imageUrl(file), creditText(artist, license)]
    );
    updated += res.rowCount;
  }
  return updated;
}

module.exports = { applySpotImages };

if (require.main === module) {
  const { pool } = require('../src/db');
  applySpotImages(pool)
    .then((n) => console.log(`Foto spot diperbarui: ${n} dari ${SPOT_IMAGES.length} spot`))
    .catch((err) => {
      console.error('Gagal mengisi foto spot:', err.message);
      process.exitCode = 1;
    })
    .finally(() => pool.end());
}
