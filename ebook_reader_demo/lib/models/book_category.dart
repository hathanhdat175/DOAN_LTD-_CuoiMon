import 'json.dart';

/// Thể loại sách (bảng Categories).
class BookCategory {
  BookCategory({required this.id, required this.name, this.bookCount = 0});

  factory BookCategory.fromJson(Map<String, dynamic> json) {
    return BookCategory(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      bookCount: parseInt(json['bookCount']),
    );
  }

  final String id;
  String name;

  /// Số sách thuộc thể loại (mọi trạng thái).
  int bookCount;
}
