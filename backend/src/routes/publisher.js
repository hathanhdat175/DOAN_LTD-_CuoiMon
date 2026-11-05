const express = require('express');
const db = require('../db');
const { authenticate, requireRole } = require('../middleware/auth');
const { bookUpload, relativePath, removeFile } = require('../middleware/upload');
const { countPdfPages } = require('../utils/pdf');
const { toBook, BOOK_COLUMNS, BOOK_FROM } = require('../utils/mappers');
const { badRequest, notFound, forbidden, parseId } = require('../utils/http-error');

/** Chức năng của Publisher: đăng, sửa, xóa, theo dõi sách của mình. */
const router = express.Router();
router.use(authenticate, requireRole('Publisher'));

/** Gỡ các file vừa tải lên nếu yêu cầu bị từ chối giữa chừng. */
function cleanupUploads(req) {
  for (const list of Object.values(req.files || {})) {
    for (const f of list) removeFile(relativePath(f));
  }
}

/** Kiểm tra dữ liệu form đăng / sửa sách. Trả về object đã chuẩn hóa. */
async function validateBookForm(body) {
  const title = String(body.title || '').trim();
  const author = String(body.author || '').trim();
  const description = String(body.description || '').trim();
  const categoryId = Number(body.categoryId);
  const totalPages = Number(body.totalPages);

  if (!title) throw badRequest('Vui lòng nhập tên sách.');
  if (title.length > 200) throw badRequest('Tên sách tối đa 200 ký tự.');
  if (!author) throw badRequest('Vui lòng nhập tác giả.');
  if (author.length > 100) throw badRequest('Tên tác giả tối đa 100 ký tự.');
  if (!Number.isInteger(totalPages) || totalPages < 1 || totalPages > 5000) {
    throw badRequest('Số trang phải là số nguyên từ 1 đến 5000.');
  }
  if (!Number.isInteger(categoryId)) throw badRequest('Vui lòng chọn thể loại.');
  const cat = await db.query('SELECT 1 FROM dbo.Categories WHERE CategoryId = @categoryId', { categoryId });
  if (!cat.recordset.length) throw badRequest('Thể loại không tồn tại.');

  return { title, author, description, categoryId, totalPages };
}

async function loadOwnBook(req, id) {
  const r = await db.query(`SELECT ${BOOK_COLUMNS} ${BOOK_FROM} WHERE b.BookId = @id`, { id });
  const row = r.recordset[0];
  if (!row) throw notFound('Sách không tồn tại.');
  if (Number(row.PublisherId) !== req.user.UserId) throw forbidden('Bạn chỉ được thao tác trên sách do mình đăng.');
  return row;
}

/** GET /api/publisher/books?status= — sách của tôi. */
router.get('/books', async (req, res) => {
  const status = req.query.status ? String(req.query.status) : null;
  const result = await db.query(
    `SELECT ${BOOK_COLUMNS} ${BOOK_FROM}
     WHERE b.PublisherId = @uid AND (@status IS NULL OR b.Status = @status)
     ORDER BY b.CreatedAt DESC, b.BookId DESC`,
    { uid: req.user.UserId, status: { type: db.sql.VarChar(20), value: status } },
  );
  res.json(result.recordset.map(toBook));
});

/** GET /api/publisher/stats — dashboard: số sách theo trạng thái và tổng lượt xem. */
router.get('/stats', async (req, res) => {
  const result = await db.query(
    `SELECT COUNT(*) AS Total,
            SUM(CASE WHEN Status = 'Approved' THEN 1 ELSE 0 END) AS Approved,
            SUM(CASE WHEN Status = 'Pending'  THEN 1 ELSE 0 END) AS Pending,
            SUM(CASE WHEN Status = 'Rejected' THEN 1 ELSE 0 END) AS Rejected,
            ISNULL(SUM(Views), 0) AS Views
     FROM dbo.Books WHERE PublisherId = @uid`,
    { uid: req.user.UserId },
  );
  const r = result.recordset[0];
  res.json({
    total: Number(r.Total || 0),
    approved: Number(r.Approved || 0),
    pending: Number(r.Pending || 0),
    rejected: Number(r.Rejected || 0),
    views: Number(r.Views || 0),
  });
});

