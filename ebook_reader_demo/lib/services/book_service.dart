
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api/bookhub_api.dart';
import 'app_store.dart';
import 'local/local_cache.dart';

/// Nghiệp vụ về sách cho Reader và Publisher.
///
/// Gọi REST API (`GET /api/books`, `PUT /api/me/progress/:id`,
/// `POST /api/publisher/books` dạng multipart...) và ghi kết quả vào [AppStore].
/// Tiến độ đọc và sách đã tải được lưu thêm trên máy (sqflite) để đọc offline.
class BookService {
  BookService(this._store);

  final AppStore _store;

  Listenable get changes => _store;

  BookHubApi get _api => _store.api;
  AppUser? get currentUser => _store.currentUser;
  String get _uid => _store.currentUser?.id ?? '';

  List<BookCategory> get categories => _store.categories;
  List<AppNotice> get notices => _store.notices;
  List<Book> get catalog => _store.catalog;

  /// Đổi đường dẫn ảnh bìa thành URL đầy đủ của máy chủ.
  String? coverUrl(Book book) => _api.resolveUrl(book.coverUrl);

  Book? bookById(String id) => _store.books[id] ?? _store.downloads[id]?.book;

  String categoryName(String id) {
    for (final BookCategory c in _store.categories) {
      if (c.id == id) {
        return c.name;
      }
    }
    return 'Chưa phân loại';
  }

  // ---------------------------------------------------------------------------
  // READER
  // ---------------------------------------------------------------------------

  /// Tải dữ liệu cho khu vực đọc sách: thể loại, sách, yêu thích, lịch sử, thông báo.
  /// Trước đó đồng bộ các trang đọc đã lưu khi mất mạng.
  Future<void> loadLibrary() async {
    await _loadDownloads();
    await syncPendingProgress();
    final List<Object> results = await Future.wait<Object>(<Future<Object>>[
      _api.getCategories(),
      _api.getBooks(),
      _api.getFavorites(),
      _api.getProgress(),
      _api.getNotifications(),
    ]);
    _store.categories = results[0] as List<BookCategory>;
    _store.catalog = results[1] as List<Book>;
    _store.favorites = results[2] as List<Book>;
    _store.favoriteIds = _store.favorites.map((Book b) => b.id).toSet();
    _store.history = results[3] as List<ReadingRecord>;
    _store.notices = results[4] as List<AppNotice>;
    _store.remember(_store.catalog);
    _store.remember(_store.favorites);
    _store.remember(<Book>[
      for (final ReadingRecord r in _store.history)
        if (r.book != null) r.book!,
    ]);
    _store.commit();
  }

  /// Danh sách sách đã tải về máy (đọc được khi không có mạng).
  Future<void> _loadDownloads() async {
    if (_uid.isEmpty) {
      return;
    }
    final List<DownloadedBook> list = await _store.cache.downloads(_uid);
    _store.downloads = <String, DownloadedBook>{for (final DownloadedBook d in list) d.book.id: d};
  }

  /// Khi không gọi được máy chủ: dựng lịch sử đọc từ dữ liệu trên máy.
  Future<void> loadOffline() async {
    await _loadDownloads();
    final List<LocalProgress> local = await _store.cache.progress(_uid);
    final List<ReadingRecord> records = <ReadingRecord>[
      for (final LocalProgress p in local)
        if (bookById(p.bookId) != null)
          ReadingRecord(bookId: p.bookId, page: p.page, updatedAt: p.updatedAt, book: bookById(p.bookId)),
    ]..sort((ReadingRecord a, ReadingRecord b) => b.updatedAt.compareTo(a.updatedAt));
    if (records.isNotEmpty || _store.history.isEmpty) {
      _store.history = records;
    }
    _store.commit();
  }

  /// Tra cứu sách đã duyệt theo từ khóa (tên sách / tác giả) và thể loại.
  Future<List<Book>> search({String query = '', String? categoryId}) async {
    final List<Book> list = await _api.getBooks(query: query, categoryId: categoryId);
    _store.catalog = list;
    _store.remember(list);
    _store.commit();
    return list;
  }

  /// Lấy lại thông tin mới nhất của một cuốn sách.
  Future<Book> refreshBook(String id) async {
    final Book book = await _api.getBook(id);
    _store.remember(<Book>[book]);
    _store.commit();
    return book;
  }

  // ----- Thông báo -----

  int get unreadNotices => _store.unreadNotices;

  /// Tải danh sách thông báo và số thông báo chưa đọc.
  Future<void> loadNotices() async {
    final List<Object> results = await Future.wait<Object>(<Future<Object>>[
      _api.getNotifications(),
      _api.getUnreadCount(),
    ]);
    _store.notices = results[0] as List<AppNotice>;
    _store.unreadNotices = results[1] as int;
    _store.commit();
  }

