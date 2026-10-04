// Membaca konfigurasi dari .env di satu tempat agar mudah dicek.
require('dotenv').config({ quiet: true });

const config = {
  port: Number(process.env.PORT) || 3000,
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  llmProvider: process.env.LLM_PROVIDER || 'gemini',
  geminiApiKey: process.env.GEMINI_API_KEY || '',
  geminiModel: process.env.GEMINI_MODEL || '',
  externalTimeoutMs: Number(process.env.EXTERNAL_TIMEOUT_MS) || 8000,
  demoMode: process.env.DEMO_MODE === 'true',
};

// Gagal cepat jika variabel wajib belum diisi, supaya error-nya jelas.
const required = ['databaseUrl', 'jwtSecret'];
for (const key of required) {
  if (!config[key]) {
    throw new Error(`Konfigurasi "${key}" belum diisi. Cek file .env (lihat .env.example).`);
  }
}

module.exports = config;