/** POST /api/publisher/books (multipart: pdf, cover + các trường) — đăng sách, trạng thái Pending. */
router.post('/books', bookUpload, async (req, res) => {
  const pdf = req.files?.pdf?.[0];
  const cover = req.files?.cover?.[0];
  try {
    if (!pdf) throw badRequest('Vui lòng chọn file PDF của sách.');
    const form = await validateBookForm(req.body);
    const realPages = await countPdfPages(pdf.path);
    if (realPages === null) throw badRequest('File PDF bị lỗi hoặc không đọc được.');

    const result = await db.query(
      `INSERT INTO dbo.Books (Title, Author, Description, CategoryId, PublisherId, PdfPath, CoverPath, TotalPages)
       OUTPUT inserted.BookId
       VALUES (@title, @author, @description, @categoryId, @uid, @pdfPath, @coverPath, @totalPages)`,
      {
        ...form,
        totalPages: realPages,
        uid: req.user.UserId,
        pdfPath: relativePath(pdf),
        coverPath: { type: db.sql.VarChar(255), value: cover ? relativePath(cover) : null },
      },
    );
    const row = await loadOwnBook(req, Number(result.recordset[0].BookId));
    res.status(201).json(toBook(row));
  } catch (err) {
    cleanupUploads(req);
    throw err;
  }
});

/**
 * PUT /api/publisher/books/:id (multipart) — sửa sách của mình.
 * Nội dung thay đổi nên sách quay về Pending để Admin duyệt lại.
 * Trường removeCover=true để bỏ ảnh bìa hiện tại.
 */
router.put('/books/:id', bookUpload, async (req, res) => {
  const pdf = req.files?.pdf?.[0];
  const cover = req.files?.cover?.[0];
  try {
    const id = parseId(req.params.id);
    const old = await loadOwnBook(req, id);
    const form = await validateBookForm(req.body);

    let totalPages = form.totalPages;
    if (pdf) {
      const realPages = await countPdfPages(pdf.path);
      if (realPages === null) throw badRequest('File PDF bị lỗi hoặc không đọc được.');
      totalPages = realPages;
    } else {
      // Giữ file cũ nên số trang cũng giữ theo file cũ.
      totalPages = Number(old.TotalPages);
    }
    const removeCover = String(req.body.removeCover || '') === 'true';
    const coverPath = cover ? relativePath(cover) : removeCover ? null : old.CoverPath;
    const pdfPath = pdf ? relativePath(pdf) : old.PdfPath;

    await db.query(
      `UPDATE dbo.Books
       SET Title = @title, Author = @author, Description = @description, CategoryId = @categoryId,
           TotalPages = @totalPages, PdfPath = @pdfPath, CoverPath = @coverPath,
           Status = 'Pending', RejectReason = NULL, ReviewedBy = NULL, ReviewedAt = NULL
       WHERE BookId = @id`,
      {
        ...form,
        totalPages,
        id,
        pdfPath,
        coverPath: { type: db.sql.VarChar(255), value: coverPath },
      },
    );
    if (pdf) removeFile(old.PdfPath);
    if (old.CoverPath && old.CoverPath !== coverPath) removeFile(old.CoverPath);

    res.json(toBook(await loadOwnBook(req, id)));
  } catch (err) {
    cleanupUploads(req);
    throw err;
  }
});

/** DELETE /api/publisher/books/:id — xóa sách của mình (tiến độ, yêu thích xóa theo CASCADE). */
router.delete('/books/:id', async (req, res) => {
  const id = parseId(req.params.id);
  const old = await loadOwnBook(req, id);
  await db.query('DELETE FROM dbo.Books WHERE BookId = @id', { id });
  removeFile(old.PdfPath);
  removeFile(old.CoverPath);
  res.status(204).end();
});

module.exports = router;
