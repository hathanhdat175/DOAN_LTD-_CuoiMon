const { HttpError } = require('../utils/http-error');

/**
 * Giới hạn số request theo địa chỉ IP trong một khoảng thời gian (lưu trong bộ nhớ).
 * Dùng cho API đăng nhập / đăng ký để chống dò mật khẩu tự động (brute force).
 * Khóa tài khoản theo số lần sai được xử lý riêng trong routes/auth.js.
 */
function rateLimit({ windowMs, max, message }) {
  const hits = new Map(); // ip -> { count, resetAt }

  const timer = setInterval(() => {
    const now = Date.now();
    for (const [ip, h] of hits) {
      if (h.resetAt <= now) hits.delete(ip);
    }
  }, windowMs);
  timer.unref();

  return (req, res, next) => {
    const ip = req.ip || req.socket.remoteAddress || 'unknown';
    const now = Date.now();
    let h = hits.get(ip);
    if (!h || h.resetAt <= now) {
      h = { count: 0, resetAt: now + windowMs };
      hits.set(ip, h);
    }
    h.count += 1;
    if (h.count > max) {
      res.set('Retry-After', String(Math.ceil((h.resetAt - now) / 1000)));
      throw new HttpError(429, message);
    }
    next();
  };
}

module.exports = { rateLimit };
