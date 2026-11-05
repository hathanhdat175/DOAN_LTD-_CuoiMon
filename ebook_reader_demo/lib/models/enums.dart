// Các kiểu liệt kê (enum) dùng trong mô hình dữ liệu.

/// Ba vai trò người dùng trong hệ thống.
enum UserRole { reader, publisher, admin }

/// Trạng thái kiểm duyệt của một cuốn sách.
enum BookStatus { pending, approved, rejected }

extension UserRoleText on UserRole {
  /// Tên vai trò bằng tiếng Việt.
  String get label {
    switch (this) {
      case UserRole.reader:
        return 'Người đọc';
      case UserRole.publisher:
        return 'Người đăng';
      case UserRole.admin:
        return 'Quản trị viên';
    }
  }

  /// Tên vai trò theo tài liệu thiết kế (giá trị cột Users.Role).
  String get code {
    switch (this) {
      case UserRole.reader:
        return 'Reader';
      case UserRole.publisher:
        return 'Publisher';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

/// Đổi giá trị cột Users.Role thành [UserRole].
UserRole userRoleFromCode(String code) {
  for (final UserRole r in UserRole.values) {
    if (r.code == code) {
      return r;
    }
  }
  return UserRole.reader;
}

extension BookStatusText on BookStatus {
  String get label {
    switch (this) {
      case BookStatus.pending:
        return 'Chờ duyệt';
      case BookStatus.approved:
        return 'Đã duyệt';
      case BookStatus.rejected:
        return 'Bị từ chối';
    }
  }

  /// Giá trị cột Books.Status.
  String get code {
    switch (this) {
      case BookStatus.pending:
        return 'Pending';
      case BookStatus.approved:
        return 'Approved';
      case BookStatus.rejected:
        return 'Rejected';
    }
  }
}

/// Đổi giá trị cột Books.Status thành [BookStatus].
BookStatus bookStatusFromCode(String code) {
  for (final BookStatus s in BookStatus.values) {
    if (s.code == code) {
      return s;
    }
  }
  return BookStatus.pending;
}
