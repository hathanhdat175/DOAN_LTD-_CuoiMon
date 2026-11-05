const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env'), quiet: true });

const rootDir = path.join(__dirname, '..');

/** Cấu hình đọc từ file .env (có giá trị mặc định để chạy ngay trên máy Windows). */
module.exports = {
  port: Number(process.env.PORT || 3000),
  jwtSecret: process.env.JWT_SECRET || 'bookhub-nhom10-dev-secret',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
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
