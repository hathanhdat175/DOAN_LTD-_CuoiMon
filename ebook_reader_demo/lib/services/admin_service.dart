import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api/bookhub_api.dart';
import 'app_store.dart';

/// Nghiệp vụ quản trị: duyệt sách, quản lý người dùng, thể loại, thông báo, báo cáo.
///
/// Gọi các API `/api/admin/...` (chỉ tài khoản vai trò Admin mới được phép).
class AdminService {
  AdminService(this._store);

  final AppStore _store;

  Listenable get changes => _store;

  BookHubApi get _api => _store.api;

  AdminStats get stats => _store.adminStats;
  List<AppUser> get users => _store.users;
  List<BookCategory> get categories => _store.categories;

  /// Tải toàn bộ dữ liệu cho các tab quản trị.
  Future<void> loadAll() async {
    final List<Object> results = await Future.wait<Object>(<Future<Object>>[
      _api.getAdminStats(),
      _api.getAdminBooks(),
      _api.getUsers(),
      _api.getCategories(),
    ]);
    _store.adminStats = results[0] as AdminStats;
    _store.adminBooks = results[1] as List<Book>;
    _store.users = results[2] as List<AppUser>;
    _store.categories = results[3] as List<BookCategory>;
    _store.commit();
  }

  Future<void> _refreshStats() async {
    _store.adminStats = await _api.getAdminStats();
    _store.commit();
  }

  List<Book> booksByStatus(BookStatus status) => _store.adminBooks.where((Book b) => b.status == status).toList();

  int countByStatus(BookStatus status) {
    switch (status) {
      case BookStatus.pending:
        return _store.adminStats.pending;
      case BookStatus.approved:
        return _store.adminStats.approved;
      case BookStatus.rejected:
        return _store.adminStats.rejected;
    }
  }

  void _replaceBook(Book book) {
    _store.adminBooks = <Book>[for (final Book b in _store.adminBooks) b.id == book.id ? book : b];
    _store.books.remove(book.id);
    _store.commit();
  }

  Future<void> approveBook(String bookId) async {
    _replaceBook(await _api.approveBook(bookId));
    await _refreshStats();
  }

  Future<void> rejectBook(String bookId, String reason) async {
    _replaceBook(await _api.rejectBook(bookId, reason.trim()));
    await _refreshStats();
  }

  Future<void> deleteBook(String bookId) async {
    await _api.adminDeleteBook(bookId);
    _store.adminBooks = _store.adminBooks.where((Book b) => b.id != bookId).toList();
    _store.books.remove(bookId);
    _store.catalog = _store.catalog.where((Book b) => b.id != bookId).toList();
    _store.commit();
    await _refreshStats();
  }

  Future<void> setLocked(String userId, bool locked) async {
    final AppUser updated = await _api.setUserLocked(userId, locked);
    _store.users = <AppUser>[for (final AppUser u in _store.users) u.id == userId ? updated : u];
    _store.commit();
    await _refreshStats();
  }

  int booksInCategory(String categoryId) {
    for (final BookCategory c in _store.categories) {
      if (c.id == categoryId) {
        return c.bookCount;
      }
    }
    return 0;
  }

  Future<void> _reloadCategories() async {
    _store.categories = await _api.getCategories();
    _store.commit();
  }

  Future<void> addCategory(String name) async {
    await _api.addCategory(name.trim());
    await _reloadCategories();
    await _refreshStats();
  }

  Future<void> renameCategory(String categoryId, String name) async {
    await _api.renameCategory(categoryId, name.trim());
    await _reloadCategories();
  }

  /// Máy chủ từ chối (409) nếu thể loại còn sách.
  Future<void> deleteCategory(String categoryId) async {
    await _api.deleteCategory(categoryId);
    await _reloadCategories();
    await _refreshStats();
  }

  Future<void> sendNotice(String title, String body) async {
    await _api.sendNotification(title.trim(), body.trim());
    _store.notices = await _api.getNotifications();
    _store.commit();
  }

  Future<AdminReport> report(ReportRange range) => _api.getReport(range);

  /// Sách đã duyệt có nhiều lượt xem nhất (tính từ danh sách đã tải).
  List<Book> topBooks(int count) {
    final List<Book> list = _store.adminBooks.where((Book b) => b.isApproved).toList()
      ..sort((Book a, Book b) => b.views.compareTo(a.views));
    return list.length > count ? list.sublist(0, count) : list;
  }
}
