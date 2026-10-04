// Titik masuk server: menjalankan aplikasi Express di PORT dari .env.
const config = require('./config');
const app = require('./app');

// 0.0.0.0 agar server bisa diakses dari HP di jaringan Wi-Fi yang sama (bukan hanya localhost).
app.listen(config.port, '0.0.0.0', () => {
  console.log(`PhotoQuest API berjalan di http://0.0.0.0:${config.port}`);
  console.log(`DEMO_MODE = ${config.demoMode}`);
});
