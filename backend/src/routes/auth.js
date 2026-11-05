const express = require('express');
const bcrypt = require('bcryptjs');
const db = require('../db');
const { signToken, authenticate } = require('../middleware/auth');
const { toUser } = require('../utils/mappers');
const { badRequest, unauthorized, forbidden, conflict } = require('../utils/http-error');

const router = express.Router();
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** POST /api/auth/register — đăng ký Reader hoặc Publisher, trả về JWT. */
router.post('/register', async (req, res) => {
  const fullName = String(req.body.fullName || '').trim();
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  const role = String(req.body.role || 'Reader');

  if (!fullName || !email || !password) {
    throw badRequest('Vui lòng nhập đầy đủ họ tên, email và mật khẩu.');
  }
  if (fullName.length > 100) throw badRequest('Họ tên tối đa 100 ký tự.');
  if (!EMAIL_RE.test(email) || email.length > 100) throw badRequest('Email không hợp lệ.');
  if (password.length < 6) throw badRequest('Mật khẩu tối thiểu 6 ký tự.');
  if (!['Reader', 'Publisher'].includes(role)) {
    throw badRequest('Chỉ được đăng ký vai trò Reader hoặc Publisher.');
  }

  const exists = await db.query('SELECT 1 FROM dbo.Users WHERE Email = @email', { email });
  if (exists.recordset.length) {
    throw conflict('Email này đã được sử dụng.');
  }

  const hash = await bcrypt.hash(password, 10);
  const result = await db.query(
    `INSERT INTO dbo.Users (FullName, Email, PasswordHash, Role)
     OUTPUT inserted.UserId, inserted.FullName, inserted.Email, inserted.Role, inserted.IsLocked, inserted.CreatedAt
     VALUES (@fullName, @email, @hash, @role)`,
    { fullName, email, hash, role },
  );
  const user = result.recordset[0];
  res.status(201).json({ token: signToken(user), user: toUser(user) });
});

/** POST /api/auth/login — so khớp mật khẩu bcrypt, kiểm tra khóa, trả về JWT. */
router.post('/login', async (req, res) => {
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  if (!email || !password) {
    throw badRequest('Vui lòng nhập email và mật khẩu.');
  }

  const result = await db.query(
    'SELECT UserId, FullName, Email, PasswordHash, Role, IsLocked, CreatedAt FROM dbo.Users WHERE Email = @email',
    { email },
  );
  const user = result.recordset[0];
  if (!user) {
    throw unauthorized('Email chưa được đăng ký.');
  }
  if (!(await bcrypt.compare(password, user.PasswordHash))) {
    throw unauthorized('Mật khẩu không đúng.');
  }
  if (user.IsLocked) {
    throw forbidden('Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.');
  }
  res.json({ token: signToken(user), user: toUser(user) });
});

/** GET /api/auth/me — người dùng của token hiện tại (dùng khi mở lại ứng dụng). */
router.get('/me', authenticate, (req, res) => {
  res.json(toUser(req.user));
});

module.exports = router;
