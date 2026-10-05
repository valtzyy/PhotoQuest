// Rekomendasi pemotretan terstruktur dari LLM, dengan fallback template.
//
// Format WAJIB:
// { "composition": [string], "timing": string, "position": string,
//   "stability": string, "tips": [string] }
const { generateText, LlmUnavailableError } = require('./llmService');

// Template per jenis foto (dipakai jika LLM gagal / timeout / JSON rusak).
const TEMPLATES = {
  landscape: {
    composition: [
      'Terapkan rule of thirds: letakkan horizon di garis 1/3 atas atau bawah.',
      'Tambahkan foreground (batu, pohon, pagar) agar foto punya kedalaman.',
      'Cari leading lines seperti jalan setapak atau garis pantai.',
    ],
    timing: 'Datang 30 menit sebelum golden hour untuk mencari posisi dan memotret saat cahaya paling hangat.',
    position: 'Ambil posisi sedikit lebih tinggi agar lanskap terlihat luas, hindari memotret melawan matahari langsung.',
    stability: 'Gunakan tripod atau letakkan HP pada permukaan datar; pakai timer 2 detik.',
    tips: ['Kunci fokus & eksposur (AE/AF lock) pada area langit.', 'Coba mode HDR saat kontras tinggi.'],
  },
  sunset: {
    composition: [
      'Letakkan matahari di titik pertemuan garis rule of thirds, bukan di tengah.',
      'Gunakan siluet objek (orang, candi, pohon) sebagai elemen utama.',
      'Sisakan ruang langit yang luas jika awan berwarna.',
    ],
    timing: 'Mulai memotret 20 menit sebelum matahari terbenam dan lanjutkan hingga 15 menit sesudahnya (blue hour).',
    position: 'Posisikan diri menghadap barat dengan objek siluet di antara Anda dan matahari.',
    stability: 'Cahaya makin redup, gunakan tripod dan timer agar foto tidak blur.',
    tips: ['Turunkan eksposur sedikit agar warna langit lebih pekat.', 'Jangan menatap matahari langsung lewat lensa.'],
  },
  street: {
    composition: [
      'Cari momen manusia yang bercerita (pedagang, becak, interaksi).',
      'Gunakan bingkai alami seperti pintu, jendela, atau gang.',
      'Perhatikan latar belakang agar tidak terlalu ramai.',
    ],
    timing: 'Pagi atau sore hari memberi bayangan panjang dan suasana yang hidup.',
    position: 'Berdiri di tepi keramaian, siap memotret dari setinggi pinggang agar tidak mencolok.',
    stability: 'Gunakan shutter cepat dan mode burst untuk subjek yang bergerak.',
    tips: ['Minta izin bila memotret wajah dari dekat.', 'Aktifkan grid kamera untuk menjaga garis lurus.'],
  },
  architecture: {
    composition: [
      'Jaga garis vertikal tetap lurus (gunakan grid kamera).',
      'Manfaatkan simetri bangunan dengan posisi tepat di tengah.',
      'Potret detail ornamen sebagai variasi selain foto keseluruhan.',
    ],
    timing: 'Golden hour membuat tekstur bangunan menonjol; blue hour cocok jika lampu bangunan menyala.',
    position: 'Mundur cukup jauh dan pakai lensa lebar agar bangunan tidak terpotong.',
    stability: 'Gunakan Level di PhotoQuest agar HP tidak miring (|roll| ≤ 2°).',
    tips: ['Hindari distorsi dengan tidak terlalu menengadahkan HP.', 'Datang saat sepi agar bangunan bersih dari kerumunan.'],
  },
  portrait: {
    composition: [
      'Letakkan mata subjek di garis 1/3 atas frame.',
      'Gunakan latar belakang sederhana agar subjek menonjol.',
      'Beri ruang di arah pandangan subjek (lead room).',
    ],
    timing: 'Cahaya golden hour atau langit berawan memberi cahaya lembut pada wajah.',
    position: 'Posisikan subjek membelakangi matahari rendah untuk rim light, atau di area teduh terbuka.',
    stability: 'Pegang HP dengan dua tangan dan rapatkan siku ke badan.',
    tips: ['Gunakan mode Potret untuk efek bokeh.', 'Fokus pada mata subjek.'],
  },
};

