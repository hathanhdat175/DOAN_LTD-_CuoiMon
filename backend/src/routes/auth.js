const express = require('express');
const bcrypt = require('bcryptjs');
const config = require('../config');
const db = require('../db');
const { signToken, authenticate } = require('../middleware/auth');
const { rateLimit } = require('../middleware/rate-limit');
const { toUser } = require('../utils/mappers');
const { assertStrongPassword } = require('../utils/password');
const { HttpError, badRequest, unauthorized, forbidden, conflict } = require('../utils/http-error');

const router = express.Router();
// Phản hồi chứa token không được lưu vào bộ nhớ đệm (cache) của trình duyệt / proxy.
router.use((_req, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
});
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Thông báo chung cho sai email HOẶC sai mật khẩu: không để lộ email nào đã có tài khoản.
const WRONG_LOGIN = 'Email hoặc mật khẩu không đúng.';

// Băm sẵn một mật khẩu giả để khi email không tồn tại vẫn tốn thời gian so khớp như bình thường
// (tránh đoán email có tồn tại hay không dựa vào thời gian phản hồi).
let dummyHash;
const getDummyHash = () => (dummyHash ??= bcrypt.hashSync('BookHub-dummy-password', config.bcryptRounds));

// Mỗi địa chỉ IP gọi đăng nhập / đăng ký tối đa 20 lần mỗi 5 phút.
const authLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 20,
  message: 'Bạn thao tác quá nhanh, vui lòng thử lại sau ít phút.',
});

/** POST /api/auth/register — đăng ký Reader hoặc Publisher, trả về JWT. */
router.post('/register', authLimiter, async (req, res) => {
  const fullName = String(req.body.fullName || '').trim();
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  const role = String(req.body.role || 'Reader');

  if (!fullName || !email || !password) {
    throw badRequest('Vui lòng nhập đầy đủ họ tên, email và mật khẩu.');
  }
  if (fullName.length > 100) throw badRequest('Họ tên tối đa 100 ký tự.');
  if (!EMAIL_RE.test(email) || email.length > 100) throw badRequest('Email không hợp lệ.');
  assertStrongPassword(password, { email });
  if (!['Reader', 'Publisher'].includes(role)) {
    throw badRequest('Chỉ được đăng ký vai trò Reader hoặc Publisher.');
  }

  const exists = await db.query('SELECT 1 FROM dbo.Users WHERE Email = @email', { email });
  if (exists.recordset.length) {
    throw conflict('Email này đã được sử dụng.');
  }

  const hash = await bcrypt.hash(password, config.bcryptRounds);
  const result = await db.query(
    `INSERT INTO dbo.Users (FullName, Email, PasswordHash, Role, PasswordChangedAt)
     OUTPUT inserted.UserId, inserted.FullName, inserted.Email, inserted.Role, inserted.IsLocked,
            inserted.CreatedAt, inserted.TokenVersion
     VALUES (@fullName, @email, @hash, @role, SYSDATETIME())`,
    { fullName, email, hash, role },
  );
  const user = result.recordset[0];
  res.status(201).json({ token: signToken(user), user: toUser(user) });
});

/**
 * POST /api/auth/login — so khớp mật khẩu bcrypt, kiểm tra khóa, trả về JWT.
 * Nhập sai mật khẩu liên tiếp LOGIN_MAX_ATTEMPTS lần (mặc định 5) thì tạm khóa đăng nhập
 * LOGIN_LOCK_MINUTES phút (mặc định 15) để chống dò mật khẩu.
 */
router.post('/login', authLimiter, async (req, res) => {
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  if (!email || !password) {
    throw badRequest('Vui lòng nhập email và mật khẩu.');
  }

  const result = await db.query(
    `SELECT UserId, FullName, Email, PasswordHash, Role, IsLocked, CreatedAt, TokenVersion,
            DATEDIFF(SECOND, SYSDATETIME(), LockoutUntil) AS LockSeconds
     FROM dbo.Users WHERE Email = @email`,
    { email },
  );
  const user = result.recordset[0];
  if (!user) {
    await bcrypt.compare(password, getDummyHash());
    throw unauthorized(WRONG_LOGIN);
  }

  const lockSeconds = Number(user.LockSeconds || 0);
  if (lockSeconds > 0) {
    throw new HttpError(
      429,
      `Bạn đã nhập sai mật khẩu quá nhiều lần. Vui lòng thử lại sau ${Math.ceil(lockSeconds / 60)} phút.`,
    );
  }

  if (!(await bcrypt.compare(password, user.PasswordHash))) {
    const max = config.loginMaxAttempts;
    const upd = await db.query(
      `UPDATE dbo.Users SET
         FailedLoginCount = CASE WHEN FailedLoginCount + 1 >= @max THEN 0 ELSE FailedLoginCount + 1 END,
         LockoutUntil     = CASE WHEN FailedLoginCount + 1 >= @max
                                 THEN DATEADD(MINUTE, @minutes, SYSDATETIME()) ELSE NULL END
       OUTPUT inserted.FailedLoginCount, CASE WHEN inserted.LockoutUntil IS NULL THEN 0 ELSE 1 END AS Locked
       WHERE UserId = @id`,
      { id: Number(user.UserId), max, minutes: config.loginLockMinutes },
    );
    const row = upd.recordset[0] || {};
    if (Number(row.Locked)) {
      throw new HttpError(
        429,
        `Bạn đã nhập sai mật khẩu ${max} lần. Đăng nhập bị tạm khóa ${config.loginLockMinutes} phút.`,
      );
    }
    const left = max - Number(row.FailedLoginCount || 0);
    throw unauthorized(left <= 2 ? `${WRONG_LOGIN} Còn ${left} lần thử trước khi bị tạm khóa.` : WRONG_LOGIN);
  }

  if (user.IsLocked) {
    throw forbidden('Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.');
  }
  await db.query(
    `UPDATE dbo.Users SET FailedLoginCount = 0, LockoutUntil = NULL, LastLoginAt = SYSDATETIME()
     WHERE UserId = @id`,
    { id: Number(user.UserId) },
  );
  res.json({ token: signToken(user), user: toUser(user) });
});

/** GET /api/auth/me — người dùng của token hiện tại (dùng khi mở lại ứng dụng). */
router.get('/me', authenticate, (req, res) => {
  res.json(toUser(req.user));
});

module.exports = router;
