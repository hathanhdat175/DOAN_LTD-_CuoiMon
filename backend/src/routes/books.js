const fs = require('fs');
const path = require('path');
const express = require('express');
const config = require('../config');
const db = require('../db');
const { authenticate } = require('../middleware/auth');
const { toBook, toCategory, toNotification, BOOK_COLUMNS, BOOK_FROM } = require('../utils/mappers');
const { notFound, forbidden, parseId } = require('../utils/http-error');

const router = express.Router();

// Mọi chức năng đọc sách đều yêu cầu đăng nhập (kiểm tra tài khoản trước khi mở sách).
router.use(authenticate);

/** Lấy sách theo id; Reader chỉ thấy sách đã duyệt, chủ sách và Admin thấy mọi trạng thái. */
async function loadVisibleBook(req, id) {
  const result = await db.query(`SELECT ${BOOK_COLUMNS} ${BOOK_FROM} WHERE b.BookId = @id`, { id });
  const row = result.recordset[0];
  if (!row) {
    throw notFound('Sách không tồn tại hoặc đã bị gỡ.');
  }
  const canSeeAll = req.user.Role === 'Admin' || Number(row.PublisherId) === req.user.UserId;
  if (row.Status !== 'Approved' && !canSeeAll) {
    throw forbidden('Sách chưa được duyệt hoặc đã bị gỡ.');
  }
  return row;
}

/** GET /api/categories — danh sách thể loại kèm số sách đã duyệt. */
router.get('/categories', async (_req, res) => {
  const result = await db.query(`
    SELECT c.CategoryId, c.Name, c.CreatedAt,
           (SELECT COUNT(*) FROM dbo.Books b WHERE b.CategoryId = c.CategoryId) AS BookCount
    FROM dbo.Categories c
    ORDER BY c.Name`);
  res.json(result.recordset.map(toCategory));
});

/** GET /api/books?q=&categoryId= — tra cứu sách đã duyệt theo tên/tác giả và thể loại. */
router.get('/books', async (req, res) => {
  const q = String(req.query.q || '').trim();
  const categoryId = req.query.categoryId ? parseId(req.query.categoryId, 'categoryId') : null;
  const result = await db.query(
    `SELECT ${BOOK_COLUMNS} ${BOOK_FROM}
     WHERE b.Status = 'Approved'
       AND (@q = N'' OR b.Title LIKE N'%' + @q + N'%' OR b.Author LIKE N'%' + @q + N'%')
       AND (@categoryId IS NULL OR b.CategoryId = @categoryId)
     ORDER BY b.CreatedAt DESC, b.BookId DESC`,
    { q, categoryId: { type: db.sql.Int, value: categoryId } },
  );
  res.json(result.recordset.map(toBook));
});

/** GET /api/books/:id — chi tiết sách. */
router.get('/books/:id', async (req, res) => {
  const row = await loadVisibleBook(req, parseId(req.params.id));
  res.json(toBook(row));
});

/** POST /api/books/:id/view — tăng lượt xem khi mở đọc sách lần đầu. */
router.post('/books/:id/view', async (req, res) => {
  const id = parseId(req.params.id);
  await loadVisibleBook(req, id);
  const result = await db.query('UPDATE dbo.Books SET Views = Views + 1 OUTPUT inserted.Views WHERE BookId = @id', {
    id,
  });
  res.json({ views: Number(result.recordset[0].Views) });
});

/** GET /api/books/:id/file — nội dung PDF (đọc online hoặc tải về máy). */
router.get('/books/:id/file', async (req, res) => {
  const row = await loadVisibleBook(req, parseId(req.params.id));
  const full = path.resolve(config.rootDir, row.PdfPath);
  if (!full.startsWith(config.uploadDir) || !fs.existsSync(full)) {
    throw notFound('Không tìm thấy file PDF của sách trên máy chủ.');
  }
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `inline; filename="book-${row.BookId}.pdf"`);
  res.sendFile(full);
});

// ---------------------------------------------------------------------------
// THÔNG BÁO: thông báo hệ thống (RecipientId = NULL) và thông báo riêng của người dùng.
// Thông báo có NotificationId lớn hơn Users.LastReadNotificationId là "chưa đọc".
// ---------------------------------------------------------------------------

const VISIBLE_NOTICES = '(n.RecipientId IS NULL OR n.RecipientId = @uid)';

/** GET /api/notifications — 50 thông báo mới nhất, kèm cờ đã đọc. */
router.get('/notifications', async (req, res) => {
  const result = await db.query(
    `SELECT TOP 50 n.NotificationId, n.Title, n.Body, n.SentAt, n.RecipientId,
            CASE WHEN n.NotificationId <= u.LastReadNotificationId THEN 1 ELSE 0 END AS IsRead
     FROM dbo.Notifications AS n
     JOIN dbo.Users AS u ON u.UserId = @uid
     WHERE ${VISIBLE_NOTICES}
     ORDER BY n.SentAt DESC, n.NotificationId DESC`,
    { uid: req.user.UserId },
  );
  res.json(result.recordset.map(toNotification));
});

/** GET /api/notifications/unread-count — số thông báo chưa đọc (hiện trên biểu tượng chuông). */
router.get('/notifications/unread-count', async (req, res) => {
  const result = await db.query(
    `SELECT COUNT(*) AS N
     FROM dbo.Notifications AS n
     JOIN dbo.Users AS u ON u.UserId = @uid
     WHERE ${VISIBLE_NOTICES} AND n.NotificationId > u.LastReadNotificationId`,
    { uid: req.user.UserId },
  );
  res.json({ count: Number(result.recordset[0].N) });
});

/** POST /api/notifications/read-all — đánh dấu đã đọc mọi thông báo hiện có. */
router.post('/notifications/read-all', async (req, res) => {
  await db.query(
    `UPDATE dbo.Users
     SET LastReadNotificationId = (
       SELECT ISNULL(MAX(n.NotificationId), 0) FROM dbo.Notifications AS n WHERE ${VISIBLE_NOTICES})
     WHERE UserId = @uid`,
    { uid: req.user.UserId },
  );
  res.status(204).end();
});

module.exports = router;
