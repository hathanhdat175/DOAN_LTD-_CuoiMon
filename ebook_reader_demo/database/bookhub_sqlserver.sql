/* =============================================================================
   BookHub - Ứng dụng đọc sách (Nhóm 10)
   Script tạo cơ sở dữ liệu BookHubDB trên Microsoft SQL Server (7 bảng).

   Cách chạy (chọn một):
     1. SSMS: File -> Open -> File... chọn file này -> Execute (F5).
     2. Backend: cd backend && npm run setup-db
        (chạy script này và tạo luôn file PDF mẫu cho các sách trong uploads/pdf).

   Script chạy lại được nhiều lần (xóa bảng cũ rồi tạo lại, dữ liệu mẫu được nạp lại).
   ============================================================================= */

IF DB_ID(N'BookHubDB') IS NULL
    CREATE DATABASE BookHubDB;
GO

USE BookHubDB;
GO

/* ---------- Xóa bảng cũ (theo thứ tự ngược với khóa ngoại) ---------- */
IF OBJECT_ID(N'dbo.vw_ApprovedBooks', N'V') IS NOT NULL DROP VIEW dbo.vw_ApprovedBooks;
IF OBJECT_ID(N'dbo.Downloads', N'U')       IS NOT NULL DROP TABLE dbo.Downloads;
IF OBJECT_ID(N'dbo.DeviceTokens', N'U')    IS NOT NULL DROP TABLE dbo.DeviceTokens;
IF OBJECT_ID(N'dbo.Notifications', N'U')   IS NOT NULL DROP TABLE dbo.Notifications;
IF OBJECT_ID(N'dbo.Favorites', N'U')       IS NOT NULL DROP TABLE dbo.Favorites;
IF OBJECT_ID(N'dbo.ReadingProgress', N'U') IS NOT NULL DROP TABLE dbo.ReadingProgress;
IF OBJECT_ID(N'dbo.Books', N'U')           IS NOT NULL DROP TABLE dbo.Books;
IF OBJECT_ID(N'dbo.Categories', N'U')      IS NOT NULL DROP TABLE dbo.Categories;
IF OBJECT_ID(N'dbo.Users', N'U')           IS NOT NULL DROP TABLE dbo.Users;
GO

/* ---------- 1. Users: người dùng của cả 3 vai trò ---------- */
CREATE TABLE dbo.Users (
    UserId        INT IDENTITY(1,1) NOT NULL,
    FullName      NVARCHAR(100)     NOT NULL,
    Email         VARCHAR(100)      NOT NULL,
    PasswordHash  VARCHAR(255)      NOT NULL,   -- mật khẩu đã mã hóa bằng bcrypt
    Role          VARCHAR(20)       NOT NULL,
    IsLocked      BIT               NOT NULL CONSTRAINT DF_Users_IsLocked  DEFAULT (0),
    CreatedAt     DATETIME2(0)      NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSDATETIME()),
    -- Mã thông báo mới nhất người dùng đã xem: thông báo có NotificationId lớn hơn là "chưa đọc".
    LastReadNotificationId INT      NOT NULL CONSTRAINT DF_Users_LastReadNotificationId DEFAULT (0),
    CONSTRAINT PK_Users       PRIMARY KEY (UserId),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT CK_Users_Role  CHECK (Role IN ('Reader', 'Publisher', 'Admin'))
);
GO

/* ---------- 2. Categories: thể loại sách ---------- */
CREATE TABLE dbo.Categories (
    CategoryId  INT IDENTITY(1,1) NOT NULL,
    Name        NVARCHAR(100)     NOT NULL,
    CreatedAt   DATETIME2(0)      NOT NULL CONSTRAINT DF_Categories_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Categories      PRIMARY KEY (CategoryId),
    CONSTRAINT UQ_Categories_Name UNIQUE (Name)
);
GO

