import 'dart:typed_data';

import 'book.dart';
import 'json.dart';

/// Số liệu Dashboard của Admin.
class AdminStats {
  const AdminStats({
    this.users = 0,
    this.lockedUsers = 0,
    this.categories = 0,
    this.pending = 0,
    this.approved = 0,
    this.rejected = 0,
    this.views = 0,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      users: parseInt(json['users']),
      lockedUsers: parseInt(json['lockedUsers']),
      categories: parseInt(json['categories']),
      pending: parseInt(json['pending']),
      approved: parseInt(json['approved']),
      rejected: parseInt(json['rejected']),
      views: parseInt(json['views']),
    );
  }

  final int users;
  final int lockedUsers;
  final int categories;
  final int pending;
  final int approved;
  final int rejected;
  final int views;
}

/// Khoảng thời gian của báo cáo thống kê.
enum ReportRange { days7, weeks4, months6 }

extension ReportRangeCode on ReportRange {
  String get code {
    switch (this) {
      case ReportRange.days7:
        return '7d';
      case ReportRange.weeks4:
        return '4w';
      case ReportRange.months6:
        return '6m';
    }
  }
}

/// Báo cáo thống kê theo thời gian (màn hình Báo cáo của Admin).
class AdminReport {
  const AdminReport({
    required this.labels,
    required this.reads,
    required this.uploads,
    required this.topBooks,
    this.usersByRole = const <String, int>{},
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) {
    final Object? roles = json['usersByRole'];
    return AdminReport(
      labels: (json['labels'] as List<dynamic>? ?? <dynamic>[]).map((dynamic e) => e.toString()).toList(),
      reads: parseIntList(json['reads']),
      uploads: parseIntList(json['uploads']),
      topBooks: (json['topBooks'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => Book.fromJson(e as Map<String, dynamic>))
          .toList(),
      usersByRole: roles is Map<String, dynamic>
          ? roles.map((String k, dynamic v) => MapEntry<String, int>(k, parseInt(v)))
          : const <String, int>{},
    );
  }

  final List<String> labels;
  final List<int> reads;
  final List<int> uploads;
  final List<Book> topBooks;
  final Map<String, int> usersByRole;
}

/// Một file người dùng chọn để tải lên (PDF hoặc ảnh bìa).
class UploadFile {
  const UploadFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Dữ liệu form Đăng / Sửa sách gửi lên máy chủ.
class BookDraft {
  const BookDraft({
    required this.title,
    required this.author,
    required this.description,
    required this.categoryId,
    required this.totalPages,
    this.pdf,
    this.cover,
    this.removeCover = false,
  });

  final String title;
  final String author;
  final String description;
  final String categoryId;
  final int totalPages;

  /// File PDF (bắt buộc khi đăng mới, tùy chọn khi sửa).
  final UploadFile? pdf;

  /// Ảnh bìa mới (null = giữ ảnh cũ).
  final UploadFile? cover;

  /// Bỏ ảnh bìa hiện tại khi sửa sách.
  final bool removeCover;
}
