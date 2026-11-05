const express = require('express');
const db = require('../db');
const { authenticate } = require('../middleware/auth');
const { num, toBook, BOOK_COLUMNS, BOOK_FROM } = require('../utils/mappers');
const { badRequest, notFound, parseId } = require('../utils/http-error');

/**
 * Dữ liệu đọc sách của người dùng hiện tại (mọi vai trò):
 * sách yêu thích (Favorites) và tiến độ đọc / lịch sử đọc (ReadingProgress).
 */
const router = express.Router();
router.use(authenticate);

async function ensureApproved(bookId) {
  const r = await db.query("SELECT TotalPages FROM dbo.Books WHERE BookId = @bookId AND Status = 'Approved'", {
    bookId,
  });
  if (!r.recordset.length) {
    throw notFound('Sách không tồn tại hoặc chưa được duyệt.');
  }
  return { TotalPages: Number(r.recordset[0].TotalPages) };
}

/** GET /api/me/favorites — sách yêu thích (chỉ sách còn ở trạng thái Đã duyệt). */
router.get('/favorites', async (req, res) => {
  const result = await db.query(
    `SELECT ${BOOK_COLUMNS}, f.CreatedAt AS FavoritedAt ${BOOK_FROM}
     JOIN dbo.Favorites f ON f.BookId = b.BookId
     WHERE f.UserId = @uid AND b.Status = 'Approved'
     ORDER BY f.CreatedAt DESC`,
    { uid: req.user.UserId },
  );
  res.json(result.recordset.map(toBook));
});

/** PUT /api/me/favorites/:bookId — đánh dấu yêu thích. */
router.put('/favorites/:bookId', async (req, res) => {
  const bookId = parseId(req.params.bookId, 'bookId');
  await ensureApproved(bookId);
  await db.query(
    `IF NOT EXISTS (SELECT 1 FROM dbo.Favorites WHERE UserId = @uid AND BookId = @bookId)
       INSERT INTO dbo.Favorites (UserId, BookId) VALUES (@uid, @bookId)`,
    { uid: req.user.UserId, bookId },
  );
  res.status(204).end();
});

/** DELETE /api/me/favorites/:bookId — bỏ yêu thích. */
router.delete('/favorites/:bookId', async (req, res) => {
  const bookId = parseId(req.params.bookId, 'bookId');
  await db.query('DELETE FROM dbo.Favorites WHERE UserId = @uid AND BookId = @bookId', {
    uid: req.user.UserId,
    bookId,
  });
  res.status(204).end();
});

/** GET /api/me/progress — lịch sử đọc, mới nhất trước, kèm thông tin sách. */
router.get('/progress', async (req, res) => {
  const result = await db.query(
    `SELECT ${BOOK_COLUMNS}, p.CurrentPage, p.UpdatedAt ${BOOK_FROM}
     JOIN dbo.ReadingProgress p ON p.BookId = b.BookId
     WHERE p.UserId = @uid AND b.Status = 'Approved'
     ORDER BY p.UpdatedAt DESC`,
    { uid: req.user.UserId },
  );
  res.json(
    result.recordset.map((row) => ({
      bookId: num(row.BookId),
      currentPage: num(row.CurrentPage),
      updatedAt: row.UpdatedAt,
      book: toBook(row),
    })),
  );
});

/** PUT /api/me/progress/:bookId { page } — lưu trang đang đọc bằng lệnh MERGE. */
router.put('/progress/:bookId', async (req, res) => {
  const bookId = parseId(req.params.bookId, 'bookId');
  const page = Number(req.body.page);
  if (!Number.isInteger(page) || page < 1) {
    throw badRequest('Số trang không hợp lệ.');
  }
  const book = await ensureApproved(bookId);
  const current = Math.min(page, book.TotalPages);
  const result = await db.query(
    `MERGE dbo.ReadingProgress AS t
     USING (SELECT @uid AS UserId, @bookId AS BookId, @page AS CurrentPage) AS s
     ON t.UserId = s.UserId AND t.BookId = s.BookId
     WHEN MATCHED THEN
       UPDATE SET CurrentPage = s.CurrentPage, UpdatedAt = SYSDATETIME()
     WHEN NOT MATCHED THEN
       INSERT (UserId, BookId, CurrentPage) VALUES (s.UserId, s.BookId, s.CurrentPage)
     OUTPUT inserted.CurrentPage, inserted.UpdatedAt;`,
    { uid: req.user.UserId, bookId, page: current },
  );
  const row = result.recordset[0];
  res.json({ bookId, currentPage: num(row.CurrentPage), updatedAt: row.UpdatedAt });
});