/* ---------- 3. Books: sách do Publisher đăng, Admin duyệt ---------- */
CREATE TABLE dbo.Books (
    BookId        INT IDENTITY(1,1) NOT NULL,
    Title         NVARCHAR(200)     NOT NULL,
    Author        NVARCHAR(100)     NOT NULL,
    Description   NVARCHAR(MAX)     NULL,
    CategoryId    INT               NOT NULL,
    PublisherId   INT               NOT NULL,   -- người đăng (Users.Role = 'Publisher')
    PdfPath       VARCHAR(255)      NOT NULL,   -- đường dẫn file PDF trong thư mục uploads
    CoverPath     VARCHAR(255)      NULL,       -- đường dẫn ảnh bìa (NULL = ứng dụng tự vẽ bìa)
    TotalPages    INT               NOT NULL,
    Status        VARCHAR(20)       NOT NULL CONSTRAINT DF_Books_Status    DEFAULT ('Pending'),
    RejectReason  NVARCHAR(500)     NULL,       -- bắt buộc khi Status = 'Rejected'
    ReviewedBy    INT               NULL,       -- Admin đã duyệt / từ chối
    ReviewedAt    DATETIME2(0)      NULL,
    Views         INT               NOT NULL CONSTRAINT DF_Books_Views     DEFAULT (0),
    CreatedAt     DATETIME2(0)      NOT NULL CONSTRAINT DF_Books_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Books              PRIMARY KEY (BookId),
    CONSTRAINT FK_Books_Categories   FOREIGN KEY (CategoryId)  REFERENCES dbo.Categories (CategoryId),
    CONSTRAINT FK_Books_Publisher    FOREIGN KEY (PublisherId) REFERENCES dbo.Users (UserId),
    CONSTRAINT FK_Books_Reviewer     FOREIGN KEY (ReviewedBy)  REFERENCES dbo.Users (UserId),
    CONSTRAINT CK_Books_TotalPages   CHECK (TotalPages > 0),
    CONSTRAINT CK_Books_Views        CHECK (Views >= 0),
    CONSTRAINT CK_Books_Status       CHECK (Status IN ('Pending', 'Approved', 'Rejected')),
    CONSTRAINT CK_Books_RejectReason CHECK (Status <> 'Rejected' OR RejectReason IS NOT NULL)
);
GO

CREATE INDEX IX_Books_Status      ON dbo.Books (Status);
CREATE INDEX IX_Books_CategoryId  ON dbo.Books (CategoryId);
CREATE INDEX IX_Books_PublisherId ON dbo.Books (PublisherId);
GO

/* ---------- 4. ReadingProgress: trang đang đọc của từng người ---------- */
CREATE TABLE dbo.ReadingProgress (
    UserId       INT          NOT NULL,
    BookId       INT          NOT NULL,
    CurrentPage  INT          NOT NULL,
    UpdatedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_ReadingProgress_UpdatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_ReadingProgress       PRIMARY KEY (UserId, BookId),
    CONSTRAINT FK_ReadingProgress_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId) ON DELETE CASCADE,
    CONSTRAINT FK_ReadingProgress_Books FOREIGN KEY (BookId) REFERENCES dbo.Books (BookId) ON DELETE CASCADE,
    CONSTRAINT CK_ReadingProgress_Page  CHECK (CurrentPage >= 1)
);
GO

/* ---------- 5. Favorites: sách yêu thích ---------- */
CREATE TABLE dbo.Favorites (
    UserId     INT          NOT NULL,
    BookId     INT          NOT NULL,
    CreatedAt  DATETIME2(0) NOT NULL CONSTRAINT DF_Favorites_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Favorites       PRIMARY KEY (UserId, BookId),
    CONSTRAINT FK_Favorites_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId) ON DELETE CASCADE,
    CONSTRAINT FK_Favorites_Books FOREIGN KEY (BookId) REFERENCES dbo.Books (BookId) ON DELETE CASCADE
);
GO

/* ---------- 6. Notifications: thông báo do Admin gửi ----------
   RecipientId = NULL : thông báo hệ thống gửi đến toàn bộ người dùng.
   RecipientId = x    : thông báo riêng (ví dụ kết quả duyệt sách gửi cho Publisher). */
