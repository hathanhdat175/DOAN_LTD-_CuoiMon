/* =============================================================================
   Nâng cấp CSDL BookHubDB đã có (không xóa dữ liệu) – bổ sung ngày 05/11/2026:
   Bảo mật tài khoản.
     - Users.FailedLoginCount, Users.LockoutUntil: đếm số lần nhập sai mật khẩu liên tiếp,
       sai 5 lần thì tạm khóa đăng nhập 15 phút (chống dò mật khẩu).
     - Users.TokenVersion: tăng lên mỗi khi đổi mật khẩu -> các JWT cũ hết hiệu lực
       (đăng xuất khỏi các thiết bị khác).
     - Users.PasswordChangedAt, Users.LastLoginAt: thời điểm đổi mật khẩu / đăng nhập gần nhất.
     - Đổi mật khẩu các tài khoản mẫu từ 123456 sang Demo@123 (đạt chính sách mật khẩu mới:
       ít nhất 8 ký tự, có chữ hoa, chữ thường, chữ số và ký tự đặc biệt).
       Chỉ đổi tài khoản còn dùng mật khẩu 123456 mẫu; tài khoản đã tự đổi mật khẩu thì giữ nguyên.

   Cách chạy (chọn một):
     1. SSMS: mở file này -> Execute (F5).
     2. Backend: cd backend && npm run migrate
   Chạy lại nhiều lần vẫn an toàn (chỉ thêm khi chưa có).
   ============================================================================= */

USE BookHubDB;
GO

IF COL_LENGTH(N'dbo.Users', N'FailedLoginCount') IS NULL
    ALTER TABLE dbo.Users ADD FailedLoginCount INT NOT NULL
        CONSTRAINT DF_Users_FailedLoginCount DEFAULT (0);
GO

IF COL_LENGTH(N'dbo.Users', N'LockoutUntil') IS NULL
    ALTER TABLE dbo.Users ADD LockoutUntil DATETIME2(0) NULL;
GO

IF COL_LENGTH(N'dbo.Users', N'TokenVersion') IS NULL
    ALTER TABLE dbo.Users ADD TokenVersion INT NOT NULL
        CONSTRAINT DF_Users_TokenVersion DEFAULT (0);
GO

IF COL_LENGTH(N'dbo.Users', N'PasswordChangedAt') IS NULL
    ALTER TABLE dbo.Users ADD PasswordChangedAt DATETIME2(0) NULL;
GO

IF COL_LENGTH(N'dbo.Users', N'LastLoginAt') IS NULL
    ALTER TABLE dbo.Users ADD LastLoginAt DATETIME2(0) NULL;
GO

/* Mật khẩu mẫu: 123456 (cũ) -> Demo@123 (mới), băm bằng bcrypt. */
UPDATE dbo.Users
SET PasswordHash = '$2b$10$2s1C1tYrYJM69Vr/AzK9LOfxtZwYnLI5pjeLfRqJn1KqOApHABpkC'
WHERE PasswordHash = '$2b$10$LdAP3BfAvdMuaQ6rTjWXhuRzaf1CuETqrSMBr80uGd/fpDunNQYZW';
GO
