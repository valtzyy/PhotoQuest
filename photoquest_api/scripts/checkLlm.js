// Cek konfigurasi Gemini: daftar model yang tersedia untuk API key di .env,
// lalu uji GEMINI_MODEL dengan satu pesan singkat.
// Jalankan: npm run llm:check   (API key TIDAK pernah ditampilkan)
const axios = require('axios');
const config = require('../src/config');
const { generateText } = require('../src/services/llmService');

async function main() {
  if (!config.geminiApiKey) {
    console.log('GEMINI_API_KEY kosong di .env -> fitur AI memakai template fallback.');
    return;
  }
  console.log(`GEMINI_API_KEY terisi (${config.geminiApiKey.length} karakter).`);

  try {
    const res = await axios.get('https://generativelanguage.googleapis.com/v1beta/models', {
      params: { pageSize: 200 },
      headers: { 'x-goog-api-key': config.geminiApiKey },
      timeout: 10000,
    });
    const names = (res.data.models || [])
      .filter((m) => (m.supportedGenerationMethods || []).includes('generateContent'))
      .map((m) => m.name.replace('models/', ''))
      .filter((n) => n.startsWith('gemini'));
    console.log('\nModel gemini yang mendukung generateContent untuk key ini:');
    names.forEach((n) => console.log(`  - ${n}`));
  } catch (err) {
    const status = err.response?.status;
    console.log(`\nGagal mengambil daftar model (${status ?? err.code}): ${err.response?.data?.error?.message || err.message}`);
    if (status === 400 || status === 403) console.log('-> Periksa kembali GEMINI_API_KEY.');
    return;
  }

  if (!config.geminiModel) {
    console.log('\nGEMINI_MODEL masih kosong. Pilih salah satu nama di atas lalu isi di .env.');
    return;
  }

  console.log(`\nMenguji GEMINI_MODEL = ${config.geminiModel} ...`);
  const started = Date.now();
  try {
    const reply = await generateText({
      system: 'Jawab dalam bahasa Indonesia, maksimal 1 kalimat.',
      messages: [{ role: 'user', text: 'Apa itu golden hour dalam fotografi?' }],
    });
    console.log(`OK (${Date.now() - started} ms): ${reply}`);
  } catch (err) {
    console.log(`GAGAL (${Date.now() - started} ms): ${err.message}`);
    console.log('-> Coba model lain dari daftar di atas, atau cek kuota di Google AI Studio.');
  }
}

main();