CREATE TABLE dbo.Notifications (
    NotificationId  INT IDENTITY(1,1) NOT NULL,
    Title           NVARCHAR(200)     NOT NULL,
    Body            NVARCHAR(1000)    NOT NULL,
    SentBy          INT               NOT NULL,
    RecipientId     INT               NULL,
    SentAt          DATETIME2(0)      NOT NULL CONSTRAINT DF_Notifications_SentAt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Notifications           PRIMARY KEY (NotificationId),
    CONSTRAINT FK_Notifications_Users     FOREIGN KEY (SentBy)      REFERENCES dbo.Users (UserId),
    CONSTRAINT FK_Notifications_Recipient FOREIGN KEY (RecipientId) REFERENCES dbo.Users (UserId)
);
GO

CREATE INDEX IX_Notifications_RecipientId ON dbo.Notifications (RecipientId);
GO

/* ---------- 7. DeviceTokens: mã thiết bị nhận thông báo đẩy (Firebase Cloud Messaging) ----------
   Ứng dụng gửi FCM token lên sau khi đăng nhập; máy chủ dùng để đẩy thông báo tới điện thoại.
   Một người dùng có thể có nhiều thiết bị; token hết hạn được máy chủ tự xóa. */
CREATE TABLE dbo.DeviceTokens (
    DeviceTokenId  INT IDENTITY(1,1) NOT NULL,
    UserId         INT               NOT NULL,
    Token          VARCHAR(512)      NOT NULL,
    Platform       VARCHAR(20)       NOT NULL CONSTRAINT DF_DeviceTokens_Platform  DEFAULT ('android'),
    UpdatedAt      DATETIME2(0)      NOT NULL CONSTRAINT DF_DeviceTokens_UpdatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_DeviceTokens        PRIMARY KEY (DeviceTokenId),
    CONSTRAINT UQ_DeviceTokens_Token  UNIQUE (Token),
    CONSTRAINT FK_DeviceTokens_Users  FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId) ON DELETE CASCADE,
    CONSTRAINT CK_DeviceTokens_Platform CHECK (Platform IN ('android', 'ios', 'web'))
);
GO

CREATE INDEX IX_DeviceTokens_UserId ON dbo.DeviceTokens (UserId);
GO

/* ---------- 8. Downloads: sách người dùng đã tải về máy để đọc offline ----------
   File PDF nằm trên điện thoại (sqflite + thư mục ứng dụng); bảng này ghi nhận trên máy chủ
   ai đã tải sách nào, lúc nào (xem lại trong SSMS, thống kê lượt tải). */
CREATE TABLE dbo.Downloads (
    UserId        INT          NOT NULL,
    BookId        INT          NOT NULL,
    DownloadedAt  DATETIME2(0) NOT NULL CONSTRAINT DF_Downloads_DownloadedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Downloads       PRIMARY KEY (UserId, BookId),
    CONSTRAINT FK_Downloads_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId) ON DELETE CASCADE,
    CONSTRAINT FK_Downloads_Books FOREIGN KEY (BookId) REFERENCES dbo.Books (BookId) ON DELETE CASCADE
);
GO

/* ---------- View: sách đã duyệt, dùng cho trang chủ của Reader ---------- */
CREATE VIEW dbo.vw_ApprovedBooks
AS
SELECT b.BookId, b.Title, b.Author, b.Description, b.CoverPath, b.TotalPages, b.Views, b.CreatedAt,
       c.CategoryId, c.Name AS CategoryName,
       u.FullName AS PublisherName
FROM dbo.Books AS b
JOIN dbo.Categories AS c ON c.CategoryId = b.CategoryId
JOIN dbo.Users AS u      ON u.UserId = b.PublisherId
WHERE b.Status = 'Approved';
GO

/* =============================================================================
   DỮ LIỆU MẪU
   Mật khẩu của mọi tài khoản mẫu: 123456 (đã băm bằng bcrypt, cost = 10).
   File PDF của sách mẫu được tạo bởi lệnh "npm run setup-db" trong thư mục backend.
   ============================================================================= */
