const express = require('express');
const db = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');
const { removeFile } = require('../middleware/upload');
const { toBook, toUser, toCategory, toNotification, BOOK_COLUMNS, BOOK_FROM } = require('../utils/mappers');
const { badRequest, notFound, conflict, parseId } = require('../utils/http-error');
const { sendPushInBackground } = require('../utils/push');

/** Chức năng của Admin: kiểm duyệt, người dùng, thể loại, thông báo, báo cáo. */
const router = express.Router();
router.use(authenticate, requireRole('Admin'));

const STATUSES = ['Pending', 'Approved', 'Rejected'];

async function loadBook(id) {
  const r = await db.query(`SELECT ${BOOK_COLUMNS} ${BOOK_FROM} WHERE b.BookId = @id`, { id });
  if (!r.recordset.length) throw notFound('Sách không tồn tại.');
  return r.recordset[0];
}

/** Gửi thông báo riêng cho một người dùng (kết quả duyệt sách). */
async function notifyUser(recipientId, senderId, title, body, data = {}) {
  await db.query(
    'INSERT INTO dbo.Notifications (Title, Body, SentBy, RecipientId) VALUES (@title, @body, @senderId, @recipientId)',
    { title, body, senderId, recipientId },
  );
  // Đồng thời đẩy thông báo tới điện thoại của người nhận (nếu đã bật FCM).
  sendPushInBackground(recipientId, title, body, data);
}

// ---------------------------------------------------------------------------
// TỔNG QUAN
// ---------------------------------------------------------------------------

/** GET /api/admin/stats — số liệu cho Dashboard Admin. */
router.get('/stats', async (_req, res) => {
  const r = await db.query(`
    SELECT
      (SELECT COUNT(*) FROM dbo.Users) AS Users,
      (SELECT COUNT(*) FROM dbo.Users WHERE IsLocked = 1) AS LockedUsers,
      (SELECT COUNT(*) FROM dbo.Categories) AS Categories,
      (SELECT COUNT(*) FROM dbo.Books WHERE Status = 'Pending') AS Pending,
      (SELECT COUNT(*) FROM dbo.Books WHERE Status = 'Approved') AS Approved,
      (SELECT COUNT(*) FROM dbo.Books WHERE Status = 'Rejected') AS Rejected,
      (SELECT ISNULL(SUM(Views), 0) FROM dbo.Books) AS Views`);
  const s = r.recordset[0];
  res.json({
    users: Number(s.Users),
    lockedUsers: Number(s.LockedUsers),
    categories: Number(s.Categories),
    pending: Number(s.Pending),
    approved: Number(s.Approved),
    rejected: Number(s.Rejected),
    views: Number(s.Views),
  });
});

// ---------------------------------------------------------------------------
// KIỂM DUYỆT SÁCH
// ---------------------------------------------------------------------------

/** GET /api/admin/books?status=Pending — danh sách sách theo trạng thái. */
router.get('/books', async (req, res) => {
  const status = req.query.status ? String(req.query.status) : null;
  if (status && !STATUSES.includes(status)) throw badRequest('Trạng thái không hợp lệ.');
  const result = await db.query(
    `SELECT ${BOOK_COLUMNS} ${BOOK_FROM}
     WHERE (@status IS NULL OR b.Status = @status)
     ORDER BY b.CreatedAt DESC, b.BookId DESC`,
    { status: { type: db.sql.VarChar(20), value: status } },
  );
  res.json(result.recordset.map(toBook));
});

/** PATCH /api/admin/books/:id/approve — duyệt sách, ghi người duyệt, báo cho Publisher. */
router.patch('/books/:id/approve', async (req, res) => {
  const id = parseId(req.params.id);
  const book = await loadBook(id);
  await db.query(
    `UPDATE dbo.Books
     SET Status = 'Approved', RejectReason = NULL, ReviewedBy = @adminId, ReviewedAt = SYSDATETIME()
     WHERE BookId = @id`,
    { id, adminId: req.user.UserId },
  );
  await notifyUser(
    Number(book.PublisherId),
    req.user.UserId,
    'Sách đã được duyệt',
    `Sách “${book.Title}” đã được duyệt và hiển thị cho người đọc.`,
    { type: 'book_approved', bookId: id },
  );
  res.json(toBook(await loadBook(id)));
});

