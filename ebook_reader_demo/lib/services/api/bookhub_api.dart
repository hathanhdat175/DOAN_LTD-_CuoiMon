import 'dart:typed_data';

import '../../models/models.dart';

/// Lỗi trả về từ máy chủ (hoặc lỗi mạng) kèm thông báo tiếng Việt cho người dùng.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;

  /// Mã HTTP (null = không kết nối được máy chủ).
  final int? statusCode;

  bool get isNetworkError => statusCode == null;
  bool get isUnauthorized => statusCode == 401;

  /// Bị tạm khóa / giới hạn do thao tác quá nhiều lần.
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => message;
}

/// Kết quả đăng nhập / đăng ký: JWT và thông tin người dùng.
class AuthResult {
  AuthResult({required this.token, required this.user});

  final String token;
  final AppUser user;
}

/// Hợp đồng giữa ứng dụng và máy chủ BookHub (tầng dữ liệu – BookHubDB).
///
/// - [RestBookHubApi]: gọi REST API Node.js/Express (kết nối SQL Server) bằng Dio.
/// - [MockBookHubApi]: dữ liệu giả lập trong bộ nhớ, dùng cho kiểm thử tự động
///   và chạy thử giao diện khi chưa bật máy chủ.
abstract class BookHubApi {
  /// JWT đính kèm vào mỗi request (null = chưa đăng nhập).
  String? get token;
  set token(String? value);

  /// Đổi đường dẫn tương đối của ảnh bìa (/uploads/cover/...) thành URL đầy đủ.
  String? resolveUrl(String? path);

  // ----- Xác thực -----
  Future<AuthResult> login(String email, String password);
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  });
  Future<AppUser> me();

  /// Đổi mật khẩu (cần mật khẩu hiện tại). Trả về token mới; token cũ trên các máy khác hết hiệu lực.
  Future<AuthResult> changePassword(String currentPassword, String newPassword);

  // ----- Reader (mọi vai trò) -----
  Future<List<BookCategory>> getCategories();
  Future<List<Book>> getBooks({String query = '', String? categoryId});
  Future<Book> getBook(String id);
  Future<int> addView(String id);
  Future<Uint8List> downloadPdf(String id, {void Function(int received, int total)? onProgress});
  Future<List<AppNotice>> getNotifications();

  /// Số thông báo chưa đọc (biểu tượng chuông / tab Tài khoản).
  Future<int> getUnreadCount();

  /// Đánh dấu đã đọc mọi thông báo hiện có.
  Future<void> markNotificationsRead();

  /// Ghi nhận / gỡ mã thiết bị nhận thông báo đẩy Firebase Cloud Messaging.
  Future<void> registerDevice(String token, String platform);
  Future<void> unregisterDevice(String token);
  Future<List<Book>> getFavorites();
  Future<void> setFavorite(String bookId, bool favorite);

  /// Ghi nhận lên máy chủ (bảng Downloads) việc tải / xóa bản tải về của một cuốn sách.
  Future<void> setDownloaded(String bookId, bool downloaded);
  Future<List<ReadingRecord>> getProgress();
  Future<ReadingRecord> saveProgress(String bookId, int page);

  // ----- Publisher -----
  Future<List<Book>> getMyBooks();
  Future<Book> createBook(BookDraft draft);
  Future<Book> updateBook(String id, BookDraft draft);
  Future<void> deleteMyBook(String id);

  // ----- Admin -----
  Future<AdminStats> getAdminStats();
  Future<List<Book>> getAdminBooks({BookStatus? status});
  Future<Book> approveBook(String id);
  Future<Book> rejectBook(String id, String reason);
  Future<void> adminDeleteBook(String id);
  Future<List<AppUser>> getUsers();
  Future<AppUser> setUserLocked(String id, bool locked);
  Future<BookCategory> addCategory(String name);
  Future<BookCategory> renameCategory(String id, String name);
  Future<void> deleteCategory(String id);
  Future<void> sendNotification(String title, String body);
  Future<AdminReport> getReport(ReportRange range);
}