DECLARE @pwd VARCHAR(255) = '$2b$10$LdAP3BfAvdMuaQ6rTjWXhuRzaf1CuETqrSMBr80uGd/fpDunNQYZW';
DECLARE @now DATETIME2(0) = SYSDATETIME();

SET IDENTITY_INSERT dbo.Users ON;
INSERT INTO dbo.Users (UserId, FullName, Email, PasswordHash, Role, IsLocked, CreatedAt) VALUES
(1, N'Hà Thành Đạt',        'reader@demo.com',    @pwd, 'Reader',    0, DATEADD(DAY, -40, @now)),
(2, N'Nguyễn Huy Gia Bảo',  'publisher@demo.com', @pwd, 'Publisher', 0, DATEADD(DAY, -35, @now)),
(3, N'Nguyễn Đắc Anh Khôi', 'admin@demo.com',     @pwd, 'Admin',     0, DATEADD(DAY, -60, @now)),
(4, N'Người đọc mẫu 01',    'reader01@demo.com',  @pwd, 'Reader',    0, DATEADD(DAY, -21, @now)),
(5, N'Người đọc mẫu 02',    'reader02@demo.com',  @pwd, 'Reader',    1, DATEADD(DAY, -12, @now)),
(6, N'Nhà xuất bản mẫu',    'nxb@demo.com',       @pwd, 'Publisher', 0, DATEADD(DAY, -18, @now));
SET IDENTITY_INSERT dbo.Users OFF;

SET IDENTITY_INSERT dbo.Categories ON;
INSERT INTO dbo.Categories (CategoryId, Name) VALUES
(1, N'Văn học'), (2, N'Công nghệ'), (3, N'Kỹ năng'), (4, N'Lịch sử'), (5, N'Thiếu nhi');
SET IDENTITY_INSERT dbo.Categories OFF;

SET IDENTITY_INSERT dbo.Books ON;
INSERT INTO dbo.Books (BookId, Title, Author, Description, CategoryId, PublisherId, PdfPath, CoverPath,
                       TotalPages, Status, RejectReason, ReviewedBy, ReviewedAt, Views, CreatedAt) VALUES
(1, N'Dế Mèn Phiêu Lưu Ký', N'Tô Hoài',
    N'Hành trình phiêu lưu của chú Dế Mèn qua nhiều vùng đất, gặp gỡ nhiều bạn bè và rút ra bài học về lòng nhân ái, sự khiêm tốn.',
    5, 2, 'uploads/pdf/sample-1.pdf', NULL, 24, 'Approved', NULL, 3, DATEADD(DAY, -29, @now), 1280, DATEADD(DAY, -30, @now)),
(2, N'Số Đỏ', N'Vũ Trọng Phụng',
    N'Tiểu thuyết trào phúng nổi tiếng của văn học Việt Nam, khắc họa xã hội thành thị đầu thế kỷ XX.',
    1, 2, 'uploads/pdf/sample-2.pdf', NULL, 32, 'Approved', NULL, 3, DATEADD(DAY, -27, @now), 964, DATEADD(DAY, -28, @now)),
(3, N'Tắt Đèn', N'Ngô Tất Tố',
    N'Tác phẩm hiện thực viết về cuộc sống cùng cực của người nông dân trước Cách mạng.',
    1, 6, 'uploads/pdf/sample-3.pdf', NULL, 20, 'Approved', NULL, 3, DATEADD(DAY, -25, @now), 742, DATEADD(DAY, -26, @now)),
(4, N'Truyện Kiều', N'Nguyễn Du',
    N'Kiệt tác truyện thơ Nôm gồm 3.254 câu lục bát, kể về cuộc đời nàng Thúy Kiều.',
    1, 6, 'uploads/pdf/sample-4.pdf', NULL, 40, 'Approved', NULL, 3, DATEADD(DAY, -24, @now), 1530, DATEADD(DAY, -25, @now)),
