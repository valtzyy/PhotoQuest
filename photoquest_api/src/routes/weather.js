// GET /weather?lat=&lng= -> proxy Open-Meteo + golden hour (lihat weatherService).
const express = require('express');

const weatherService = require('../services/weatherService');
const { ok, fail } = require('../utils/response');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.get('/', requireAuth, async (req, res) => {
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  const valid =
    req.query.lat !== undefined && req.query.lng !== undefined &&
    Number.isFinite(lat) && Number.isFinite(lng) &&
    Math.abs(lat) <= 90 && Math.abs(lng) <= 180;
  if (!valid) return fail(res, 400, 'Parameter lat/lng tidak valid');

  const data = await weatherService.getWeather(lat, lng);
  const message = data.is_estimate
    ? 'Data cuaca tidak tersedia, memakai estimasi'
    : 'OK';
  return ok(res, data, message);
});

module.exports = router;
