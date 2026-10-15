// Lapisan LLM: route hanya memanggil generateText(), tidak tahu provider apa yang dipakai.
// Untuk mengganti provider (mis. Groq), tambahkan fungsi baru di `providers`
// lalu ubah LLM_PROVIDER di .env. Route tidak perlu diubah.
const axios = require('axios');
const config = require('../config');

const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta';

/** Error khusus agar route bisa membalas "Assistant sedang tidak tersedia". */
class LlmUnavailableError extends Error {
  constructor(message) {
    super(message);
    this.name = 'LlmUnavailableError';
  }
}

/**
 * Provider Gemini (REST models.generateContent).
 * messages: [{ role: 'user' | 'assistant', text }]
 */
async function geminiGenerate({ system, messages, json, temperature, http, model, timeout }) {
  if (!config.geminiApiKey || !model) {
    throw new LlmUnavailableError('GEMINI_API_KEY / GEMINI_MODEL belum diisi di .env');
  }

  const body = {
    systemInstruction: { parts: [{ text: system }] },
    // Gemini memakai role "model" untuk jawaban asisten.
    contents: messages.map((m) => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: m.text }],
    })),
    generationConfig: {
      temperature,
      maxOutputTokens: 2048,
      // Minta keluaran JSON murni (dipakai untuk rekomendasi terstruktur).
      ...(json ? { responseMimeType: 'application/json' } : {}),
    },
  };

  const url = `${GEMINI_BASE}/models/${encodeURIComponent(model)}:generateContent`;
  const res = await http.post(url, body, {
    timeout, // maks. EXTERNAL_TIMEOUT_MS, dibatasi sisa anggaran total
    // API key dikirim lewat header, tidak di URL (agar tidak tercatat di log).
    headers: { 'x-goog-api-key': config.geminiApiKey, 'Content-Type': 'application/json' },
  });

  const parts = res.data?.candidates?.[0]?.content?.parts ?? [];
  const text = parts.map((p) => p.text ?? '').join('').trim();
  if (!text) {
    const reason = res.data?.candidates?.[0]?.finishReason || res.data?.promptFeedback?.blockReason;
    throw new LlmUnavailableError(`Respons LLM kosong${reason ? ` (${reason})` : ''}`);
  }
  return text;
}

const providers = {
  gemini: geminiGenerate,
};

/** Percobaan model cadangan butuh sisa waktu minimal ini agar masuk akal. */
const MIN_ATTEMPT_MS = 1500;

/** Urutan model: GEMINI_MODEL lalu GEMINI_FALLBACK_MODELS (tanpa duplikat/kosong). */
function modelChain() {
  return [...new Set([config.geminiModel, ...config.geminiFallbackModels].filter(Boolean))];
}

/**
 * Gangguan sementara di sisi model -> layak mencoba model lain:
 * timeout/jaringan (tanpa respons), 404 model tidak tersedia, 408, 429 kuota, 5xx.
 * 400/401/403 (permintaan/key salah) akan sama di semua model -> tidak.
 */
function isTransient(err) {
  const status = err.response?.status;
  if (!status) return true;
  return status === 404 || status === 408 || status === 429 || status >= 500;
}

/**
 * Hasilkan teks dari LLM. Bila model utama gangguan sementara, coba model
 * cadangan berikutnya selama anggaran waktu total ([budgetMs]) masih cukup.
 * Semua kegagalan (timeout, kuota habis, key salah, respons kosong) dilempar
 * sebagai LlmUnavailableError agar pemanggil bisa memakai fallback.
 */
async function generateText({
  system,
  messages,
  json = false,
  temperature = 0.6,
  http = axios,
  budgetMs = config.llmTotalTimeoutMs,
  attemptMs = config.externalTimeoutMs, // batas per percobaan model
  now = Date.now,
}) {
  const provider = providers[config.llmProvider];
  if (!provider) throw new LlmUnavailableError(`LLM_PROVIDER "${config.llmProvider}" tidak dikenal`);

  const models = modelChain();
  const deadline = now() + budgetMs;
  let lastError;
  // Minimal satu percobaan; tanpa model, provider melempar error konfigurasi.
  for (let i = 0; i < Math.max(models.length, 1); i++) {
    const model = models[i];
    const remaining = deadline - now();
    if (i > 0 && remaining < MIN_ATTEMPT_MS) {
      console.warn(`[llm] anggaran waktu habis, ${model} tidak dicoba`);
      break;
    }
    try {
      const text = await provider({
        system, messages, json, temperature, http, model,
        timeout: Math.min(attemptMs, remaining),
      });
      if (i > 0) console.info(`[llm] dijawab oleh model cadangan ${model}`);
      return text;
    } catch (err) {
      if (err instanceof LlmUnavailableError) throw err;
      const status = err.response?.status;
      const detail = err.response?.data?.error?.message || err.message;
      const next = isTransient(err) ? models[i + 1] : undefined;
      console.warn(`[llm] gagal (${status ?? err.code ?? 'error'}) ${model}: ${detail}${next ? ` → coba ${next}` : ''}`);
      lastError = new LlmUnavailableError(status ? `LLM error ${status}` : 'LLM tidak merespons');
      if (!next) break;
    }
  }
  throw lastError;
}

module.exports = { generateText, LlmUnavailableError };
