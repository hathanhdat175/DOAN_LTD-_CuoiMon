const jwt = require('jsonwebtoken');
const config = require('../config');
const db = require('../db');
const { unauthorized, forbidden } = require('../utils/http-error');

/** Tạo JWT chứa mã người dùng và vai trò. */
function signToken(user) {
  return jwt.sign({ sub: user.UserId, role: user.Role }, config.jwtSecret, { expiresIn: config.jwtExpiresIn });
}

/**
 * Kiểm tra header "Authorization: Bearer <token>".
 * Đọc lại người dùng từ CSDL để chặn ngay tài khoản vừa bị khóa (không chờ token hết hạn).
 */
async function authenticate(req, _res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    throw unauthorized('Vui lòng đăng nhập.');
  }
  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret);
  } catch {
    throw unauthorized();
  }
  const result = await db.query(
    'SELECT UserId, FullName, Email, Role, IsLocked, CreatedAt FROM dbo.Users WHERE UserId = @id',
    { id: Number(payload.sub) },
  );
  const user = result.recordset[0];
  if (!user) {
    throw unauthorized();
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
