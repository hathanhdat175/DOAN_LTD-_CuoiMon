const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env'), quiet: true });

const rootDir = path.join(__dirname, '..');

/** Cấu hình đọc từ file .env (có giá trị mặc định để chạy ngay trên máy Windows). */
const DEFAULT_JWT_SECRET = 'bookhub-nhom10-dev-secret';

module.exports = {
  port: Number(process.env.PORT || 3000),
  jwtSecret: process.env.JWT_SECRET || DEFAULT_JWT_SECRET,
  // Khóa JWT yếu (để mặc định, giống file mẫu, hoặc ngắn hơn 32 ký tự) -> máy chủ in cảnh báo khi khởi động.
  weakJwtSecret:
    !process.env.JWT_SECRET ||
    [DEFAULT_JWT_SECRET, 'bookhub-nhom10-doi-chuoi-nay'].includes(process.env.JWT_SECRET) ||
    process.env.JWT_SECRET.length < 32,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  // Bảo mật đăng nhập
  bcryptRounds: Number(process.env.BCRYPT_ROUNDS || 12),
  loginMaxAttempts: Number(process.env.LOGIN_MAX_ATTEMPTS || 5),
  loginLockMinutes: Number(process.env.LOGIN_LOCK_MINUTES || 15),
  db: {
    driver: process.env.DB_DRIVER || (process.platform === 'win32' ? 'msnodesqlv8' : 'tedious'),
    server: process.env.DB_SERVER || 'localhost',
    port: Number(process.env.DB_PORT || 1433),
    user: process.env.DB_USER || 'sa',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'BookHubDB',
    odbcDriver: process.env.DB_ODBC_DRIVER || 'ODBC Driver 17 for SQL Server',
  },
  rootDir,
  uploadDir: path.resolve(rootDir, process.env.UPLOAD_DIR || 'uploads'),
  maxUploadBytes: Number(process.env.MAX_UPLOAD_MB || 50) * 1024 * 1024,
  // Thông báo đẩy Firebase (tùy chọn): đường dẫn file khóa tài khoản dịch vụ, tương đối với thư mục backend.
  fcmServiceAccount: process.env.FCM_SERVICE_ACCOUNT || '',
};
