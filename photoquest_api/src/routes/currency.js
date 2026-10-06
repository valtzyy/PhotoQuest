// Konverter: kurs mata uang (proxy Frankfurter) dan daftar gear fotografi.
const express = require('express');

const db = require('../db');
const currencyService = require('../services/currencyService');
const { ok, fail } = require('../utils/response');
const { requireAuth } = require('../middleware/auth');

const currencyRouter = express.Router();
const gearRouter = express.Router();

// GET /currency?base=IDR -> { base, date, source, fetched_at, rates: { IDR, USD, EUR, JPY } }
currencyRouter.get('/', requireAuth, async (req, res) => {
  const base = String(req.query.base || 'IDR').toUpperCase();
  if (!currencyService.CURRENCIES.includes(base)) {
    return fail(res, 400, `base harus salah satu dari: ${currencyService.CURRENCIES.join(', ')}`);
  }
  const data = await currencyService.getRates(base);
  return ok(res, data, data.source === 'fallback' ? 'Kurs live tidak tersedia, memakai kurs tetap' : 'OK');
});

// GET /gear -> daftar gear fotografi (harga dalam rupiah)
gearRouter.get('/', requireAuth, async (req, res) => {
  const { rows } = await db.query('SELECT id, name, price_idr FROM gear_items ORDER BY price_idr');
  return ok(res, rows);
});

module.exports = { currencyRouter, gearRouter };
