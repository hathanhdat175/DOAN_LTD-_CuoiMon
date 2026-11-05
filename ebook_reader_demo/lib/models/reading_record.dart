import 'book.dart';
import 'json.dart';

/// Tiến độ đọc của một người dùng với một cuốn sách (bảng ReadingProgress).
class ReadingRecord {
  ReadingRecord({
    required this.bookId,
    required this.page,
    required this.updatedAt,
    this.book,
  });

  factory ReadingRecord.fromJson(Map<String, dynamic> json) {
    final Object? book = json['book'];
    return ReadingRecord(
      bookId: json['bookId'].toString(),
      page: parseInt(json['currentPage'], 1),
      updatedAt: parseDate(json['updatedAt']),
      book: book is Map<String, dynamic> ? Book.fromJson(book) : null,
    );
  }

  final String bookId;
  int page;
  DateTime updatedAt;

  /// Thông tin sách đi kèm (API trả về cùng lịch sử đọc).
  Book? book;
}
