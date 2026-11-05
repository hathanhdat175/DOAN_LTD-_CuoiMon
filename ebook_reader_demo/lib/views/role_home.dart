import 'package:flutter/material.dart';

import '../models/models.dart';
import 'admin/admin_shell.dart';
import 'publisher/publisher_shell.dart';
import 'reader/reader_shell.dart';

/// Điều hướng theo vai trò: mỗi vai trò có một màn hình chính riêng.
Widget homeForRole(UserRole role) {
  switch (role) {
    case UserRole.reader:
      return const ReaderShell();
    case UserRole.publisher:
      return const PublisherShell();
    case UserRole.admin:
      return const AdminShell();
  }
}

/// Mở màn hình chính của [role] và xóa hết các màn hình trước đó
/// (để nút Back không quay lại màn hình đăng nhập).
void goToHome(BuildContext context, UserRole role) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (BuildContext _) => homeForRole(role)),
    (Route<dynamic> route) => false,
  );
}
