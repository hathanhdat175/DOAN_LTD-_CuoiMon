/** Chuyển bản ghi SQL (PascalCase) thành JSON trả về cho ứng dụng (camelCase). */

/** Một số driver (msnodesqlv8) trả cột INT dưới dạng chuỗi, nên ép kiểu số cho chắc chắn. */
const num = (v) => (v === null || v === undefined ? v : Number(v));

function toUser(row) {
  return {
    id: num(row.UserId),
    fullName: row.FullName,
    email: row.Email,
    role: row.Role,
    isLocked: !!row.IsLocked,
    createdAt: row.CreatedAt,
  };
}

function toCategory(row) {
  return {
    id: num(row.CategoryId),
    name: row.Name,
    bookCount: num(row.BookCount ?? 0),
    createdAt: row.CreatedAt,
  };
}

/** Các cột cần SELECT để dựng một Book đầy đủ (kèm tên thể loại, người đăng). */
const BOOK_COLUMNS = `
  b.BookId, b.Title, b.Author, b.Description, b.CategoryId, c.Name AS CategoryName,
  b.PublisherId, u.FullName AS PublisherName, b.CoverPath, b.PdfPath, b.TotalPages,
  b.Status, b.RejectReason, b.ReviewedBy, b.ReviewedAt, b.Views, b.CreatedAt`;

const BOOK_FROM = `
  FROM dbo.Books AS b
  JOIN dbo.Categories AS c ON c.CategoryId = b.CategoryId
  JOIN dbo.Users AS u ON u.UserId = b.PublisherId`;

function toBook(row) {
  return {
    id: num(row.BookId),
    title: row.Title,
    author: row.Author,
    description: row.Description || '',
    categoryId: num(row.CategoryId),
    categoryName: row.CategoryName,
    publisherId: num(row.PublisherId),
    publisherName: row.PublisherName,
    coverUrl: row.CoverPath ? `/${row.CoverPath}` : null,
    totalPages: num(row.TotalPages),
    status: row.Status,
    rejectReason: row.RejectReason,
    reviewedAt: row.ReviewedAt,
    views: num(row.Views),
    createdAt: row.CreatedAt,
  };
}

function toNotification(row) {
  return {
    id: num(row.NotificationId),
    title: row.Title,
    body: row.Body,
    sentAt: row.SentAt,
    personal: row.RecipientId != null,
    isRead: !!row.IsRead,
  };
}

module.exports = { num, toUser, toCategory, toBook, toNotification, BOOK_COLUMNS, BOOK_FROM };
