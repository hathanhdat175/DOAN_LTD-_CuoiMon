const express = require('express');
const cors = require('cors');
const multer = require('multer');
const config = require('./config');
const db = require('./db');
const { HttpError } = require('./utils/http-error');
const push = require('./utils/push');

/** Tạo ứng dụng Express (tách khỏi server.js để dễ kiểm thử). */
function createApp() {
  const app = express();

  app.use(cors());
  app.use(express.json({ limit: '1mb' }));

  // Ảnh bìa được phục vụ công khai; file PDF chỉ đọc qua /api/books/:id/file (cần đăng nhập).
  app.use('/uploads/cover', express.static(`${config.uploadDir}/cover`, { maxAge: '7d' }));

  app.get('/api/health', async (_req, res) => {
    await db.query('SELECT 1 AS ok');
    res.json({ status: 'ok', database: config.db.database, push: push.status(), time: new Date().toISOString() });
  });

  app.use('/api/auth', require('./routes/auth'));
  app.use('/api/me', require('./routes/me'));
  app.use('/api/publisher', require('./routes/publisher'));
  app.use('/api/admin', require('./routes/admin'));
  app.use('/api', require('./routes/books'));

  app.use((_req, _res, next) => next(new HttpError(404, 'Không tìm thấy API.')));

  // Xử lý lỗi tập trung: luôn trả JSON { message }.
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err instanceof HttpError) {
      return res.status(err.status).json({ message: err.message });
    }
    if (err instanceof multer.MulterError) {
      const message =
        err.code === 'LIMIT_FILE_SIZE'
          ? `File quá lớn (tối đa ${Math.round(config.maxUploadBytes / 1024 / 1024)} MB).`
          : `Lỗi tải file: ${err.message}`;
      return res.status(400).json({ message });
    }
    if (err.type === 'entity.parse.failed') {
      return res.status(400).json({ message: 'Dữ liệu gửi lên không đúng định dạng JSON.' });
    }
    console.error(err);
    return res.status(500).json({ message: 'Lỗi máy chủ, vui lòng thử lại sau.' });
  });

  return app;
}

module.exports = { createApp };
