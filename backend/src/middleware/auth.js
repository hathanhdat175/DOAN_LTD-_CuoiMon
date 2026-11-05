const jwt = require('jsonwebtoken');
const config = require('../config');
const db = require('../db');
const { unauthorized, forbidden } = require('../utils/http-error');

/**
 * Tạo JWT chứa mã người dùng, vai trò và phiên bản token (TokenVersion).
 * Khi người dùng đổi mật khẩu, TokenVersion tăng lên nên mọi token cũ (trên các máy khác) hết hiệu lực.
 */
function signToken(user) {
  return jwt.sign(
    { sub: user.UserId, role: user.Role, ver: Number(user.TokenVersion || 0) },
    config.jwtSecret,
    { expiresIn: config.jwtExpiresIn, algorithm: 'HS256' },
  );
}

/**
 * Kiểm tra header "Authorization: Bearer <token>".
 * Đọc lại người dùng từ CSDL để chặn ngay tài khoản vừa bị khóa hoặc vừa đổi mật khẩu
 * (không chờ token hết hạn).
 */
async function authenticate(req, _res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    throw unauthorized('Vui lòng đăng nhập.');
  }
  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'] });
  } catch {
    throw unauthorized();
  }
  const result = await db.query(
    'SELECT UserId, FullName, Email, Role, IsLocked, CreatedAt, TokenVersion FROM dbo.Users WHERE UserId = @id',
    { id: Number(payload.sub) },
  );
  const user = result.recordset[0];
  if (!user) {
    throw unauthorized();
  }
  if (Number(payload.ver || 0) !== Number(user.TokenVersion || 0)) {
    throw unauthorized('Mật khẩu tài khoản đã được thay đổi, vui lòng đăng nhập lại.');
  }
  if (user.IsLocked) {
    throw forbidden('Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.');
  }
  user.UserId = Number(user.UserId);
  req.user = user;
  next();
}

/** Phân quyền theo vai trò (RBAC), ví dụ requireRole('Admin'). */
function requireRole(...roles) {
  return (req, _res, next) => {
    if (!req.user || !roles.includes(req.user.Role)) {
      throw forbidden();
    }
    next();
  };
}

module.exports = { signToken, authenticate, requireRole };