  /// Hỏi máy chủ số thông báo chưa đọc (gọi định kỳ khi ứng dụng đang mở).
  /// Có thông báo mới thì tải lại danh sách để màn hình Tài khoản / Thông báo luôn mới.
  Future<int> refreshUnread() async {
    final int count = await _api.getUnreadCount();
    if (count != _store.unreadNotices) {
      final bool hasNew = count > _store.unreadNotices;
      _store.unreadNotices = count;
      if (hasNew) {
        _store.notices = await _api.getNotifications();
      }
      _store.commit();
    }
    return count;
  }

  /// Đánh dấu đã đọc mọi thông báo (khi mở màn hình Thông báo).
  Future<void> markNoticesRead() async {
    if (_store.unreadNotices == 0 && _store.notices.every((AppNotice n) => n.isRead)) {
      return;
    }
    await _api.markNotificationsRead();
    _store.unreadNotices = 0;
    _store.commit();
  }

  /// Cập nhật cờ đã đọc của danh sách thông báo trên máy (sau khi rời màn hình Thông báo,
  /// để các nơi khác như tab Tài khoản không còn hiện chấm "chưa đọc").
  void markLocalNoticesRead() {
    if (_store.unreadNotices > 0 || _store.notices.every((AppNotice n) => n.isRead)) {
      return;
    }
    for (final AppNotice n in _store.notices) {
      n.isRead = true;
    }
    _store.commit();
  }

  /// Ghi nhận thiết bị nhận thông báo đẩy (khi đã cấu hình Firebase Cloud Messaging).
  Future<void> registerDevice(String token, String platform) => _api.registerDevice(token, platform);

  // ----- Yêu thích -----

  bool isFavorite(String bookId) => _store.favoriteIds.contains(bookId);

  List<Book> get favoriteBooks => _store.favorites;

  /// Đổi trạng thái yêu thích ngay trên giao diện rồi gửi lên máy chủ;
  /// nếu máy chủ báo lỗi thì hoàn tác.
  Future<void> toggleFavorite(String bookId) async {
    final bool next = !isFavorite(bookId);
    final List<Book> before = List<Book>.of(_store.favorites);
    _applyFavorite(bookId, next);
    try {
      await _api.setFavorite(bookId, next);
    } on ApiException {
      _store.favorites = before;
      _store.favoriteIds = before.map((Book b) => b.id).toSet();
      _store.commit();
      rethrow;
    }
  }

  void _applyFavorite(String bookId, bool favorite) {
    if (favorite) {
      final Book? b = bookById(bookId);
      _store.favoriteIds.add(bookId);
      if (b != null && !_store.favorites.any((Book x) => x.id == bookId)) {
        _store.favorites = <Book>[b, ..._store.favorites];
      }
    } else {
      _store.favoriteIds.remove(bookId);
      _store.favorites = _store.favorites.where((Book x) => x.id != bookId).toList();
    }
    _store.commit();
  }

  // ----- Tải về / đọc offline -----

  bool isDownloaded(String bookId) => _store.downloads.containsKey(bookId);

  List<DownloadedBook> get downloads {
    final List<DownloadedBook> list = _store.downloads.values.toList()
      ..sort((DownloadedBook a, DownloadedBook b) => b.savedAt.compareTo(a.savedAt));
    return list;
  }

  int get downloadCount => _store.downloads.length;

  /// Tải file PDF về máy để đọc khi không có mạng.
  Future<void> download(Book book, {void Function(int received, int total)? onProgress}) async {
    final Uint8List bytes = await _api.downloadPdf(book.id, onProgress: onProgress);
    await _store.files.save(_uid, book.id, bytes);
    await _store.cache.saveDownload(_uid, book);
    _store.downloads[book.id] = DownloadedBook(book: book, savedAt: DateTime.now());
    _store.commit();
    // Ghi nhận lên SQL Server (bảng Downloads); file đã nằm trên máy nên lỗi ở bước này không chặn việc đọc offline.
    try {
      await _api.setDownloaded(book.id, true);
    } on ApiException {
      // Bỏ qua: lần tải lại sau sẽ ghi nhận.
    }
  }

  Future<void> removeDownload(String bookId) async {
    await _store.files.delete(_uid, bookId);
    await _store.cache.removeDownload(_uid, bookId);
    _store.downloads.remove(bookId);
    _store.commit();
    try {
      await _api.setDownloaded(bookId, false);
    } on ApiException {
      // Mất mạng: bản ghi trên máy chủ chỉ là thống kê, không ảnh hưởng ứng dụng.
    }
  }

  /// Nội dung PDF để mở trong trình đọc: ưu tiên bản đã tải về máy.
  Future<Uint8List> openPdf(Book book, {void Function(int received, int total)? onProgress}) async {
    if (isDownloaded(book.id)) {
      final Uint8List? local = await _store.files.read(_uid, book.id);
      if (local != null) {
        return local;
      }
    }
    return _api.downloadPdf(book.id, onProgress: onProgress);
  }

