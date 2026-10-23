// Membaca konfigurasi dari .env di satu tempat agar mudah dicek.
require('dotenv').config({ quiet: true });

/** "a, b,,a" -> ['a', 'b'] (spasi, entri kosong, dan duplikat dibuang). */
const parseList = (value) => [...new Set((value || '').split(',').map((s) => s.trim()).filter(Boolean))];

const config = {
  port: Number(process.env.PORT) || 3000,
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  llmProvider: process.env.LLM_PROVIDER || 'gemini',
  geminiApiKey: process.env.GEMINI_API_KEY || '',
  geminiModel: process.env.GEMINI_MODEL || '',
  // Model cadangan bila GEMINI_MODEL sedang gangguan (503 / timeout / dll.).
  geminiFallbackModels: parseList(process.env.GEMINI_FALLBACK_MODELS),
  externalTimeoutMs: Number(process.env.EXTERNAL_TIMEOUT_MS) || 8000,
  // Anggaran waktu total semua percobaan LLM (model utama + cadangan).
  llmTotalTimeoutMs: Number(process.env.LLM_TOTAL_TIMEOUT_MS) || 12000,
  demoMode: process.env.DEMO_MODE === 'true',
  // Blockchain Ethereum Sepolia (relayer). Semuanya opsional: bila kosong, hasil challenge
  // tetap tersimpan dan status pencatatan on-chain = failed (bisa dicoba ulang).
  // SEPOLIA_RPC_URL dan ETH_PRIVATE_KEY adalah RAHASIA: jangan di-log atau di-commit.
  sepoliaRpcUrl: process.env.SEPOLIA_RPC_URL || '',
  ethPrivateKey: process.env.ETH_PRIVATE_KEY || '',
  chainContractAddress: process.env.CHAIN_CONTRACT_ADDRESS || '',
};

// Gagal cepat jika variabel wajib belum diisi, supaya error-nya jelas.
const required = ['databaseUrl', 'jwtSecret'];
for (const key of required) {
  if (!config[key]) {
    throw new Error(`Konfigurasi "${key}" belum diisi. Cek file .env (lihat .env.example).`);
  }
}

module.exports = config;
