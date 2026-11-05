import '../models/models.dart';
import '../services/book_service.dart';
import 'base_viewmodel.dart';

/// ViewModel cho các màn hình của Publisher (tổng quan, sách của tôi, đăng sách).
class PublisherViewModel extends BaseViewModel {
  PublisherViewModel(this._books) : super(_books.changes);

  final BookService _books;

  AppUser? get currentUser => _books.currentUser;
  List<BookCategory> get categories => _books.categories;
  String categoryName(String id) => _books.categoryName(id);
  String? coverUrl(Book book) => _books.coverUrl(book);

  Future<void> loadMyBooks() => load(_books.loadMyBooks);

  /// Sách của Publisher đang đăng nhập, có thể lọc theo trạng thái.
  List<Book> myBooks({BookStatus? status}) => _books.booksOfPublisher(status: status);

  /// Số sách theo trạng thái và tổng lượt xem (cho Dashboard).
  int count(BookStatus status) => myBooks(status: status).length;
  int get totalViews => myBooks().fold<int>(0, (int sum, Book b) => sum + b.views);

  Future<Book> addBook(BookDraft draft) => _books.addBook(draft);
  Future<Book> updateBook(String id, BookDraft draft) => _books.updateBook(id, draft);
  Future<void> deleteBook(String bookId) => _books.deleteBook(bookId);
}
