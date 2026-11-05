import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api/bookhub_api.dart';
import 'local/local_cache.dart';
import 'local/pdf_file_store.dart';
import 'local/token_storage.dart';

/// Kho dữ liệu dùng chung của ứng dụng (thay cho MockDatabase ở bản demo).
///
/// Giữ bản sao dữ liệu mới nhất lấy từ REST API để các màn hình đọc đồng bộ
/// (không phải chờ mạng mỗi lần vẽ lại). Mỗi khi Service ghi dữ liệu xong,
/// [commit] phát tín hiệu để mọi ViewModel đang lắng nghe cập nhật giao diện.
class AppStore extends ChangeNotifier {
  AppStore({
    required this.api,
    TokenStorage? tokens,
    LocalCache? cache,
    PdfFileStore? files,
  })  : tokens = tokens ?? MemoryTokenStorage(),
        cache = cache ?? MemoryLocalCache(),
        files = files ?? PdfFileStore();

  final BookHubApi api;
  final TokenStorage tokens;
  final LocalCache cache;
  final PdfFileStore files;

  /// Người dùng đang đăng nhập (null = chưa đăng nhập).
  AppUser? currentUser;

  // ----- Dữ liệu đọc sách (mọi vai trò) -----
  List<BookCategory> categories = <BookCategory>[];
  List<Book> catalog = <Book>[];
  List<Book> favorites = <Book>[];
  Set<String> favoriteIds = <String>{};
  List<ReadingRecord> history = <ReadingRecord>[];
  List<AppNotice> notices = <AppNotice>[];

  /// Số thông báo chưa đọc (hiện huy hiệu ở tab Tài khoản).
  int unreadNotices = 0;
  Map<String, DownloadedBook> downloads = <String, DownloadedBook>{};

  /// Mọi sách đã từng tải về từ API, tra theo id (dùng cho màn hình Chi tiết).
  final Map<String, Book> books = <String, Book>{};

  // ----- Publisher -----
  List<Book> myBooks = <Book>[];

  // ----- Admin -----
  AdminStats adminStats = const AdminStats();
  List<Book> adminBooks = <Book>[];
  List<AppUser> users = <AppUser>[];

  /// Ghi nhớ sách vào bảng tra cứu [books].
  void remember(Iterable<Book> list) {
    for (final Book b in list) {
      books[b.id] = b;
    }
  }

  /// Gọi sau mỗi lần ghi dữ liệu để báo cho các ViewModel cập nhật giao diện.
  void commit() => notifyListeners();

  /// Xóa toàn bộ dữ liệu của phiên đăng nhập (khi đăng xuất).
  void clearSession() {
    currentUser = null;
    api.token = null;
    categories = <BookCategory>[];
    catalog = <Book>[];
    favorites = <Book>[];
    favoriteIds = <String>{};
    history = <ReadingRecord>[];
    notices = <AppNotice>[];
    unreadNotices = 0;
    downloads = <String, DownloadedBook>{};
    books.clear();
    myBooks = <Book>[];
    adminStats = const AdminStats();
    adminBooks = <Book>[];
    users = <AppUser>[];
  }
}
