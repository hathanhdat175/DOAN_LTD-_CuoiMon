import 'dart:async';
import 'dart:typed_data';

import '../models/models.dart';
import '../services/api/bookhub_api.dart';
import '../services/book_service.dart';
import '../services/local/local_cache.dart';
import 'base_viewmodel.dart';

/// ViewModel cho các màn hình của Reader (trang chủ, chi tiết, đọc sách...).
/// Publisher và Admin cũng dùng ViewModel này khi vào khu vực đọc sách.
class ReaderViewModel extends BaseViewModel {
  ReaderViewModel(this._books) : super(_books.changes);

  final BookService _books;

  AppUser? get currentUser => _books.currentUser;
  List<BookCategory> get categories => _books.categories;
  List<AppNotice> get notices => _books.notices;

  /// Đang ở chế độ ngoại tuyến (không gọi được máy chủ, chỉ đọc sách đã tải).
  bool offline = false;

  /// Tải dữ liệu khu vực đọc sách; mất mạng thì chuyển sang dữ liệu trên máy.
  Future<void> loadLibrary() async {
    // Người dùng khác đăng nhập: bỏ bộ lọc tìm kiếm của phiên trước.
    final String? uid = currentUser?.id;
    if (uid != _loadedFor) {
      _loadedFor = uid;
      _query = '';
      _categoryId = null;
      _debounce?.cancel();
    }
    await load(() async {
      try {
        await _books.loadLibrary();
        offline = false;
        // Làm mới khi đang lọc: tải lại đúng kết quả của bộ lọc đang hiện trên màn hình.
        if (_query.trim().isNotEmpty || _categoryId != null) {
          await _books.search(query: _query, categoryId: _categoryId);
        }
      } on ApiException catch (e) {
        if (!e.isNetworkError) {
          rethrow;
        }
        offline = true;
        await _books.loadOffline();
      }
    });
  }

  Future<void> loadNotices() async {
    try {
      await _books.loadNotices();
    } on ApiException {
      // Giữ danh sách cũ khi không tải được.
    }
  }

  // ----- Thông báo -----

  /// Số thông báo chưa đọc (huy hiệu trên tab Tài khoản và mục Thông báo).
  int get unreadNotices => _books.unreadNotices;

  /// Hỏi lại số thông báo chưa đọc; mất mạng thì giữ số cũ.
  Future<int> refreshUnread() async {
    try {
      return await _books.refreshUnread();
    } on ApiException {
      return _books.unreadNotices;
    }
  }

  /// Gửi mã thiết bị nhận thông báo đẩy lên máy chủ (dùng khi đã bật Firebase Cloud Messaging).
  Future<void> registerDevice(String token, String platform) => _books.registerDevice(token, platform);

  /// Gọi khi rời màn hình Thông báo: các thông báo vừa xem không còn hiện là "mới".
  void markLocalNoticesRead() => _books.markLocalNoticesRead();

  /// Đánh dấu đã đọc tất cả (gọi khi mở màn hình Thông báo).
  Future<void> markNoticesRead() async {
    try {
      await _books.markNoticesRead();
    } on ApiException {
      // Lần sau mở màn hình sẽ thử lại.
    }
  }

  // ----- Tìm kiếm -----

  String _query = '';
  String? _categoryId;
  Timer? _debounce;

  /// Người dùng của lần tải dữ liệu gần nhất.
  String? _loadedFor;
  bool searching = false;

  String get query => _query;
  String? get categoryId => _categoryId;

  /// Kết quả tra cứu gần nhất (sách đã duyệt).
  List<Book> get books => _books.catalog;

  /// Gọi API tìm sách; gõ phím liên tục thì chờ 300 ms mới gửi request.
  void search({String? query, String? categoryId, bool clearCategory = false, bool immediate = false}) {
    if (query != null) {
      _query = query;
    }
    if (clearCategory) {
      _categoryId = null;
    } else if (categoryId != null) {
      _categoryId = categoryId;
    }
    _debounce?.cancel();
    if (immediate) {
      _runSearch();
    } else {
      _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
    }
  }

  Future<void> _runSearch() async {
    searching = true;
    notifyListeners();
    try {
      await _books.search(query: _query, categoryId: _categoryId);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  /// Tìm sách trong danh sách đã tải (dùng cho kiểm thử và lọc nhanh).
  List<Book> searchBooks({String query = '', String? categoryId}) {
    final String q = query.trim().toLowerCase();
    return _books.catalog
        .where((Book b) =>
            b.isApproved &&
            (categoryId == null || b.categoryId == categoryId) &&
            (q.isEmpty || b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q)))
        .toList();
  }

  Book? bookById(String id) => _books.bookById(id);
  Future<Book> refreshBook(String id) => _books.refreshBook(id);
  String categoryName(String id) => _books.categoryName(id);
  String? coverUrl(Book book) => _books.coverUrl(book);

  // ----- Yêu thích -----

  bool isFavorite(String bookId) => _books.isFavorite(bookId);
  Future<void> toggleFavorite(String bookId) => _books.toggleFavorite(bookId);
  List<Book> get favoriteBooks => _books.favoriteBooks;

  // ----- Tải về -----

  bool isDownloaded(String bookId) => _books.isDownloaded(bookId);
  int get downloadCount => _books.downloadCount;
  List<DownloadedBook> get downloads => _books.downloads;

  /// Tiến độ tải file của từng sách (0..1), dùng để hiện thanh tiến trình.
  final Map<String, double> downloadProgress = <String, double>{};

  Future<void> download(Book book) async {
    downloadProgress[book.id] = 0;
    notifyListeners();
    try {
      await _books.download(book, onProgress: (int received, int total) {
        if (total > 0) {
          downloadProgress[book.id] = received / total;
          notifyListeners();
        }
      });
    } finally {
      downloadProgress.remove(book.id);
      notifyListeners();
    }
  }

  Future<void> removeDownload(String bookId) => _books.removeDownload(bookId);

  // ----- Đọc sách -----

  Future<Uint8List> openPdf(Book book) => _books.openPdf(book);
  int pageOf(String bookId) => _books.pageOf(bookId);
  Future<void> saveProgress(String bookId, int page) => _books.saveProgress(bookId, page);
  List<ReadingRecord> get history => _books.history;
  Future<void> increaseViews(String bookId) => _books.increaseViews(bookId);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