/** PATCH /api/admin/books/:id/reject { reason } — từ chối kèm lý do. */
router.patch('/books/:id/reject', async (req, res) => {
  const id = parseId(req.params.id);
  const reason = String(req.body.reason || '').trim();
  if (!reason) throw badRequest('Vui lòng nhập lý do từ chối.');
  if (reason.length > 500) throw badRequest('Lý do tối đa 500 ký tự.');
  const book = await loadBook(id);
  await db.query(
    `UPDATE dbo.Books
     SET Status = 'Rejected', RejectReason = @reason, ReviewedBy = @adminId, ReviewedAt = SYSDATETIME()
     WHERE BookId = @id`,
    { id, reason, adminId: req.user.UserId },
  );
  await notifyUser(
    Number(book.PublisherId),
    req.user.UserId,
    'Sách bị từ chối',
    `Sách “${book.Title}” bị từ chối. Lý do: ${reason}`,
    { type: 'book_rejected', bookId: id },
  );
  res.json(toBook(await loadBook(id)));
});

/** DELETE /api/admin/books/:id — xóa bất kỳ sách nào. */
router.delete('/books/:id', async (req, res) => {
  const id = parseId(req.params.id);
  const book = await loadBook(id);
  await db.query('DELETE FROM dbo.Books WHERE BookId = @id', { id });
  removeFile(book.PdfPath);
  removeFile(book.CoverPath);
  res.status(204).end();
});

// ---------------------------------------------------------------------------
// NGƯỜI DÙNG
// ---------------------------------------------------------------------------

/** GET /api/admin/users?q= — danh sách người dùng. */
router.get('/users', async (req, res) => {
  const q = String(req.query.q || '').trim();
  const result = await db.query(
    `SELECT UserId, FullName, Email, Role, IsLocked, CreatedAt FROM dbo.Users
     WHERE @q = N'' OR FullName LIKE N'%' + @q + N'%' OR Email LIKE '%' + @q + '%'
     ORDER BY UserId`,
    { q },
  );
  res.json(result.recordset.map(toUser));
});

/** PATCH /api/admin/users/:id/lock { locked } — khóa / mở khóa (không áp dụng cho Admin). */
router.patch('/users/:id/lock', async (req, res) => {
  const id = parseId(req.params.id);
  const locked = req.body.locked === true || req.body.locked === 'true';
  const r = await db.query('SELECT Role FROM dbo.Users WHERE UserId = @id', { id });
  if (!r.recordset.length) throw notFound('Người dùng không tồn tại.');
  if (r.recordset[0].Role === 'Admin') throw badRequest('Không thể khóa tài khoản quản trị viên.');
  const result = await db.query(
    `UPDATE dbo.Users SET IsLocked = @locked
     OUTPUT inserted.UserId, inserted.FullName, inserted.Email, inserted.Role, inserted.IsLocked, inserted.CreatedAt
     WHERE UserId = @id`,
    { id, locked },
  );
  res.json(toUser(result.recordset[0]));
});

// ---------------------------------------------------------------------------
// THỂ LOẠI
// ---------------------------------------------------------------------------

function validateCategoryName(body) {
  const name = String(body.name || '').trim();
  if (!name) throw badRequest('Vui lòng nhập tên thể loại.');
  if (name.length > 100) throw badRequest('Tên thể loại tối đa 100 ký tự.');
  return name;
}

async function ensureUniqueName(name, exceptId = 0) {
  const r = await db.query('SELECT 1 FROM dbo.Categories WHERE Name = @name AND CategoryId <> @exceptId', {
    name,
    exceptId,
  });
  if (r.recordset.length) throw conflict('Tên thể loại đã tồn tại.');
}

/** POST /api/admin/categories { name } */
router.post('/categories', async (req, res) => {
  const name = validateCategoryName(req.body);
  await ensureUniqueName(name);
  const r = await db.query(
    'INSERT INTO dbo.Categories (Name) OUTPUT inserted.CategoryId, inserted.Name, inserted.CreatedAt VALUES (@name)',
    { name },
  );
  res.status(201).json(toCategory(r.recordset[0]));
});

/** PUT /api/admin/categories/:id { name } */
router.put('/categories/:id', async (req, res) => {
  const id = parseId(req.params.id);
  const name = validateCategoryName(req.body);
  await ensureUniqueName(name, id);
  const r = await db.query(
    'UPDATE dbo.Categories SET Name = @name OUTPUT inserted.CategoryId, inserted.Name, inserted.CreatedAt WHERE CategoryId = @id',
    { id, name },
  );
  if (!r.recordset.length) throw notFound('Thể loại không tồn tại.');
  res.json(toCategory(r.recordset[0]));
});