// ---------------------------------------------------------------------------
// SÁCH ĐÃ TẢI VỀ MÁY (file nằm trên điện thoại, máy chủ chỉ ghi nhận)
// ---------------------------------------------------------------------------

/** GET /api/me/downloads — sách đã tải về, mới nhất trước. */
router.get('/downloads', async (req, res) => {
  const result = await db.query(
    `SELECT ${BOOK_COLUMNS}, d.DownloadedAt ${BOOK_FROM}
     JOIN dbo.Downloads d ON d.BookId = b.BookId
     WHERE d.UserId = @uid AND b.Status = 'Approved'
     ORDER BY d.DownloadedAt DESC`,
    { uid: req.user.UserId },
  );
  res.json(result.recordset.map((row) => ({ ...toBook(row), downloadedAt: row.DownloadedAt })));
});

/** PUT /api/me/downloads/:bookId — ghi nhận đã tải sách về máy. */
router.put('/downloads/:bookId', async (req, res) => {
  const bookId = parseId(req.params.bookId, 'bookId');
  await ensureApproved(bookId);
  await db.query(
    `MERGE dbo.Downloads AS t
     USING (SELECT @uid AS UserId, @bookId AS BookId) AS s
     ON t.UserId = s.UserId AND t.BookId = s.BookId
     WHEN MATCHED THEN UPDATE SET DownloadedAt = SYSDATETIME()
     WHEN NOT MATCHED THEN INSERT (UserId, BookId) VALUES (s.UserId, s.BookId);`,
    { uid: req.user.UserId, bookId },
  );
  res.status(204).end();
});

/** DELETE /api/me/downloads/:bookId — xóa bản tải về khỏi máy. */
router.delete('/downloads/:bookId', async (req, res) => {
  const bookId = parseId(req.params.bookId, 'bookId');
  await db.query('DELETE FROM dbo.Downloads WHERE UserId = @uid AND BookId = @bookId', {
    uid: req.user.UserId,
    bookId,
  });
  res.status(204).end();
});

// ---------------------------------------------------------------------------
// THIẾT BỊ NHẬN THÔNG BÁO ĐẨY (FCM)
// ---------------------------------------------------------------------------

const PLATFORMS = ['android', 'ios', 'web'];

function readToken(body) {
  const token = String(body.token || '').trim();
  if (!token || token.length > 512) throw badRequest('Mã thiết bị (token) không hợp lệ.');
  return token;
}

/**
 * PUT /api/me/device-token { token, platform } — ghi nhận thiết bị của người dùng hiện tại.
 * Token đã thuộc người khác (đăng nhập tài khoản khác trên cùng máy) được chuyển sang người này.
 */
router.put('/device-token', async (req, res) => {
  const token = readToken(req.body);
  const platform = PLATFORMS.includes(req.body.platform) ? req.body.platform : 'android';
  await db.query(
    `MERGE dbo.DeviceTokens AS t
     USING (SELECT @token AS Token) AS s ON t.Token = s.Token
     WHEN MATCHED THEN UPDATE SET UserId = @uid, Platform = @platform, UpdatedAt = SYSDATETIME()
     WHEN NOT MATCHED THEN INSERT (UserId, Token, Platform) VALUES (@uid, @token, @platform);`,
    { uid: req.user.UserId, token: { type: db.sql.VarChar(512), value: token }, platform },
  );
  res.status(204).end();
});

/** DELETE /api/me/device-token { token } — gỡ thiết bị khi đăng xuất. */
router.delete('/device-token', async (req, res) => {
  const token = readToken(req.body);
  await db.query('DELETE FROM dbo.DeviceTokens WHERE Token = @token AND UserId = @uid', {
    uid: req.user.UserId,
    token: { type: db.sql.VarChar(512), value: token },
  });
  res.status(204).end();
});

module.exports = router;