(5, N'Lập trình Flutter cơ bản', N'Nhóm 10',
    N'Tài liệu nhập môn Flutter và Dart: widget, layout, điều hướng, quản lý trạng thái và kết nối REST API.',
    2, 2, 'uploads/pdf/sample-5.pdf', NULL, 36, 'Approved', NULL, 3, DATEADD(DAY, -19, @now), 2110, DATEADD(DAY, -20, @now)),
(6, N'Nhập môn Cơ sở dữ liệu', N'Khoa CNTT',
    N'Các khái niệm nền tảng về mô hình quan hệ, chuẩn hóa dữ liệu và ngôn ngữ truy vấn SQL.',
    2, 6, 'uploads/pdf/sample-6.pdf', NULL, 28, 'Approved', NULL, 3, DATEADD(DAY, -17, @now), 835, DATEADD(DAY, -18, @now)),
(7, N'Cấu trúc dữ liệu và giải thuật', N'Khoa CNTT',
    N'Danh sách, ngăn xếp, hàng đợi, cây, đồ thị và các giải thuật sắp xếp, tìm kiếm thường dùng.',
    2, 6, 'uploads/pdf/sample-7.pdf', NULL, 44, 'Approved', NULL, 3, DATEADD(DAY, -14, @now), 1176, DATEADD(DAY, -15, @now)),
(8, N'Kỹ năng học tập hiệu quả', N'Nhóm 10',
    N'Phương pháp ghi chú, quản lý thời gian và ôn tập dành cho sinh viên.',
    3, 2, 'uploads/pdf/sample-8.pdf', NULL, 16, 'Approved', NULL, 3, DATEADD(DAY, -11, @now), 498, DATEADD(DAY, -12, @now)),
(9, N'Lịch sử Việt Nam giản lược', N'Nhóm 10',
    N'Tóm lược các giai đoạn chính của lịch sử Việt Nam từ thời dựng nước đến hiện đại.',
    4, 2, 'uploads/pdf/sample-9.pdf', NULL, 30, 'Approved', NULL, 3, DATEADD(DAY, -9, @now), 611, DATEADD(DAY, -10, @now)),
(10, N'Chí Phèo', N'Nam Cao',
    N'Truyện ngắn kinh điển về bi kịch bị cự tuyệt quyền làm người của một người nông dân.',
    1, 6, 'uploads/pdf/sample-10.pdf', NULL, 12, 'Approved', NULL, 3, DATEADD(DAY, -7, @now), 889, DATEADD(DAY, -8, @now)),
(11, N'Thiết kế giao diện di động', N'Nhóm 10',
    N'Nguyên tắc Material Design 3, bố cục, màu sắc và kiểu chữ cho ứng dụng di động.',
    2, 2, 'uploads/pdf/sample-11.pdf', NULL, 22, 'Pending', NULL, NULL, NULL, 0, DATEADD(DAY, -3, @now)),
(12, N'Kỹ năng thuyết trình', N'Nhà xuất bản mẫu',
    N'Cách chuẩn bị nội dung, thiết kế slide và trình bày trước đám đông.',
    3, 6, 'uploads/pdf/sample-12.pdf', NULL, 18, 'Pending', NULL, NULL, NULL, 0, DATEADD(DAY, -2, @now)),
(13, N'Tuyển tập bài tập SQL', N'Nhóm 10',
    N'Tuyển tập bài tập truy vấn SQL có lời giải.',
    2, 2, 'uploads/pdf/sample-13.pdf', NULL, 14, 'Rejected',
    N'File PDF bị lỗi ở trang 5–8, vui lòng tải lại file đầy đủ.', 3, DATEADD(DAY, -5, @now), 0, DATEADD(DAY, -6, @now));
SET IDENTITY_INSERT dbo.Books OFF;

