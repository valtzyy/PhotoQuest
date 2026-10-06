// Kurs mata uang dari Frankfurter (data kurs referensi ECB, tanpa API key).
//
// Catatan presisi: jika diminta langsung base=IDR, Frankfurter membulatkan kurs
// (mis. USD 5.6e-05) sehingga konversi bisa meleset ±0,5%. Karena itu kurs
// selalu diambil dengan base EUR lalu dihitung kurs silangnya sendiri:
//   rate(base -> X) = EUR->X / EUR->base
//
// Fallback: cache 6 jam -> live -> cache lama -> kurs tetap (source "fallback").
const axios = require('axios');
const config = require('../config');

const FRANKFURTER_URL = 'https://api.frankfurter.dev/v1/latest';
const CURRENCIES = ['IDR', 'USD', 'EUR', 'JPY'];
const CACHE_TTL_MS = 6 * 60 * 60 * 1000; // 6 jam

// Kurs tetap (snapshot Frankfurter 2 Okt 2026, base EUR) jika API gagal & belum ada cache.
const FALLBACK = {
  date: '2026-10-02',
  rates: { EUR: 1, IDR: 20149.32, USD: 1.1225, JPY: 176.99 },
};

/** Ubah tabel kurs base EUR menjadi kurs relatif terhadap `base`. */
function crossRates(eurRates, base) {
  const rates = {};
  for (const c of CURRENCIES) {
    rates[c] = eurRates[c] / eurRates[base];
  }
  return rates;
}

function createCurrencyService({
  fetcher = () =>
    axios
      .get(FRANKFURTER_URL, {
        params: { base: 'EUR', symbols: 'IDR,USD,JPY' },
        timeout: config.externalTimeoutMs,
      })
      .then((r) => r.data),
  now = () => new Date(),
} = {}) {
  let cache = null; // { eurRates, date, savedAt }

  async function loadEurTable() {
    if (cache && now().getTime() - cache.savedAt < CACHE_TTL_MS) {
      return { ...cache, source: 'cache' };
    }
    try {
      const data = await fetcher();
      const eurRates = { EUR: 1, ...data.rates };
      for (const c of CURRENCIES) {
        if (typeof eurRates[c] !== 'number') throw new Error(`Kurs ${c} tidak ada`);
      }
      cache = { eurRates, date: data.date, savedAt: now().getTime() };
      return { ...cache, source: 'live' };
    } catch (err) {
      console.warn('[currency] Frankfurter gagal:', err.message);
      if (cache) return { ...cache, source: 'cache' };
      return { eurRates: FALLBACK.rates, date: FALLBACK.date, savedAt: now().getTime(), source: 'fallback' };
    }
  }

  async function getRates(base = 'IDR') {
    const table = await loadEurTable();
    return {
      base,
      date: table.date, // tanggal kurs ECB
      source: table.source, // live | cache | fallback
      fetched_at: new Date(table.savedAt).toISOString(),
      rates: crossRates(table.eurRates, base),
    };
  }

  return { getRates };
}

module.exports = { ...createCurrencyService(), createCurrencyService, crossRates, CURRENCIES, FALLBACK };
