// Format respons seragam untuk seluruh API: { success, data, message }.
// Aplikasi Flutter cukup membaca tiga field ini untuk semua endpoint.

function ok(res, data = null, message = 'OK', status = 200) {
  return res.status(status).json({ success: true, data, message });
}

function fail(res, status = 400, message = 'Terjadi kesalahan', data = null) {
  return res.status(status).json({ success: false, data, message });
}

module.exports = { ok, fail };