INSERT INTO dbo.ReadingProgress (UserId, BookId, CurrentPage, UpdatedAt) VALUES
(1, 5, 14, @now),
(1, 4, 6,  DATEADD(DAY, -2, @now)),
(4, 1, 10, DATEADD(DAY, -1, @now)),
(4, 2, 3,  DATEADD(DAY, -3, @now)),
(4, 7, 20, DATEADD(DAY, -5, @now)),
(2, 4, 12, DATEADD(DAY, -4, @now)),
(6, 5, 8,  DATEADD(DAY, -6, @now)),
(6, 9, 2,  DATEADD(DAY, -12, @now)),
(3, 10, 5, DATEADD(DAY, -20, @now));

INSERT INTO dbo.Favorites (UserId, BookId) VALUES (1, 1), (1, 5), (4, 4);

INSERT INTO dbo.Downloads (UserId, BookId, DownloadedAt) VALUES (1, 5, DATEADD(DAY, -1, @now));

INSERT INTO dbo.Notifications (Title, Body, SentBy, RecipientId, SentAt) VALUES
(N'Chào mừng đến với BookHub',
 N'Thư viện sách điện tử của Nhóm 10. Chúc bạn có những giờ đọc sách thú vị!', 3, NULL, DATEADD(DAY, -1, @now)),
(N'Sách bị từ chối',
 N'Sách “Tuyển tập bài tập SQL” bị từ chối. Lý do: File PDF bị lỗi ở trang 5–8, vui lòng tải lại file đầy đủ.',
 3, 2, DATEADD(DAY, -5, @now));
GO

/* =============================================================================
   MỘT SỐ CÂU LỆNH MẪU MÀ BACKEND SỬ DỤNG
   (để trong khối chú thích để không làm thay đổi dữ liệu mẫu khi chạy cả file;
    muốn thử thì bôi đen từng câu lệnh rồi bấm Execute)
   =============================================================================


-- Trang chủ Reader: sách đã duyệt, lọc theo từ khóa và thể loại
SELECT * FROM dbo.vw_ApprovedBooks
WHERE (Title LIKE N'%Flutter%' OR Author LIKE N'%Flutter%')
ORDER BY CreatedAt DESC;

-- Admin duyệt sách
UPDATE dbo.Books
SET Status = 'Approved', RejectReason = NULL, ReviewedBy = 3, ReviewedAt = SYSDATETIME()
WHERE BookId = 11;

-- Lưu trang đang đọc (thêm mới nếu chưa có, cập nhật nếu đã có)
MERGE dbo.ReadingProgress AS t
USING (SELECT 1 AS UserId, 5 AS BookId, 15 AS CurrentPage) AS s
ON t.UserId = s.UserId AND t.BookId = s.BookId
WHEN MATCHED THEN
    UPDATE SET CurrentPage = s.CurrentPage, UpdatedAt = SYSDATETIME()
WHEN NOT MATCHED THEN
    INSERT (UserId, BookId, CurrentPage) VALUES (s.UserId, s.BookId, s.CurrentPage);

-- Dashboard Publisher: số sách theo trạng thái
SELECT Status, COUNT(*) AS SoSach, SUM(Views) AS LuotXem
FROM dbo.Books
WHERE PublisherId = 2
GROUP BY Status;

-- Thông báo của một người dùng (thông báo chung + thông báo riêng)
SELECT * FROM dbo.Notifications
WHERE RecipientId IS NULL OR RecipientId = 2
ORDER BY SentAt DESC;

-- Số thông báo chưa đọc của người dùng 2
SELECT COUNT(*) AS ChuaDoc
FROM dbo.Notifications AS n
JOIN dbo.Users AS u ON u.UserId = 2
WHERE (n.RecipientId IS NULL OR n.RecipientId = 2)
  AND n.NotificationId > u.LastReadNotificationId;

-- Đánh dấu đã đọc toàn bộ thông báo của người dùng 2
UPDATE dbo.Users
SET LastReadNotificationId = (SELECT ISNULL(MAX(NotificationId), 0) FROM dbo.Notifications
                              WHERE RecipientId IS NULL OR RecipientId = 2)
WHERE UserId = 2;
*/