  // ----- Tiến độ đọc -----

  ReadingRecord? _record(String bookId) {
    for (final ReadingRecord r in _store.history) {
      if (r.bookId == bookId) {
        return r;
      }
    }
    return null;
  }

  /// Trang đang đọc (0 nếu chưa đọc).
  int pageOf(String bookId) => _record(bookId)?.page ?? 0;

  /// Lịch sử đọc của người dùng hiện tại, mới nhất đứng trước.
  List<ReadingRecord> get history => _store.history;

  /// Lưu trang đang đọc: ghi vào SQLite trên máy trước, sau đó gửi lệnh MERGE
  /// lên bảng ReadingProgress. Mất mạng thì giữ bản cục bộ để đồng bộ sau.
  Future<void> saveProgress(String bookId, int page) async {
    final Book? book = bookById(bookId);
    final ReadingRecord? r = _record(bookId);
    final ReadingRecord updated = ReadingRecord(bookId: bookId, page: page, updatedAt: DateTime.now(), book: book ?? r?.book);
    _store.history = <ReadingRecord>[updated, ..._store.history.where((ReadingRecord x) => x.bookId != bookId)];
    _store.commit();

    await _store.cache.saveProgress(_uid, bookId, page, synced: false);
    try {
      await _api.saveProgress(bookId, page);
      await _store.cache.markSynced(_uid, bookId);
    } on ApiException catch (e) {
      if (!e.isNetworkError) {
        rethrow;
      }
    }
  }

  /// Gửi các trang đọc đã lưu khi mất mạng lên máy chủ.
  Future<int> syncPendingProgress() async {
    if (_uid.isEmpty) {
      return 0;
    }
    int synced = 0;
    for (final LocalProgress p in await _store.cache.progress(_uid)) {
      if (p.synced) {
        continue;
      }
      try {
        await _api.saveProgress(p.bookId, p.page);
        await _store.cache.markSynced(_uid, p.bookId);
        synced++;
      } on ApiException catch (e) {
        if (e.isNetworkError) {
          break;
        }
        await _store.cache.markSynced(_uid, p.bookId); // sách đã bị gỡ: bỏ qua
      }
    }
    return synced;
  }

  /// Tăng lượt xem khi mở đọc sách lần đầu.
  Future<void> increaseViews(String bookId) async {
    try {
      final int views = await _api.addView(bookId);
      final Book? b = bookById(bookId);
      if (b != null) {
        b.views = views;
        _store.commit();
      }
    } on ApiException {
      // Không quan trọng nếu không cập nhật được lượt xem.
    }
  }

  // ---------------------------------------------------------------------------
  // PUBLISHER
  // ---------------------------------------------------------------------------

  Future<void> loadMyBooks() async {
    final List<Object> results = await Future.wait<Object>(<Future<Object>>[
      _api.getMyBooks(),
      _api.getCategories(),
      _api.getNotifications(),
    ]);
    _store.myBooks = results[0] as List<Book>;
    _store.categories = results[1] as List<BookCategory>;
    _store.notices = results[2] as List<AppNotice>;
    _store.commit();
  }

  List<Book> booksOfPublisher({BookStatus? status}) =>
      _store.myBooks.where((Book b) => status == null || b.status == status).toList();

  /// Đăng sách mới: trạng thái "Chờ duyệt" cho đến khi Admin xử lý.
  Future<Book> addBook(BookDraft draft) async {
    final Book book = await _api.createBook(draft);
    _store.myBooks = <Book>[book, ..._store.myBooks];
    _store.commit();
    return book;
  }

  /// Sửa sách: nội dung thay đổi nên sách quay lại "Chờ duyệt".
  Future<Book> updateBook(String id, BookDraft draft) async {
    final Book book = await _api.updateBook(id, draft);
    _store.myBooks = <Book>[for (final Book b in _store.myBooks) b.id == id ? book : b];
    _store.books.remove(id);
    _store.commit();
    return book;
  }

  /// Xóa sách của mình (tiến độ đọc, yêu thích xóa theo ON DELETE CASCADE).
  Future<void> deleteBook(String bookId) async {
    await _api.deleteMyBook(bookId);
    _store.myBooks = _store.myBooks.where((Book b) => b.id != bookId).toList();
    _forget(bookId);
  }

  void _forget(String bookId) {
    _store.books.remove(bookId);
    _store.catalog = _store.catalog.where((Book b) => b.id != bookId).toList();
    _store.favorites = _store.favorites.where((Book b) => b.id != bookId).toList();
    _store.favoriteIds.remove(bookId);
    _store.history = _store.history.where((ReadingRecord r) => r.bookId != bookId).toList();
    _store.commit();
  }
}
