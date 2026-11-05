const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const multer = require('multer');
const config = require('../config');
const { badRequest } = require('../utils/http-error');

const pdfDir = path.join(config.uploadDir, 'pdf');
const coverDir = path.join(config.uploadDir, 'cover');
fs.mkdirSync(pdfDir, { recursive: true });
fs.mkdirSync(coverDir, { recursive: true });

const IMAGE_EXT = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];

/** Multer lưu file vào uploads/pdf và uploads/cover với tên ngẫu nhiên. */
const storage = multer.diskStorage({
  destination: (_req, file, cb) => cb(null, file.fieldname === 'pdf' ? pdfDir : coverDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase() || (file.fieldname === 'pdf' ? '.pdf' : '.jpg');
    cb(null, `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`);
  },
});

function fileFilter(_req, file, cb) {
  const ext = path.extname(file.originalname || '').toLowerCase();
  if (file.fieldname === 'pdf') {
    if (ext !== '.pdf' && file.mimetype !== 'application/pdf') {
      return cb(badRequest('File sách phải có định dạng PDF.'));
    }
    return cb(null, true);
  }
  if (file.fieldname === 'cover') {
    if (!IMAGE_EXT.includes(ext) && !(file.mimetype || '').startsWith('image/')) {
      return cb(badRequest('Ảnh bìa phải là file ảnh (jpg, png, webp).'));
    }
    return cb(null, true);
  }
  return cb(badRequest(`Trường file không hợp lệ: ${file.fieldname}`));
}

const bookUpload = multer({ storage, fileFilter, limits: { fileSize: config.maxUploadBytes } }).fields([
  { name: 'pdf', maxCount: 1 },
  { name: 'cover', maxCount: 1 },
]);

/** Đường dẫn lưu trong CSDL (tương đối, dạng uploads/pdf/ten-file.pdf). */
function relativePath(file) {
  return path.relative(config.rootDir, file.path).split(path.sep).join('/');
}

/** Xóa file trên đĩa (bỏ qua nếu không tồn tại). */
function removeFile(relPath) {
  if (!relPath) return;
  const full = path.resolve(config.rootDir, relPath);
  if (!full.startsWith(config.uploadDir)) return;
  fs.promises.unlink(full).catch(() => {});
}

module.exports = { bookUpload, relativePath, removeFile };
