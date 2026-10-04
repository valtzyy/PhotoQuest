// Middleware JWT: memastikan request membawa token yang valid.
// Header yang diharapkan: Authorization: Bearer <token>
const jwt = require('jsonwebtoken');
const config = require('../config');
const { fail } = require('../utils/response');

function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return fail(res, 401, 'Token tidak ditemukan. Silakan login.');
  }

  try {
    // verify() mengecek tanda tangan (JWT_SECRET) dan masa berlaku (exp).
    const payload = jwt.verify(token, config.jwtSecret);
    // `sub` (subject) berisi id user, disimpan agar route bisa memakai req.user.id
    req.user = { id: Number(payload.sub), email: payload.email };
    return next();
  } catch (err) {
    const message = err.name === 'TokenExpiredError'
      ? 'Sesi sudah berakhir. Silakan login kembali.'
      : 'Token tidak valid. Silakan login kembali.';
    return fail(res, 401, message);
  }
}

// Membuat JWT untuk user yang berhasil login/register.
function signToken(user) {
  return jwt.sign(
    { sub: String(user.id), email: user.email },
    config.jwtSecret,
    { expiresIn: config.jwtExpiresIn } // default 7d
  );
}

module.exports = { requireAuth, signToken };
