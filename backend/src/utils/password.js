const { badRequest } = require('./http-error');

/**
 * Chính sách mật khẩu (dùng khi đăng ký và đổi mật khẩu).
 * Ứng dụng Flutter kiểm tra cùng các quy tắc này trong lib/utils/password_policy.dart,
 * máy chủ kiểm tra lại để không ai gửi thẳng request bỏ qua được.
 */
const MIN_LENGTH = 8;
const MAX_LENGTH = 64;

const RULES = [
  { label: `ít nhất ${MIN_LENGTH} ký tự`, test: (p) => [...p].length >= MIN_LENGTH },
  { label: 'một chữ hoa (A–Z)', test: (p) => /\p{Lu}/u.test(p) },
  { label: 'một chữ thường (a–z)', test: (p) => /\p{Ll}/u.test(p) },
  { label: 'một chữ số (0–9)', test: (p) => /\p{Nd}/u.test(p) },
  { label: 'một ký tự đặc biệt (ví dụ @ # $ ! %)', test: (p) => /[^\p{L}\p{N}\s]/u.test(p) },
];

/** Danh sách các yêu cầu mật khẩu còn thiếu (rỗng = đạt). */
function missingRules(password) {
  return RULES.filter((r) => !r.test(password)).map((r) => r.label);
}

/** Ném lỗi 400 với thông báo tiếng Việt nếu mật khẩu chưa đủ mạnh. */
function assertStrongPassword(password, { email } = {}) {
  if ([...password].length > MAX_LENGTH) {
    throw badRequest(`Mật khẩu tối đa ${MAX_LENGTH} ký tự.`);
  }
  if (/\s/.test(password)) {
    throw badRequest('Mật khẩu không được chứa khoảng trắng.');
  }
  const missing = missingRules(password);
  if (missing.length) {
    throw badRequest(`Mật khẩu chưa đủ mạnh, cần có ${missing.join(', ')}.`);
  }
  const name = String(email || '').split('@')[0].toLowerCase();
  if (name.length >= 4 && password.toLowerCase().includes(name)) {
    throw badRequest('Mật khẩu không được chứa tên email của bạn.');
  }
}

module.exports = { MIN_LENGTH, MAX_LENGTH, missingRules, assertStrongPassword };