/** Ambil JSON dari teks LLM (kadang dibungkus ```json ... ```). */
function extractJson(text) {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const raw = fenced ? fenced[1] : text;
  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start === -1 || end <= start) throw new Error('JSON tidak ditemukan');
  return JSON.parse(raw.slice(start, end + 1));
}

const isNonEmptyString = (v) => typeof v === 'string' && v.trim().length > 0;

/**
 * Validasi & rapikan rekomendasi. Melempar Error jika bentuknya tidak sesuai.
 */
function validateRecommendation(obj) {
  if (!obj || typeof obj !== 'object' || Array.isArray(obj)) throw new Error('Bukan objek');
  const cleanList = (list, name) => {
    if (!Array.isArray(list)) throw new Error(`${name} harus array`);
    const items = list.filter(isNonEmptyString).map((s) => s.trim().slice(0, 300)).slice(0, 5);
    if (items.length === 0) throw new Error(`${name} kosong`);
    return items;
  };
  const cleanText = (v, name) => {
    if (!isNonEmptyString(v)) throw new Error(`${name} harus teks`);
    return v.trim().slice(0, 400);
  };
  return {
    composition: cleanList(obj.composition, 'composition'),
    timing: cleanText(obj.timing, 'timing'),
    position: cleanText(obj.position, 'position'),
    stability: cleanText(obj.stability, 'stability'),
    tips: cleanList(obj.tips, 'tips'),
  };
}

function buildPrompt({ spot, photoType, plannedAtText, score, label, conditionsText, goldenText }) {
  const system =
    'Kamu adalah pemandu fotografi berbahasa Indonesia untuk fotografer pemula ' +
    '(kamera HP maupun kamera). Jawab HANYA dengan JSON valid tanpa teks lain.';
  const user = [
    'Buat rekomendasi pemotretan singkat dan praktis berdasarkan data berikut.',
    `Spot: ${spot.name} (kategori ${spot.category}). ${spot.description}`,
    `Tips spot: ${spot.tips || '-'}`,
    `Jenis foto: ${photoType}`,
    `Waktu rencana: ${plannedAtText}`,
    `Golden hour: ${goldenText}`,
    `Kondisi: ${conditionsText}`,
    `Skor kondisi pemotretan: ${score}/100 (${label})`,
    '',
    'Format JSON yang WAJIB (bahasa Indonesia, tiap kalimat maks 25 kata):',
    '{"composition": ["2-4 saran komposisi"], "timing": "satu kalimat", ' +
      '"position": "satu kalimat", "stability": "satu kalimat", "tips": ["2-3 tips"]}',
  ].join('\n');
  return { system, user };
}

/**
 * @returns {Promise<{recommendation: object, source: 'ai' | 'template'}>}
 */
async function getRecommendation(ctx, { generate = generateText } = {}) {
  const fallback = { recommendation: TEMPLATES[ctx.photoType] || TEMPLATES.landscape, source: 'template' };
  try {
    const { system, user } = buildPrompt(ctx);
    const text = await generate({
      system,
      messages: [{ role: 'user', text: user }],
      json: true,
      temperature: 0.5,
    });
    return { recommendation: validateRecommendation(extractJson(text)), source: 'ai' };
  } catch (err) {
    const reason = err instanceof LlmUnavailableError ? err.message : `JSON tidak valid: ${err.message}`;
    console.warn(`[recommendation] pakai template (${reason})`);
    return fallback;
  }
}

module.exports = { getRecommendation, validateRecommendation, extractJson, TEMPLATES };
