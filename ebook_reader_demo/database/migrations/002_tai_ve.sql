/* =============================================================================
   Nâng cấp CSDL BookHubDB đã có (không xóa dữ liệu) – bổ sung ngày 02/11/2026:
     - Bảng Downloads: ghi nhận sách người dùng đã tải về máy để đọc offline.

   Cách chạy (chọn một):
     1. SSMS: mở file này -> Execute (F5).
     2. Backend: cd backend && npm run migrate
   Chạy lại nhiều lần vẫn an toàn (chỉ thêm khi chưa có).
   ============================================================================= */

USE BookHubDB;
GO

IF OBJECT_ID(N'dbo.Downloads', N'U') IS NULL
    CREATE TABLE dbo.Downloads (
        UserId        INT          NOT NULL,
        BookId        INT          NOT NULL,
        DownloadedAt  DATETIME2(0) NOT NULL CONSTRAINT DF_Downloads_DownloadedAt DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_Downloads       PRIMARY KEY (UserId, BookId),
        CONSTRAINT FK_Downloads_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId) ON DELETE CASCADE,
        CONSTRAINT FK_Downloads_Books FOREIGN KEY (BookId) REFERENCES dbo.Books (BookId) ON DELETE CASCADE
    );
GO