/** DELETE /api/admin/categories/:id — không cho xóa khi thể loại còn sách. */
router.delete('/categories/:id', async (req, res) => {
  const id = parseId(req.params.id);
  const used = await db.query('SELECT COUNT(*) AS N FROM dbo.Books WHERE CategoryId = @id', { id });
  if (Number(used.recordset[0].N) > 0) {
    throw conflict('Không thể xóa: thể loại này vẫn còn sách.');
  }
  const r = await db.query('DELETE FROM dbo.Categories WHERE CategoryId = @id', { id });
  if (!r.rowsAffected[0]) throw notFound('Thể loại không tồn tại.');
  res.status(204).end();
});

// ---------------------------------------------------------------------------
// THÔNG BÁO HỆ THỐNG
// ---------------------------------------------------------------------------

/** POST /api/admin/notifications { title, body } — gửi đến toàn bộ người dùng. */
router.post('/notifications', async (req, res) => {
  const title = String(req.body.title || '').trim();
  const body = String(req.body.body || '').trim();
  if (!title || !body) throw badRequest('Vui lòng nhập tiêu đề và nội dung thông báo.');
  if (title.length > 200) throw badRequest('Tiêu đề tối đa 200 ký tự.');
  if (body.length > 1000) throw badRequest('Nội dung tối đa 1000 ký tự.');
  const r = await db.query(
    `INSERT INTO dbo.Notifications (Title, Body, SentBy)
     OUTPUT inserted.NotificationId, inserted.Title, inserted.Body, inserted.SentAt, inserted.RecipientId
     VALUES (@title, @body, @uid)`,
    { title, body, uid: req.user.UserId },
  );
  sendPushInBackground(null, title, body, { type: 'system' });
  res.status(201).json(toNotification(r.recordset[0]));
});

// ---------------------------------------------------------------------------
// BÁO CÁO THỐNG KÊ
// ---------------------------------------------------------------------------

const DAY = 24 * 60 * 60 * 1000;
const WEEKDAYS = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

/** Chia khoảng thời gian thành các cột của biểu đồ. */
function buildBuckets(range, now) {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const buckets = [];
  if (range === '4w') {
    for (let i = 3; i >= 0; i--) {
      const end = new Date(today.getTime() + DAY - i * 7 * DAY);
      buckets.push({ label: `Tuần ${4 - i}`, start: new Date(end.getTime() - 7 * DAY), end });
    }
  } else if (range === '6m') {
    for (let i = 5; i >= 0; i--) {
      const start = new Date(today.getFullYear(), today.getMonth() - i, 1);
      const end = new Date(today.getFullYear(), today.getMonth() - i + 1, 1);
      buckets.push({ label: `Th${start.getMonth() + 1}`, start, end });
    }
  } else {
    for (let i = 6; i >= 0; i--) {
      const start = new Date(today.getTime() - i * DAY);
      buckets.push({ label: WEEKDAYS[start.getDay()], start, end: new Date(start.getTime() + DAY) });
    }
  }
  return buckets;
}

function countInto(buckets, dates) {
  return buckets.map((b) => dates.filter((d) => d >= b.start && d < b.end).length);
}

/**
 * GET /api/admin/reports?range=7d|4w|6m
 * - Lượt đọc: số lần cập nhật tiến độ đọc (ReadingProgress.UpdatedAt) trong từng khoảng.
 * - Sách mới: số sách được đăng (Books.CreatedAt) trong từng khoảng.
 */
router.get('/reports', async (req, res) => {
  const range = ['7d', '4w', '6m'].includes(req.query.range) ? req.query.range : '7d';
  const buckets = buildBuckets(range, new Date());
  const from = buckets[0].start;

  const [reads, uploads, top, roles] = await Promise.all([
    db.query('SELECT UpdatedAt AS D FROM dbo.ReadingProgress WHERE UpdatedAt >= @from', { from }),
    db.query('SELECT CreatedAt AS D FROM dbo.Books WHERE CreatedAt >= @from', { from }),
    db.query(`SELECT TOP 5 ${BOOK_COLUMNS} ${BOOK_FROM} WHERE b.Status = 'Approved' ORDER BY b.Views DESC`),
    db.query('SELECT Role, COUNT(*) AS N FROM dbo.Users GROUP BY Role'),
  ]);

  res.json({
    range,
    labels: buckets.map((b) => b.label),
    reads: countInto(
      buckets,
      reads.recordset.map((r) => new Date(r.D)),
    ),
    uploads: countInto(
      buckets,
      uploads.recordset.map((r) => new Date(r.D)),
    ),
    topBooks: top.recordset.map(toBook),
    usersByRole: Object.fromEntries(roles.recordset.map((r) => [r.Role, Number(r.N)])),
  });
});

module.exports = router;
