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
async function geminiGenerate({ system, messages, json, temperature, http }) {
  if (!config.geminiApiKey || !config.geminiModel) {
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

  const url = `${GEMINI_BASE}/models/${encodeURIComponent(config.geminiModel)}:generateContent`;
  const res = await http.post(url, body, {
    timeout: config.externalTimeoutMs, // 8 detik
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

/**
 * Hasilkan teks dari LLM.
 * Semua kegagalan (timeout, kuota habis, key salah, respons kosong) dilempar
 * sebagai LlmUnavailableError agar pemanggil bisa memakai fallback.
 */
async function generateText({ system, messages, json = false, temperature = 0.6, http = axios }) {
  const provider = providers[config.llmProvider];
  if (!provider) throw new LlmUnavailableError(`LLM_PROVIDER "${config.llmProvider}" tidak dikenal`);
  try {
    return await provider({ system, messages, json, temperature, http });
  } catch (err) {
    if (err instanceof LlmUnavailableError) throw err;
    const status = err.response?.status;
    const detail = err.response?.data?.error?.message || err.message;
    console.warn(`[llm] gagal (${status ?? err.code ?? 'error'}): ${detail}`);
    throw new LlmUnavailableError(status ? `LLM error ${status}` : 'LLM tidak merespons');
  }
}

module.exports = { generateText, LlmUnavailableError };
