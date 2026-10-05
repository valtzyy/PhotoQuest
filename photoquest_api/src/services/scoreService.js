// Shoot Condition Score: penilaian kondisi pemotretan 0–100 berbasis aturan
// (rule-based, deterministik: input sama -> skor selalu sama).
//
//   Timing cahaya   40 poin
//   Tutupan awan    30 poin
//   Peluang hujan   20 poin
//   Kecocokan spot  10 poin

const PHOTO_TYPES = ['landscape', 'sunset', 'street', 'architecture', 'portrait'];
const HOUR_MS = 3600 * 1000;
const WIB_OFFSET_MS = 7 * HOUR_MS;

const clamp = (v, min, max) => Math.min(max, Math.max(min, v));
const round1 = (v) => Math.round(v * 10) / 10;

/** Jam (desimal) waktu WIB dari sebuah Date, mis. 16.5 = 16:30 WIB. */
function wibHour(date) {
  const d = new Date(date.getTime() + WIB_OFFSET_MS);
  return d.getUTCHours() + d.getUTCMinutes() / 60;
}

/** Jarak (jam) dari waktu t ke rentang [start, end]; 0 jika di dalamnya. */
function hoursFromWindow(t, start, end) {
  if (t >= start && t <= end) return 0;
  return (t < start ? start - t : t - end) / HOUR_MS;
}

/**
 * 1) Timing cahaya (maks 40)
 * - 40 jika di dalam golden hour pagi/sore.
 * - Turun linear sampai 10 saat jarak ke golden hour terdekat ≥ 3 jam.
 * - Tengah hari 11:00–14:00 WIB maksimal 10 untuk foto lanskap/alam
 *   (cahaya keras, bayangan pendek).
 */
function timingScore({ plannedAt, golden, photoType, spotCategory }) {
  const t = plannedAt.getTime();
  const dMorning = hoursFromWindow(t, golden.morning.start.getTime(), golden.morning.end.getTime());
  const dEvening = hoursFromWindow(t, golden.evening.start.getTime(), golden.evening.end.getTime());
  const distance = Math.min(dMorning, dEvening);

  let score = 40 - 30 * (Math.min(distance, 3) / 3);
  let note = distance === 0
    ? `Tepat di golden hour ${dMorning === 0 ? 'pagi' : 'sore'}`
    : `${round1(distance)} jam dari golden hour terdekat`;

  const hour = wibHour(plannedAt);
  const landscapeLike = ['landscape', 'sunset'].includes(photoType) ||
    ['landscape', 'nature'].includes(spotCategory);
  if (hour >= 11 && hour < 14 && landscapeLike && score > 10) {
    score = 10;
    note = 'Tengah hari (11:00–14:00): cahaya keras untuk lanskap/alam';
  }
  return { score: round1(score), note };
}

/**
 * 2) Tutupan awan (maks 30), ideal berbeda per jenis foto. Awan 100% selalu 5 poin.
 * - landscape/sunset    : ideal 20–60% (awan memberi tekstur & warna langit)
 * - street/architecture : ideal 0–50% (cahaya cerah, detail tajam)
 * - portrait            : ideal 30–80% (awan = cahaya lembut, bayangan halus)
 */
function cloudScore(cloud, photoType) {
  const c = clamp(cloud, 0, 100);
  let score;
  if (photoType === 'landscape' || photoType === 'sunset') {
    if (c < 20) score = 20 + 10 * (c / 20); // langit polos kurang dramatis
    else if (c <= 60) score = 30;
    else score = 30 - 25 * ((c - 60) / 40);
  } else if (photoType === 'portrait') {
    if (c < 30) score = 20 + 10 * (c / 30);
    else if (c <= 80) score = 30;
    else score = 30 - 25 * ((c - 80) / 20);
  } else {
    // street & architecture
    if (c <= 50) score = 30;
    else score = 30 - 25 * ((c - 50) / 50);
  }
  return { score: round1(score), note: `Tutupan awan ${Math.round(c)}%` };
}

/** 3) Peluang hujan (maks 20): 20 × (1 − rain/100). */
function rainScore(rain) {
  const r = clamp(rain, 0, 100);
  return { score: round1(20 * (1 - r / 100)), note: `Peluang hujan ${Math.round(r)}%` };
}

/**
 * 4) Kecocokan spot (maks 10)
 * - jenis foto ada di spot.photo_types
 * - best_time cocok: "any" selalu cocok; "sunrise" = sebelum 12:00 WIB; "sunset" = 12:00 ke atas
 * Keduanya cocok = 10, salah satu = 5, tidak ada = 0.
 */
function spotMatchScore({ spot, photoType, plannedAt }) {
  const typeMatch = spot.photo_types.includes(photoType);
  const hour = wibHour(plannedAt);
  const timeMatch = spot.best_time === 'any' ||
    (spot.best_time === 'sunrise' && hour < 12) ||
    (spot.best_time === 'sunset' && hour >= 12);
  const score = typeMatch && timeMatch ? 10 : typeMatch || timeMatch ? 5 : 0;
  const parts = [
    typeMatch ? 'jenis foto cocok' : 'jenis foto kurang cocok',
    timeMatch ? 'waktu cocok' : 'waktu kurang cocok',
  ];
  return { score, note: parts.join(', ') };
}

function labelFor(score) {
  if (score >= 80) return 'Sangat Baik';
  if (score >= 60) return 'Baik';
  if (score >= 40) return 'Cukup';
  return 'Kurang';
}

/**
 * Hitung skor total + rincian.
 * @param {object} p
 * @param {object} p.spot      baris tabel spots (category, photo_types, best_time)
 * @param {string} p.photoType
 * @param {Date}   p.plannedAt
 * @param {number} p.cloudCover   0–100
 * @param {number} p.rainProb     0–100
 * @param {{morning:{start:Date,end:Date}, evening:{start:Date,end:Date}}} p.golden
 */
function calculateScore({ spot, photoType, plannedAt, cloudCover, rainProb, golden }) {
  const timing = timingScore({ plannedAt, golden, photoType, spotCategory: spot.category });
  const cloud = cloudScore(cloudCover, photoType);
  const rain = rainScore(rainProb);
  const match = spotMatchScore({ spot, photoType, plannedAt });

  const breakdown = [
    { key: 'timing', label: 'Timing cahaya', max: 40, ...timing },
    { key: 'cloud', label: 'Tutupan awan', max: 30, ...cloud },
    { key: 'rain', label: 'Peluang hujan', max: 20, ...rain },
    { key: 'spot', label: 'Kecocokan spot', max: 10, ...match },
  ];
  const score = Math.round(breakdown.reduce((sum, b) => sum + b.score, 0));
  return { score, label: labelFor(score), breakdown };
}

module.exports = {
  PHOTO_TYPES,
  calculateScore,
  timingScore,
  cloudScore,
  rainScore,
  spotMatchScore,
  labelFor,
  wibHour,
};
