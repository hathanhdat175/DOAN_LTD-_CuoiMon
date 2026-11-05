import '../models/models.dart';
import '../services/admin_service.dart';
import 'base_viewmodel.dart';

/// ViewModel cho các màn hình quản trị.
class AdminViewModel extends BaseViewModel {
  AdminViewModel(this._admin) : super(_admin.changes);

  final AdminService _admin;

  Future<void> loadAll() => load(_admin.loadAll);

  AdminStats get stats => _admin.stats;
  List<AppUser> get users => _admin.users;
  List<BookCategory> get categories => _admin.categories;

  List<Book> booksByStatus(BookStatus status) => _admin.booksByStatus(status);
  int countByStatus(BookStatus status) => _admin.countByStatus(status);
  Future<void> approveBook(String bookId) => _admin.approveBook(bookId);
  Future<void> rejectBook(String bookId, String reason) => _admin.rejectBook(bookId, reason);
  Future<void> deleteBook(String bookId) => _admin.deleteBook(bookId);

  Future<void> setLocked(String userId, bool locked) => _admin.setLocked(userId, locked);

  int booksInCategory(String categoryId) => _admin.booksInCategory(categoryId);
  Future<void> addCategory(String name) => _admin.addCategory(name);
  Future<void> renameCategory(String categoryId, String name) => _admin.renameCategory(categoryId, name);
  Future<void> deleteCategory(String categoryId) => _admin.deleteCategory(categoryId);

  Future<void> sendNotice(String title, String body) => _admin.sendNotice(title, body);
  Future<AdminReport> report(ReportRange range) => _admin.report(range);
  List<Book> topBooks(int count) => _admin.topBooks(count);
}
