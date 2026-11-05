/* =============================================================================
   Nâng cấp CSDL BookHubDB đã có (không xóa dữ liệu) – bổ sung ngày 23/10/2026:
     - Users.LastReadNotificationId: đánh dấu thông báo đã đọc / chưa đọc.
     - Bảng DeviceTokens: mã thiết bị nhận thông báo đẩy Firebase Cloud Messaging.

   Cách chạy (chọn một):
     1. SSMS: mở file này -> Execute (F5).
     2. Backend: cd backend && npm run migrate
   Chạy lại nhiều lần vẫn an toàn (chỉ thêm khi chưa có).
   ============================================================================= */

USE BookHubDB;
GO

IF COL_LENGTH(N'dbo.Users', N'LastReadNotificationId') IS NULL
    ALTER TABLE dbo.Users
        ADD LastReadNotificationId INT NOT NULL
            CONSTRAINT DF_Users_LastReadNotificationId DEFAULT (0);
GO

IF OBJECT_ID(N'dbo.DeviceTokens', N'U') IS NULL
BEGIN
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
    CREATE INDEX IX_DeviceTokens_UserId ON dbo.DeviceTokens (UserId);
END
GO
